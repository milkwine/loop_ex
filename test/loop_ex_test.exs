defmodule LoopExTest do
  use ExUnit.Case, async: false
  doctest LoopEx

  test "loop suc" do
    Loop.Common.guard_run([3], interval: 4)
    LoopEx.show
    LoopEx.status |> IO.inspect
    #LoopEx.del(Loop.Common)
    assert %{module: "Loop.Common", suc: 1}
  end

  #test "loop timeout" do
  #  Loop.Common.guard_run([4], interval: 2, timeout: 2)
  #  LoopEx.show
  #  LoopEx.status |> IO.inspect
  #  LoopEx.del(Loop.Common)
  #end

  #test "loop error" do
  #  Loop.Error.guard_run([nil], interval: 2)
  #  status = LoopEx.status
  #  IO.inspect status
  #  LoopEx.show
  #end

end
