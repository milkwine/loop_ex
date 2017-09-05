defmodule LoopExTest do
  use ExUnit.Case, async: false
  doctest LoopEx

  test "loop suc" do
    Loop.Common.guard_run([3], interval: 4)
    [s] = LoopEx.status
    assert %{module: "Loop.Common", suc: 1} = s
    LoopEx.del("Loop.Common")
  end

  test "loop timeout" do
    Loop.Common.guard_run([4], interval: 2, timeout: 2)
    [s] = LoopEx.status
    assert %{module: "Loop.Common", fail: 1} = s
    LoopEx.del("Loop.Common")
  end

  test "loop error" do
    Loop.Error.guard_run([nil], interval: 2)
    [s] = LoopEx.status
    assert %{module: "Loop.Error", fail: 1} = s
    LoopEx.del("Loop.Error")
  end

end
