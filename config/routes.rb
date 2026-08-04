Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Admin authentication
  get "login", to: "sessions#new", as: :login
  post "login", to: "sessions#create"
  delete "logout", to: "sessions#destroy", as: :logout

  # Public client-facing monthly SEO report, keyed by MonthlyReport#access_token
  # (a random secure token, never a sequential/predictable ID — see CONVENTIONS.md #10)
  get "reports/:access_token", to: "reports#show", as: :public_report

  # Agency-wide API credentials for the external data-source adapters
  resources :connections, only: [ :index, :edit, :update ], param: :service

  # Dashboard overview and client roster
  get "dashboard", to: "dashboard#index", as: :dashboard
  resources :report_generations, only: [ :create ]
  resources :clients, only: [ :index, :show, :new, :create ] do
    resources :monthly_reports, only: [ :index ], as: :reports, path: "reports"
    resources :client_keywords, only: [ :index ], as: :keywords, path: "keywords"
    resources :client_service_links, only: [ :index, :edit, :update ], as: :data_sources, path: "data_sources",
      param: :service
  end

  # Defines the root path route ("/")
  root "connections#index"
end
