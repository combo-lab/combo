Combo.Env.put_env(:template, :ceex_debug_annotations, true)
Code.require_file("components.exs", __DIR__)
Combo.Env.put_env(:template, :ceex_debug_annotations, false)
