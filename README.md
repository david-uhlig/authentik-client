# 🔓 authentik API Client

[![Gem Version](http://img.shields.io/gem/v/authentik-client.svg)][gem]
[![License: MIT](https://img.shields.io/github/license/david-uhlig/authentik-client?label=License&labelColor=343B42&color=blue)][license]
[![Tests](https://github.com/david-uhlig/authentik-client/actions/workflows/main.yml/badge.svg)][tests]

An idiomatic Ruby interface for the [authentik] API; the open-source Identity Provider (IdP) and Single Sign On (SSO) platform.

This library lets you manage configuration objects in authentik - such as users, groups, and more - through a clean Ruby interface. It is *not* intended for handling SSO within your own application.

Built as a developer-friendly wrapper around the auto-generated [authentik-api] gem (via OpenAPI Generator), it simplifies common tasks and abstracts away much of the low-level complexity of the underlying client.

> [!TIP]
> For guidance on handling authentication, see [Authentication with authentik in Ruby](#authentication-with-authentik-in-ruby).

## Installation

Add the following line to your application's Gemfile:

```bash
gem "authentik-client"
```

Then install the dependencies with `bundle install`. Alternatively, you can add the gem directly from the commandline: `bundle add "authentik-client"`.

This installs the latest release of the baseline [authentik-api] client, which tracks the most recent authentik release.

To ensure compatibility with a specific authentik version, explicitly require a matching `authentik-api` version:

```ruby
# Use the latest `2026.2.x` series release (excluding release candidates).
gem "authentik-api" "~> 2026.2.0"
gem "authentik-client"
# Pin to an exact patch version.
gem "authentik-api" "2026.2.1"
gem "authentik-client"
# Test a release candidate.
gem "authentik-api" "2026.5.0-rc1"
gem "authentik-client"
# Use the latest unreleased code from GitHub.
# Tracks authentik's main branch and updates daily when the OpenAPI schema changes.
gem "authentik-api", github: "david-uhlig/authentik-api"
gem "authentik-client"
```

## Usage

### Configuration

This gem offers three ways to initialize the authentik API client:

* [At startup](#configuring-at-startup), with an initializer
* [A Rails configuration file](#rails-integration), e.g. `config/application.rb`
* [At runtime](#creating-a-client)

You can freely mix startup and runtime initialization; i.e., initialize the host in a Rails configuration file and provide the token at runtime.

#### Configuring at startup

You can configure `Authentik::Client` once globally. For example, at application startup (e.g., in a Rails initializer), and then create client instances without repeating connection details:

```ruby
# config/initializers/authentik.rb
Authentik::Client.configure do |config|
  config.host  = "authentik.example.com"
  config.token = "your-api-token"
end
```

With a global configuration in place, clients can be created without arguments:

```ruby
client = Authentik::Client.new
```

But you can also overwrite any globally configured attribute:

```ruby
client = Authentik::Client.new(token: "your-runtime-api-token")
```

> [!NOTE]
> Global configuration is fully optional.

#### Rails integration

Alternatively, when using the gem in a Rails application, it automatically loads a [Railtie](lib/authentik/client/railtie.rb) that exposes `config.authentik_client` as a standard Rails configuration accessor.

`config.authentik_client` is the same configuration class instance as `Authentik::Client.configuration`, so both styles are always in sync.

```ruby
# config/application.rb (or any environment file)

# ...
module YourApplication
  class Application < Rails::Application
    # ...
    config.authentik_client.host  = "authentik.example.com"
    config.authentik_client.token = ENV["AUTHENTIK_TOKEN"]
  end
end
```

You can also use environment-specific files:

```ruby
# config/environments/production.rb

# ...
module YourApplication
  class Application < Rails::Application
    # ...
    config.authentik_client.verify_ssl = true
  end
end
```

#### Creating a client

Finally, you can configure client instances at runtime.

```ruby
client = Authentik::Client.new(
  host: "authentik.example.com",
  token: "your-api-token"
)
```

Additional configuration options are forwarded to the underlying, auto-generated OpenAPI client:

```ruby
client = Authentik::Client.new(
  host: "authentik.example.com",
  token: "your-api-token",
  scheme: "https",    # default
  verify_ssl: false,  # disable SSL verification (e.g. for development)
  timeout: 60         # request timeout in seconds
)
```

See [`Authentik::Api::Configuration`](https://github.com/david-uhlig/authentik-api/blob/main/lib/authentik/api/configuration.rb) for a list of all available configuration options.

### Calling API endpoints

The client exposes API endpoints directly as methods.

```ruby
# Core API - lists applications.
#
# Calls `Authentik::Api::CoreApi#core_applications_list`.
# Issues a `GET` request to the `/api/v3/core/applications/` endpoint,
# see: https://api.goauthentik.io/reference/core-applications-list/.
client.core_applications_list

# Core API - lists users.
#
# Calls `Authentik::Api::CoreApi#core_users_list`.
client.core_users_list

# Admin API - retrieves the authentik version.
client.admin_version_retrieve

# OAuth2 API - lists access tokens.
client.oauth2_access_tokens_list

# Propertymappings API - lists all property mappings.
client.propertymappings_all_list
```

You can also access an API group object directly. For example, `client.core`
returns the memoized `Authentik::Api::CoreApi` instance used internally for
core endpoint dispatch.

The full list of generated endpoint methods is available in the
[auto-generated README](https://github.com/david-uhlig/authentik-api/blob/main/README_API.md) and on [api.goauthentik.io](https://api.goauthentik.io/).

**Each generated API group instance is initialized once and reused internally.**

> [!TIP]
> If you're primarily using one API group, you can assign it to a variable and do:
> ```ruby
> propmap_api = client.propertymappings
> propmap_api.all_list
> ```
> instead of:
> ```ruby
> client.propertymappings.all_list
> ```

### Available API groups

The full API reference is available at [api.goauthentik.io](https://api.goauthentik.io/).
Each group method returns the corresponding generated API class instance.

| Method                    | API class             |
|---------------------------|-----------------------|
| `client.admin`            | `AdminApi`            |
| `client.authenticators`   | `AuthenticatorsApi`   |
| `client.core`             | `CoreApi`             |
| `client.crypto`           | `CryptoApi`           |
| `client.enterprise`       | `EnterpriseApi`       |
| `client.events`           | `EventsApi`           |
| `client.flows`            | `FlowsApi`            |
| `client.managed`          | `ManagedApi`          |
| `client.oauth2`           | `Oauth2Api`           |
| `client.outposts`         | `OutpostsApi`         |
| `client.policies`         | `PoliciesApi`         |
| `client.propertymappings` | `PropertymappingsApi` |
| `client.providers`        | `ProvidersApi`        |
| `client.rac`              | `RacApi`              |
| `client.rbac`             | `RbacApi`             |
| `client.root`             | `RootApi`             |
| `client.schema`           | `SchemaApi`           |
| `client.sources`          | `SourcesApi`          |
| `client.ssf`              | `SsfApi`              |
| `client.stages`           | `StagesApi`           |
| `client.tasks`            | `TasksApi`            |
| `client.tenants`          | `TenantsApi`          |

New API groups introduced by future authentik releases are automatically discovered without changes to `Authentik::Client` wrapper.

## Versioning

This library aims to adhere to [Semantic Versioning 2.0.0](http://semver.org/). Violations of this scheme should be reported as bugs.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt.

To regenerate the underlying OpenAPI client run `bin/generate-api`.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/david-uhlig/authentik-client. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/david-uhlig/authentik-client/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](LICENSE.md).

## Code of Conduct

Everyone interacting in this project's codebases, issue trackers, chat rooms, and mailing lists is expected to follow the [code of conduct](https://github.com/david-uhlig/authentik-client/blob/main/CODE_OF_CONDUCT.md).

## Attribution

* [authentik]: The open-source IdP and SSO platform. Providing flexible and scalable authentication.

> [!NOTE]
> This project is not affiliated with or endorsed by Authentik Security Inc.

## Appendix

### Authentication with authentik in Ruby

For integrating authentik authentication into your Ruby application, you can use [OmniAuth](https://github.com/omniauth/omniauth) with the [omniauth_oidc](https://github.com/msuliq/omniauth_oidc) gem, and an OAuth2/OIDC provider configured in authentik.

#### Quick Setup Guide for Rails

1\. Configure an OAuth2/OIDC provider under: `https://authentik.example.com/if/admin/#/core/providers`

2\. Add the gems to your Gemfile:
```ruby
gem 'omniauth'
gem 'omniauth_oidc'
```

3\. Configure OmniAuth
```ruby
# config/initializers/omniauth.rb
Rails.application.config.middleware.use OmniAuth::Builder do
  provider :oidc, {
    name: :authentik,
    client_options: {
      identifier: ENV["CLIENT_ID"],
      secret: ENV["CLIENT_SECRET"],
      config_endpoint: "https://authentik.example.com/application/o/provider-slug/.well-known/openid-configuration"
    }
  }
end
```

4\. Add routes in `config/routes.rb`, e.g.:
```ruby
get "/auth/:provider/callback", to: "sessions#create"
get "/auth/failure", to: "sessions#failure"
```

5\. Create a simple sessions controller:
```ruby
class SessionsController < ApplicationController
  def create
    user = User.from_omniauth(request.env['omniauth.auth'])
    session[:user_id] = user.id
    redirect_to root_path, notice: 'Signed in successfully!'
  end
end
```

[authentik-api]: https://github.com/david-uhlig/authentik-api
[authentik]: https://github.com/goauthentik/authentik
[OpenAPI Generator]: https://openapi-generator.tech/
[gem]: https://rubygems.org/gems/authentik-client
[license]: https://github.com/david-uhlig/authentik-client/blob/main/LICENSE.md
[tests]: https://github.com/david-uhlig/authentik-client/actions/workflows/main.yml
