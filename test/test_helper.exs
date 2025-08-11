# A mechanism for setting up environments for tests, designed to help
# keep test code and environment setup code as closer as possible.
#
# It:
#
#   1. find directories ends with `_test`
#   2. run `*_test/setup.exs`
#
# It should be used for the cases that setup/_ and setup_all/_ can't
# handle. In general cases, setup/_ and setup_all/_ should be used.
#
# How to use it?
# Suppose that we have a test - `test/combo/complex_logic_test.exs`.
#
#   1. create the directory - `test/combo/complex_logic_test`.
#   2. add a file `setup.exs` into above directory.
#   3. write setups in above file.
#
setup_dirs =
  Path.join(__DIR__, "**/*_test")
  |> Path.wildcard()
  |> Enum.filter(&File.dir?/1)

for dir <- setup_dirs do
  setup_file = Path.join(dir, "setup.exs")

  if File.exists?(setup_file) do
    IO.puts("> eval test/#{Path.relative_to(setup_file, __DIR__)}")
    Code.eval_file(setup_file)
  end
end

IO.write("\n")

Code.require_file("support/router_helper.exs", __DIR__)

# Starts web server applications
Application.ensure_all_started(:plug_cowboy)

# For mix tests
Mix.shell(Mix.Shell.Process)

assert_timeout = String.to_integer(System.get_env("ELIXIR_ASSERT_TIMEOUT") || "200")

ExUnit.start(assert_receive_timeout: assert_timeout)
