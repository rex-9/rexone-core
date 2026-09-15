# frozen_string_literal: true

# app/services/chat/room_service.rb
module Chat
  class RoomService
    Error = Class.new(StandardError)
    RoomBusyError = Class.new(Error)

    class << self
      def list(user)
        user.rooms.kept.recent.includes(:messages)
      end

      def admin_list(params = {})
        scope = if params[:discarded].to_s == "true"
                  ::Chat::Room.with_discarded.discarded.includes(:user, :messages)
        else
                  ::Chat::Room.kept.includes(:user, :messages)
        end

        scope = scope.where(user_id: params[:user_id]) if params[:user_id].present?
        scope.order(SortConstants::Columns::CHAT_ROOM.first => SortConstants::Order::DESC)
      end

      def find(user, id)
        user.rooms.kept.find(id)
      end

      def admin_find(id, with_discarded: false)
        scope = with_discarded ? ::Chat::Room.with_discarded : ::Chat::Room.kept
        scope.find(id)
      end

      def create!(user, title: nil)
        default_title = ::MessageService::Ai.t(::MessageService::Ai::DEFAULT_ROOM_TITLE)
        user.rooms.create!(
          title: title.presence || default_title
        )
      end

      def update!(room, title:)
        room.update!(title: title)
        room
      end

      def discard!(room)
        raise RoomBusyError, ::MessageService::Ai.t(::MessageService::Ai::ROOM_BUSY) if busy?(room)

        room.discard!
        room
      end

      def undiscard!(room)
        room.undiscard!
        room
      end

      def destroy!(room)
        raise RoomBusyError, ::MessageService::Ai.t(::MessageService::Ai::ROOM_BUSY) if busy?(room)

        room.destroy!
      end

      def busy?(room)
        room.processing?
      end
    end
  end
end
