import Config

config :logger, :console,
  colors: [enabled: false],
  format: "\n$time $metadata[$level] $message\n"

config :hat, whitespace_trimming: false
