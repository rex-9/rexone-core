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

  # ===== PERFORMANCE =====
  # Rails Performance Route
  # authenticate :user, ->(user) { user.admin? } do
  mount RailsPerformance::Engine, at: "/performance"
  # end

  # ===== ADMINISTRATE =====
  namespace :admin do
    resources :assets
    resources :users
    resources :accesses

    namespace :payment do
      resources :products
      resources :subscriptions
      resources :transactions
    end

    namespace :chat do
      resources :rooms
      resources :messages
    end

    root to: "users#index"
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
  get "users/current", to: "users/users#get_current_user"
  get "users/peek", to: "users/users#peek_user"

  # ===== MEDIA =====
  post "media/upload", to: "assets#upload"

  # ===== NOTIFICATIONS =====
  post "notifications/push", to: "notifications#push"
  post "notifications/email", to: "notifications#email"

  # ===== WEBHOOKS =====
  post "webhooks/stripe", to: "webhooks/stripe#create"

  # ===== PAYMENTS - Client =====
  namespace :payment do
    resources :products, only: [ :index, :show ]
    resources :subscriptions, only: [ :index, :show, :destroy ] do
      member do
        post :resume
        post :cancel # Cancel sub at period end
      end
    end
    resources :transactions, only: [ :index, :show ] do
      collection do
        get :recent
      end
    end

    # Checkout
    post "session", to: "payments#create"
    get "session/:session_id", to: "payments#status"
  end

  # ===== ACCESS =====
  get "access", to: "access#index"
  get "access/active", to: "access#active"
  get "access/check", to: "access#check"
  delete "access/:id", to: "access#destroy"

  # ===== AI =====
  post "ai/chat", to: "ai#chat"
  get "ai/history", to: "ai#history"
  delete "ai/clear", to: "ai#clear"
  put "ai/rename", to: "ai#rename"
  get "ai/rooms", to: "ai#rooms"
  post "ai/rooms", to: "ai#create_room"
  delete "ai/rooms/:id", to: "ai#destroy_room"
  post "ai/summarize", to: "ai#summarize"
  post "ai/translate", to: "ai#translate"
  post "ai/analyze", to: "ai#analyze"
end
