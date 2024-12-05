Rails.application.routes.draw do
  # Rails Admin Route
  mount RailsAdmin::Engine => "/admin", as: "rails_admin"

  # Rswag Route
  mount Rswag::Ui::Engine => "/api-docs"
  mount Rswag::Api::Engine => "/api-docs"

  # Rails Performance Route
  # authenticate :user, ->(user) { user.admin? } do
  mount RailsPerformance::Engine, at: "/performance"
  # end

  # Devise Routes
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
    post "signin/token", to: "users/sessions#token_sign_in"
    post "confirmation/resend", to: "users/confirmations#resend"
    post "confirmation/confirm_with_code", to: "users/confirmations#confirm_with_code"
    post "password/forgot", to: "users/passwords#create"
    put "password/reset", to: "users/passwords#update"
  end

  # App Routes
  get "users/current", to: "users/users#get_current_user"

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  # root "posts#index"
end
