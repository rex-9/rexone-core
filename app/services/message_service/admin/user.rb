module MessageService
  module Admin
    class User < MessageService::Base
      USERS_RETRIEVED = "admin.user.users_retrieved"
      USER_RETRIEVED = "admin.user.user_retrieved"
      USER_CREATED = "admin.user.user_created"
      USER_UPDATED = "admin.user.user_updated"
      USER_DISCARDED = "admin.user.user_discarded"
      USER_RESTORED = "admin.user.user_restored"
      USER_DELETED = "admin.user.user_deleted"
      DISCARDED_USERS_RETRIEVED = "admin.user.discarded_users_retrieved"
      USER_NOT_DISCARDED = "admin.user.user_not_discarded"
      SELF_LIFECYCLE_PROTECTED = "admin.user.self_lifecycle_protected"
      LAST_SUPER_ADMIN_PROTECTED = "admin.user.last_super_admin_protected"
      USER_ROLES_RETRIEVED = "admin.user.user_roles_retrieved"
      USER_PERMISSIONS_RETRIEVED = "admin.user.user_permissions_retrieved"
      USER_CREATE_FAILED = "admin.user.user_create_failed"
      USER_UPDATE_FAILED = "admin.user.user_update_failed"
    end
  end
end
