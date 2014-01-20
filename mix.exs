defmodule Game.Mixfile do
  use Mix.Project

  def project do
    [ app: :game,
      version: "0.0.1",
      elixir: "~> 0.12.0",
      deps: deps ]
  end

  # Configuration for the OTP application
  def application do
    [
      mod: { Game, [] },
      applications: [ :exreloader, :ranch ]
    ]
  end

  # Returns the list of dependencies in the format:
  # { :foobar, git: "https://github.com/elixir-lang/foobar.git", tag: "0.1" }
  #
  # To specify particular versions, regardless of the tag, do:
  # { :barbat, "~> 0.1", github: "elixir-lang/barbat" }
  defp deps do
    [
      {:exreloader, "0.0.1", [github: "yrashk/exreloader"]},
      { :jsonex, "2.0", github: "marcelog/jsonex", tag: "2.0" },
      { :ranch, "0.4.0", [ github: "extend/ranch", tag: "0.4.0" ] }
      #{ :httpotion, github: "myfreeweb/httpotion" }
    ]
  end
end
