---
title: Configuration and environments
slug: configuration
kind: reference
last_verified: 2026-08-02
---

# Configuration and environments

Every environment variable, credential, and non-default piece of configuration, and what
breaks without each.

---

## The stack

| Piece | Choice |
|---|---|
| Framework | Rails 8.1.2, Ruby 3.3.7 |
| Database | PostgreSQL 16 (`pg`), four logical databases in production |
| Assets | Propshaft; **no Node build step** |
| JavaScript | Importmap + Hotwire (Turbo, Stimulus) |
| CSS | Tailwind v4 via `tailwindcss-rails` |
| Jobs / cache / cable | Solid Queue, Solid Cache, Solid Cable |
| HTTP client | Faraday with `faraday-retry` |
| Soft delete | `discard` |
| Testing | Minitest, WebMock, Capybara + Selenium |
| Container | Dockerfile → Thruster → Puma |

---

## Environment variables

### Required in production

| Variable | Purpose | Without it |
|---|---|---|
| `DATABASE_URL` | Primary database | App will not boot |
| `QUEUE_DATABASE_URL` | Solid Queue | Jobs unavailable |
| `CACHE_DATABASE_URL` | Solid Cache | Cache unavailable |
| `CABLE_DATABASE_URL` | Solid Cable | Cable unavailable |
| `AR_ENCRYPTION_PRIMARY_KEY` | Encrypted credential columns | **Boot raises** |
| `AR_ENCRYPTION_DETERMINISTIC_KEY` | Same | **Boot raises** |
| `AR_ENCRYPTION_KEY_DERIVATION_SALT` | Same | **Boot raises** |

Generate the three encryption values with `bin/rails db:encryption:init`.

### Optional

| Variable | Purpose | Default |
|---|---|---|
| `SOLID_QUEUE_IN_PUMA` | Runs the job worker inside the web process | **Unset — see the warning below** |
| `ANTHROPIC_API_KEY` | Report highlight banners | Unset; banners silently omitted |
| `RAILS_LOG_LEVEL` | Log verbosity | `info` |
| `RAILS_MASTER_KEY` | Credentials file, if used instead of the AR encryption vars | — |

### Used only by the manual testing rake task

`REAL_CLIENT_NAME`, `REAL_CLIENT_WEBSITE`, `REAL_CLIENT_ADDRESS`, `REPORT_MONTH`,
`APP_HOST`, `HUBSPOT_ACCESS_TOKEN`, `HUBSPOT_COMPANY_ID`, `GHL_ACCESS_TOKEN`,
`GHL_LOCATION_ID`, `YEXT_API_KEY`, `YEXT_ENTITY_ID`, `SEMRUSH_API_KEY`,
`SEMRUSH_PROJECT_ID`, `GA4_PROPERTY_ID`, `GA4_SERVICE_ACCOUNT_EMAIL`,
`GA4_SERVICE_ACCOUNT_PRIVATE_KEY`.

See `lib/tasks/real_client.rake`. **Credentials come from the environment only — never
hardcode a real key there, the file is committed.**

---

## Active Record encryption

`config/initializers/active_record_encryption.rb` backs the two encrypted credential
columns (`AgencyConnection#encrypted_credentials`,
`ClientServiceLink#override_credentials`).

Resolution order: Rails credentials → environment variables → **insecure fixed defaults
outside production**.

**Production raises without real keys**, with one exemption: `SECRET_KEY_BASE_DUMMY=1`,
which the Dockerfile sets during `assets:precompile`, since that step boots the full
environment with no runtime secrets available. **Do not widen that exemption** — an earlier
version of this broke a deploy (`858fae1`).

Dev and test fall back to fixed insecure values so the app boots without configuration.
This is why CI needs no secrets and why `RAILS_MASTER_KEY` is deliberately commented out in
the workflow. **Don't "fix" that by adding the secret.**

---

## Credentials to obtain

| Service | Credential | Where from |
|---|---|---|
| HubSpot | Private-app access token | HubSpot private app |
| GoHighLevel | v2 OAuth access token | GHL; agency-wide needs Marketplace access (**not yet available**) |
| Yext | API key | Yext account |
| SEMrush | API key | SEMrush account |
| Google Analytics | Service-account `client_email` + `private_key` | Google Cloud Console — see [MSP-GUIDE](../MSP-GUIDE.md#set-up-google-analytics-for-a-practice) |
| Anthropic | API key | **Environment variable only**, not the admin panel |

The first five are managed under Connections in the admin panel. Anthropic is the
exception.

---

## Initializers worth knowing

| File | What it does |
|---|---|
| `config/initializers/active_record_encryption.rb` | The above. The only substantially custom initializer |
| `config/initializers/filter_parameter_logging.rb` | Redacts `passw`, `email`, `secret`, `token`, `_key`, `crypt`, `salt`, and card fields |
| `config/initializers/content_security_policy.rb`, `assets.rb`, `inflections.rb` | Rails defaults, unmodified |

**`filter_parameters` does not protect report links.** The access token is a **path
segment**, not a parameter, so `Started GET "/reports/<token>"` is written verbatim to the
production log. Anyone with log access can open any practice's report. Decide explicitly
how to handle this — see CLAUDE.md → Security.

---

## Production settings

| Setting | State |
|---|---|
| `config.log_level` | `ENV["RAILS_LOG_LEVEL"]`, default `info` |
| `config.cache_store` | `:solid_cache_store` |
| `config.active_job.queue_adapter` | `:solid_queue`, on its own `queue` database |
| `config.force_ssl` / `assume_ssl` | **Commented out** — session cookie not marked secure, no HSTS |
| `config.hosts` | **Unset** — no DNS-rebinding protection |
| `action_mailer.default_url_options` | **`example.com`** — a placeholder; every emailed link would point there |

The last three are open gaps, recorded in CLAUDE.md → Security.

---

## Deployment

Container-based: `Dockerfile` → `bin/thrust bin/rails server`, `EXPOSE 80`. Thruster
handles compression, caching and X-Sendfile.

**The real target appears to be Railway**, per the encryption initializer's reference to its
Variables tab. **`config/deploy.yml` is untouched Kamal boilerplate** — `192.168.0.1`,
registry `localhost:5555`, SSL commented out. Do not read it as deployment truth. Either
make Kamal real or delete it, so there is one answer.

### The worker

`config/puma.rb` starts Solid Queue **inside Puma only if `SOLID_QUEUE_IN_PUMA` is set**,
and the Dockerfile's `CMD` runs only the web server.

**If that variable is not set in the deploy environment, enqueued jobs sit in the queue
forever with no error** — which today means the nightly page scan silently never runs.
Verify it, or run `bin/jobs` as a separate process.

### Assets

Tailwind compiles at deploy into `app/assets/builds/`, which is **gitignored**. A token or
class change needs no artifact committed, but it does need a successful build step — and
locally you need `bin/dev` (which runs the Tailwind watcher) to see CSS changes.

---

## Local setup

```bash
bin/setup          # dependencies + database
bin/dev            # Rails + Tailwind watcher
bin/rails db:seed  # three demo practices with full reports
```

`db/seeds.rb` is idempotent by practice name and prints a report URL for each. It creates
three deliberately different practices — a first report, one with revenue and a negative
review, and one enrolled in AI SEO — so every rendering path can be checked without calling
a real API. It also seeds the `services` lookup rows, which a schema-loaded database would
otherwise lack.

No credentials are needed for seeds or tests. Encryption falls back to insecure local
defaults, and WebMock blocks all outbound HTTP in tests.
