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

  # GoHighLevel's agency-level OAuth redirect flow (see GhlOauthClient) — a
  # GET-based external redirect, not RESTful CRUD, hence the custom routes.
  # Path deliberately avoids the literal "ghl"/"highlevel" — GHL's own
  # Marketplace rejects a redirect URI containing a HighLevel brand
  # reference for white-labeled apps. The Ruby-side naming (controller,
  # route helpers, GhlOauthController) is unaffected since it never appears
  # in the URL itself.
  namespace :connections do
    get "scheduler/authorize", to: "ghl_oauth#authorize", as: :ghl_authorize
    get "scheduler/callback", to: "ghl_oauth#callback", as: :ghl_callback
  end

  # Practices. Data-source external_ids are edited inline on the Edit practice
  # form (see docs/features/admin-panel.md) — saving with a HubSpot company
  # ID present triggers its own sync (ClientServiceLink#enqueue_hubspot_sync),
  # so there's no separate "sync now" endpoint.
  resources :clients

  get "dashboard", to: "dashboard#index"

  get "report-log", to: "report_logs#index", as: :report_log

  # Defines the root path route ("/")
  root "dashboard#index"
end
