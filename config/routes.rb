Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Turbo Stream broadcasts (see SyncClientServicesJob) ride this — the
  # first broadcast in the app, so nothing mounted it before now.
  mount ActionCable.server => "/cable"

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
  resources :clients do
    # Suggests a GHL/Yext/SEMrush match by domain for every currently-unlinked
    # service (see SyncServicesChecker) — never persists anything itself,
    # just re-renders Edit practice with suggestions for the admin to
    # confirm by saving.
    resource :sync_services, only: [ :create ], controller: "clients/sync_services"

    member do
      # Restore a soft-deleted (offboarded) client — with warning that
      # HubSpot sync in ~1 hour may re-delete it if still marked offboarded there
      post :restore
    end

    collection do
      # Search-and-import entry point for adding a practice (see
      # HubspotCompanySearcher) — picking a result pre-fills the New client
      # form; nothing is created until that form is actually submitted.
      get "hubspot_search", to: "clients/hubspot_searches#index"
    end
  end

  get "dashboard", to: "dashboard#index"

  get "report-log", to: "report_logs#index", as: :report_log

  resources :team_members, path: "team", only: [ :index, :new, :create, :edit, :update ]

  # Defines the root path route ("/")
  root "dashboard#index"
end
