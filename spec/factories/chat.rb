FactoryBot.define do
  factory :chat_room, class: "Chat::Room" do
    user
    sequence(:title) { |n| "Conversation #{n}" }
  end

  factory :chat_message, class: "Chat::Message" do
    association :room, factory: :chat_room
    role { "user" }
    content { "Hello" }
    metadata { {} }
  end
end
