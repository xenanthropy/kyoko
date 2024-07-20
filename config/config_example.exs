import Config

config :nostrum,
  # insert token here
  token: "INSERT_BOT_TOKEN_HERE",
  num_shards: :auto,
  streamlink: false

config :logger, :console,
  format: "$metadata[$level] $message\n",
  metadata: [:debug]
