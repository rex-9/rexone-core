# app/controllers/v1/iam/roles_controller.rb:
class V1::Iam::RolesController < V1::ApplicationController
  before_action :super_admin_required!, except: [ :index ]

  # GET /iam/roles/
  def index
    roles = Iam::Role.all.includes(:permissions, :users)

    render_json_response(
      status_code: 200,
      message: iam_message(MessageService::Iam::ROLES_FETCHED),
      data: {
        roles: Iam::RoleSerializer.new(roles).serializable_hash[:data]
      }
    )
  end

  # GET /iam/roles/:id
  def show
    role = Iam::Role.find(params[:id])

    render_json_response(
      status_code: 200,
      message: iam_message(MessageService::Iam::ROLE_FETCHED),
      data: {
        role: Iam::RoleSerializer.new(role).serializable_hash[:data][:attributes]
      }
    )
  end

  # POST /iam/roles/
  def create
    role = Iam::Role.new(role_params)

    if role.save
      assign_permissions(role) if params[:permission_ids].present?

      render_json_response(
        status_code: 201,
        message: iam_message(MessageService::Iam::ROLE_CREATED),
        data: {
          role: Iam::RoleSerializer.new(role).serializable_hash[:data][:attributes]
        }
      )
    else
      render_json_response(
        status_code: 422,
        message: iam_message(MessageService::Iam::ROLE_CREATE_FAILED),
        error: role.errors.full_messages.to_sentence
      )
    end
  end

  # PUT /iam/roles/:id
  def update
    role = Iam::Role.find(params[:id])

    if role.update(role_params)
      if params.key?(:permission_ids)
        role.role_permissions.destroy_all
        assign_permissions(role)
      end

      render_json_response(
        status_code: 200,
        message: iam_message(MessageService::Iam::ROLE_UPDATED),
        data: {
          role: Iam::RoleSerializer.new(role).serializable_hash[:data][:attributes]
        }
      )
    else
      render_json_response(
        status_code: 422,
        message: iam_message(MessageService::Iam::ROLE_UPDATE_FAILED),
        error: role.errors.full_messages.to_sentence
      )
    end
  end

  # DELETE /iam/roles/:id
  def destroy
    role = Iam::Role.find(params[:id])

    if role.system?
      render_json_response(
        status_code: 422,
        message: iam_message(MessageService::Iam::SYSTEM_ROLE_DELETE_FORBIDDEN),
        error: iam_message(MessageService::Iam::SYSTEM_ROLE_DELETE_ERROR)
      )
      return
    end

    role.destroy

    render_json_response(
      status_code: 200,
      message: iam_message(MessageService::Iam::ROLE_DELETED)
    )
  end

  private

  def iam_message(key, **options)
    MessageService::Iam.t(key, **options)
  end

  def role_params
    params.permit(:name, :description)
  end

  def assign_permissions(role)
    Iam::Permission.where(id: params[:permission_ids]).each do |perm|
      role.role_permissions.find_or_create_by!(permission: perm)
    end
  end
end
