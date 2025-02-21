defmodule Playwright.Runner.Catalog do
  @moduledoc false
  # `Catalog` provides storage and management of known resources. It implements
  # `GenServer` in order to maintain state, while domain logic is handled within
  # caller modules such as `Connection`, `Event`, and `Response`.
  use GenServer
  require Logger

  @enforce_keys [:callers, :storage]
  defstruct [:callers, :storage]

  def start_link(arg) do
    GenServer.start_link(__MODULE__, arg)
  end

  # Retrieve an entry from the `Catalog` storage. In this case (without a
  # `caller` provided), the entry is expected to exist. `nil` will be
  # returned if it does not.
  def get(pid, guid) do
    GenServer.call(pid, {:get, guid})
  end

  # Retrieves an entry from the `Catalog` storage. In this case, a `caller` is
  # provided. If the entry does not exist at the time of the call, a `reply`
  # will be sent to the caller when the entry arrives. The caller will block
  # until the reply is received (or the default timeout is reached).
  def get(pid, guid, caller) do
    case get(pid, guid) do
      nil ->
        await!(pid, {guid, caller})

      item ->
        found!(pid, {item, caller})
    end
  end

  # Adds an entry to the `Catalog` storage. Curently, the creation of the entry
  # to add is left to the caller. At some future point, that responsibility
  # might move here.
  def put(pid, item) do
    GenServer.call(pid, {:put, item})
  end

  # Removes an entry from the `Catalog` storage.
  def rm(pid, guid) do
    GenServer.call(pid, {:rm, guid})
  end

  # Recursively removal: given a "parent" entry, removes that and all
  # descendants.
  def rm_r(pid, guid) do
    children = filter(pid, %{parent: get(pid, guid)}, [])
    children |> Enum.each(fn child -> rm_r(pid, child.guid) end)

    rm(pid, guid)
  end

  # Retrieves a list of entries, filtered by some attributes.
  def filter(pid, filter, default \\ nil) do
    GenServer.call(pid, {:filter, {filter, default}})
  end

  # @impl
  # ----------------------------------------------------------------------------

  @impl GenServer
  def init(root) do
    {:ok, %__MODULE__{callers: %{}, storage: %{"Root" => root}}}
  end

  @impl GenServer
  def handle_call({:get, guid}, _, %{storage: storage} = state) do
    {:reply, storage[guid], state}
  end

  @impl GenServer
  def handle_call({:put, item}, _, %{callers: callers, storage: storage} = state) do
    with updated <- Map.put(storage, item.guid, item) do
      caller = Map.get(callers, item.guid)

      if caller do
        handle_call({:found, {item, caller}}, nil, state)
      end

      {:reply, updated, %{state | storage: updated}}
    end
  end

  @impl GenServer
  def handle_call({:rm, guid}, _, %{storage: storage} = state) do
    with updated <- Map.delete(storage, guid) do
      {:reply, updated, %{state | storage: updated}}
    end
  end

  @impl GenServer
  def handle_call({:await, {guid, caller}}, _, %{callers: callers} = state) do
    with updated <- Map.put(callers, guid, caller) do
      {:reply, updated, %{state | callers: updated}}
    end
  end

  @impl GenServer
  def handle_call({:found, {item, caller}}, _, state) do
    {:reply, GenServer.reply(caller, item), state}
  end

  @impl GenServer
  def handle_call({:values}, _, %{storage: storage} = state) do
    {:reply, Map.values(storage), state}
  end

  @impl GenServer
  def handle_call({:filter, {filter, default}}, _, %{storage: storage} = state) do
    case select(Map.values(storage), filter, []) do
      [] ->
        {:reply, default, state}

      result ->
        {:reply, result, state}
    end
  end

  # private
  # ----------------------------------------------------------------------------

  def await!(pid, {guid, caller}) do
    GenServer.call(pid, {:await, {guid, caller}})
  end

  def found!(pid, {item, caller}) do
    GenServer.call(pid, {:found, {item, caller}})
  end

  defp select([], _attrs, result) do
    result
  end

  defp select([head | tail], attrs, result) when head.type == "" do
    select(tail, attrs, result)
  end

  defp select([head | tail], %{parent: parent, type: type} = attrs, result)
       when head.parent.guid == parent.guid and head.type == type do
    select(tail, attrs, result ++ [head])
  end

  defp select([head | tail], %{parent: parent} = attrs, result)
       when head.parent.guid == parent.guid do
    select(tail, attrs, result ++ [head])
  end

  defp select([head | tail], %{type: type} = attrs, result)
       when head.type == type do
    select(tail, attrs, result ++ [head])
  end

  defp select([head | tail], %{guid: guid} = attrs, result)
       when head.guid == guid do
    select(tail, attrs, result ++ [head])
  end

  defp select([_head | tail], attrs, result) do
    select(tail, attrs, result)
  end
end
