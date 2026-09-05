module MessageService
  class User < Base
    CURRENT_FETCHED = "user.current_fetched"
    NOT_AUTHENTICATED = "user.not_authenticated"
    CURRENT_NOT_FOUND = "user.current_not_found"
    IAM_FETCHED = "user.iam_fetched"
    CURRENT_UPDATED = "user.current_updated"
    CURRENT_UPDATE_FAILED = "user.current_update_failed"
  end
end
