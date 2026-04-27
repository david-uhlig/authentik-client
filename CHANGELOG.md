## [Unreleased]

## 0.2.0

### Breaking

#### Removed the `Authentik::ApiProxy` class.

The preferred way of calling endpoints is now directly on the `Authentik::Client` instance:
```ruby
client = Authentik::Client.new
# >= 0.2.0
client.core_users_list # preferred
client.core.core_users_list # still works
# previously supported (< 0.2.0)
client.core.users_list # not supported in >= 0.2.0
client.core.core_users_list
```

Calling groups on an `Authentik::Client` instance now returns an `Authentik::Api::<Group>Api` instance instead of an `Authentik::ApiProxy` instance.

```ruby
client = Authentik::Client.new
# >= 0.2.0
client.core # => #<Authentik::Api::CoreApi ...>
# previously (< 0.2.0)
client.core # => #<Authentik::ApiProxy ...>
```

## 0.1.1

- Fix Railtie logger integration.

## 0.1.0

- Initial release.
