defmodule LoopEx.Spec do

  @moduledoc false

  @doc """
  Helper func for using Supervisor tree.

  ## Options

    * `:interval` - interval seconds to run. Default: 300.
    * `:timeout` - timeout seconds. Default: interval * 1.5
    * `:sleep_on_error` - sleep seconds when error occurs. Default: interval

  ## Examples
      def start(_type, _args) do

        children = [
          loop(Cron.MMS, [[param],[interval: 120, ]]),
        ]
        opts = [strategy: :one_for_one]
        Supervisor.start_link(children, opts)
      end
  """
  #loop(module, [param, [loop_opt]], worker_opt)
  def loop(module, params, opt \\ []) do
    import Supervisor.Spec

    opt = if is_nil(Keyword.get(opt, :id))
    do
      Keyword.put(opt, :id, module)
    else
      opt
    end

    worker(Task, [module, :loop, params], opt)
  end
end
