defmodule GrpcKubeTest do
  use ExUnit.Case
  doctest GrpcKube

  test "greets the world" do
    assert GrpcKube.hello() == :world
  end
end
