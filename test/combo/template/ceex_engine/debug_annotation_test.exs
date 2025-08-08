defmodule Combo.Template.CEExEngine.DebugAnnotationTest do
  use ExUnit.Case

  import ComboTest.Template.CEExEngine.Helper, only: [render_compiled: 1]

  test "remote component (without root tag)" do
    alias __MODULE__.Components

    assigns = %{}

    assert render_compiled("<Components.remote value='1'/>") ==
             """
             <!-- <Combo.Template.CEExEngine.DebugAnnotationTest.Components.remote> test/combo/template/ceex_engine/debug_annotation_test/support/components.exs:5 () -->\
             REMOTE COMPONENT: Value: 1\
             <!-- </Combo.Template.CEExEngine.DebugAnnotationTest.Components.remote> -->\
             """
  end

  test "remote component (with root tag)" do
    alias __MODULE__.Components

    assigns = %{}

    assert render_compiled("<Components.remote_with_root value='1'/>") ==
             """
             <!-- <Combo.Template.CEExEngine.DebugAnnotationTest.Components.remote_with_root> test/combo/template/ceex_engine/debug_annotation_test/support/components.exs:9 () -->\
             <div>REMOTE COMPONENT: Value: 1</div>\
             <!-- </Combo.Template.CEExEngine.DebugAnnotationTest.Components.remote_with_root> -->\
             """
  end

  test "local component (without root tag)" do
    import __MODULE__.Components

    assigns = %{}

    assert render_compiled("<.local value='1'/>") ==
             """
             <!-- <Combo.Template.CEExEngine.DebugAnnotationTest.Components.local> test/combo/template/ceex_engine/debug_annotation_test/support/components.exs:13 () -->\
             LOCAL COMPONENT: Value: 1\
             <!-- </Combo.Template.CEExEngine.DebugAnnotationTest.Components.local> -->\
             """
  end

  test "local component (with root tag)" do
    import __MODULE__.Components

    assigns = %{}

    assert render_compiled("<.local_with_root value='1'/>") ==
             """
             <!-- <Combo.Template.CEExEngine.DebugAnnotationTest.Components.local_with_root> test/combo/template/ceex_engine/debug_annotation_test/support/components.exs:17 () -->\
             <div>LOCAL COMPONENT: Value: 1</div>\
             <!-- </Combo.Template.CEExEngine.DebugAnnotationTest.Components.local_with_root> -->\
             """
  end

  test "nesting" do
    alias __MODULE__.Components

    assigns = %{}

    assert render_compiled("<Components.nested value='1'/>") ==
             """
             <!-- <Combo.Template.CEExEngine.DebugAnnotationTest.Components.nested> test/combo/template/ceex_engine/debug_annotation_test/support/components.exs:21 () --><div>
               <!-- @caller test/combo/template/ceex_engine/debug_annotation_test/support/components.exs:23 () -->\
             <!-- <Combo.Template.CEExEngine.DebugAnnotationTest.Components.local_with_root> test/combo/template/ceex_engine/debug_annotation_test/support/components.exs:17 () -->\
             <div>LOCAL COMPONENT: Value: local</div>\
             <!-- </Combo.Template.CEExEngine.DebugAnnotationTest.Components.local_with_root> -->
             </div><!-- </Combo.Template.CEExEngine.DebugAnnotationTest.Components.nested> -->\
             """
  end
end
