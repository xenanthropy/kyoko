defmodule Kyoko.Application do
  use Application

  def start(_type, _args) do
    # Set Logger level based on DEBUG environment variable
    if System.get_env("DEBUG") == "true" do
      Logger.configure(level: :debug)
    else
      Logger.configure(level: :info)
    end

    children = [
      KyokoSupervisor
    ]

    opts = [strategy: :one_for_one, name: Kyoko.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
