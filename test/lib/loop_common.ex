defmodule Loop.Common do
  use LoopEx
  def run(sleep) do
    IO.puts "In Loop Common. Sleep #{sleep}s!"
    sleep |> :timer.seconds |> Process.sleep
  end
  
end
