# frozen_string_literal: true

module AnalyticsService
  class Overview
    class << self
      def call(...)
        new(...).call
      end
    end

    attr_reader :period, :start_date, :end_date, :time_range, :prev_time_range, :grain

    def initialize(period: AnalyticsConstants::Period::THIRTY_DAYS, start_date: nil, end_date: nil)
      @period     = period.to_s.presence || AnalyticsConstants::Period::THIRTY_DAYS
      @start_date = start_date
      @end_date   = end_date
      resolve_time_ranges!
    end

    def call
      {
        period: period,
        start_date: time_range.begin.iso8601,
        end_date: time_range.end.iso8601,
        grain: grain,
        kpis: build_kpis,
        time_series: build_time_series,
        breakdowns: build_breakdowns
      }
    end

    private

    def resolve_time_ranges!
      now = Time.current.utc

      if start_date.present? && end_date.present?
        s_date = parse_utc(start_date, fallback: 29.days.ago(now).beginning_of_day)
        e_date = parse_utc(end_date, fallback: now.end_of_day)
        @time_range = s_date..e_date
        duration = @time_range.end - @time_range.begin
        @prev_time_range = (@time_range.begin - duration)..@time_range.begin
        days_count = ((@time_range.end - @time_range.begin) / 1.day).round
        @grain = days_count > 90 ? AnalyticsConstants::Grain::MONTHLY : (days_count <= 2 ? AnalyticsConstants::Grain::HOURLY : AnalyticsConstants::Grain::DAILY)
        return
      end

      case period
      when AnalyticsConstants::Period::TODAY
        @time_range = now.beginning_of_day..now.end_of_day
        @prev_time_range = 1.day.ago(now).beginning_of_day..1.day.ago(now).end_of_day
        @grain = AnalyticsConstants::Grain::HOURLY
      when AnalyticsConstants::Period::YESTERDAY
        yesterday = 1.day.ago(now)
        @time_range = yesterday.beginning_of_day..yesterday.end_of_day
        @prev_time_range = 2.days.ago(now).beginning_of_day..2.days.ago(now).end_of_day
        @grain = AnalyticsConstants::Grain::HOURLY
      when AnalyticsConstants::Period::SEVEN_DAYS
        @time_range = 6.days.ago(now).beginning_of_day..now.end_of_day
        @prev_time_range = 13.days.ago(now).beginning_of_day..7.days.ago(now).end_of_day
        @grain = AnalyticsConstants::Grain::DAILY
      when AnalyticsConstants::Period::THIS_MONTH
        @time_range = now.beginning_of_month..now.end_of_month
        @prev_time_range = 1.month.ago(now).beginning_of_month..1.month.ago(now).end_of_month
        @grain = AnalyticsConstants::Grain::DAILY
      when AnalyticsConstants::Period::LAST_MONTH
        last_m = 1.month.ago(now)
        @time_range = last_m.beginning_of_month..last_m.end_of_month
        @prev_time_range = 2.months.ago(now).beginning_of_month..2.months.ago(now).end_of_month
        @grain = AnalyticsConstants::Grain::DAILY
      when AnalyticsConstants::Period::THIS_YEAR
        @time_range = now.beginning_of_year..now.end_of_year
        @prev_time_range = 1.year.ago(now).beginning_of_year..1.year.ago(now).end_of_year
        @grain = AnalyticsConstants::Grain::MONTHLY
      when AnalyticsConstants::Period::LAST_YEAR
        last_y = 1.year.ago(now)
        @time_range = last_y.beginning_of_year..last_y.end_of_year
        @prev_time_range = 2.years.ago(now).beginning_of_year..2.years.ago(now).end_of_year
        @grain = AnalyticsConstants::Grain::MONTHLY
      else # default 30d
        @period = AnalyticsConstants::Period::THIRTY_DAYS
        @time_range = 29.days.ago(now).beginning_of_day..now.end_of_day
        @prev_time_range = 59.days.ago(now).beginning_of_day..30.days.ago(now).end_of_day
        @grain = AnalyticsConstants::Grain::DAILY
      end
    end

    def parse_utc(value, fallback:)
      return fallback if value.blank?

      Time.zone.parse(value.to_s)&.utc || fallback
    rescue
      fallback
    end

    ACTIVE_SUB_STATUSES = [
      PaymentConstants::SubscriptionStatus::ACTIVE,
      PaymentConstants::SubscriptionStatus::TRIALING
    ].freeze

    SUCCEEDED_TX_STATUS = PaymentConstants::TransactionStatus::SUCCEEDED

    def build_kpis
      # Users
      total_users = User.kept.count
      new_users_current = User.kept.where(created_at: time_range).count
      new_users_prev = User.kept.where(created_at: prev_time_range).count

      # Revenue (in major currency units, dividing cents by 100)
      # Combined: One-time succeeded transactions + Active/Trialing subscriptions
      tx_total_cents  = Payment::Transaction.kept.where(status: SUCCEEDED_TX_STATUS).sum(:price_unit_amount)
      sub_total_cents = Payment::Subscription.kept.joins(:product).where(status: ACTIVE_SUB_STATUSES).sum("payment_products.price_unit_amount")
      total_revenue_cents = tx_total_cents + sub_total_cents

      tx_period_cents  = Payment::Transaction.kept.where(status: SUCCEEDED_TX_STATUS, created_at: time_range).sum(:price_unit_amount)
      sub_period_cents = Payment::Subscription.kept.joins(:product).where(status: ACTIVE_SUB_STATUSES, payment_subscriptions: { created_at: time_range }).sum("payment_products.price_unit_amount")
      period_revenue_cents = tx_period_cents + sub_period_cents

      tx_prev_cents  = Payment::Transaction.kept.where(status: SUCCEEDED_TX_STATUS, created_at: prev_time_range).sum(:price_unit_amount)
      sub_prev_cents = Payment::Subscription.kept.joins(:product).where(status: ACTIVE_SUB_STATUSES, payment_subscriptions: { created_at: prev_time_range }).sum("payment_products.price_unit_amount")
      prev_revenue_cents = tx_prev_cents + sub_prev_cents

      # Transactions
      period_transactions = Payment::Transaction.kept.where(status: SUCCEEDED_TX_STATUS, created_at: time_range).count
      prev_transactions   = Payment::Transaction.kept.where(status: SUCCEEDED_TX_STATUS, created_at: prev_time_range).count

      # Subscriptions
      active_subscriptions = Payment::Subscription.kept.where(status: ACTIVE_SUB_STATUSES).count

      # Chat & AI Messages
      current_messages    = Chat::Message.kept.where(created_at: time_range)
      prev_messages_count = Chat::Message.kept.where(created_at: prev_time_range).count
      total_chat_messages = current_messages.count
      user_messages_count = current_messages.where(role: AiConstants::ChatRole::USER).count
      ai_messages_count   = current_messages.where(role: AiConstants::ChatRole::ASSISTANT).count

      # Client Logs (Errors)
      unresolved_errors = Log::Client.kept.where(resolved_at: nil).count
      total_period_errors = Log::Client.kept.where(created_at: time_range).count

      # Feedbacks
      period_feedbacks = Feedback.kept.where(created_at: time_range).count

      {
        total_users: total_users,
        new_users: new_users_current,
        users_delta_pct: calculate_delta_pct(new_users_current, new_users_prev),

        total_revenue: (total_revenue_cents / 100.0).round(2),
        period_revenue: (period_revenue_cents / 100.0).round(2),
        revenue_delta_pct: calculate_delta_pct(period_revenue_cents, prev_revenue_cents),

        period_transactions: period_transactions,
        transactions_delta_pct: calculate_delta_pct(period_transactions, prev_transactions),

        active_subscriptions: active_subscriptions,

        total_messages: total_chat_messages,
        user_messages: user_messages_count,
        ai_messages: ai_messages_count,
        messages_delta_pct: calculate_delta_pct(total_chat_messages, prev_messages_count),

        unresolved_errors: unresolved_errors,
        period_errors: total_period_errors,
        period_feedbacks: period_feedbacks
      }
    end

    def build_time_series
      buckets = generate_bucket_keys

      # Group queries in pure UTC
      users_by_bucket         = group_count(User.kept.where(created_at: time_range))
      transactions_by_bucket  = group_count(Payment::Transaction.kept.where(status: SUCCEEDED_TX_STATUS, created_at: time_range))
      tx_revenue_by_bucket    = group_sum(Payment::Transaction.kept.where(status: SUCCEEDED_TX_STATUS, created_at: time_range), :price_unit_amount)
      sub_revenue_by_bucket   = group_sum(
        Payment::Subscription.kept.joins(:product).where(status: ACTIVE_SUB_STATUSES, payment_subscriptions: { created_at: time_range }),
        "payment_products.price_unit_amount",
        "payment_subscriptions.created_at"
      )
      user_messages_by_bucket = group_count(Chat::Message.kept.where(role: AiConstants::ChatRole::USER, created_at: time_range))
      ai_messages_by_bucket   = group_count(Chat::Message.kept.where(role: AiConstants::ChatRole::ASSISTANT, created_at: time_range))

      buckets.map do |key, label|
        rev_cents = (tx_revenue_by_bucket[key] || 0) + (sub_revenue_by_bucket[key] || 0)
        {
          date: label,
          key: key,
          revenue: (rev_cents / 100.0).round(2),
          transactions: transactions_by_bucket[key] || 0,
          new_users: users_by_bucket[key] || 0,
          user_messages: user_messages_by_bucket[key] || 0,
          ai_messages: ai_messages_by_bucket[key] || 0
        }
      end
    end

    def generate_bucket_keys
      buckets = {}
      cursor = time_range.begin

      while cursor <= time_range.end
        case grain
        when :hourly
          key = cursor.strftime("%Y-%m-%d %H:00")
          label = cursor.iso8601
          buckets[key] = label
          cursor += 1.hour
        when :monthly
          key = cursor.strftime("%Y-%m")
          label = cursor.iso8601
          buckets[key] = label
          cursor = cursor.next_month.beginning_of_month
        else # :daily
          key = cursor.strftime("%Y-%m-%d")
          label = cursor.iso8601
          buckets[key] = label
          cursor += 1.day
        end
      end

      buckets
    end

    def group_count(scope, time_col = nil)
      col = time_col || "#{scope.table_name}.created_at"
      case grain
      when :hourly
        scope.group("TO_CHAR(#{col}, 'YYYY-MM-DD HH24:00')").count
      when :monthly
        scope.group("TO_CHAR(#{col}, 'YYYY-MM')").count
      else
        scope.group("TO_CHAR(#{col}, 'YYYY-MM-DD')").count
      end
    end

    def group_sum(scope, column, time_col = nil)
      col = time_col || "#{scope.table_name}.created_at"
      case grain
      when :hourly
        scope.group("TO_CHAR(#{col}, 'YYYY-MM-DD HH24:00')").sum(column)
      when :monthly
        scope.group("TO_CHAR(#{col}, 'YYYY-MM')").sum(column)
      else
        scope.group("TO_CHAR(#{col}, 'YYYY-MM-DD')").sum(column)
      end
    end

    def build_breakdowns
      subscription_cycles = Payment::Subscription.kept
        .where(status: ACTIVE_SUB_STATUSES)
        .group(:cycle)
        .count

      feedback_ratings = Feedback.kept
        .where(created_at: time_range)
        .where.not(rating: nil)
        .group(:rating)
        .count

      errors_by_platform = Log::Client.kept
        .where(created_at: time_range)
        .group(:platform)
        .count

      {
        subscriptions_by_cycle: subscription_cycles,
        feedback_ratings: feedback_ratings,
        errors_by_platform: errors_by_platform
      }
    end

    def calculate_delta_pct(current, previous)
      return 0.0 if previous.to_f.zero? && current.to_f.zero?
      return 100.0 if previous.to_f.zero? && current.to_f.positive?

      (((current - previous) / previous.to_f) * 100).round(1)
    end
  end
end
