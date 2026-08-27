module MessageService
  class User < Base
    USERS_RETRIEVED = "user.users_retrieved"
    CURRENT_FETCHED = "user.current_fetched"
    NOT_AUTHENTICATED = "user.not_authenticated"
    CURRENT_NOT_FOUND = "user.current_not_found"
    IAM_FETCHED = "user.iam_fetched"
  end
end
