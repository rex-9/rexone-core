# app/services/message_service/feedback.rb

module MessageService
  class Feedback < Base
    CREATED   = "feedback.created"
    FETCHED   = "feedback.fetched"
    UPDATED   = "feedback.updated"
    DESTROYED = "feedback.destroyed"
    NOT_FOUND = "feedback.not_found"
  end
end
