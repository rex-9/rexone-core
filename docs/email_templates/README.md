# Email templates

These provider-agnostic HTML templates are the source copy for transactional email providers such as Brevo or OneSignal.

Use the same template ID as the filename without `.html`. Placeholders use `{{snake_case}}` so the HTML can be pasted into most provider editors without Ruby or Rails dependencies.

Current templates:

- `email_confirmation`
- `password_reset`
- `payment_purchase_confirmation`
- `payment_failed`
- `payment_subscription_confirmation`
- `payment_subscription_canceled`
- `payment_subscription_resumed`
- `welcome`
- `sign_in_alert`

When creating provider-hosted templates, keep the provider template name/alias aligned with these IDs. Brevo numeric template IDs can be wired later if we want provider-side rendering only.
