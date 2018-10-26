defmodule GrpcKube.HelloRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{name: String.t()}
  defstruct [:name]

  field(:name, 1, type: :string)
end

defmodule GrpcKube.HelloResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{name: String.t()}
  defstruct [:name]

  field(:name, 1, type: :string)
end

defmodule GrpcKube.HelloService.Service do
  @moduledoc false

  use GRPC.Service, name: "HelloService"
  alias GrpcKube.HelloRequest
  alias GrpcKube.HelloResponse

  rpc(:SayHello, HelloRequest, HelloResponse)
end

defmodule GrpcKube.HelloService.Stub do
  @moduledoc false

  use GRPC.Stub, service: GrpcKube.HelloService.Service
end
