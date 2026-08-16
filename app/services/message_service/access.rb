module MessageService
  class Access < Base
    FETCHED = "access.fetched"
    ACTIVE_FETCHED = "access.active_fetched"
    CHECK_COMPLETED = "access.check_completed"
    UNAUTHORIZED = "access.unauthorized"
    NOT_OWNED = "access.not_owned"
    REVOKED = "access.revoked"
  end
end
