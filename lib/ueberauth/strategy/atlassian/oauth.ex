defmodule Ueberauth.Strategy.Atlassian.OAuth do
  @moduledoc """
    Ueberauth strategy to authenticate via Atlassian.
  """


  use OAuth2.Strategy

    @defaults [
      strategy: __MODULE__,
      site: "https://api.atlassian.com",
      authorize_url: "https://auth.atlassian.com/authorize",
      token_url: "https://auth.atlassian.com/oauth/token",
      token_method: :post
    ]

    @doc """
    Create a preconfigured OAuth2.Client
    """
    def client(opts \\ []) do
      # This is where we grab the Client ID and Client Secret we created earilier
      config =
        :ueberauth
        |> Application.fetch_env!(Ueberauth.Strategy.Atlassian.OAuth)
        |> check_config_key_exists(:client_id)
        |> check_config_key_exists(:client_secret)

      client_opts =
        @defaults
        |> Keyword.merge(config)
        |> Keyword.merge(opts)

      json_library = Ueberauth.json_library()

      OAuth2.Client.new(client_opts)
      |> OAuth2.Client.put_serializer("application/json", json_library)
    end

    def authorize_url!(params \\ [], opts \\ []) do
      client(opts)
      |> OAuth2.Client.authorize_url!(params)
    end

    @doc """
    Access a url authenticating with the given token
    """
    def get(token, url, headers \\ [], opts \\ []) do
      [token: token]
      |> client
      |> OAuth2.Client.get(url, headers, opts)
    end

    def authorize_url(client, params) do
     client
     |> OAuth2.Strategy.AuthCode.authorize_url(params)
    end

    @doc """
    Retrieves an access token by calling https://auth.atlassian.com or returns an error

        ```
        curl --request POST
        --url 'https://auth.atlassian.com/oauth/token'
        --header 'Content-Type: application/json'
        --data '{"grant_type": "authorization_code",
          "client_id": "YOUR_CLIENT_ID",
          "client_secret": "YOUR_CLIENT_SECRET",
          "code": "YOUR_AUTHORIZATION_CODE",
          "redirect_uri": "https://YOUR_APP_CALLBACK_URL"}'
        ```
    """
    def get_access_token(params \\ [], opts \\ []) do
      maybe_a_client =
        opts
        |> client
        |> OAuth2.Client.get_token(params, [{"Accept", "application/json"}, {"content-type", "application/json"}])

      case maybe_a_client do
        {:error, %OAuth2.Response{body: %{"error" => error}} = response} ->
          description = Map.get(response.body, "error_description", "")
          {:error, {error, description}}

        {:error, %OAuth2.Error{reason: reason}} ->
          {:error, {"error", to_string(reason)}}

        {:ok, %OAuth2.Client{token: %{access_token: nil} = token}} ->
          %{"error" => error, "error_description" => description} = token.other_params
          {:error, {error, description}}

        {:ok, %OAuth2.Client{token: token}} ->
          {:ok, token}
      end
    end

    @doc """
    Exchange your refresh token for a new access token.
    ```
    curl --request POST
      --url 'https://auth.atlassian.com/oauth/token'
      --header 'Content-Type: application/json'
      --data '{ "grant_type": "refresh_token",
                "client_id": "YOUR_CLIENT_ID",
                "client_secret": "YOUR_CLIENT_SECRET",
                "refresh_token": "YOUR_REFRESH_TOKEN" }'
    ```
    """
    def refresh_access_token(refresh_token) when is_binary(refresh_token) do
      client = client()

      maybe_a_client =
        %{client | token: %{refresh_token: refresh_token}}
        |> put_header("Accept", "application/json")
        |> put_param("client_id", client.client_id)
        |> put_param("client_secret", client.client_secret)
        |> OAuth2.Client.refresh_token([], [{"content-type", "application/json"}], [])

      case maybe_a_client do
          {:error, %OAuth2.Response{body: %{"error" => error}} = response} ->
            description = Map.get(response.body, "error_description", "")
            {:error, {error, description}}

          {:error, %OAuth2.Error{reason: reason}} ->
            {:error, {"error", to_string(reason)}}

          {:ok, %OAuth2.Client{token: %{access_token: nil} = token}} ->
            %{"error" => error, "error_description" => description} = token.other_params
            {:error, {error, description}}

          {:ok, %OAuth2.Client{token: token}} ->
            {:ok, token}
      end

    end

    def get_token(client, params, headers) do
      client
      |> put_param("client_secret", client.client_secret)
      |> put_header("Accept", "application/json")
      |> OAuth2.Strategy.AuthCode.get_token(params, headers)
    end

    defp check_config_key_exists(config, key) when is_list(config) do
      unless Keyword.has_key?(config, key) do
        raise "#{inspect(key)} missing from config :ueberauth, Ueberauth.Strategy.Atlassian"
      end

      config
    end

    defp check_config_key_exists(_, _) do
      raise "Config :ueberauth, Ueberauth.Strategy.Atlassian is not a keyword list, as expected"
    end
  end
