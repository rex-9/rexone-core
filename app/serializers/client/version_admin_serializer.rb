class Client::VersionAdminSerializer < ApplicationSerializer
  set_type :version

  attributes :number,
             :title,
             :description,
             :status,
             :is_force_update,
             :released_at,
             :ios_build_number,
             :android_build_number,
             :metadata,
             :created_at,
             :updated_at,
             :discarded_at,
             :undiscarded_at,
             :install_count
end
