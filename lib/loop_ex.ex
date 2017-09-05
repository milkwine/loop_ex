defmodule LoopEx do

  @moduledoc """

  """

  defmacro __using__(_) do
    quote do
      require Logger
      def short_name, do: __MODULE__ |> to_string |> String.replace("Elixir.", "")
      def guard_run(param, opt) when is_list(opt) do

        Logger.metadata(loop_module: __MODULE__, param: param, opt: opt)

        Process.flag(:trap_exit, true)

        interval       = Keyword.get(opt, :interval, 300)
        timeout        = Keyword.get(opt, :timeout, round(interval * 1.5))
        sleep_on_error = Keyword.get(opt, :sleep_on_error, interval)
        sleep_on_error = if sleep_on_error < 2, do: 2, else: sleep_on_error

        Logger.info "Loop [#{short_name()}] inti. Interval: #{interval}, Timeout: #{timeout}, Sleep_on_Error: #{sleep_on_error}"

        task           = Task.async(__MODULE__, :run, param)
        begin          = Timex.now |> Timex.to_unix

        LoopEx.begin(short_name(), interval)

        suc = case Task.yield(task, :timer.seconds(timeout)) do
          {:ok, result} ->
            case result do
              :error        ->
                LoopEx.fail(short_name(), "return error atom")
                false
              {:error, msg} ->
                LoopEx.fail(short_name(), msg)
                false
              _             ->
                LoopEx.suc(short_name())
                true
            end
          nil ->
            Task.shutdown(task)
            LoopEx.fail(short_name(), "Timeout!")
            false
          {:exit, reason} ->
            LoopEx.fail(short_name(), "Exit: #{inspect reason}")
            false
        end

        Logger.info "Loop [#{short_name()}] end"
        Process.flag(:trap_exit, false)

        due = interval - ((Timex.now |> Timex.to_unix) - begin)
        due = if !suc && due > sleep_on_error, do: sleep_on_error, else: due

        if due > 0 do
          Logger.info "Loop [#{short_name()}] Sleep #{due}s"
         due |> :timer.seconds |> Process.sleep
        end

      end

      def loop(param, opt) when is_list(opt) do
        start_after = Keyword.pop_first(opt, :after, 0)
        if start_after != 0, do: start_after |> :timer.seconds |> Process.sleep
        guard_run(param, opt)
        loop(param, opt)
      end

    end
  end

  defstruct count:        0,
            suc:          0,
            fail:         0,
            begin:        0,
            interval:     0,
            status:     nil,
            last_error: nil

  use GenServer

  def start_link do
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

  def suc(module) do
    GenServer.cast(__MODULE__, {:suc, module})
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

  def del(module) do
    GenServer.cast(__MODULE__, {:delete, module})
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
  @title  ~w(Module Status Count Suc Fail Begin Interval Exceed Error)
  def show do

    :io.format @format, @title

    status() |> Enum.map(fn stat ->
      last_error = stat.last_error
      last_error = if last_error, do: "Happen at #{last_error.time}(count: #{last_error.count}), Msg: #{inspect last_error.msg}", else: ""
      param = [
        stat.module,   stat.status, stat.count,
        stat.suc,      stat.fail,   stat.begin,
        stat.interval, stat.exceed, last_error
      ] |> Enum.map(&to_string/1)
      :io.format @format, param
    end)

  end

end
