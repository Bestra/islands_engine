defmodule IslandsEngine.Game do
  alias IslandsEngine.{Board, Coordinate, Guesses, Island, Rules}
  use GenServer, start: {__MODULE__, :start_link, []}, restart: :transient

  @timeout 1000 * 60 * 30

  @players [:player1, :player2]

  def via_tuple(name), do: {:via, Registry, {Registry.Game, name}}

  def start_link(name) when is_binary(name) do
    GenServer.start_link(__MODULE__, name, name: via_tuple(name))
  end

  def add_player(game, name) when is_binary(name) do
    GenServer.call(game, {:add_player, name})
  end

  def position_island(game, player, key, row, col) when player in @players do
    GenServer.call(game, {:position_island, player, key, row, col})
  end

  def set_islands(game, player) when player in @players,
    do: GenServer.call(game, {:set_islands, player})

  def guess_coordinate(game, player, row, col) when player in @players do
    GenServer.call(game, {:guess_coordinate, player, row, col})
  end

  defp opponent(:player1), do: :player2
  defp opponent(:player2), do: :player1

  ### Callbacks

  def init(name) do
    # Don't initialize data from ets on init because init blocks, and this could
    # very eventually end up being a bottleneck.
    # do it afterwards.
    send(self(), {:set_state, name})
    # it's important to note that ^^ could cause a race condition if messages have queued up
    # in the process mailbox before :set_state, which is slightly possible since we use a :via tuple
    # to register the pid
    {:ok, fresh_state(name)}
  end

  def handle_info({:set_state, name}, _state) do
    state_data =
      case :ets.lookup(:game_state, name) do
        [] -> fresh_state(name)
        [{_key, state}] -> state
      end

    :ets.insert(:game_state, {name, state_data})
    {:noreply, state_data, @timeout}
  end

  def handle_info(:timeout, state) do
    {:stop, {:shutdown, :timeout}, state}
  end

  def terminate({:shutdown, :timeout}, state_data) do
    :ets.delete(:game_state, state_data.player1.name)
    :ok
  end

  def terminate(_reason, _state), do: :ok

  defp fresh_state(name) do
    player1 = %{name: name, board: Board.new(), guesses: Guesses.new()}
    player2 = %{name: nil, board: Board.new(), guesses: Guesses.new()}
    %{player1: player1, player2: player2, rules: %Rules{}}
  end

  def handle_call({:add_player, name}, _from, state) do
    with {:ok, rules} <- Rules.check(state.rules, :add_player) do
      state
      |> update_player2_name(name)
      |> update_rules(rules)
      |> reply_success(:ok)
    else
      :error -> {:reply, :error, state}
    end
  end

  def handle_call({:position_island, player, key, row, col}, _from, state) do
    board = player_board(state, player)

    with {:ok, rules} <- Rules.check(state.rules, {:position_islands, player}),
         {:ok, coordinate} <- Coordinate.new(row, col),
         {:ok, island} <- Island.new(key, coordinate),
         %{} = board <- Board.position_island(board, key, island) do
      state
      |> update_board(player, board)
      |> update_rules(rules)
      |> reply_success(:ok)
    else
      :error ->
        {:reply, :error, state}

      {:error, :invalid_coordinate} ->
        {:reply, {:error, :invalid_coordinate}, state}

      {:error, :invalid_island_type} ->
        {:reply, {:error, :invalid_island_type}, state}
    end
  end

  def handle_call({:set_islands, player}, _from, state) do
    board = player_board(state, player)

    with {:ok, rules} <- Rules.check(state.ruls, {:set_islands, player}),
         true <- Board.all_islands_positioned?(board) do
      state
      |> update_rules(rules)
      |> reply_success({:ok, board})
    else
      :error -> {:reply, :error, state}
      false -> {:reply, {:error, :not_all_islands_positioned}, state}
    end
  end

  def handle_call({:guess_coordinate, player_key, row, col}, _from, state) do
    opponent_key = opponent(player_key)
    opponent_board = player_board(state, opponent_key)

    with {:ok, rules} <- Rules.check(state.rules, {:guess_coordinate, player_key}),
         {:ok, coordinate} <- Coordinate.new(row, col),
         {hit_or_miss, forested_island, win_status, opponent_board} <-
           Board.guess(opponent_board, coordinate),
         {:ok, rules} <- Rules.check(rules, {:win_check, win_status}) do
      state
      |> update_board(opponent_key, opponent_board)
      |> update_guesses(player_key, hit_or_miss, coordinate)
      |> update_rules(rules)
      |> reply_success({hit_or_miss, forested_island, win_status})
    else
      :error ->
        {:reply, :error, state}

      {:error, :invalid_coordinate} = e ->
        {:reply, e, state}
    end
  end

  defp update_guesses(state, player_key, hit_or_miss, coordinate) do
    update_in(state[player_key].guesses, fn g ->
      Guesses.add(g, hit_or_miss, coordinate)
    end)
  end

  defp player_board(state, player), do: Map.get(state, player).board

  defp update_board(state, player, board) do
    Map.update!(state, player, fn p -> %{p | board: board} end)
  end

  defp update_player2_name(state, name), do: put_in(state.player2.name, name)

  defp update_rules(state, rules), do: %{state | rules: rules}

  defp reply_success(state, reply) do
    :ets.insert(:game_state, {state.player1.name, state})
    {:reply, reply, state, @timeout}
  end
end
