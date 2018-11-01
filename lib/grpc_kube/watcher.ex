defmodule GrpcKube.Watcher do
  @moduledoc false

  use GenServer
  alias GrpcKube.Channels
  alias Kazan.Apis.Core.V1.Event, as: V1Event
  alias Kazan.Models.Apimachinery.Meta.V1.ObjectMeta
  alias Kazan.Watcher
  alias Kazan.Watcher.Event
  import Kazan.Apis.Core.V1, only: [list_event_for_all_namespaces!: 0]
  require Logger

  def start_link(_) do
    GenServer.start_link(__MODULE__, [])
  end

  @impl true
  def init(args) do
    Watcher.start_link(list_event_for_all_namespaces!(), send_to: self())
    {:ok, args}
  end

  @impl true
  def handle_info(%Event{object: object}, state) do
    case object do
      %V1Event{message: "Started container"} = event ->
        sync_connection(event)

      %V1Event{message: "Killing container" <> _} = event ->
        sync_connection(event)

      _ ->
        :ok
    end

    {:noreply, state}
  end

  defp sync_connection(%V1Event{metadata: %ObjectMeta{namespace: namespace}}) do
    connections =
      Enum.filter(get_connections(), fn %{namespace: connection_namespace} -> connection_namespace == namespace end)

    case connections do
      [%{endpoint_name: endpoint_name, timeout: timeout}] ->
        Process.send_after(Channels, {:sync_connections, namespace, endpoint_name}, timeout)

      _ ->
        :ok
    end
  end

  defp get_connections do
    Application.get_env(:grpc_kube, :connections)
  end
end
