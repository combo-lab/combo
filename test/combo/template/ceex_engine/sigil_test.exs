defmodule Combo.Template.CEExEngine.SigilTest do
  use ExUnit.Case, async: true

  import Combo.Template.CEExEngine.Sigil

  @dir Path.rootname(__ENV__.file)

  test "~CE" do
    assigns = %{}

    ~CE"""
    Hello, world!
    """
  end

  test "~CE with noformat modifier" do
    assigns = %{}

    ~CE"""
    Hello, world!
    """noformat
  end

  test "raises a runtime error when \"assigns\" variable not exist" do
    message = "~CE requires a variable named \"assigns\" to exist and be set to a map"

    assert_raise RuntimeError, message, fn ->
      Code.require_file("#{@dir}/missing_assigns.exs", __DIR__)
    end
  end

  test "raises an argument error when using unsupported modifier" do
    message = "~CE expected modifier to be empty or noformat, got: bad"

    assert_raise ArgumentError, message, fn ->
      Code.require_file("#{@dir}/unsupported_modifier.exs", __DIR__)
    end
  end
end
