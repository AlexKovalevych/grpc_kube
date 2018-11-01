defmodule GrpcKube.Channels do
  @moduledoc false

  use GenServer
  alias GRPC.Channel
  import Kazan.Apis.Core.V1, only: [list_namespaced_pod!: 1]
  require Logger

  def start_link(arg) do
    GenServer.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(arg) do
    :ets.new(:channels, [:set, :named_table, :protected])

    Enum.map(get_connections(), fn %{namespace: namespace, label: label} ->
      :ets.insert(:channels, {namespace, []})
      sync_namespaced_connections(namespace, label)
    end)

    {:ok, arg}
  end

  @impl true
  def handle_call({:sync_connections, namespace, label}, _, state) do
    sync_namespaced_connections(namespace, label)
    {:reply, :ok, state}
  end

  @impl true
  def handle_info({:gun_down, _, :http2, :closed, [], []}, state) do
    Enum.map(get_connections(), fn %{namespace: namespace, label: label} ->
      sync_namespaced_connections(namespace, label)
    end)

    {:noreply, state}
  end

  defp sync_namespaced_connections(namespace, label) do
    pod_list = list_namespaced_pod!(namespace) |> Kazan.run!()

    # Create new connections
    Enum.each(pod_list.items, fn pod ->
      if Map.get(pod.metadata.labels, "app") == label do
        create_connection(namespace, pod.metadata.name, pod.status.pod_ip)
      end
    end)

    # Drop obsolete connections
    [{_, channels}] = :ets.lookup(:channels, namespace)

    Enum.each(channels, fn channel ->
      drop_connection(namespace, channels, pod_list.items, channel)
    end)
  end

  def create_connection(_, _, nil), do: :ok

  def create_connection(namespace, pod_name, pod_ip) do
    [{_, channels}] = :ets.lookup(:channels, namespace)

    existing_channels =
      Enum.filter(channels, fn %Channel{host: host} ->
        "#{host}:50051" == create_host(pod_ip, namespace)
      end)

    if existing_channels == [] do
      Logger.info("Creating connection for namespace: #{namespace} and pod: #{pod_name}, ip: #{pod_ip}")
      {:ok, channel} = GRPC.Stub.connect(create_host(pod_ip, namespace))
      :ets.insert(:channels, {namespace, [channel | channels]})
    end
  end

  def drop_connection(namespace, channels, pods, channel) do
    existing_pod =
      Enum.find(pods, fn pod ->
        create_host(pod.status.pod_ip, namespace) == "#{channel.host}:50051"
      end)

    if !existing_pod do
      Logger.info("Dropping connection for namespace: #{namespace}, ip: #{channel.host}:50051")
      :ets.insert(:channels, {namespace, channels -- channel})
    end
  end

  defp create_host(ip, namespace) do
    "#{String.replace(ip, ".", "-")}.#{namespace}.pod.cluster.local:50051"
  end

  defp get_connections do
    Application.get_env(:grpc_kube, :connections)
  end
end
