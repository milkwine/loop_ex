defmodule LoopEx do

  defmacro __using__(_) do
    quote do
      require Logger
      def loop(param, opt) when is_list(opt) do
        interval       = Keyword.get(opt, :interval, 300)
        start_after    = Keyword.get(opt, :after, 0)
        sleep_on_error = Keyword.get(opt, :sleep_on_error, interval)
        sleep_on_error = if sleep_on_error < 2, do: 2, else: sleep_on_error

        Logger.metadata(loop_module: __MODULE__)
        Logger.info "Loop [#{__MODULE__}] inti. Interval: #{interval}, start_after: #{start_after}, sleep_on_error: #{sleep_on_error}"

        start_after |> :timer.seconds |> Process.sleep
        loop(param, interval, sleep_on_error)
      end
      def loop(param, interval, sleep_on_error) do
        Logger.info "Loop [#{__MODULE__}] begin, interval:#{interval}"

        begin = Timex.now |> Timex.to_unix
        LoopEx.begin(__MODULE__, interval)

        suc = try do
          case unquote(:run)(param) do
            :error        -> LoopEx.fail(__MODULE__, "return fail value")
            {:error, msg} -> LoopEx.fail(__MODULE__, msg)
            _             -> LoopEx.suc(__MODULE__)
          end
          Logger.info "Loop [#{__MODULE__}] end"
          true
        rescue
          err -> 
            Logger.error "Loop [#{__MODULE__}] rescue: #{inspect err}"
            LoopEx.fail(__MODULE__, err)
            false
        catch
          err ->
            Logger.error "Loop [#{__MODULE__}] catch: #{inspect err}"
            LoopEx.fail(__MODULE__, err)
            false
        end

        due = interval - ( (Timex.now |> Timex.to_unix) - begin )
        due = if !suc && due > sleep_on_error, do: sleep_on_error, else: due

        if due > 0 do
          Logger.info "Loop [#{__MODULE__}] Sleep #{due}s"
          due |> :timer.seconds |> Process.sleep 
        end

        loop(param, interval, sleep_on_error)
      end
    end
  end

  defstruct count: 0, suc: 0, fail: 0, begin: 0, interval: 0, status: nil, last_error: nil

  use GenServer

  def start_link() do
    GenServer.start_link(__MODULE__, %{}, name: LoopEx)
  end

  def handle_cast({:begin, module, interval}, stats) do
    now = Timex.now |> Timex.to_unix
    stat = Map.get(stats, module, %LoopEx{})
    stat = stat
    |> Map.put(:count, stat.count + 1)
    |> Map.put(:begin, now)
    |> Map.put(:interval, interval)
    |> Map.put(:status, :running)

    stats = Map.put(stats, module, stat)
    {:noreply, stats}
  end

  def handle_cast({:suc, module}, stats) do
    stat = Map.get(stats, module, %LoopEx{})
    stat = stat
    |> Map.put(:suc, stat.suc + 1)
    |> Map.put(:status, :suc)
    stats = Map.put(stats, module, stat)
    {:noreply, stats}
  end

  def handle_cast({:fail, module, msg}, stats) do
    now = Timex.now |> Timex.to_unix
    stat = Map.get(stats, module, %LoopEx{})
    last_error = %{count: stat.count, time: now, msg: msg}
    stat = stat
    |> Map.put(:fail, stat.fail + 1)
    |> Map.put(:status, :fail)
    |> Map.put(:last_error, last_error)
    stats = Map.put(stats, module, stat)
    {:noreply, stats}
  end


  def handle_cast({:delete, module}, stats) do
    stats = Map.delete(stats, module)
    {:noreply, stats}
  end

  def handle_call(:all, _from, stats) do
    {:reply, stats, stats}
  end

  def begin(module, interval) do
    GenServer.cast(__MODULE__, {:begin, module, interval})
  end

  def suc(module) do
    GenServer.cast(__MODULE__, {:suc, module})
  end

  def fail(module, msg) do
    GenServer.cast(__MODULE__, {:fail, module, msg})
  end


  def status do

    ratio = Application.get_env(:loop_ex, :ratio, 0.5)
    now = Timex.now |> Timex.to_unix
    stats = GenServer.call(__MODULE__, :all)
    stats |> Map.to_list |> Enum.map(fn {module, stat} -> 
      exceed = (now - stat.begin - stat.interval) - stat.interval * ratio
      new_stat = if exceed > 0, do: Map.put(stat, :status, :timeout), else: stat
      new_stat |> Map.put(:exceed, exceed) |> Map.put(:module, module)
    end)

  end

  @format "~40.. s|~7.. s|~6.. s|~6.. s|~6.. s|~10.. s|~10.. s|~10.. s|~70.. s\n"
  def show do

    :io.format @format, ~w(Module Status Count Suc Fail Begin Interval Exceed Error)

    status() |> Enum.map(fn stat ->
      last_error = stat.last_error
      last_error = if last_error, do: "Happen at #{last_error.time}(count: #{last_error.count}), Msg: #{inspect last_error.msg}", else: ""

      param = [stat.module, stat.status, stat.count, stat.suc, stat.fail, stat.begin, stat.interval, stat.exceed, last_error]
      |> Enum.map(&to_string/1)
      :io.format @format, param
    end)

  end

end
