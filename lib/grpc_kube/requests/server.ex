defmodule GrpcKube.HelloService.Server do
  @moduledoc false

  use GRPC.Server, service: GrpcKube.HelloService.Service

  alias GrpcKube.HelloRequest
  alias GrpcKube.HelloResponse

  @spec say_hello(HelloRequest.t(), GRPC.Server.Stream.t()) :: HelloResponse.t()
  def say_hello(request, _stream) do
    HelloResponse.new(message: "Hello #{request.name}")
  end
end
