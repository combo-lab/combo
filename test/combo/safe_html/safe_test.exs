defmodule Combo.SafeHTML.SafeTest do
  use ExUnit.Case, async: true

  alias Combo.SafeHTML.Safe

  test "impl for atoms" do
    assert Safe.to_iodata(nil) == ""
    assert Safe.to_iodata(:"<foo>") == [[[] | "&lt;"], "foo" | "&gt;"]
  end

  test "impl for bitstrings" do
    assert Safe.to_iodata("") == ""
    assert Safe.to_iodata("<foo>") == [[[] | "&lt;"], "foo" | "&gt;"]
  end

  test "impl for integer" do
    assert Safe.to_iodata(1) == "1"
  end

  test "impl for float" do
    assert Safe.to_iodata(1.0) == "1.0"
  end

  describe "impl for tuple" do
    test "{:safe, _}" do
      assert Safe.to_iodata({:safe, "<foo>"}) == "<foo>"
    end

    test "other" do
      assert_raise Protocol.UndefinedError, fn ->
        Safe.to_iodata({"needs %{count}", [count: 123]})
      end
    end
  end

  test "impl for iolist" do
    assert Safe.to_iodata(~c"foo") == [102, 111, 111]
    assert Safe.to_iodata(~c"<foo>") == ["&lt;", 102, 111, 111, "&gt;"]
    assert Safe.to_iodata([~c"<foo>"]) == [["&lt;", 102, 111, 111, "&gt;"]]
    assert Safe.to_iodata([?<, "foo" | ?>]) == ["&lt;", "foo" | "&gt;"]

    assert_raise ArgumentError, ~r/templates only support iodata/, fn ->
      Safe.to_iodata(~c"foo🐥")
    end
  end

  test "impl for Time" do
    {:ok, time} = Time.new(12, 13, 14)
    assert Safe.to_iodata(time) == "12:13:14"
  end

  test "impl for Date" do
    {:ok, date} = Date.new(2000, 1, 1)
    assert Safe.to_iodata(date) == "2000-01-01"
  end

  test "impl for NaiveDateTime" do
    {:ok, datetime} = NaiveDateTime.new(2000, 1, 1, 12, 13, 14)
    assert Safe.to_iodata(datetime) == "2000-01-01T12:13:14"
  end

  test "impl for DateTime" do
    datetime = %DateTime{
      year: 2000,
      month: 1,
      day: 1,
      hour: 12,
      minute: 13,
      second: 14,
      microsecond: {0, 0},
      zone_abbr: "<H>",
      time_zone: "<Hello>",
      std_offset: -1800,
      utc_offset: 3600
    }

    assert Safe.to_iodata(datetime) == "2000-01-01T12:13:14+00:30"
  end

  if Code.ensure_loaded?(Duration) do
    test "impl for Duration" do
      duration = Duration.new!(month: 1)
      assert Safe.to_iodata(duration) == "P1M"
    end
  end

  test "impl for URI" do
    uri = %URI{scheme: "http", host: "www.example.org", path: "/foo", query: "secret=<a&b>"}

    assert uri |> Safe.to_iodata() |> IO.iodata_to_binary() ==
             "http://www.example.org/foo?secret=&lt;a&amp;b&gt;"
  end

  if Code.ensure_loaded?(Decimal) do
    test "impl for Decimal" do
      decimal = Decimal.new("3.1415926")
      assert Safe.to_iodata(decimal) == "3.1415926"
    end
  end

  test "equivalences" do
    # Since some code may compare Safe.to_iodata("") with Safe.to_iodata(nil),
    # we make sure they have equivalent representations.
    assert Safe.to_iodata("") == Safe.to_iodata(nil)
  end
end
