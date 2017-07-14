defmodule LoopEx.Application do
  use Application

  @moduledoc """

  """
  def start(_type, _args) do
    import Supervisor.Spec

    children = [
      worker(LoopEx, [], id: LoopEx),
    ]

    opts = [strategy: :one_for_one, name: LoopEx.Supervisor]
    Supervisor.start_link(children, opts)
  end

end
