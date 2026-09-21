# frozen_string_literal: true

# app/services/email_service/template_renderer.rb
require "erb"

module EmailService
  class TemplateRenderer
    DEFAULT_DISCLAIMER = "You are receiving this email as a registered user of RexOne."

    TEMPLATES = {
      "email_confirmation" => {
        subject: "Confirm your RexOne email",
        headline: "Confirm your email",
        body: "Use this code to confirm {{email}}.",
        highlight_key: :code,
        disclaimer: "If you did not request this, you can safely ignore this email."
      },
      "password_reset" => {
        subject: "Reset your RexOne passcode",
        headline: "Reset your passcode",
        body: "We received a passcode reset request for {{email}}.",
        cta_text: "Reset passcode",
        cta_url_key: :reset_url,
        disclaimer: "If you did not request a passcode reset, you can safely ignore this email."
      },
      "payment_purchase_confirmation" => {
        subject: "Payment confirmation",
        headline: "Payment successful",
        body: "Hi {{user_name}}, your payment for {{product_name}} was completed successfully.",
        details: ->(d) {
          items = {}
          items["Amount"] = d[:amount] if d[:amount].present?
          items["Date"] = d[:date] if d[:date].present?
          items
        },
        disclaimer: "Thank you for your business. You can review your transaction history anytime in your billing settings."
      },
      "payment_failed" => {
        subject: "Payment failed - action required",
        headline: "Payment failed",
        body: "Hi {{user_name}}, we could not process the payment for {{product_name}}.\n\nPlease update your payment method before {{due_date}} to avoid access interruption.",
        cta_text: "Update Payment Method",
        cta_url_key: :link,
        disclaimer: "If you have already updated your billing information, please disregard this notice."
      },
      "payment_subscription_confirmation" => {
        subject: "Subscription confirmation",
        headline: "Subscription activated",
        body: "Hi {{user_name}}, your {{period}} subscription to {{product_name}} is now active.",
        details: ->(d) {
          items = {}
          period_text = [ d[:current_period_start], d[:current_period_end] ].compact.join(" - ")
          items["Current period"] = period_text if period_text.present?
          items
        },
        disclaimer: "You can manage your subscription anytime in your account settings."
      },
      "payment_subscription_canceled" => {
        subject: "Subscription canceled",
        headline: "Subscription canceled",
        body: "Hi {{user_name}}, your subscription to {{product_name}} was canceled on {{canceled_on}}.\n\nYour access remains active until {{valid_until}}.",
        disclaimer: "You can resume your subscription anytime from your account settings."
      },
      "payment_subscription_resumed" => {
        subject: "Subscription resumed",
        headline: "Subscription resumed",
        body: "Hi {{user_name}}, your subscription to {{product_name}} has been resumed.\n\nYour current period ends on {{current_period_end}}.",
        disclaimer: "You can manage your subscription anytime in your account settings."
      },
      "welcome" => {
        subject: "Welcome to RexOne",
        headline: "Welcome to RexOne",
        body: "Hi {{user_name}}, thanks for joining RexOne. We are excited to have you here.",
        disclaimer: "You are receiving this email as a registered user of RexOne."
      },
      "sign_in_alert" => {
        subject: "Security alert: new sign-in",
        headline: "New sign-in detected",
        body: "Hi {{user_name}}, we noticed a new sign-in to your account at {{time}}.",
        disclaimer: "If this wasn't you, reset your passcode immediately to protect your account."
      }
    }.freeze

    SUBJECTS = TEMPLATES.transform_values { |config| config[:subject] }.freeze

    class << self
      # Renders a registered template
      def render(template_id, data = {})
        data = normalize_data(data)
        config = TEMPLATES[template_id.to_s]
        return nil unless config

        render_from_config(config, data)
      end

      # Generic Master Shell renderer for ad-hoc alerts, broadcasts, and campaigns
      def render_content(title:, body:, cta_text: nil, cta_url: nil, highlight: nil, details: nil, disclaimer: nil, data: {})
        data = normalize_data(data)

        # Merge direct arguments into data for placeholder replacement
        data[:title] ||= title
        data[:headline] ||= title
        data[:body] ||= body
        data[:cta_text] ||= cta_text if cta_text.present?
        data[:cta_url] ||= cta_url if cta_url.present?
        data[:highlight] ||= highlight if highlight.present?
        data[:disclaimer] ||= disclaimer if disclaimer.present?

        interpolated_title = interpolate_html(title, data)
        interpolated_body = format_body_text(interpolate_html(body, data))

        resolved_highlight = highlight.presence || data[:highlight].presence || data[:code].presence || data[:promo_code].presence
        highlight_html = build_highlight_html(resolved_highlight) if resolved_highlight.present?

        resolved_details = details.presence || data[:details]
        details_html = build_details_html(resolved_details, data) if resolved_details.present?

        resolved_cta_url = cta_url.presence || data[:cta_url].presence || data[:reset_url].presence || data[:link].presence
        resolved_cta_text = cta_text.presence || data[:cta_text].presence || "Open RexOne"
        cta_html = build_cta_html(resolved_cta_url, resolved_cta_text, data) if resolved_cta_url.present?

        resolved_disclaimer = disclaimer.presence || data[:disclaimer].presence || DEFAULT_DISCLAIMER
        interpolated_disclaimer = interpolate_html(resolved_disclaimer, data)

        build_master_layout(
          subject: interpolate_plain(title, data),
          headline: interpolated_title,
          body_html: interpolated_body,
          highlight_html: highlight_html,
          details_html: details_html,
          cta_html: cta_html,
          disclaimer: interpolated_disclaimer
        )
      end

      def subject(template_id, data = {})
        data = normalize_data(data)
        raw_subject = data[:subject].presence || data["subject"].presence || SUBJECTS[template_id.to_s] || template_id.to_s.tr("_", " ").titleize
        interpolate_plain(raw_subject, data)
      end

      # Legacy placeholder replacement (kept for backwards compatibility with any direct calls)
      def replace_placeholders(content, data)
        return "" if content.blank?

        data = normalize_data(data)
        content.to_s.gsub(/\{\{([a-zA-Z0-9_]+)\}\}/) do
          key = $1
          raw_value = data[key.to_sym] || data[key] || ""
          ERB::Util.html_escape(raw_value.to_s)
        end
      end

      # Interpolates placeholders with HTML-escaped values while also escaping literal input text
      def interpolate_html(content, data)
        return "" if content.blank?

        data = normalize_data(data)
        tokens = content.to_s.split(/(\{\{[a-zA-Z0-9_]+\}\})/)
        tokens.map do |token|
          if token =~ /\A\{\{([a-zA-Z0-9_]+)\}\}\z/
            key = $1
            raw_value = data[key.to_sym] || data[key] || ""
            ERB::Util.html_escape(raw_value.to_s)
          else
            ERB::Util.html_escape(token)
          end
        end.join
      end

      # Interpolates placeholders without escaping (useful for email subjects and raw URLs)
      def interpolate_plain(content, data)
        return "" if content.blank?

        data = normalize_data(data)
        content.to_s.gsub(/\{\{([a-zA-Z0-9_]+)\}\}/) do
          key = $1
          (data[key.to_sym] || data[key] || "").to_s
        end
      end

      private

      def normalize_data(data)
        return {}.with_indifferent_access unless data.is_a?(Hash)

        data.respond_to?(:with_indifferent_access) ? data.with_indifferent_access : data.dup
      end

      def render_from_config(config, data)
        headline = interpolate_html(config[:headline], data)
        body_html = format_body_text(interpolate_html(config[:body], data))

        # 1. Highlight box (e.g. OTP code or Promo code)
        highlight_key = config[:highlight_key]
        raw_highlight = highlight_key ? (data[highlight_key] || data[highlight_key.to_s]) : data[:highlight]
        highlight_html = build_highlight_html(raw_highlight) if raw_highlight.present?

        # 2. Key-value details table
        details_builder = config[:details]
        raw_details = details_builder.respond_to?(:call) ? details_builder.call(data) : config[:details]
        details_html = build_details_html(raw_details, data) if raw_details.present?

        # 3. Call to Action Button
        cta_url_key = config[:cta_url_key]
        raw_cta_url = cta_url_key ? (data[cta_url_key] || data[cta_url_key.to_s]) : (data[:cta_url] || data[:link])
        cta_text = config[:cta_text].presence || data[:cta_text].presence || "Continue"
        cta_html = build_cta_html(raw_cta_url, cta_text, data) if raw_cta_url.present?

        # 4. Disclaimer
        disclaimer = interpolate_html(config[:disclaimer].presence || DEFAULT_DISCLAIMER, data)

        build_master_layout(
          subject: subject_for_config(config, data),
          headline: headline,
          body_html: body_html,
          highlight_html: highlight_html,
          details_html: details_html,
          cta_html: cta_html,
          disclaimer: disclaimer
        )
      end

      def subject_for_config(config, data)
        raw_subject = data[:subject].presence || config[:subject]
        interpolate_plain(raw_subject, data)
      end

      def format_body_text(text)
        return "" if text.blank?

        paragraphs = text.to_s.split(/\n\n+/)
        if paragraphs.size > 1
          paragraphs.map { |p| "<p style=\"margin:0 0 14px 0;line-height:1.6;\">#{p.gsub("\n", "<br/>")}</p>" }.join
        else
          text.gsub("\n", "<br/>")
        end
      end

      def build_highlight_html(raw_value)
        escaped = ERB::Util.html_escape(raw_value.to_s)
        <<~HTML
          <tr>
            <td style="padding:24px 0;">
              <div style="font-size:32px;letter-spacing:8px;font-weight:700;color:#ffffff;background:#12040a;border:1px solid #ff3048;border-radius:14px;padding:18px;text-align:center;box-shadow:0 0 20px rgba(255,48,72,0.2);">
                #{escaped}
              </div>
            </td>
          </tr>
        HTML
      end

      def build_details_html(details_hash, data)
        return "" unless details_hash.is_a?(Hash) && details_hash.compact.present?

        rows = details_hash.compact.map do |key, val|
          escaped_key = ERB::Util.html_escape(key.to_s)
          escaped_val = ERB::Util.html_escape(interpolate_plain(val.to_s, data))
          <<~HTML
            <tr>
              <td style="padding:8px 0;color:#b9a7af;font-size:14px;">#{escaped_key}</td>
              <td align="right" style="padding:8px 0;color:#ffffff;font-weight:600;font-size:14px;">#{escaped_val}</td>
            </tr>
          HTML
        end.join

        <<~HTML
          <tr>
            <td style="padding:20px 0;">
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#12040a;border:1px solid #360c18;border-radius:14px;padding:16px;color:#f8f4f6;">
                #{rows}
              </table>
            </td>
          </tr>
        HTML
      end

      def build_cta_html(raw_url, raw_text, data)
        resolved_url = interpolate_plain(raw_url.to_s, data).strip
        return "" if resolved_url.blank?

        resolved_url = AppConfig.client_url(resolved_url) if defined?(AppConfig)
        escaped_url = ERB::Util.html_escape(resolved_url)
        escaped_text = ERB::Util.html_escape(interpolate_plain(raw_text.to_s, data))

        <<~HTML
          <tr>
            <td style="padding:24px 0;">
              <table role="presentation" cellpadding="0" cellspacing="0">
                <tr>
                  <td align="center" style="border-radius:12px;background:#ff3048;">
                    <a href="#{escaped_url}" style="display:inline-block;padding:14px 28px;font-family:Arial,Helvetica,sans-serif;font-size:15px;font-weight:700;color:#ffffff;text-decoration:none;border-radius:12px;">
                      #{escaped_text}
                    </a>
                  </td>
                </tr>
              </table>
            </td>
          </tr>
          <tr>
            <td style="font-size:13px;line-height:1.6;color:#b9a7af;">
              If the button does not work, copy and paste this link into your browser:<br/>
              <a href="#{escaped_url}" style="color:#ff6b7d;text-decoration:none;word-break:break-all;">#{escaped_url}</a>
            </td>
          </tr>
        HTML
      end

      def build_master_layout(subject:, headline:, body_html:, highlight_html:, details_html:, cta_html:, disclaimer:)
        <<~HTML
          <!doctype html>
          <html>
            <head>
              <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
              <meta http-equiv="Content-Type" content="text/html; charset=UTF-8"/>
              <title>#{ERB::Util.html_escape(subject)}</title>
            </head>
            <body style="margin:0;padding:0;background:#14040b;color:#f8f4f6;font-family:Arial,Helvetica,sans-serif;-webkit-font-smoothing:antialiased;">
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#14040b;padding:32px 16px;">
                <tr>
                  <td align="center">
                    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:560px;background:#210912;border:1px solid #5a1020;border-radius:18px;padding:32px 28px;box-shadow:0 8px 32px rgba(255,48,72,0.08);">
                      <!-- Brand Header -->
                      <tr>
                        <td style="padding-bottom:24px;border-bottom:1px solid #360c18;">
                          <table role="presentation" width="100%" cellpadding="0" cellspacing="0">
                            <tr>
                              <td style="font-size:20px;font-weight:900;letter-spacing:1px;color:#ff3048;">
                                REX<span style="color:#ffffff;">ONE</span>
                              </td>
                              <td align="right" style="font-size:12px;color:#b9a7af;letter-spacing:0.5px;text-transform:uppercase;">
                                ALERT CENTER
                              </td>
                            </tr>
                          </table>
                        </td>
                      </tr>

                      <!-- Headline -->
                      #{headline.present? ? %(<tr><td style="padding-top:24px;font-size:22px;font-weight:700;line-height:1.3;color:#ffffff;">#{headline}</td></tr>) : ""}

                      <!-- Main Body Message -->
                      <tr>
                        <td style="padding-top:16px;font-size:15px;line-height:1.6;color:#e6d9df;">
                          #{body_html}
                        </td>
                      </tr>

                      <!-- Highlight Callout (Code / Promo) -->
                      #{highlight_html}

                      <!-- Key-Value Details Grid -->
                      #{details_html}

                      <!-- Action Button -->
                      #{cta_html}

                      <!-- Footer / Disclaimer -->
                      <tr>
                        <td style="padding-top:28px;border-top:1px solid #360c18;margin-top:24px;">
                          <table role="presentation" width="100%" cellpadding="0" cellspacing="0">
                            <tr>
                              <td style="font-size:12px;line-height:1.6;color:#b9a7af;">
                                #{disclaimer}
                              </td>
                            </tr>
                            <tr>
                              <td style="padding-top:12px;font-size:11px;color:#78666f;">
                                &copy; 2026 RexOne Ecosystem. All rights reserved.
                              </td>
                            </tr>
                          </table>
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>
              </table>
            </body>
          </html>
        HTML
      end
    end
  end
end
