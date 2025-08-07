import Config

config :logger, :console,
  colors: [enabled: false],
  format: "\n$time $metadata[$level] $message\n"

config :combo,
  json_module: Jason,
  stacktrace_depth: 20

config :combo, :template, trim_on_ceex_engine: false
