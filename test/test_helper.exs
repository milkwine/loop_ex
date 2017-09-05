"#{Path.dirname(__ENV__.file)}/lib/*"
|> Path.wildcard
|> Enum.filter(&!File.dir?(&1))
|> Enum.each(&Code.require_file/1)

ExUnit.start()
