use Mix.Releases.Config,
  default_release: :default,
  default_environment: :default

environment :default do
  set(dev_mode: false)
  set(include_erts: true)
  set(include_src: false)

  set(
    overlays: [
      {:template, "rel/templates/vm.args.eex", "releases/<%= release_version %>/vm.args"}
    ]
  )
end

release :grpc_kube do
  set(version: current_version(:grpc_kube))

  set(
    applications: [
      grpc_kube: :permanent
    ]
  )
end
