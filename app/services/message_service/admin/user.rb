module MessageService
  module Admin
    class User < MessageService::Base
      USERS_RETRIEVED = "admin.user.users_retrieved"
      USER_RETRIEVED = "admin.user.user_retrieved"
      USER_CREATED = "admin.user.user_created"
      USER_UPDATED = "admin.user.user_updated"
      USER_DELETED = "admin.user.user_deleted"
      USER_ROLES_RETRIEVED = "admin.user.user_roles_retrieved"
      USER_CREATE_FAILED = "admin.user.user_create_failed"
      USER_UPDATE_FAILED = "admin.user.user_update_failed"
    end
  end
end
