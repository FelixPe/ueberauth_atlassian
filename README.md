# Überauth Atlassian

> Atlassian OAuth2 strategy for Überauth.

## Installation

1.  Setup your application at [Atlassian Developer Console](https://developer.atlassian.com/console/myapps/).

2.  Add `:ueberauth_atlassian` to your list of dependencies in `mix.exs`:

    ```elixir
    def deps do
      [
        {:ueberauth_atlassian, "~> 0.1.0"}
      ]
    end
    ```

3.  Add Atlassian to your Überauth configuration:

    ```elixir
    config :ueberauth, Ueberauth,
      providers: [
        atlassian: {Ueberauth.Strategy.Atlassian, []}
      ]
    ```

4.  Update your provider configuration:

    Use that if you want to read client ID/secret from the environment
    variables in the compile time:

    ```elixir
    config :ueberauth, Ueberauth.Strategy.Atlassian.OAuth,
      client_id: System.get_env("ATLASSIAN_CLIENT_ID"),
      client_secret: System.get_env("ATLASSIAN_CLIENT_SECRET")
    ```

    Use that if you want to read client ID/secret from the environment
    variables in the run time:

    ```elixir
    config :ueberauth, Ueberauth.Strategy.Atlassian.OAuth,
      client_id: {System, :get_env, ["ATLASSIAN_CLIENT_ID"]},
      client_secret: {System, :get_env, ["ATLASSIAN_CLIENT_SECRET"]}
    ```

5.  Include the Überauth plug in your controller:

    ```elixir
    defmodule MyApp.AuthController do
      use MyApp.Web, :controller
      plug Ueberauth
      ...
    end
    ```

6.  Create the request and callback routes if you haven't already:

    ```elixir
    scope "/auth", MyApp do
      pipe_through :browser

      get "/:provider", AuthController, :request
      get "/:provider/callback", AuthController, :callback
    end
    ```

7.  Your controller needs to implement callbacks to deal with `Ueberauth.Auth` and `Ueberauth.Failure` responses.

For an example implementation see the [Überauth Example](https://github.com/ueberauth/ueberauth_example) application.

## Calling

Depending on the configured url you can initiate the request through:

    /auth/atlassian

Or with options:

    /auth/atlassian?scope=read%3Ame%20read%3Ajira-work

By default the requested scope is "read:me offline_access". Scope can be configured either explicitly as a `scope` query value on the request path or in your configuration:

```elixir
config :ueberauth, Ueberauth,
  providers: [
    atlassian: {Ueberauth.Strategy.Atlassian, [default_scope: "read:me offline_access"]}
  ]
```

## Copyright and License

Copyright (c) 2023 Felix Penzlin
Copyright (c) 2015 Sean Callan

Released under the MIT License, which can be found in the repository in [LICENSE](https://github.com/FelixPe/ueberauth_atlassian/blob/master/LICENSE).