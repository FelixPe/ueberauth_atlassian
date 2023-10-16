defmodule Ueberauth.Strategy.Atlassian do
@moduledoc """
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
"""

  use Ueberauth.Strategy,
    default_scope: "read:me offline_access",
    userinfo_endpoint: "https://api.atlassian.com/me",
    uid_field: :account_id,
    response_type: "code",
    prompt: "consent",
    oauth2_module: Ueberauth.Strategy.Atlassian.OAuth

    alias Ueberauth.Auth.Credentials
    alias Ueberauth.Auth.Info
    alias Ueberauth.Auth.Extra

    @doc """
    This function will be called by your auth controller request handler.
    It forwards the user to Atlassian for authentication in return it passes back a code to the callback.
    """
    def handle_request!(conn) do
      scopes = conn.params["scope"] || option(conn, :default_scope)
      response_type = option(conn, :response_type)
      prompt = option(conn, :prompt)

      params =
        [scope: scopes, response_type: response_type, prompt: prompt]
        |> with_state_param(conn)

      module = option(conn, :oauth2_module)
      opts = [redirect_uri: callback_url(conn)]

      redirect!(conn, apply(module, :authorize_url!, [params, opts]))
    end

    @doc """
    This function will be called by your auth controller callback handler.
    The user is forwarded to the callback after authentication on Atlassian.
    The function retrieves the access token and fetches the user details.
    """
    def handle_callback!(%Plug.Conn{params: %{"code" => code}} = conn) do

      # Uses our oauth module to perform the token fetch
      module = option(conn, :oauth2_module)
      opts = [redirect_uri: callback_url(conn)]
      params = [code: code]

      case apply(module, :get_access_token, [params, opts]) do
        {:ok, token} ->
          fetch_user(conn, token)
        {:error, {error_code, error_description}} ->
          set_errors!(conn, [error(error_code, error_description)])
      end
    end

    def handle_callback!(conn) do
      set_errors!(conn, [error("missing_code", "No code received")])
    end

    @doc """
    The function retrieves exchanges a refresh token for an access token.
    """
    def handle_refresh!(conn, refresh_token) do

      # Uses our oauth module to perform the token fetch
      module = option(conn, :oauth2_module)

      case apply(module, :refresh_access_token, [refresh_token]) do
        {:ok, token} ->
          fetch_user(conn, token)
        {:error, {error_code, error_description}} ->
          set_errors!(conn, [error(error_code, error_description)])
      end
    end


    @doc """
    Cleanup user information on logout.
    """
    def handle_cleanup!(conn) do
      conn
      |> put_private(:atlassian_user, nil)
      |> put_private(:atlassian_token, nil)
    end

    @doc """
    Fetches the uid field from the response.
    """
    def uid(conn) do
      uid_field =
        conn
        |> option(:uid_field)
        |> to_string

      conn.private.atlassian_user[uid_field]
    end

    @doc """
    Gets called after handle_callback! to set the credentials struct with the token information
    """
    def credentials(conn) do
      token = conn.private.atlassian_token
      scope_string = token.other_params["scope"] || ""
      scopes = String.split(scope_string, " ")

      %Credentials{
        token: token.access_token,
        token_type: token.token_type,
        refresh_token: token.refresh_token,
        expires_at: token.expires_at,
        expires: !!token.expires_at,
        scopes: scopes
      }
    end

    @doc """
    Fetches the fields to populate the info section of the `Ueberauth.Auth` struct.
    """
    def info(conn) do
      user = conn.private.atlassian_user

      %Info{
        name: user["name"],
        nickname: user["nickname"],
        email: user["email"],
        location: user["locale"],
        image: user["picture"]
      }
    end

    def extra(conn) do
      %Extra{
        raw_info: %{
          token: conn.private.atlassian_token,
          user: conn.private.atlassian_user
        }
      }
    end

    defp fetch_user(conn, token) do
      conn = put_private(conn, :atlassian_token, token)

      # userinfo_endpoint default to https://api.atlassian.com/me
      # the userinfo_endpoint may be overridden in options when necessary.
      resp = Ueberauth.Strategy.Atlassian.OAuth.get(token, get_userinfo_endpoint(conn))

      case resp do
        {:ok, %OAuth2.Response{status_code: 401, body: _body}} ->
          set_errors!(conn, [error("token", "unauthorized")])

        {:ok, %OAuth2.Response{status_code: status_code, body: user}}
        when status_code in 200..399 ->
          put_private(conn, :atlassian_user, user)

        {:error, %OAuth2.Response{status_code: status_code}} ->
          set_errors!(conn, [error("OAuth2", status_code)])

        {:error, %OAuth2.Error{reason: reason}} ->
          set_errors!(conn, [error("OAuth2", reason)])
      end
    end

    defp get_userinfo_endpoint(conn) do
      case option(conn, :userinfo_endpoint) do
        {:system, varname, default} ->
          System.get_env(varname) || default

        {:system, varname} ->
          System.get_env(varname) || Keyword.get(default_options(), :userinfo_endpoint)

        other ->
          other
      end
    end

    defp option(conn, key) do
      Keyword.get(options(conn) || [], key, Keyword.get(default_options(), key))
    end
end
