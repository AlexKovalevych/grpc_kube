defmodule GrpcKube.Channels do
  @moduledoc false

  use GenServer
  alias Kazan.Apis.Core.V1.EndpointAddress
  alias Kazan.Apis.Core.V1.EndpointSubset
  import Kazan.Apis.Core.V1, only: [list_namespaced_endpoints!: 1]
  require Logger

  def start_link(arg) do
    GenServer.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(arg) do
    :ets.new(:channels, [:set, :named_table, :protected])

    Enum.map(get_connections(), fn %{namespace: namespace, endpoint_name: endpoint_name} ->
      :ets.insert(:channels, {namespace, []})
      sync_namespaced_connections(namespace, endpoint_name)
    end)

    {:ok, arg}
  end

  @impl true
  def handle_call({:sync_connections, namespace, endpoint_name}, _, state) do
    sync_namespaced_connections(namespace, endpoint_name)
    {:reply, :ok, state}
  end

  @impl true
  def handle_info({:gun_down, _, :http2, :closed, [], []}, state) do
    Enum.map(get_connections(), fn %{namespace: namespace, endpoint_name: endpoint_name} ->
      sync_namespaced_connections(namespace, endpoint_name)
    end)

    {:noreply, state}
  end

  defp sync_namespaced_connections(namespace, endpoint_name) do
    endpoints_list = list_namespaced_endpoints!(namespace) |> Kazan.run!()

    Enum.each(endpoints_list.items, fn endpoint ->
      if endpoint.metadata.name == endpoint_name do
        create_connections(namespace, hd(endpoint.subsets))
        drop_connections(namespace, hd(endpoint.subsets))
      end
    end)
  end

  def create_connections(namespace, %EndpointSubset{addresses: addresses}) do
    [{_, channels}] = :ets.lookup(:channels, namespace)
    existing_channels = Enum.map(channels, &(Map.get(&1, :host) <> ":50051"))
    kube_channels = Enum.map(addresses, fn %EndpointAddress{ip: ip} -> create_host(ip, namespace) end)

    new_channels =
      Enum.reduce(kube_channels, channels, fn kube_channel, acc ->
        if kube_channel not in existing_channels do
          Logger.info("Creating connection for namespace: #{namespace} and host: #{kube_channel}")
          {:ok, channel} = GRPC.Stub.connect(kube_channel)
          [channel | acc]
        end
      end)

    :ets.insert(:channels, {namespace, new_channels})
  end

  def create_connections(_, _), do: :ok

  def drop_connections(namespace, %EndpointSubset{addresses: addresses}) do
    [{_, channels}] = :ets.lookup(:channels, namespace)
    kube_channels = Enum.map(addresses, fn %EndpointAddress{ip: ip} -> create_host(ip, namespace) end)

    Enum.each(channels, fn channel ->
      existing_channel = "#{channel.host}:50051"

      if existing_channel not in kube_channels do
        Logger.info("Dropping connection for namespace: #{namespace} and host: #{existing_channel}")
        :ets.insert(:channels, {namespace, channels -- [channel]})
      end
    end)
  end

  def drop_connections(_, _), do: :ok

  defp create_host(ip, namespace) do
    "#{String.replace(ip, ".", "-")}.#{namespace}.pod.cluster.local:50051"
  end

  defp get_connections do
    Application.get_env(:grpc_kube, :connections)
  end
end
