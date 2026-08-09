Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Defines the root path route ("/")
  # root "posts#index"

  # Default Action Cable mounts the WebSocket server at /cable
  # mount ActionCable.server => '/cable'

  # ===== HEALTH CHECK =====
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up", to: "rails/health#show", as: :rails_health_check
  # get "up" => "rails/health#show", as: :rails_health_check

  # ===== API DOCS - RSWAG =====
  mount Rswag::Ui::Engine => "/api-docs"
  mount Rswag::Api::Engine => "/api-docs"

  # ===== PULSE =====
  # Rails Pulse Performance Route
  mount RailsPulse::Engine => "/admin/pulse"

  # ===== SOLID STACK =====
  mount SolidWebUi::Queue::Engine => "/admin/queue"
  mount SolidWebUi::Cache::Engine => "/admin/cache"
  mount SolidWebUi::Cable::Engine => "/admin/cable"

  # ===== ADMINISTRATE =====
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
    end

    namespace :chat do
      resources :rooms, only: %i[index show new create edit update destroy]
      resources :messages, only: %i[index show new create edit update destroy]
    end

    root to: "users#index"
  end

  # ===== IAM =====
  namespace :iam do
    resources :permissions, only: [ :index, :show ]
    resources :roles, only: [ :index, :show, :create, :update, :destroy ]

    resources :users, only: [] do
      resources :roles, only: [ :index, :create, :destroy ], controller: "user_roles"
    end
  end

  # ===== AUTH (Devise) =====
  devise_for :users, path: "", path_names: {
    sign_in: "signin",
    sign_out: "signout",
    registration: "signup"
  },
  controllers: {
    sessions: "users/sessions",
    registrations: "users/registrations",
    confirmations: "users/confirmations",
    passwords: "users/passwords"
  }

  devise_scope :user do
    post "signin/google", to: "users/sessions#google_sign_in"
    post "signin/google/complete", to: "users/sessions#google_sign_in_complete"
    post "signin/token", to: "users/sessions#token_sign_in"
    post "confirmation/send_code", to: "users/confirmations#send_code"
    post "confirmation/confirm_code", to: "users/confirmations#confirm_code"
    post "password/forgot", to: "users/passwords#create"
    put "password/reset", to: "users/passwords#update"
  end

  # ===== USERS =====
  get "users/current", to: "users/users#read_current_user"
  get "users/current/iam", to: "users/users#read_current_iam"
  get "users/peek", to: "users/users#read_peek_user"

  # ===== MEDIA =====
  post "media/upload", to: "assets#create_upload"

  # ===== NOTIFICATIONS =====
  post "notifications/push", to: "notifications#create_push"
  post "notifications/email", to: "notifications#create_email"

  # ===== WEBHOOKS =====
  post "webhooks/stripe", to: "webhooks/stripe#create"

  # ===== PAYMENTS - Client =====
  namespace :payment do
    resources :products, only: [ :index, :show ]
    resources :subscriptions, only: [ :index, :show, :destroy ] do
      member do
        post :create_resume
        post :create_cancel # Cancel sub at period end
      end
    end
    resources :transactions, only: [ :index, :show ] do
      collection do
        get :read_recent
      end
    end

    # Checkout
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
