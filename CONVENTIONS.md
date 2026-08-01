# CONVENTIONS.md — Ruby on Rails 8 Best Practices & Developer Guidelines

> **Source**: Based on the [official Ruby on Rails Guides](https://guides.rubyonrails.org/) for Rails 8.1.  
> **Purpose**: This file defines conventions, patterns, and guardrails for any developer or AI agent contributing to this codebase. Read this before writing any code.  
> **Stack**: Rails 8.1.2 · Ruby 3.3.7 · PostgreSQL 16 (`pg`) · Propshaft · Importmap · Hotwire (Turbo + Stimulus) · Solid Queue/Cache/Cable

---

## 1. Convention Over Configuration

Rails is built on the principle of "Convention Over Configuration" — the framework assumes sensible defaults so you write less boilerplate. This only works if everyone follows the conventions.

**Explain**: Rails auto-discovers models, controllers, views, jobs, and mailers by file path and class name. Breaking naming conventions breaks autoloading, routing, and associations silently.

### Dos
- Follow Rails naming conventions exactly — they are not suggestions.
- Let Rails infer table names, foreign keys, and join tables from class names.
- Use `config.load_defaults 8.1` (already set) and stay current with framework defaults.
- Read the [Rails Guides](https://guides.rubyonrails.org/) when unsure — they are the canonical reference.

### Don'ts
- Don't fight the framework — if you're writing boilerplate Rails would generate for you, you're doing it wrong.
- Don't override conventions (e.g., custom table names, custom primary key names) without a documented reason.
- Don't copy patterns from other frameworks (Django, Laravel, Express) — use the Rails way.

---

## 2. Active Record Naming Conventions

Active Record uses naming conventions to map between models and database tables automatically.

**Explain**: The model class name is singular PascalCase. The table name is plural snake_case. Foreign keys are `singularized_table_name_id`. Rails derives all of this automatically — you should never need to declare `self.table_name`.

### Dos
- **Model → Table**: `Client` → `clients`, `MonthlyReport` → `monthly_reports`, `ClientKeyword` → `client_keywords`.
- **Foreign keys**: `client_id`, `monthly_report_id` — always `<singular_model>_id`.
- **Join tables** (HABTM): Alphabetical order of the two table names → `clients_keywords` (though prefer `has_many :through` over HABTM).
- **Primary key**: Column named `id` (we use `uuid` type in this project).
- **Timestamps**: Always include `created_at` and `updated_at` via `t.timestamps` in migrations.
- Use `_count` suffix for counter cache columns: `reports_count`.
- Use `_type` suffix for polymorphic type columns: `commentable_type`.

### Don'ts
- Don't use `self.table_name = "..."` unless interfacing with a legacy database.
- Don't name foreign keys manually — let Rails infer them.
- Don't use singular table names — Rails expects plural.
- Don't use `camelCase` or `PascalCase` for column names — always `snake_case`.

---

## 3. Migrations

Migrations are Ruby classes that modify the database schema over time. They are the **only** way to change the schema.

**Explain**: Each migration is a timestamped file in `db/migrate/`. Rails tracks which have run via an internal `schema_migrations` table. Migrations must be reversible and should do one logical thing.

### Dos
- Generate migrations with the CLI: `bin/rails generate migration AddPhoneToClients phone:string`.
- Use `change` method (auto-reversible) whenever possible instead of `up`/`down`.
- Use `null: false` for columns that must always have a value.
- Use `index: true` or `add_index` for columns you query by frequently.
- Use `add_index :table, [:col1, :col2], unique: true` for composite uniqueness constraints.
- Back a string-backed `enum`'s allowed values at the DB level too, not just the model's
  `validate: true` — a Ruby validation doesn't stop a raw SQL script, console `update_column`, or
  a future migration from writing an invalid value. Two ways to do it, pick by whether the values
  carry any real behavior of their own:
  - **A fixed handful of literal values, no associated data** — `add_check_constraint :table,
    "column IN ('a', 'b', 'c')", name: "..."`. Simple, but the allowed-values list is baked into
    the migration itself, so adding a value means a new migration that edits the constraint.
  - **Values that have their own metadata or are referenced from more than one table** (this is
    the `service` enum's shape — see `Service` / `db/migrate/*_create_services.rb`) — a small
    lookup table with a natural string primary key (`id: false do |t| t.string :key,
    primary_key: true end`), and `add_foreign_key :table, :lookup_table, column: :enum_column,
    primary_key: :key` from every table that has the enum column. One place to add a new value
    (a row) instead of editing a constraint in N places.
  - Either way: a database built via `db:schema:load` (what test-suite prep and some fresh
    deploys use) replays *structure* only — any rows a migration inserted via `reversible`/`create`
    are gone. If something else (a FK, a feature) depends on those rows always existing, seed them
    from a real constant AND from a place that actually runs for every DB-build path (this
    project's test suite bootstraps `Service::KEYS` in `test_helper.rb` for exactly this reason —
    see that file's comment).
- Use `decimal` (not `float`) for monetary values: `t.decimal :estimated_revenue, precision: 10, scale: 2`.
- Use `text` for long-form content, `string` (varchar) for short fields.
- Use `t.references :client, type: :uuid, foreign_key: true` for associations with UUID PKs.
- Keep migrations small and focused — one migration per logical change.
- Always run `bin/rails db:migrate` and commit the updated `db/schema.rb`.

### Don'ts
- Don't edit a migration after it has been run and committed — create a new migration instead.
- Don't use `execute` with raw SQL unless the migration DSL can't express what you need.
- Don't use `float` for anything that requires precision (money, percentages).
- Don't add database-level default values for complex logic — handle defaults in the model.
- Don't forget to add `foreign_key: true` on reference columns.
- Don't delete or rename old migration files — they are a historical record.
- Don't put data manipulation (`update_all`, `create`) in schema migrations — use `bin/rails db:seed` or a separate data migration. The one exception is seeding a lookup table's rows in the same migration that creates it, when a FK constraint added in that migration depends on those rows existing (see the `services` table) — that's schema-adjacent reference data, not business data. Even then, also seed it from `db/seeds.rb` (or equivalent), since `db:schema:load` won't replay the migration's insert.

---

## 4. Models — Structure & Ordering

Models are the core of Rails applications. They represent business entities and encapsulate all data access logic, validations, and domain rules.

**Explain**: Every model inherits from `ApplicationRecord` and lives in `app/models/`. Follow a consistent internal ordering so any developer can scan a model file quickly.

### Dos
- Order model internals consistently:
  ```ruby
  class Client < ApplicationRecord
    # 1. Constants
    STATUSES = %w[pending active offboarded].freeze

    # 2. Enums
    enum :onboarding_status, { pending: "pending", active: "active", offboarded: "offboarded" }

    # 3. Associations
    has_many :reports, dependent: :destroy
    has_many :integrations, dependent: :destroy

    # 4. Validations
    validates :name, presence: true
    validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }

    # 5. Scopes
    scope :active, -> { where(onboarding_status: "active") }
    scope :with_ai_seo, -> { where(ai_seo_enrolled: true) }

    # 6. Callbacks (use sparingly)

    # 7. Class methods
    def self.needing_report(year, month)
      active.where.not(id: MonthlyReport.where(report_month: Date.new(year, month, 1)).select(:client_id))
    end

    # 8. Instance methods
    def display_name
      "#{name} — Dr. #{doctor_name}"
    end
  end
  ```
- Declare `dependent:` on every `has_many` and `has_one` — choose `:destroy`, `:delete_all`, `:nullify`, or `:restrict_with_error` based on the relationship.
- Use `enum` with explicit string mappings and `validate: true`:
  ```ruby
  enum :status, { active: "active", expired: "expired" }, validate: true
  ```
  Pair it with a DB check constraint on the same column (§3) — the model validation and the
  constraint enforce the same invariant at two layers, which is the point: the validation gives a
  friendly error in normal app code, the constraint is what actually holds under a bypass.

### Don'ts
- Don't use `default_scope` — it silently applies to every query and causes bugs. Use named scopes.
- Don't skip `dependent:` on associations — orphaned records cause data integrity issues.
- Don't use integer-backed enums — string-backed enums are readable in the database and safer during refactors.
- Don't create "god models" with hundreds of lines — extract concerns or service objects.
- Don't use `serialize` — use native JSON columns with proper typing instead.

---

## 5. Validations

Validations ensure only valid data is saved to the database.

**Explain**: Validations are declared in the model and run automatically before `save`, `create`, and `update`. They are the primary defense against bad data. Database constraints are the secondary defense.

### Dos
- Validate at both the model level AND the database level (e.g., `validates :email, presence: true` + `null: false` in migration).
- Use built-in validators: `presence`, `uniqueness`, `length`, `format`, `numericality`, `inclusion`.
- Use `uniqueness` validations with a database-level unique index to prevent race conditions:
  ```ruby
  validates :access_token, uniqueness: true  # model level
  # + add_index :monthly_reports, :access_token, unique: true  # database level
  ```
- Use `format` with named Regexp constants for readability:
  ```ruby
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }
  ```
- Use conditional validations when validation depends on state:
  ```ruby
  validates :estimated_revenue, presence: true, if: :has_online_scheduler?
  ```
- Use custom validator classes for complex validations, placed in `app/validators/`.

### Don'ts
- Don't rely solely on model validations — always add database constraints (`null: false`, unique indexes) as a safety net.
- Don't use `validates_presence_of` (old syntax) — use `validates :field, presence: true`.
- Don't skip validations with `save(validate: false)` unless there is a documented, justified reason.
- Don't validate associations that don't exist yet — use `optional: true` on `belongs_to` when the FK is nullable.
- Don't use `validates :field, uniqueness: true` without a corresponding database unique index — it's not race-condition safe on its own.

---

## 6. Associations

Associations declare relationships between models. Rails uses them to generate efficient SQL joins and eager-loading.

**Explain**: Declaring `has_many :reports` on `Client` tells Rails that `reports` has a `client_id` column pointing back. Rails generates finder methods, build methods, and join queries automatically.

### Dos
- Use `has_many :through` instead of `has_and_belongs_to_many` (HABTM) — the join model gives you a place to add columns, validations, and callbacks.
- Always specify `dependent:` behavior:
  - `:destroy` — remove children and run their callbacks.
  - `:delete_all` — remove children without callbacks (faster for large datasets).
  - `:nullify` — set the FK to null.
  - `:restrict_with_error` — prevent deletion if children exist.
- Use `inverse_of` when Rails can't infer the inverse (scoped or conditional associations).
- Use `counter_cache: true` on `belongs_to` when you frequently need `.count` — it avoids a COUNT query.

### Don'ts
- Don't use HABTM (`has_and_belongs_to_many`) — it offers no join model, no validations, no timestamps.
- Don't create circular `dependent: :destroy` chains — they cause infinite loops.
- Don't declare associations without corresponding foreign keys in the database.
- Don't use `has_one` when the relationship is actually `has_many` — it silently ignores extra records.

---

## 7. Callbacks — Use Sparingly

Callbacks are hooks that run at specific points in an object's lifecycle (before/after save, create, update, destroy).

**Explain**: Callbacks are powerful but dangerous. They create invisible side effects that make models hard to understand, test, and debug. The Rails Guides explicitly warn about callback complexity.

### Dos
- Use callbacks only for simple, self-contained concerns directly related to the model's own data:
  - `before_validation :normalize_email` — formatting the model's own field.
  - `before_create :generate_access_token` — setting a default on the model itself.
- Keep callbacks short — delegate to a private method if logic is more than one line.
- Use `after_commit` (not `after_save`) when triggering external side effects (sending emails, enqueueing jobs) — `after_save` runs inside the transaction and the record might be rolled back.

### Don'ts
- Don't use callbacks to modify other models — use a service object instead.
- Don't use callbacks to send emails or enqueue jobs from `after_save` — use `after_commit`.
- Don't chain long sequences of callbacks — they run in declaration order and create hidden dependencies.
- Don't use `before_destroy` to prevent deletion — use `dependent: :restrict_with_error` on the parent.
- Don't use callbacks for business logic that spans multiple models — that belongs in a service object.
- Don't use `after_initialize` or `after_find` — they run on every object instantiation/query and kill performance.

---

## 8. Query Interface — Active Record Querying

Active Record provides a rich query interface that generates optimized SQL.

**Explain**: Use the query interface instead of raw SQL. It handles quoting, escaping, and database-specific syntax. It also enables method chaining and lazy evaluation.

### Dos
- Use the query interface for all database queries:
  ```ruby
  Client.where(onboarding_status: "active").order(created_at: :desc).limit(10)
  ```
- Use `find` for primary key lookups (raises `RecordNotFound` on miss — correct for show actions).
- Use `find_by` for lookups by other columns (returns `nil` on miss).
- Use `find_by!` when a miss should raise an error.
- Use eager loading to prevent N+1 queries:
  ```ruby
  # Preload associations you know you'll use
  Client.includes(:reports, :integrations).where(onboarding_status: "active")
  ```
- Use `select` to limit columns when you don't need all fields.
- Use `exists?` instead of `.count > 0` or `.present?` for existence checks — it's faster.
- Use `find_each` or `in_batches` for processing large datasets:
  ```ruby
  Client.active.find_each(batch_size: 100) do |client|
    GenerateMonthlyReportJob.perform_later(client.id)
  end
  ```
- Use scopes for reusable query fragments:
  ```ruby
  scope :for_month, ->(year, month) { where(report_month: Date.new(year, month, 1)) }
  ```

### Don'ts
- Don't use `Client.all` and iterate in Ruby to filter — let the database do the work.
- Don't use `.count` or `.present?` to check existence — use `.exists?`.
- Don't load entire tables into memory — use `find_each` for batch processing.
- Don't use raw SQL (`find_by_sql`, `execute`) unless the query interface truly can't express it.
- Don't use string interpolation in `where` clauses — it causes SQL injection:
  ```ruby
  # WRONG — SQL injection risk
  Client.where("name = '#{params[:name]}'")

  # CORRECT — parameterized
  Client.where(name: params[:name])
  Client.where("name = ?", params[:name])
  ```
- Don't trigger queries inside loops (N+1 problem) — use `includes`, `preload`, or `eager_load`.

---

## 9. Controllers

Controllers handle HTTP requests, orchestrate models/services, and render responses.

**Explain**: Rails controllers are thin by design. A controller action should: authenticate, load data, call a service or model method, render a response. That's it.

### Dos
- Keep controllers thin — no business logic, no complex conditionals.
- Use `before_action` for shared logic (authentication, loading resources):
  ```ruby
  class Admin::ClientsController < ApplicationController
    before_action :authenticate_admin!
    before_action :set_client, only: [:show, :edit, :update, :destroy]

    def show; end

    private

    def set_client
      @client = Client.find(params[:id])
    end
  end
  ```
- Use strong parameters for every action that accepts input:
  ```ruby
  def client_params
    params.require(:client).permit(:name, :email, :phone, :website_url, :has_online_scheduler)
  end
  ```
- Stick to the 7 RESTful actions: `index`, `show`, `new`, `create`, `edit`, `update`, `destroy`.
- Use `respond_to` for multiple format support (HTML, Turbo Stream, JSON).
- Use HTTP status codes correctly: `redirect_to @client, notice: "Created"` (302), `render :new, status: :unprocessable_entity` (422).
- Namespace admin controllers: `Admin::ClientsController` in `app/controllers/admin/clients_controller.rb`.

### Don'ts
- Don't put business logic in controllers — delegate to models or services.
- Don't query the database directly in views — prepare all data in the controller.
- Don't create non-RESTful actions unless absolutely necessary.
- Don't use `params[:key]` directly without strong parameters.
- Don't rescue exceptions broadly — let errors surface or handle them in a specific `rescue_from`.
- Don't render and redirect in the same action — it's a logic error.
- Don't use `session` for large objects — sessions should contain only IDs and simple flags.

---

## 10. Routing

The router maps URLs to controller actions. It is the single source of truth for your URL structure.

**Explain**: Rails routing uses a DSL in `config/routes.rb`. Resourceful routing generates standard RESTful routes. Custom routes should be the exception.

### Dos
- Use resourceful routes as the primary pattern:
  ```ruby
  namespace :admin do
    resources :clients do
      resources :integrations, only: [:index, :create, :destroy], shallow: true
    end
    resources :reports, only: [:index, :show] do
      member do
        post :regenerate
        post :send_report
      end
    end
  end
  ```
- Use `only:` or `except:` to restrict generated routes to what you actually need.
- Use `namespace` for admin sections (prefixes URL, controller module, and helper names).
- Use `shallow: true` on nested resources to keep URLs clean for show/edit/update/destroy.
- Use `member` routes for actions on a specific record, `collection` routes for actions on the set.
- Use named route helpers (`admin_client_path(@client)`) instead of hardcoded URL strings.
- Keep nesting to one level maximum: `/admin/clients/:client_id/integrations` — not deeper.
- Order routes logically in the file: public routes first, then admin namespace.

### Don'ts
- Don't create deeply nested routes (more than 1 level) — use `shallow: true` or flatten.
- Don't hardcode URL paths in views or controllers — use route helpers.
- Don't use `match` without specifying the HTTP method — it opens routes to all methods.
- Don't define routes for actions that don't exist on the controller.
- Don't put catchall routes at the top of the file — they shadow everything below them.
- Don't use sequential numeric IDs in public-facing URLs — use secure tokens.

---

## 11. Views, Layouts & Rendering

Views render the HTML response. Layouts wrap views in consistent page structure.

**Explain**: Rails uses ERB templates by default. Views live in `app/views/<controller_name>/`. Layouts live in `app/views/layouts/`. Partials are reusable view fragments prefixed with underscore.

### Dos
- Use `.html.erb` templates — this is a server-rendered Hotwire application.
- Use the application layout (`app/views/layouts/application.html.erb`) as the outer shell.
- Use partials for reusable UI components:
  ```erb
  <%= render "shared/metric_card", title: "Total Visits", value: @visits %>
  ```
- Use `content_for` and `yield` for page-specific assets or titles:
  ```erb
  <% content_for :title, "Dashboard" %>
  ```
- Use semantic HTML5: `<main>`, `<section>`, `<article>`, `<nav>`, `<header>`, `<footer>`.
- Use Rails helpers for links, forms, and assets:
  ```erb
  <%= link_to "View Report", public_report_path(report.access_token) %>
  <%= form_with model: @client do |f| %>
  ```
- Pass local variables to partials explicitly — don't rely on instance variables in partials:
  ```erb
  <%= render partial: "client_row", locals: { client: client } %>
  ```

### Don'ts
- Don't put complex Ruby logic in views — extract to helpers, presenters, or the controller.
- Don't use instance variables in partials — pass locals.
- Don't write raw `<script>` tags — use Stimulus controllers.
- Don't use inline styles — put CSS in `app/assets/stylesheets/`.
- Don't render multiple formats in one action without `respond_to`.
- Don't use `render` and `redirect_to` in the same controller path.

---

## 12. Hotwire: Turbo & Stimulus

Hotwire is Rails' default approach to building modern, interactive web applications without writing custom JavaScript for every interaction.

**Explain**: **Turbo** accelerates page navigation (Turbo Drive), enables partial page updates (Turbo Frames), and delivers real-time HTML updates (Turbo Streams). **Stimulus** adds small, focused JavaScript behaviors to existing HTML.

### Dos
- Use **Turbo Drive** (enabled by default) — it makes all link clicks and form submissions fetch via AJAX and replace the `<body>`.
- Use **Turbo Frames** to scope updates to a specific part of the page:
  ```erb
  <%= turbo_frame_tag "client_details" do %>
    <!-- This section can be independently loaded/replaced -->
  <% end %>
  ```
- Use **Turbo Streams** for real-time multi-target updates after form submissions:
  ```ruby
  respond_to do |format|
    format.turbo_stream { render turbo_stream: turbo_stream.replace(@client) }
    format.html { redirect_to @client }
  end
  ```
- Use **Stimulus** for client-side behavior (tabs, charts, toggles, copy-to-clipboard):
  ```javascript
  // app/javascript/controllers/tabs_controller.js
  import { Controller } from "@hotwired/stimulus"

  export default class extends Controller {
    static targets = ["tab", "panel"]

    switch(event) {
      const index = this.tabTargets.indexOf(event.currentTarget)
      this.panelTargets.forEach((panel, i) => {
        panel.hidden = i !== index
      })
    }
  }
  ```
- Connect Stimulus controllers via `data-controller` attributes in HTML:
  ```erb
  <div data-controller="tabs">
    <button data-tabs-target="tab" data-action="click->tabs#switch">Tab 1</button>
  </div>
  ```
- Register new Stimulus controllers in `app/javascript/controllers/index.js` via `eagerLoadControllersFrom` (already set up by Rails).

### Don'ts
- Don't add `data-turbo="false"` everywhere — fix the root issue instead.
- Don't use jQuery or legacy JavaScript libraries — use Stimulus.
- Don't write JavaScript that directly manipulates DOM outside of Stimulus controllers.
- Don't use `<script>` tags inline in views — create a Stimulus controller.
- Don't bypass Turbo for forms unless you have a specific reason (file uploads, third-party redirects).

---

## 13. Importmap & Asset Pipeline (Propshaft)

This project uses **Importmap** for JavaScript delivery and **Propshaft** for asset serving.

**Explain**: Importmap uses browser-native ES module imports via `<script type="importmap">`. No bundler, no Webpack, no Node.js build step. Propshaft is a minimal asset pipeline that serves, fingerprints, and compresses static files.

### Dos
- Pin JavaScript dependencies using the CLI:
  ```bash
  ./bin/importmap pin chart.js
  ```
- Declare pins in `config/importmap.rb`:
  ```ruby
  pin "application"
  pin "@hotwired/turbo-rails", to: "turbo.min.js"
  pin "@hotwired/stimulus", to: "stimulus.min.js"
  pin_all_from "app/javascript/controllers", under: "controllers"
  ```
- Place CSS in `app/assets/stylesheets/` — Propshaft serves it automatically.
- Place static assets (images, fonts) in `app/assets/images/` or `app/assets/fonts/`.
- Use `asset_path` helper in CSS/ERB for fingerprinted asset URLs.

### Don'ts
- Don't install Webpack, esbuild, Vite, or any JS bundler — Importmap handles everything.
- Don't add `node_modules/` to the project — Importmap pins from CDN or `vendor/javascript/`.
- Don't use `require` syntax — use ES module `import`.
- Don't add `cssbundling-rails` or `jsbundling-rails` gems.
- Don't put JavaScript in `app/assets/` — put it in `app/javascript/`.

---

## 14. Active Job & Solid Queue

Background jobs handle work that shouldn't block HTTP requests.

**Explain**: Active Job is Rails' unified interface for background jobs. This project uses **Solid Queue** — a database-backed queue that requires no Redis or external dependencies. Recurring schedules are defined in `config/recurring.yml`.

### Dos
- Inherit all jobs from `ApplicationJob`.
- Place jobs in `app/jobs/` with descriptive names:
  ```ruby
  # app/jobs/generate_monthly_report_job.rb
  class GenerateMonthlyReportJob < ApplicationJob
    queue_as :default
    retry_on StandardError, wait: :polynomially_longer, attempts: 3

    def perform(client_id, year, month)
      client = Client.find(client_id)
      ReportGenerator.new(client, year, month).call
    end
  end
  ```
- Make jobs **idempotent** — safe to retry without creating duplicates or side effects.
- Pass IDs as arguments, not full ActiveRecord objects — objects can't be serialized reliably.
- Use `retry_on` for transient failures (API timeouts, network errors).
- Use `discard_on` for permanent failures (record not found, invalid state).
- Define recurring schedules in `config/recurring.yml`:
  ```yaml
  generate_monthly_reports:
    class: GenerateMonthlyReportJob
    schedule: "0 6 1 * *"  # 6am on the 1st of every month
  ```
- Keep jobs small — delegate to service objects for the actual work.

### Don'ts
- Don't pass ActiveRecord objects as job arguments — pass IDs and re-query.
- Don't perform synchronous long-running work in controller actions — enqueue a job.
- Don't catch and swallow all errors — let Solid Queue's retry mechanism handle transient failures.
- Don't add Redis, Sidekiq, or Resque — Solid Queue is the queue backend for this project.
- Don't put complex logic directly in the `perform` method — delegate to a service.

---

## 15. Action Mailer

Mailers generate and send emails.

**Explain**: Mailers are similar to controllers — they have actions that render templates. Each mailer action returns a `Mail::Message` object. Emails should always be sent from background jobs, not from controller actions.

### Dos
- Place mailers in `app/mailers/`, views in `app/views/<mailer_name>/`.
- Always create both HTML and plain-text templates:
  ```
  app/views/report_mailer/report_ready.html.erb
  app/views/report_mailer/report_ready.text.erb
  ```
- Use `deliver_later` (not `deliver_now`) to enqueue email delivery as a background job:
  ```ruby
  ReportMailer.report_ready(report).deliver_later
  ```
- Set a default `from` address in `ApplicationMailer`:
  ```ruby
  class ApplicationMailer < ActionMailer::Base
    default from: "reports@mysocialpractice.com"
    layout "mailer"
  end
  ```
- Use mailer previews for development testing:
  ```ruby
  # test/mailers/previews/report_mailer_preview.rb
  class ReportMailerPreview < ActionMailer::Preview
    def report_ready
      ReportMailer.report_ready(MonthlyReport.first)
    end
  end
  ```

### Don'ts
- Don't use `deliver_now` in production code — it blocks the request.
- Don't put complex logic in mailers — they should only assemble the email.
- Don't forget the plain-text template — email clients fall back to it.
- Don't send emails directly from controllers — enqueue via a job or use `deliver_later`.

---

## 16. Services & Business Logic

Service objects encapsulate business operations that don't belong in models or controllers.

**Explain**: Rails doesn't generate a `services` directory by default, but it's a widely adopted convention. `app/services/` is autoloaded by Zeitwerk, so classes there are available without `require`. Use services for operations that orchestrate multiple models, call external APIs, or implement complex business rules.

### Dos
- Place services in `app/services/` — they are autoloaded.
- Name services as action-oriented nouns: `ReportGenerator`, `SitemapCrawler`, `AiSummaryBuilder`.
- Use a consistent interface — prefer `#call` or a descriptively named method:
  ```ruby
  class ReportGenerator
    def initialize(client, year, month)
      @client = client
      @year = year
      @month = month
    end

    def call
      # orchestrate data fetching, aggregation, report creation
    end
  end
  ```
- Organize API adapters in a subdirectory: `app/services/adapters/semrush_adapter.rb`.
- Return structured results (not raw booleans) so callers can inspect outcomes:
  ```ruby
  Result = Struct.new(:success?, :report, :errors, keyword_init: true)
  ```
- Handle errors gracefully — rescue specific exceptions, log them, return structured errors.
- Keep services focused: one service = one responsibility.

### Don'ts
- Don't put API logic in models or controllers — it belongs in service objects.
- Don't create "god services" that do everything — split into focused classes.
- Don't use class methods as the primary interface — instantiate with dependencies.
- Don't hardcode API endpoints or keys — use `Rails.application.credentials` or `ENV`.
- Don't silently swallow errors in service objects — always return or raise.

---

## 17. Autoloading & Zeitwerk

Rails 8 uses **Zeitwerk** for autoloading. Files and their class names must follow strict naming conventions.

**Explain**: Zeitwerk maps file paths to constants. `app/models/client.rb` must define `Client`. `app/services/adapters/semrush_adapter.rb` must define `Adapters::SemrushAdapter`. If the mapping is wrong, you get `NameError` at runtime.

### Dos
- Follow the naming convention exactly:
  | File path | Must define |
  |---|---|
  | `app/models/client.rb` | `Client` |
  | `app/models/monthly_report.rb` | `MonthlyReport` |
  | `app/services/report_generator.rb` | `ReportGenerator` |
  | `app/services/adapters/semrush_adapter.rb` | `Adapters::SemrushAdapter` |
  | `app/controllers/admin/clients_controller.rb` | `Admin::ClientsController` |
  | `app/jobs/generate_monthly_report_job.rb` | `GenerateMonthlyReportJob` |
- One class/module per file — Zeitwerk enforces this.
- Use `config.autoload_lib(ignore: %w[assets tasks])` (already configured) for `lib/` code.
- Use `Rails.autoloaders.log!` in development to debug autoloading issues.

### Don'ts
- Don't use `require` or `require_relative` for autoloaded code — Zeitwerk handles it.
- Don't put multiple classes in one file — Zeitwerk expects one constant per file.
- Don't use acronyms inconsistently — define inflections in `config/initializers/inflections.rb` if needed:
  ```ruby
  ActiveSupport::Inflector.inflections(:en) do |inflect|
    inflect.acronym "API"
    inflect.acronym "GHL"
    inflect.acronym "AI"
  end
  ```
- Don't name files with numbers at the beginning — Zeitwerk can't handle `1_migration.rb`.

---

## 18. Testing

Rails uses **Minitest** by default. Tests verify that your code works as intended.

**Explain**: Tests live in `test/` and mirror the `app/` structure. Fixtures (YAML files) provide test data. The test database is separate from development and is reset before each test run.

### Dos
- Use the standard test directory structure:
  ```
  test/
  ├── models/          — Unit tests for models
  ├── controllers/     — Functional tests for controllers
  ├── integration/     — End-to-end request tests
  ├── services/        — Tests for service objects
  ├── jobs/            — Tests for background jobs
  ├── mailers/         — Tests for mailers
  ├── system/          — Browser tests (Capybara + Selenium)
  └── fixtures/        — YAML test data
  ```
- Use fixtures for test data — they're fast and transactional:
  ```yaml
  # test/fixtures/clients.yml
  acme_dental:
    id: <%= SecureRandom.uuid %>
    name: "Acme Dental"
    email: "admin@acmedental.com"
    onboarding_status: "active"
  ```
- Test the public interface, not internals.
- Test happy path, edge cases, and error conditions.
- Use `assert_difference` for testing record creation/deletion:
  ```ruby
  assert_difference "Client.count", 1 do
    post admin_clients_path, params: { client: valid_params }
  end
  ```
- Run tests: `bin/rails test` (unit/integration) and `bin/rails test:system` (browser).
- Use `setup` method for shared test setup, not `before` (that's RSpec).

### Don'ts
- Don't use RSpec unless explicitly requested — Minitest is the Rails default.
- Don't use `sleep` in tests — use proper assertions and Capybara wait mechanisms.
- Don't test framework behavior — test your application's behavior.
- Don't create test data with `create` in every test — use fixtures for speed.
- Don't write tests that depend on execution order — each test should be independent.
- Don't mock/stub everything — test real behavior when practical.

---

## 19. Security

Rails includes security protections by default. Understand them and don't disable them.

**Explain**: Rails protects against CSRF, SQL injection, XSS, and mass assignment out of the box. The [Rails Security Guide](https://guides.rubyonrails.org/security.html) is essential reading.

### Dos
- Use **strong parameters** in every controller — never pass `params` directly to mass assignment.
- Use **CSRF protection** (enabled by default via `protect_from_forgery with: :exception`).
- Use `has_secure_password` for password authentication (bcrypt):
  ```ruby
  class AdminUser < ApplicationRecord
    has_secure_password
    validates :email, presence: true, uniqueness: true
  end
  ```
- Store secrets in `config/credentials.yml.enc` — edit with `bin/rails credentials:edit`.
- Use `ActiveRecord::Encryption` for sensitive database columns (API tokens, PII):
  ```ruby
  class AgencyConnection < ApplicationRecord
    encrypts :encrypted_credentials
  end
  ```
- Use `SecureRandom.urlsafe_base64(32)` for tokens (report access tokens, API keys).
- Use parameterized queries — never string-interpolate user input into SQL.
- Run security scanners regularly:
  ```bash
  bin/brakeman          # Static analysis for vulnerabilities
  bin/bundler-audit     # Check gems for known CVEs
  ```
- Set secure headers via `config/initializers/content_security_policy.rb`.
- Use `filter_parameter_logging.rb` to prevent sensitive data from appearing in logs.

### Don'ts
- Don't disable CSRF protection.
- Don't use `params.permit!` — it permits everything and defeats strong parameters.
- Don't store passwords in plaintext — always use `has_secure_password` (bcrypt).
- Don't store API keys in source code, `.env` files committed to git, or plain database columns.
- Don't use `html_safe` or `raw` unless you have explicitly sanitized the content.
- Don't log sensitive data — passwords, tokens, API keys, and personal information.
- Don't use `send` or `public_send` with user-controlled method names — it enables arbitrary method execution.
- Don't commit `config/master.key` or any credential decryption key.

---

## 20. Caching

Caching reduces database queries and speeds up responses.

**Explain**: This project uses **Solid Cache** (database-backed, no Redis). Rails provides fragment caching, Russian doll caching, and low-level caching out of the box.

### Dos
- Use fragment caching in views for expensive partials:
  ```erb
  <% cache @client do %>
    <%= render "client_details", client: @client %>
  <% end %>
  ```
- Use Russian doll caching (nested caches that auto-expire):
  ```erb
  <% cache @report do %>
    <% @report.metrics.each do |metric| %>
      <% cache metric do %>
        <%= render metric %>
      <% end %>
    <% end %>
  <% end %>
  ```
- Use `touch: true` on `belongs_to` to expire parent caches when children change:
  ```ruby
  belongs_to :report, touch: true
  ```
- Use low-level caching for expensive computations:
  ```ruby
  Rails.cache.fetch("client_#{id}/keyword_summary/#{year}/#{month}", expires_in: 1.hour) do
    compute_keyword_summary
  end
  ```

### Don'ts
- Don't cache user-specific content without including the user in the cache key.
- Don't cache data that changes frequently without an expiration strategy.
- Don't use `Rails.cache.write` when `Rails.cache.fetch` with a block is more appropriate.
- Don't cache in development unless you're specifically testing caching behavior (`bin/rails dev:cache` to toggle).

---

## 21. Error Reporting & Logging

Rails 8 has a built-in error reporting API (`Rails.error`).

**Explain**: Use `Rails.error.handle` and `Rails.error.record` to capture and report errors consistently. All subscribers (error tracking services, custom loggers) receive the error context automatically.

### Dos
- Use `Rails.error.handle` to rescue and continue:
  ```ruby
  Rails.error.handle(context: { client_id: client.id, service: "semrush" }) do
    adapter.fetch_data(year: year, month: month)
  end
  ```
- Use `Rails.error.record` to rescue, report, and re-raise:
  ```ruby
  Rails.error.record(context: { report_id: report.id }) do
    generate_report!
  end
  ```
- Use structured log messages with context:
  ```ruby
  Rails.logger.info("[ReportGenerator] Generated report for client=#{client.id} month=#{month}/#{year}")
  Rails.logger.error("[SemrushAdapter] API call failed: #{e.message} client=#{client.id}")
  ```
- Use appropriate log levels: `debug` for verbose detail, `info` for normal operations, `warn` for recoverable issues, `error` for failures.

### Don'ts
- Don't use `puts` or `p` — use `Rails.logger`.
- Don't rescue `Exception` — rescue `StandardError` or more specific classes.
- Don't log full API responses at `info` level — use `debug`.
- Don't swallow errors silently — always log or report.
- Don't include sensitive data in log messages (passwords, tokens, PII).

---

## 22. Configuration & Credentials

Rails separates configuration from code using credentials, environment files, and initializers.

**Explain**: Secrets go in `config/credentials.yml.enc` (encrypted, committed to git). Environment-specific settings go in `config/environments/`. Application-wide config goes in `config/application.rb` or initializers.

### Dos
- Store API keys and secrets in Rails credentials:
  ```bash
  bin/rails credentials:edit
  ```
  ```yaml
  semrush:
    api_key: sk_live_xxxxx
  yext:
    api_key: yt_xxxxx
  ```
- Access credentials in code:
  ```ruby
  Rails.application.credentials.dig(:semrush, :api_key)
  ```
- Use per-environment credentials for production:
  ```bash
  bin/rails credentials:edit --environment production
  ```
- Use `config/recurring.yml` for Solid Queue scheduled jobs.
- Keep environment-specific settings in `config/environments/`.
- Use initializers (`config/initializers/`) for gem configuration and application boot setup.

### Don'ts
- Don't commit `config/master.key` or `config/credentials/production.key`.
- Don't put secrets in environment variables for local development — use Rails credentials.
- Don't hardcode API URLs, keys, or environment-specific values in application code.
- Don't use `Rails.env.production?` scattered through business logic — use configuration objects or feature flags.
- Don't put runtime logic in initializers — they run once at boot.

---

## 23. Naming Conventions — Complete Reference

Consistent naming is critical because Rails autoloading, routing, and association inference all depend on it.

### Dos

| Entity | Convention | Example |
|---|---|---|
| Model class | Singular PascalCase | `Client`, `MonthlyReport`, `ClientKeyword` |
| Database table | Plural snake_case | `clients`, `monthly_reports`, `client_keywords` |
| Database column | snake_case | `report_month`, `access_token`, `ai_seo_enrolled` |
| Foreign key | `<singular_model>_id` | `client_id`, `monthly_report_id` |
| Controller class | Plural PascalCase + `Controller` | `ClientsController`, `Admin::ReportsController` |
| Controller file | Plural snake_case | `clients_controller.rb`, `admin/reports_controller.rb` |
| Job class | Verb + Noun + `Job` | `GenerateMonthlyReportJob`, `DeliverReportJob` |
| Mailer class | Noun + `Mailer` | `ReportMailer`, `AdminNotificationMailer` |
| Service class | Action noun | `ReportGenerator`, `SemrushAdapter`, `AiSummaryBuilder` |
| Helper module | Singular + `Helper` | `ApplicationHelper`, `ReportsHelper` |
| View directory | Matches controller (plural) | `app/views/admin/clients/` |
| Partial file | Underscore prefix | `_header.html.erb`, `_metric_card.html.erb` |
| Stimulus controller | Kebab-case + `-controller` | `tabs-controller.js` → `data-controller="tabs"` |
| Test file | Matches source + `_test.rb` | `client_test.rb`, `report_generator_test.rb` |
| Fixture file | Plural, matches table | `clients.yml`, `monthly_reports.yml` |
| Boolean columns | Adjective or `has_`/`is_`/`needs_` | `ai_seo_enrolled`, `has_online_scheduler`, `is_first_report`, `needs_action` |
| Timestamp columns | `_at` suffix | `created_at`, `sent_at`, `generated_at`, `emailed_at` |
| Date columns | `_on` suffix or descriptive | `onboarded_at`, `published_at`, `report_month` |
| Count columns | `_count` suffix | `reports_count`, `total_reviews` |
| Status/state columns | Descriptive noun | `onboarding_status`, `credential_status`, `ghl_data_status` |

### Don'ts
- Don't abbreviate unless universally understood (`url`, `id`, `pct` — OK. `rpt`, `clnt`, `kw` — not OK).
- Don't use generic names: `data`, `info`, `stuff`, `handle`, `process`.
- Don't pluralize model class names.
- Don't use camelCase for database columns, file names, or routes.
- Don't use `type` as a column name unless it's for Single Table Inheritance (STI).

---

## 24. File & Directory Structure

Rails has a mandated directory structure. Zeitwerk autoloading depends on it.

### Dos
```
app/
├── assets/
│   ├── images/                 ← Static images
│   └── stylesheets/
│       └── application.css     ← Main stylesheet
├── controllers/
│   ├── admin/                  ← Admin namespace
│   │   └── clients_controller.rb
│   ├── application_controller.rb
│   └── concerns/               ← Shared controller modules
├── helpers/                     ← View helper modules
├── javascript/
│   ├── application.js           ← JS entrypoint
│   └── controllers/             ← Stimulus controllers
│       ├── application.js
│       ├── index.js
│       └── tabs_controller.js
├── jobs/                        ← Background jobs
│   └── generate_monthly_report_job.rb
├── mailers/                     ← Email mailers
│   └── report_mailer.rb
├── models/
│   ├── client.rb
│   ├── monthly_report.rb
│   └── concerns/               ← Shared model modules
├── services/                    ← Business logic (not Rails default, but autoloaded)
│   ├── report_generator.rb
│   ├── ai_summary_builder.rb
│   └── adapters/                ← Third-party API adapters
│       ├── base_adapter.rb
│       ├── semrush_adapter.rb
│       ├── yext_adapter.rb
│       ├── ga4_adapter.rb
│       └── ghl_adapter.rb
├── validators/                  ← Custom validators (optional)
└── views/
    ├── admin/
    │   └── clients/
    ├── layouts/
    │   ├── application.html.erb
    │   ├── mailer.html.erb
    │   └── mailer.text.erb
    ├── reports/                 ← Client-facing report views
    └── shared/                  ← Shared partials
config/
├── credentials.yml.enc         ← Encrypted secrets (committed)
├── database.yml                ← PostgreSQL connection config
├── importmap.rb                ← JS pin declarations
├── recurring.yml               ← Solid Queue scheduled jobs
├── routes.rb                   ← URL routing
├── initializers/               ← Boot-time configuration
│   └── inflections.rb          ← Acronym rules (API, GHL, AI, etc.)
└── environments/               ← Per-environment overrides
db/
├── migrate/                    ← All schema migrations (timestamped)
├── schema.rb                   ← Auto-generated schema snapshot
└── seeds.rb                    ← Seed data
test/
├── models/
├── controllers/
├── integration/
├── services/
├── jobs/
├── mailers/
├── system/                     ← Browser tests (Capybara)
└── fixtures/                   ← YAML test data
```

### Don'ts
- Don't create `app/lib/` — use `app/services/` for autoloaded business logic, `lib/` for non-autoloaded utilities.
- Don't nest models more than one level deep.
- Don't put JavaScript in `app/assets/` — put it in `app/javascript/`.
- Don't put CSS in `app/javascript/` — put it in `app/assets/stylesheets/`.
- Don't create directories in `app/` that Zeitwerk can't autoload — check with `Rails.autoloaders.log!`.

---

## 25. Git & Version Control

### Dos
- Write descriptive commit messages: `Add client keyword ranking model and migration`.
- Use feature branches: `feature/report-generation`, `fix/ga4-auth-refresh`.
- Keep commits atomic — one logical change per commit.
- Run `bin/rubocop` and `bin/rails test` before pushing.
- Commit `db/schema.rb` after every migration.
- Use `.gitignore` (already configured) to exclude logs, tmp, keys, and IDE files.

### Don'ts
- Don't commit `config/master.key`, `config/credentials/production.key`, or `.env` files.
- Don't commit `node_modules/`, `log/`, `tmp/`, or `storage/` contents.
- Don't force-push to `main`.
- Don't commit TODO/FIXME without a linked issue or explanation.
- Don't rewrite history on shared branches.

---

## 26. Project-Specific Business Rules

These rules are derived from the MSP SOW and must be respected in all code.

### Dos
- Reports cover **fully completed months only** — never the current in-progress month.
- Report access tokens (`monthly_reports.access_token`) must be cryptographically random and unguessable (`SecureRandom.urlsafe_base64(32)`).
- `emailed_at` on `monthly_reports` prevents duplicate sends — always check before sending.
- The `(client_id, report_month)` unique index prevents duplicate reports — enforce in model validations too.
- GHL data shows `"?"` placeholder with explanatory callout when `has_online_scheduler` is false.
- AI Visibility section is omitted entirely when `ai_seo_enrolled` is false.
- AI summary banners follow strict guardrails:
  - Only reference facts/numbers present in that month's computed data.
  - Max 2-3 sentences per banner.
  - Omit the section entirely if nothing genuinely positive — never generate filler.
- Keyword aggregates (gained/held/dropped counts) are computed at **runtime** — not stored.
- MoM comparisons use **current month vs. immediately previous month** only.
- `report_traffic.ghl_data_status` is **snapshotted at generation time** and never retroactively updated.
- New website pages are detected via sitemap diffing; page titles and meta descriptions are pulled directly from each page's DOM.

### Don'ts
- Don't generate or display a report for the current (incomplete) month.
- Don't generate AI summary text that includes numbers not present in the report data.
- Don't pre-compute keyword aggregate counts into the database — derive at render time.
- Don't allow report URLs to be guessable (no sequential IDs, no client-name slugs).
- Don't retroactively update snapshotted report data — each report is a frozen-in-time record.
