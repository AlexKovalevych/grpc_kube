defmodule GrpcKube.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    # List all child processes to be supervised
    children = [
      {GrpcKube.Channels, []},
      {GrpcKube.Watcher, []},
      {GrpcKube.Worker, []},
      %{
        id: GRPC.Server.Supervisor,
        start: {GRPC.Server.Supervisor, :start_link, [{GrpcKube.HelloService.Server, 50051}]}
      }
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: GrpcKube.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
