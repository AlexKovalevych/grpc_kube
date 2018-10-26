defmodule GrpcKube.MixProject do
  use Mix.Project

  def project do
    [
      app: :grpc_kube,
      version: "0.1.0",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {GrpcKube.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:poolboy, "~> 1.5"},
      {:grpc, "~> 0.3.0-alpha.2"},
      {:kazan, "~> 0.10.0"},
      {:distillery, "~> 2.0"}
    ]
  end
end
