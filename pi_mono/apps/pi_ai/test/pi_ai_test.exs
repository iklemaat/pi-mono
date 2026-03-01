defmodule PiAiTest do
  use ExUnit.Case
  doctest PiAi

  test "greets the world" do
    assert PiAi.hello() == :world
  end
end
