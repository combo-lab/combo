defmodule Combo.Template.CEExEngine.DebugAnnotationTest do
  use ExUnit.Case

  import ComboTest.Template.CEExEngine.Helper

  import __MODULE__.Components
  alias __MODULE__.Components

  test "remote component without tags" do
    assert render_string!("<Components.remote />") ==
             """
             <!-- <Combo.Template.CEExEngine.DebugAnnotationTest.Components.remote> test/combo/template/ceex_engine/debug_annotation_test/components.exs:5 () -->\
             REMOTE COMPONENT\
             <!-- </Combo.Template.CEExEngine.DebugAnnotationTest.Components.remote> -->\
             """
  end

  test "remote component with tags" do
    assert render_string!("<Components.remote_with_tags />") ==
             """
             <!-- <Combo.Template.CEExEngine.DebugAnnotationTest.Components.remote_with_tags> test/combo/template/ceex_engine/debug_annotation_test/components.exs:9 () -->\
             <div>REMOTE COMPONENT</div>\
             <!-- </Combo.Template.CEExEngine.DebugAnnotationTest.Components.remote_with_tags> -->\
             """
  end

  test "local component without tags" do
    assert render_string!("<.local />") ==
             """
             <!-- <Combo.Template.CEExEngine.DebugAnnotationTest.Components.local> test/combo/template/ceex_engine/debug_annotation_test/components.exs:13 () -->\
             LOCAL COMPONENT\
             <!-- </Combo.Template.CEExEngine.DebugAnnotationTest.Components.local> -->\
             """
  end

  test "local component with tags" do
    assert render_string!("<.local_with_tags />") ==
             """
             <!-- <Combo.Template.CEExEngine.DebugAnnotationTest.Components.local_with_tags> test/combo/template/ceex_engine/debug_annotation_test/components.exs:17 () -->\
             <div>LOCAL COMPONENT</div>\
             <!-- </Combo.Template.CEExEngine.DebugAnnotationTest.Components.local_with_tags> -->\
             """
  end

  test "default slot without tags" do
    assert render_string!("<.default_slot />") ==
             """
             <!-- <Combo.Template.CEExEngine.DebugAnnotationTest.Components.default_slot> test/combo/template/ceex_engine/debug_annotation_test/components.exs:21 () -->\
             <!-- @caller test/combo/template/ceex_engine/debug_annotation_test/components.exs:22 () -->\
             <!-- <Combo.Template.CEExEngine.DebugAnnotationTest.Components.list> test/combo/template/ceex_engine/debug_annotation_test/components.exs:64 () -->\
             <!-- <:inner_block> test/combo/template/ceex_engine/debug_annotation_test/components.exs:22 () -->\n  No items.\n\
             <!-- </:inner_block> -->\
             <!-- </Combo.Template.CEExEngine.DebugAnnotationTest.Components.list> -->\
             <!-- </Combo.Template.CEExEngine.DebugAnnotationTest.Components.default_slot> -->\
             """
  end

  test "default slot with tags" do
    assert render_string!("<.default_slot_with_tags />") ==
             """
             <!-- <Combo.Template.CEExEngine.DebugAnnotationTest.Components.default_slot_with_tags> test/combo/template/ceex_engine/debug_annotation_test/components.exs:29 () -->\
             <!-- @caller test/combo/template/ceex_engine/debug_annotation_test/components.exs:30 () -->\
             <!-- <Combo.Template.CEExEngine.DebugAnnotationTest.Components.list> test/combo/template/ceex_engine/debug_annotation_test/components.exs:64 () -->\
             <!-- <:inner_block> test/combo/template/ceex_engine/debug_annotation_test/components.exs:30 () -->\n  <p>No items</p>\n\
             <!-- </:inner_block> -->\
             <!-- </Combo.Template.CEExEngine.DebugAnnotationTest.Components.list> -->\
             <!-- </Combo.Template.CEExEngine.DebugAnnotationTest.Components.default_slot_with_tags> -->\
             """
  end

  test "named slot without tags" do
    assert render_string!("<.named_slot />") == """
           <!-- <Combo.Template.CEExEngine.DebugAnnotationTest.Components.named_slot> test/combo/template/ceex_engine/debug_annotation_test/components.exs:37 () -->\
           <!-- @caller test/combo/template/ceex_engine/debug_annotation_test/components.exs:38 () -->\
           <!-- <Combo.Template.CEExEngine.DebugAnnotationTest.Components.list> test/combo/template/ceex_engine/debug_annotation_test/components.exs:64 () -->\
           <ul>\
           <!-- <:item> test/combo/template/ceex_engine/debug_annotation_test/components.exs:39 () -->Coding<!-- </:item> -->, \
           <!-- <:item> test/combo/template/ceex_engine/debug_annotation_test/components.exs:40 () -->Sleeping<!-- </:item> -->\
           </ul>\
           <!-- <:inner_block> test/combo/template/ceex_engine/debug_annotation_test/components.exs:38 () -->\n  \
           <!-- </:inner_block> -->\
           <!-- </Combo.Template.CEExEngine.DebugAnnotationTest.Components.list> -->\
           <!-- </Combo.Template.CEExEngine.DebugAnnotationTest.Components.named_slot> -->\
           """
  end

  test "named slot with tags" do
    assert render_string!("<.named_slot_with_tags />") == """
           <!-- <Combo.Template.CEExEngine.DebugAnnotationTest.Components.named_slot_with_tags> test/combo/template/ceex_engine/debug_annotation_test/components.exs:46 () -->\
           <!-- @caller test/combo/template/ceex_engine/debug_annotation_test/components.exs:47 () -->\
           <!-- <Combo.Template.CEExEngine.DebugAnnotationTest.Components.list> test/combo/template/ceex_engine/debug_annotation_test/components.exs:64 () -->\
           <ul>\
           <!-- <:item> test/combo/template/ceex_engine/debug_annotation_test/components.exs:48 () --><span>Coding</span><!-- </:item> -->, \
           <!-- <:item> test/combo/template/ceex_engine/debug_annotation_test/components.exs:49 () --><span>Sleeping</span><!-- </:item> -->\
           </ul>\
           <!-- <:inner_block> test/combo/template/ceex_engine/debug_annotation_test/components.exs:47 () -->\n  \
           <!-- </:inner_block> -->\
           <!-- </Combo.Template.CEExEngine.DebugAnnotationTest.Components.list> -->\
           <!-- </Combo.Template.CEExEngine.DebugAnnotationTest.Components.named_slot_with_tags> -->\
           """
  end

  test "nesting" do
    assert render_string!("<Components.nesting />") ==
             """
             <!-- <Combo.Template.CEExEngine.DebugAnnotationTest.Components.nesting> test/combo/template/ceex_engine/debug_annotation_test/components.exs:55 () -->\
             <div>\n  \
             <!-- @caller test/combo/template/ceex_engine/debug_annotation_test/components.exs:57 () -->\
             <!-- <Combo.Template.CEExEngine.DebugAnnotationTest.Components.local_with_tags> test/combo/template/ceex_engine/debug_annotation_test/components.exs:17 () -->\
             <div>LOCAL COMPONENT</div>\
             <!-- </Combo.Template.CEExEngine.DebugAnnotationTest.Components.local_with_tags> -->\n\
             </div>\
             <!-- </Combo.Template.CEExEngine.DebugAnnotationTest.Components.nesting> -->\
             """
  end
end
