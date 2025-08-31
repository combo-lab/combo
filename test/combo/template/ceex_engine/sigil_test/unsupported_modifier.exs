defmodule Combo.Template.CEExEngine.SigilTest.UnsupportedModifier do
  import Combo.Template.CEExEngine.Sigil

  def component do
    ~CE"""
    Hello, world!
    """bad
  end
end
