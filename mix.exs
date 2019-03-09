defmodule Scnle.MixProject do
  use Mix.Project

  def project do
    [
      app: :scnle,
      version: "0.1.0",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: alias()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Scnle.Application, []}
    ]
  end

  defp alias() do
    [
      test: "test --no-start"
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:mix_test_watch, "~> 0.8", only: :dev, runtime: false},
      {:local_cluster, "~> 1.0", only: [:test]}
    ]
  end
end
