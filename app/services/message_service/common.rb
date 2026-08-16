module MessageService
  class Common < Base
    UNAUTHORIZED = "common.authorization.unauthorized"
    PERMISSION_DENIED = "common.authorization.permission_denied"
    ADMIN_REQUIRED = "common.authorization.admin_required"
    SUPER_ADMIN_REQUIRED = "common.authorization.super_admin_required"
    TOO_MANY_REQUESTS = "common.rate_limit.too_many_requests"
    RATE_LIMIT_EXCEEDED = "common.rate_limit.exceeded"
    REQUEST_BLOCKED = "common.rate_limit.request_blocked"
  end
end
