defmodule GrpcKube.Worker do
  @moduledoc false

  use GenServer
  alias GrpcKube.Channels

  def start_link(arg) do
    GenServer.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(arg) do
    {:ok, arg}
  end

  @impl true
  def handle_call({:get_channel, namespace}, _, state) do
    channels = Channels.get_channels(namespace)

    channel =
      case channels do
        [] -> nil
        _ -> Enum.random(channels)
      end

    {:reply, channel, state}
  end
end
