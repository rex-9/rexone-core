# config/routes.rb
Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Defines the root path route ("/")
  # root "posts#index"

  # Default Action Cable mounts the WebSocket server at /cable
  mount ActionCable.server => "/cable"

  # ===== HEALTH CHECK =====
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up", to: "rails/health#show", as: :rails_health_check
  # get "up" => "rails/health#show", as: :rails_health_check

  # ===== API DOCS - RSWAG =====
  mount Rswag::Ui::Engine => "/api-docs"
  mount Rswag::Api::Engine => "/api-docs"

  # ===== RAILS PULSE PERFORMANCE =====
  mount RailsPulse::Engine => "/admin/pulse"

  # ===== RED - RAILS ERROR DASHBOARD =====
  mount RailsErrorDashboard::Engine => "admin/red" # or /error_dashboard

  # ===== SOLID STACK =====
  mount SolidWebUi::Queue::Engine => "/admin/queue"
  mount SolidWebUi::Cache::Engine => "/admin/cache"
  mount SolidWebUi::Cable::Engine => "/admin/cable"

  # ============================================================
  # ADMINISTRATE
  # ============================================================
  # Separate from the versioned application API.
  # Administrate is intended for Super Admin access.
  namespace :admin do
    resources :assets, only: %i[index show new create edit update destroy]
    resources :users, only: %i[index show new create edit update destroy]
    resources :accesses, only: %i[index show new create edit update destroy]

    namespace :iam do
      resources :permissions, only: %i[index show new create edit update destroy]
      resources :roles, only: %i[index show new create edit update destroy]
      resources :user_roles, only: %i[index show new create edit update destroy]
      resources :role_permissions, only: %i[index show new create edit update destroy]
    end

    namespace :payment do
      resources :products, only: %i[index show new create edit update destroy]
      resources :subscriptions, only: %i[index show new create edit update destroy]
      resources :transactions, only: %i[index show new create edit update destroy]
      resources :webhook_events, only: %i[index show]
    end

    namespace :chat do
      resources :rooms, only: %i[index show new create edit update destroy]
      resources :messages, only: %i[index show new create edit update destroy]
    end

    namespace :log do
      resources :clients, only: %i[index show new create edit update destroy]
    end

    root to: "users#index"
  end

  # ===== AUTH (Devise) =====
  devise_for :users,
    path: "",
    path_names: {
      sign_in: "signin",
      sign_out: "signout",
      registration: "signup"
    },
    controllers: {
      sessions: "auth/sessions",
      registrations: "auth/registrations",
      confirmations: "auth/confirmations",
      passwords: "auth/passwords"
    }

  devise_scope :user do
    get "peek", to: "auth/sessions#peek_user"

    post "signin/google", to: "auth/sessions#google_sign_in"
    post "signin/google/complete", to: "auth/sessions#google_sign_in_complete"
    post "signin/token", to: "auth/sessions#token_sign_in"

    post "confirmation/send_code", to: "auth/confirmations#send_code"
    post "confirmation/confirm_code", to: "auth/confirmations#confirm_code"

    post "password/forgot", to: "auth/passwords#create"
    put "password/reset", to: "auth/passwords#update"
  end

  # ===== WEBHOOKS =====
  post "webhooks/stripe", to: "webhooks/stripe#create"

  # ============================================================
  # API V1 - All API routes should be API-only (no new/edit)
  # ============================================================
  namespace :v1 do
    # Client Logging
    namespace :log do
      resources :clients, only: [ :create, :index, :show, :destroy ] do
        member do
          patch :update_resolve, path: "resolve"
          patch :update_unresolve, path: "unresolve"
        end
      end
    end

    # ===== USERS =====
    get "users/", to: "users#index"
    get "users/current", to: "users#read_current_user"
    get "users/current/iam", to: "users#read_current_iam"

    # ===== ADMIN API =====
    # React Admin Dashboard.
    # Requires an admin role ("admin" or a role ending with "_admin") plus normal resource permissions.
    namespace :admin do
      # API-only: no new/edit needed
      resources :users, only: %i[index show create update] do
        # collection do
        #   get    :read_teaching_users, path: "teachers" # GET /v1/admin/users/teachers # V1::Admin::UsersController#read_teaching_users
        #   post   :create_users
        #   put    :update_users
        #   delete :delete_users
        # end

        # member do
        #   get :read_user_iam, path: "iam" # GET /v1/admin/users/:id/iam # V1::Admin::UsersController#read_user_iam
        #   post :create_user
        #   post :update_user
        #   post :delete_user
        # end

        collection do
          get :read_roles, path: "roles"
          get :read_discarded, path: "discarded"
        end

        member do
          post :discard
          post :undiscard
        end
      end

      namespace :iam do
        resources :roles, only: %i[index show create update destroy] do
          collection do
            get :read_permissions, path: "permissions"
          end
        end
      end

      namespace :chat do
        resources :rooms, only: %i[index show update destroy]
        resources :messages, only: %i[index show update destroy]
      end

      namespace :payment do
        resources :products, only: %i[index show create update destroy] do
          collection do
            get :read_discarded, path: "discarded"
          end

          member do
            post :undiscard
          end
        end
      end

      resources :notifications, only: %i[create] do
        collection do
          get :read_templates, path: "templates"
        end
      end
    end

    # ===== IAM =====
    namespace :iam do
      # API-only: no new/edit
      resources :permissions, only: %i[index show create update destroy] do
        collection do
          get :discarded
          get :undiscarded
        end

        member do
          post :discard
          post :undiscard
        end
      end

      resources :roles, only: %i[index show create update destroy]

      resources :users, only: [] do
        resources :roles,
          only: %i[index create destroy],
          controller: "user_roles"
      end
    end

    # ===== MEDIA =====
    post "media/upload", to: "assets#create_upload"

    # ===== PAYMENTS - CLIENT =====
    namespace :payment do
      resources :products, only: %i[index show]

      resources :subscriptions, only: %i[index show destroy] do
        member do
          post :create_cancel, path: "cancel"
          post :create_resume, path: "resume"
        end
      end

      resources :transactions, only: %i[index show] do
        collection do
          get :read_recent, path: "recent"
        end
      end

      post "session", to: "payments#create"
      get "session/:session_id", to: "payments#read_status"
    end

    # ===== ACCESS =====
    get "access", to: "access#index"
    get "access/active", to: "access#read_active"
    get "access/check", to: "access#read_check"
    delete "access/:id", to: "access#destroy"

    # ===== AI =====
    post "ai/chat", to: "ai#create_chat"
    get "ai/history", to: "ai#read_history"
    delete "ai/clear", to: "ai#destroy_clear"
    put "ai/rename", to: "ai#update_rename"

    get "ai/rooms", to: "ai#read_rooms"
    post "ai/rooms", to: "ai#create_room"
    delete "ai/rooms/:id", to: "ai#destroy_room"

    post "ai/summarize", to: "ai#create_summarize"
    post "ai/translate", to: "ai#create_translate"
    post "ai/analyze", to: "ai#create_analyze"
  end
end
