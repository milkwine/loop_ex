defmodule LoopEx.Spec do

  #loop(module, [param, [loop_opt]], worker_opt)
  def loop(module, params, opt \\ []) do
    import Supervisor.Spec
    opt = if is_nil(Keyword.get(opt, :id)), do: Keyword.put(opt, :id, module), else: opt
    worker(Task, [module, :loop, params], opt)
  end
end
