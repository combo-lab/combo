# This module name should be Combo.HTMLTest, but if I do that, the module name
# will conflict with another module. Because of that, I named it like this.
defmodule Combo.HTML.Test do
  use ExUnit.Case, async: true

  import Combo.HTML
  doctest Combo.HTML
end
