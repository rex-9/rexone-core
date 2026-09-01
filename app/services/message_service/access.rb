module MessageService
  class Access < Base
    FETCHED = "access.fetched"
    ACTIVE_FETCHED = "access.active_fetched"
    CHECK_COMPLETED = "access.check_completed"
    UNAUTHORIZED = "access.unauthorized"
    NOT_OWNED = "access.not_owned"
    REVOKED = "access.revoked"
    GRANTED = "access.granted"
    ALREADY_GRANTED = "access.already_granted"
    ALREADY_GRANTED_WITH_USERS = "access.already_granted_with_users"
    EXTENDED = "access.extended"
    REACTIVATED = "access.reactivated"
    NOT_FOUND = "access.not_found"
    PRODUCT_NOT_FOUND = "access.product_not_found"
    USERS_NOT_FOUND = "access.users_not_found"
    USER_NOT_FOUND = "access.user_not_found"
    CANNOT_EXTEND_LIFETIME = "access.cannot_extend_lifetime"
  end
end
