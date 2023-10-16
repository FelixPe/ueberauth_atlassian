defmodule UeberauthAtlassian.MixProject do
  use Mix.Project

  @source_url "https://github.com/FelixPe/ueberauth_atlassian"
  @version "0.2.0"

  def project do
    [
      app: :ueberauth_atlassian,
      version: @version,
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      package: package(),
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ueberauth, "~> 0.7.0"},
      {:oauth2, "~> 2.1.0"},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      name: "ueberauth_atlassian",
      description: "An Uberauth strategy for Atlassian authentication.",
      files: ["lib", "mix.exs", "README.md", "LICENSE"],
      maintainers: ["Felix Penzlin"],
      licenses: ["MIT"],
      links: %{
        GitHub: @source_url
      }
    ]
  end
end
