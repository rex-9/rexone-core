# spec/services/feedback_service_spec.rb

require "rails_helper"

RSpec.describe FeedbackService, type: :service do
  describe ".infer_category" do
    context "with English feedback" do
      it "classifies bug reports correctly" do
        expect(described_class.infer_category("The app crashed on checkout")).to eq(FeedbackConstants::Category::BUG)
        expect(described_class.infer_category("Getting 500 error when clicking button")).to eq(FeedbackConstants::Category::BUG)
      end

      it "classifies feature requests correctly" do
        expect(described_class.infer_category("Could you please add dark mode support?")).to eq(FeedbackConstants::Category::FEATURE_REQUEST)
        expect(described_class.infer_category("I have a suggestion for the dashboard")).to eq(FeedbackConstants::Category::FEATURE_REQUEST)
      end

      it "classifies improvements correctly" do
        expect(described_class.infer_category("The page loading is very slow, please optimize")).to eq(FeedbackConstants::Category::IMPROVEMENT)
        expect(described_class.infer_category("The UI layout is confusing")).to eq(FeedbackConstants::Category::IMPROVEMENT)
      end

      it "defaults to general category" do
        expect(described_class.infer_category("Great product, keep it up!")).to eq(FeedbackConstants::Category::GENERAL)
      end
    end

    context "with Myanmar (Burmese) feedback" do
      it "classifies bug reports correctly" do
        expect(described_class.infer_category("အက်ပ်က ဖွင့်မရတော့ဘူး")).to eq(FeedbackConstants::Category::BUG)
        expect(described_class.infer_category("စနစ်မှာ အမှား ဖြစ်နေတယ်")).to eq(FeedbackConstants::Category::BUG)
      end

      it "classifies feature requests correctly" do
        expect(described_class.infer_category("နောက်ထပ် လုပ်ဆောင်ချက် အသစ် ထည့်ပေးပါ")).to eq(FeedbackConstants::Category::FEATURE_REQUEST)
        expect(described_class.infer_category("ဒီ feature လေး ထည့်ချင်ပါတယ်")).to eq(FeedbackConstants::Category::FEATURE_REQUEST)
      end

      it "classifies improvements correctly" do
        expect(described_class.infer_category("စနစ်က သိပ်နှေးနေတယ် မြန်အောင် ပြင်ပေးပါ")).to eq(FeedbackConstants::Category::IMPROVEMENT)
        expect(described_class.infer_category("ဒီဇိုင်းလေး ပြောင်းစေချင်တယ်")).to eq(FeedbackConstants::Category::IMPROVEMENT)
      end
    end
  end

  describe ".infer_priority" do
    it "infers critical priority for security, hack, and exploit cues" do
      expect(described_class.infer_priority("Critical security exploit found, user data leak", nil)).to eq(FeedbackConstants::Priority::CRITICAL)
      expect(described_class.infer_priority("အကောင့် ခိုး ခံရပြီး လုံခြုံရေး ပေါက်ကြား နေပါတယ်", nil)).to eq(FeedbackConstants::Priority::CRITICAL)
    end

    it "infers urgent priority for billing and access emergency cues in English and Myanmar" do
      expect(described_class.infer_priority("Emergency! I lost_money and was charged_twice", nil)).to eq(FeedbackConstants::Priority::URGENT)
      expect(described_class.infer_priority("အရေးပေါ် ပိုက်ဆံဖြတ် သွားပါတယ်", nil)).to eq(FeedbackConstants::Priority::URGENT)
    end

    it "infers high priority for bugs with low ratings" do
      expect(described_class.infer_priority("App is broken", 1)).to eq(FeedbackConstants::Priority::HIGH)
      expect(described_class.infer_priority("သုံးမရတော့ဘူး", 2)).to eq(FeedbackConstants::Priority::HIGH)
    end

    it "infers medium priority for improvements" do
      expect(described_class.infer_priority("Please optimize the slow design layout", nil)).to eq(FeedbackConstants::Priority::MEDIUM)
    end

    it "infers low priority for general feedback" do
      expect(described_class.infer_priority("Loving the app, great work!", nil)).to eq(FeedbackConstants::Priority::LOW)
    end
  end
end
