# frozen_string_literal: true

require "rails_helper"

RSpec.describe AnalyticsService::Overview, type: :service do
  describe "#call" do
    it "returns calculated KPIs, time-series data, and breakdowns for 30d default" do
      user = create(:user)
      product = create(:payment_product, price_unit_amount: 5000)
      create(:payment_transaction, user: user, product: product, price_unit_amount: 5000, status: "succeeded")
      create(:payment_subscription, user: user, product: product, status: "active", cycle: "monthly")
      room = create(:chat_room, user: user)
      create(:chat_message, room: room, role: "user", content: "Hello AI")
      create(:chat_message, room: room, role: "assistant", content: "Hello human")
      create(:log_client, user: user, platform: "web", severity: "error")
      create(:feedback, user: user, rating: 5)

      result = described_class.call(period: "30d")

      expect(result[:period]).to eq("30d")
      expect(result[:grain]).to eq(:daily)
      expect(result[:kpis][:total_users]).to be >= 1
      expect(result[:kpis][:new_users]).to be >= 1
      expect(result[:kpis][:period_revenue]).to eq(50.0)
      expect(result[:kpis][:period_transactions]).to eq(1)
      expect(result[:kpis][:active_subscriptions]).to eq(1)
      expect(result[:kpis][:total_messages]).to eq(2)
      expect(result[:kpis][:user_messages]).to eq(1)
      expect(result[:kpis][:ai_messages]).to eq(1)
      expect(result[:kpis][:unresolved_errors]).to eq(1)
      expect(result[:kpis][:period_feedbacks]).to eq(1)

      expect(result[:time_series]).to be_an(Array)
      expect(result[:time_series].size).to be >= 28

      expect(result[:breakdowns][:subscriptions_by_cycle]).to eq({ "monthly" => 1 })
      expect(result[:breakdowns][:feedback_ratings]).to eq({ 5 => 1 })
      expect(result[:breakdowns][:errors_by_platform]).to eq({ "web" => 1 })
    end

    it "supports hourly grain for today and yesterday" do
      today_result = described_class.call(period: "today")
      expect(today_result[:grain]).to eq(:hourly)

      yesterday_result = described_class.call(period: "yesterday")
      expect(yesterday_result[:grain]).to eq(:hourly)
    end
  end
end
