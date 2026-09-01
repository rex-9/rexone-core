module MessageService
  module Admin
    class Chat < MessageService::Base
      ROOMS_RETRIEVED = "admin.chat.rooms_retrieved"
      ROOM_RETRIEVED = "admin.chat.room_retrieved"
      ROOM_UPDATED = "admin.chat.room_updated"
      ROOM_UPDATE_FAILED = "admin.chat.room_update_failed"
      ROOM_DELETED = "admin.chat.room_deleted"
      MESSAGES_RETRIEVED = "admin.chat.messages_retrieved"
      MESSAGE_RETRIEVED = "admin.chat.message_retrieved"
      MESSAGE_UPDATED = "admin.chat.message_updated"
      MESSAGE_UPDATE_FAILED = "admin.chat.message_update_failed"
      MESSAGE_DELETED = "admin.chat.message_deleted"
    end
  end
end
