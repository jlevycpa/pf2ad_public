defmodule PF2AD.Mixfile do
  use Mix.Project

  def project do
    [app: :pf2ad,
     version: "0.0.1",
     elixir: "~> 1.2",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     escript: [main_module: PF2AD],
     deps: deps]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [applications: [:logger, :httpoison, :sweet_xml, :csv, :eldap, :ssl, :eex, :bamboo]]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [{:httpoison, "~> 0.8.0"},
    {:sweet_xml, "~> 0.6.1"},
    {:csv, "~> 1.3.3"},
    {:bamboo, "~> 0.8"},
    {:hackney, "1.6.5"}]
  end
end