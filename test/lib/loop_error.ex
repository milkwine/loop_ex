defmodule Loop.Error do
  use LoopEx
  def run(_) do
    IO.puts "in Loop Error"
    1/0
  end
  
end
