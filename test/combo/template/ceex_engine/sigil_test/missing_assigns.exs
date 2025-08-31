defmodule Combo.Template.CEExEngine.SigilTest.MissingAssigns do
  import Combo.Template.CEExEngine.Sigil

  def component do
    ~CE"""
    Hello, world!
    """
  end
end
