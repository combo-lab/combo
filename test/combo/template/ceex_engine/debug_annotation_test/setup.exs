Application.put_env(:combo, :ceex_debug_annotations, true)
Code.require_file("support/components.exs", __DIR__)
Application.put_env(:combo, :ceex_debug_annotations, false)
