defmodule GrpcKube.Channels do
  @moduledoc false

  use GenServer
  import Kazan.Apis.Core.V1, only: [list_namespaced_pod!: 1]
  require Logger

  def start_link(arg) do
    GenServer.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(arg) do
    :ets.new(:channels, [:set, :named_table, :protected])
    connections = Application.get_env(:grpc_kube, :connections)

    Enum.map(connections, fn %{namespace: namespace, label: label} ->
      :ets.insert(:channels, {namespace, []})
      pod_list = list_namespaced_pod!(namespace) |> Kazan.run!()

      Enum.each(pod_list.items, fn pod ->
        if Map.get(pod.metadata.labels, "app") == label do
          create_connection(namespace, pod.metadata.name)
        end
      end)
    end)

    {:ok, arg}
  end

  def create_connection(namespace, pod_name) do
    Logger.info("Creating connection for namespace: #{namespace} and pod: #{pod_name}")
    {:ok, channel} = GRPC.Stub.connect("#{pod_name}:50051")
    channels = :ets.lookup(:channels, namespace)
    :ets.update_element(:channels, namespace, [channel | channels])
    {:ok, channel}
  end

  def drop_connection(namespace, channel) do
    Logger.info("Dropping connection for namespace: #{namespace}")
    channels = :ets.lookup(:channels, namespace)
    :ets.update_element(:channels, namespace, channels -- channel)
  end
end
