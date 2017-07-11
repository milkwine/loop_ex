defmodule LoopEx do

  defmacro __using__(_) do
    quote do
      require Logger
      def loop(param, interval \\ 300) do
        Logger.metadata(loop_module: __MODULE__)
        Logger.info "Loop begin, interval:#{interval}"

        begin = Timex.now |> Timex.to_unix
        #LoopEx.begin(__MODULE__, interval)
        LoopEx.fine(__MODULE__, interval)

        try do
          unquote(:run)(param)
          #LoopEx.done(__MODULE__)
        rescue
          err -> 
            Logger.error "rescue: #{inspect err}"
            LoopEx.msg(__MODULE__, err)
        catch
          err ->
            Logger.error "catch: #{inspect err}"
            LoopEx.msg(__MODULE__, err)
        end

        due = interval - ( (Timex.now |> Timex.to_unix) - begin )

        if due > 0 do
          Logger.info "Sleep #{due}s"
          due |> :timer.seconds |> Process.sleep 
        end

        loop(param, interval)
      end
    end
  end

  #counts begin end delay status last_error_count last_error_msg
  use GenServer

  def start_link() do
    GenServer.start_link(__MODULE__, [%{}, %{}], name: LoopEx)
  end

  def handle_cast({:fine, module, interval}, [stat, msgs]) do

    now = Timex.now |> Timex.to_unix
    stat = Map.put(stat, module, {now, interval})
    {:noreply, [stat, msgs]}
  end

  def handle_cast({:msg, module, msg}, [stat, msgs]) do
    msg = if is_binary(msg), do: msg, else: inspect(msg)
    now = Timex.now |> Timex.to_unix
    msgs = Map.put(msgs, module, {now, msg})
    {:noreply, [stat, msgs]}
  end

  def handle_cast({:delete, module}, [stat, msgs]) do
    stat = Map.delete(stat, module)
    msgs = Map.delete(msgs, module)
    {:noreply, [stat, msgs]}
  end

  def handle_call(:all, _from, [stat, msgs]) do
    {:reply, [stat, msgs], [stat, msgs]}
  end

  def fine(module, interval) do
    GenServer.cast(__MODULE__, {:fine, module, interval})
  end

  def msg(module, msg) do
    GenServer.cast(__MODULE__, {:msg, module, msg})
  end

  def status do

    ratio = Application.get_env(:loop_ex, :ratio, 0.5)
    now = Timex.now |> Timex.to_unix
    [stats, msgs] = GenServer.call(__MODULE__, :all)

    stats |> Map.to_list |> Enum.map(fn {module, {start, interval}} -> 
      late = (now - start - interval) - interval * ratio
      {uptime, msg} = Map.get(msgs, module, {nil, nil})
      stat = cond do
        uptime && (now - uptime - interval) -> :error
        late > 0                            -> :timeout
        true                                -> :running
      end
      
      [module, start, interval, late, stat, uptime, msg]
    end)
  end

  @format "~30.. s|~15.. s|~15.. s|~10.. s|~10.. s|~15.. s|~30.. s\n"
  def show do

    :io.format @format, ["Module", "Last", "Interval", "Delay", "Status", "Uptime", "Msg"];

    status() |> Enum.map(fn param ->
      param = Enum.map(param, &to_string/1)
      :io.format @format, param
    end)

  end

end
