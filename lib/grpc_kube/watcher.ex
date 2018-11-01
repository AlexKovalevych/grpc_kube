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

  def init(args) do
    Watcher.start_link(list_event_for_all_namespaces!(), send_to: self())
    {:ok, args}
  end

  def handle_info(%Event{object: object}, state) do
    case object do
      %V1Event{message: "Deleted pod: " <> _} = event ->
        drop_connection(event)

      %V1Event{message: "Started container"} = event ->
        create_connection(event)

      _ ->
        :ok
    end

    {:noreply, state}
  end

  defp create_connection(%V1Event{metadata: %ObjectMeta{namespace: namespace}}) do
    connections =
      Enum.filter(get_connections(), fn %{namespace: connection_namespace} -> connection_namespace == namespace end)

    case connections do
      [%{label: label}] ->
        GenServer.call(Channels, {:sync_connections, namespace, label})

      _ ->
        :ok
    end
  end

  defp drop_connection(%V1Event{metadata: %ObjectMeta{namespace: namespace, labels: labels} = metadata}) do
    Enum.map(get_connections(), fn %{namespace: child_namespace, label: child_label} ->
      label = Map.get(labels || %{}, "app")

      if namespace == child_namespace and label == child_label do
        Logger.info("New connection should be deleted for pod #{metadata.name}")
      end
    end)
  end

  defp get_connections do
    Application.get_env(:grpc_kube, :connections)
  end
end
