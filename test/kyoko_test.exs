defmodule KyokoTest do
  use ExUnit.Case
  doctest Kyoko

  test "greets the world" do
    assert Kyoko.hello() == :world
  end
end
