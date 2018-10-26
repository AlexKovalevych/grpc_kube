defmodule GrpcKube.Watcher do
  @moduledoc false

  use GenServer
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
    Logger.info(
      inspect(%{object: object.involved_object, message: object.message, namespace: object.metadata.namespace})
    )

    case object do
      %Kazan.Apis.Core.V1.Event{message: "Deleted pod: " <> pod_name} ->
        Logger.info("deleted pod #{pod_name}")
    end

    {:noreply, state}
  end

  def handle_info(%Event{} = event, state) do
    {:noreply, state}
  end
end
