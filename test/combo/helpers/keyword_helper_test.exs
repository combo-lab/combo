defmodule Combo.Helpers.KeywordHelperTest do
  use ExUnit.Case, async: true

  alias Combo.Helpers.KeywordHelper, as: KH

  test "has_key?/2" do
    assert KH.has_key?([], [:k1]) == false
    assert KH.has_key?([], [:k1, :k2]) == false

    assert KH.has_key?([k1: []], [:k1]) == true
    assert KH.has_key?([k1: "i"], [:k1]) == true
    assert KH.has_key?([k1: nil], [:k1]) == true
    assert KH.has_key?([k1: false], [:k1]) == true

    assert KH.has_key?([k1: []], [:k1, :k2]) == false
    assert KH.has_key?([k1: [k2: "i"]], [:k1, :k2]) == true
    assert KH.has_key?([k1: [k2: nil]], [:k1, :k2]) == true
    assert KH.has_key?([k1: [k2: false]], [:k1, :k2]) == true
  end

  test "get/3" do
    assert KH.get([], [:k1]) == nil
    assert KH.get([], [:k1, :k2]) == nil
    assert KH.get([], [:k1, :k2], "dv2") == "dv2"

    assert KH.get([k1: []], [:k1]) == []
    assert KH.get([k1: "i"], [:k1]) == "i"
    assert KH.get([k1: nil], [:k1]) == nil
    assert KH.get([k1: false], [:k1]) == false

    assert KH.get([k1: []], [:k1, :k2]) == nil
    assert KH.get([k1: [k2: "i"]], [:k1, :k2]) == "i"
    assert KH.get([k1: [k2: nil]], [:k1, :k2]) == nil
    assert KH.get([k1: [k2: false]], [:k1, :k2]) == false
    assert KH.get([k1: [k2: false]], [:k1, :k2], "dv2") == false
  end

  test "put/3" do
    assert KH.put([], [:k1], "v1") == [k1: "v1"]
    assert KH.put([], [:k1, :k2], "v2") == [k1: [k2: "v2"]]

    assert KH.put([k1: [k2: "v2"]], [:k1, :k2], "v2!") == [k1: [k2: "v2!"]]
    assert KH.put([k1: [k2: "v2"]], [:k1, :k3], "v3") == [k1: [k2: "v2", k3: "v3"]]
  end

  test "merge/2" do
    assert KH.merge([], k1: "v1") == [k1: "v1"]
    assert KH.merge([k1: "v1"], []) == [k1: "v1"]

    assert KH.merge([k1: "v1"], k2: "v2") == [k1: "v1", k2: "v2"]

    assert KH.merge([k1: [k2: [k3: []]]], k1: [k2: [k4: "v4"]]) == [k1: [k2: [k3: [], k4: "v4"]]]
  end
end
