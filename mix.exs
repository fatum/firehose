defmodule Firehose.MixProject do
  use Mix.Project

  def project do
    [
      app: :firehose,
      description: "This application accumulates and sends data in batches to AWS Firehose",
      version: "0.1.0",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      package: package(),
      deps: deps()
    ]
  end

  def package do
    [
      name: :firehose,
      maintainers: ["Maxim Filipovich <fatumka@gmail.com>"],
      files: ["lib", "mix.exs", "README*"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/fatum/firehose"}
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_aws, "~> 2.0"},
      {:ex_aws_firehose, "~> 2.0"},
      {:poison, "~> 3.0"},
      {:hackney, "~> 1.9"},
      {:ex_doc, ">= 0.0.0", only: :dev}
    ]
  end
end
