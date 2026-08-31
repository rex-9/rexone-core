# frozen_string_literal: true

module AnalyticsService
  class Overview
    class << self
      def call(...)
        new(...).call
      end
    end

    PERIOD_TODAY       = "today"
    PERIOD_YESTERDAY   = "yesterday"
    PERIOD_7D          = "7d"
    PERIOD_30D         = "30d"
    PERIOD_THIS_MONTH  = "this_month"
    PERIOD_LAST_MONTH  = "last_month"
    PERIOD_THIS_YEAR   = "this_year"
    PERIOD_LAST_YEAR   = "last_year"
    PERIOD_CUSTOM      = "custom"

    attr_reader :period, :start_date, :end_date, :time_range, :prev_time_range, :grain

    def initialize(period: PERIOD_30D, start_date: nil, end_date: nil)
      @period     = period.to_s.presence || PERIOD_30D
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
        @grain = days_count > 90 ? :monthly : (days_count <= 2 ? :hourly : :daily)
        return
      end

      case period
      when PERIOD_TODAY
        @time_range = now.beginning_of_day..now.end_of_day
        @prev_time_range = 1.day.ago(now).beginning_of_day..1.day.ago(now).end_of_day
        @grain = :hourly
      when PERIOD_YESTERDAY
        yesterday = 1.day.ago(now)
        @time_range = yesterday.beginning_of_day..yesterday.end_of_day
        @prev_time_range = 2.days.ago(now).beginning_of_day..2.days.ago(now).end_of_day
        @grain = :hourly
      when PERIOD_7D
        @time_range = 6.days.ago(now).beginning_of_day..now.end_of_day
        @prev_time_range = 13.days.ago(now).beginning_of_day..7.days.ago(now).end_of_day
        @grain = :daily
      when PERIOD_THIS_MONTH
        @time_range = now.beginning_of_month..now.end_of_month
        @prev_time_range = 1.month.ago(now).beginning_of_month..1.month.ago(now).end_of_month
        @grain = :daily
      when PERIOD_LAST_MONTH
        last_m = 1.month.ago(now)
        @time_range = last_m.beginning_of_month..last_m.end_of_month
        @prev_time_range = 2.months.ago(now).beginning_of_month..2.months.ago(now).end_of_month
        @grain = :daily
      when PERIOD_THIS_YEAR
        @time_range = now.beginning_of_year..now.end_of_year
        @prev_time_range = 1.year.ago(now).beginning_of_year..1.year.ago(now).end_of_year
        @grain = :monthly
      when PERIOD_LAST_YEAR
        last_y = 1.year.ago(now)
        @time_range = last_y.beginning_of_year..last_y.end_of_year
        @prev_time_range = 2.years.ago(now).beginning_of_year..2.years.ago(now).end_of_year
        @grain = :monthly
      else # default 30d
        @period = PERIOD_30D
        @time_range = 29.days.ago(now).beginning_of_day..now.end_of_day
        @prev_time_range = 59.days.ago(now).beginning_of_day..30.days.ago(now).end_of_day
        @grain = :daily
      end
    end

    def parse_utc(value, fallback:)
      return fallback if value.blank?

      Time.zone.parse(value.to_s)&.utc || fallback
    rescue
      fallback
    end

    def build_kpis
      # Users
      total_users = User.kept.count
      new_users_current = User.kept.where(created_at: time_range).count
      new_users_prev = User.kept.where(created_at: prev_time_range).count

      # Revenue (in major currency units, dividing cents by 100)
      total_revenue_cents = Payment::Transaction.kept.where(status: "succeeded").sum(:price_unit_amount)
      period_revenue_cents = Payment::Transaction.kept.where(status: "succeeded", created_at: time_range).sum(:price_unit_amount)
      prev_revenue_cents = Payment::Transaction.kept.where(status: "succeeded", created_at: prev_time_range).sum(:price_unit_amount)

      # Transactions
      period_transactions = Payment::Transaction.kept.where(status: "succeeded", created_at: time_range).count
      prev_transactions = Payment::Transaction.kept.where(status: "succeeded", created_at: prev_time_range).count

      # Subscriptions
      active_subscriptions = Payment::Subscription.kept.where(status: %w[active trialing]).count

      # Chat & AI Messages
      current_messages = Chat::Message.kept.where(created_at: time_range)
      prev_messages_count = Chat::Message.kept.where(created_at: prev_time_range).count
      total_chat_messages = current_messages.count
      user_messages_count = current_messages.where(role: "user").count
      ai_messages_count = current_messages.where(role: "assistant").count

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
      users_by_bucket = group_count(User.kept.where(created_at: time_range))
      transactions_by_bucket = group_count(Payment::Transaction.kept.where(status: "succeeded", created_at: time_range))
      revenue_by_bucket = group_sum(Payment::Transaction.kept.where(status: "succeeded", created_at: time_range), :price_unit_amount)
      user_messages_by_bucket = group_count(Chat::Message.kept.where(role: "user", created_at: time_range))
      ai_messages_by_bucket = group_count(Chat::Message.kept.where(role: "assistant", created_at: time_range))

      buckets.map do |key, label|
        rev_cents = revenue_by_bucket[key] || 0
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

    def group_count(scope)
      case grain
      when :hourly
        scope.group("TO_CHAR(created_at, 'YYYY-MM-DD HH24:00')").count
      when :monthly
        scope.group("TO_CHAR(created_at, 'YYYY-MM')").count
      else
        scope.group("TO_CHAR(created_at, 'YYYY-MM-DD')").count
      end
    end

    def group_sum(scope, column)
      case grain
      when :hourly
        scope.group("TO_CHAR(created_at, 'YYYY-MM-DD HH24:00')").sum(column)
      when :monthly
        scope.group("TO_CHAR(created_at, 'YYYY-MM')").sum(column)
      else
        scope.group("TO_CHAR(created_at, 'YYYY-MM-DD')").sum(column)
      end
    end

    def build_breakdowns
      subscription_cycles = Payment::Subscription.kept
        .where(status: %w[active trialing])
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
