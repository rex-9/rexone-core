# app/controllers/iam/roles_controller.rb:

class Iam::RolesController < ApplicationController
  before_action :authenticate_user!
  before_action :super_admin_required!, except: [ :index ]

  # GET /iam/roles/
  def index
    roles = Iam::Role.all.includes(:permissions, :users)

    render_json_response(
      status_code: 200,
      message: "Roles fetched",
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
      message: "Role fetched",
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
        message: "Role created",
        data: {
          role: Iam::RoleSerializer.new(role).serializable_hash[:data][:attributes]
        }
      )
    else
      render_json_response(
        status_code: 422,
        message: "Failed to create role",
        error: role.errors.full_messages.to_sentence
      )
    end
  end

  # PUT /iam/roles/:id
  def update
    role = Iam::Role.find(params[:id])

    if role.update(role_params)
      if params[:permission_ids].present?
        role.role_permissions.destroy_all
        assign_permissions(role)
      end

      render_json_response(
        status_code: 200,
        message: "Role updated",
        data: {
          role: Iam::RoleSerializer.new(role).serializable_hash[:data][:attributes]
        }
      )
    else
      render_json_response(
        status_code: 422,
        message: "Failed to update role",
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
        message: "Cannot delete system role",
        error: "System roles cannot be deleted"
      )
      return
    end

    role.destroy

    render_json_response(
      status_code: 200,
      message: "Role deleted"
    )
  end

  private

  def role_params
    params.permit(:name, :description)
  end

  def assign_permissions(role)
    Iam::Permission.where(id: params[:permission_ids]).each do |perm|
      role.role_permissions.find_or_create_by!(permission: perm)
    end
  end
end
