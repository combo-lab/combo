defmodule Combo.HTML.Formatter do
  @moduledoc """
  Formats templates files or inline templates of CEEx.

  This is a `mix format` [plugin](https://hexdocs.pm/mix/main/Mix.Tasks.Format.html#module-plugins).

  ## Setup

  Add it as a plugin to the `.formatter.exs` file and make sure to put the
  `ceex` extension in the `:inputs` option.

  ```elixir
  [
    plugins: [Combo.HTML.Formatter],
    inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ceex,ex,exs}"]
    # ...
  ]
  ```

  > ### For umbrella projects {: .info}
  >
  > In umbrella projects, you must also add two changes at the umbrella root:
  >
  >   1. add `:combo` to your `deps` in the `mix.exs` file
  >   2. add `plugins: [Combo.HTML.Formatter]` in the `.formatter.exs` file.
  >
  > This is because the formatter does not attempt to load the dependencies of
  > all children applications.

  ### Editor support

  Most editors that support `mix format` integration should automatically format
  `.ceex` and `~CE` templates. Other editors may require custom integration or
  even provide additional functionality.

  ## Options

    * `:line_length` - The Elixir formatter defaults to a maximum line length
      of 98 characters, which can be overwritten with the `:line_length` option
      in your `.formatter.exs` file.

    * `:ceex_line_length` - change the line length only for the CEEx formatter.

      ```elixir
      [
        ceex_line_length: 300
      ]
      ```

    * `:migrate_eex_to_curly_interpolation` - Automatically migrate single expression
      `<%= ... %>` EEx expression to the curly braces one. Defaults to true.

    * `:attribute_formatters` - Specify formatters for certain attributes.

      ```elixir
      [
        plugins: [Combo.HTML.Formatter],
        attribute_formatters: %{class: ClassFormatter},
      ]
      ```

    * `:inline_matcher` - a list of regular expressions to determine if a component
      should be treated as inline.
      Defaults to `["link", "button"]`, which treats any component with `link` or
      `button` in its name as inline.
      Can be disabled by setting it to an empty list.

  ## Formatting

  This formatter tries to be as consistent as possible with the Elixir formatter,
  and also take into account "block" and "inline" HTML elements.

  In the past, HTML elements were categorized as either "block-level" or
  "inline". While now these concepts are specified by CSS, the historical
  distinction remains as it typically dictates the default browser rendering
  behavior. In particular, adding or removing whitespace between the start and
  end tags of a block-level element will not change the rendered output, while
  it may for inline elements.

  The following links further explain these concepts:

  * https://developer.mozilla.org/en-US/docs/Glossary/Block-level_content
  * https://developer.mozilla.org/en-US/docs/Glossary/Inline-level_content

  Given HTML like this:

  ```ceex
    <section><h1>   <b>{@user.name}</b></h1></section>
  ```

  It will be formatted as:

  ```ceex
  <section>
    <h1><b>{@user.name}</b></h1>
  </section>
  ```

  A block element will go to the next line, while inline elements will be kept
  in the current line as long as they fit within the configured line length.

  It will also keep inline elements in their own lines if you intentionally write them this way:

  ```ceex
  <section>
    <h1>
      <b>{@user.name}</b>
    </h1>
  </section>
  ```

  This formatter will place all attributes on their own lines when they do not all fit in the
  current line. Therefore this:

  ```ceex
  <section id="user-section-id" class="sm:focus:block flex w-full p-3">
    <p>Hi</p>
  </section>
  ```

  Will be formatted to:

  ```ceex
  <section
    id="user-section-id"
    class="sm:focus:block flex w-full p-3"
  >
    <p>Hi</p>
  </section>
  ```

  This formatter **does not** format Elixir expressions with `do...end`. The
  content within it will be formatted accordingly though. Therefore, the given
  input:

  ```eex
  <%= redirect(
         to: "/my/path",
    class: "my class"
  ) do %>
          My Link
  <% end %>
  ```

  Will be formatted to

  ```eex
  <%= redirect(
         to: "/my/path",
    class: "my class"
  ) do %>
    My Link
  <% end %>
  ```

  Note that only the text `My Link` has been formatted.

  ### Intentional new lines

  The formatter will keep intentional new lines. However, the formatter will
  always keep a maximum of one line break in case you have multiple ones:

  ```ceex
  <p>
    text


    text
  </p>
  ```

  Will be formatted to:

  ```ceex
  <p>
    text

    text
  </p>
  ```

  ### Inline elements

  We don't format inline elements when there is a text without whitespace before
  or after the element. Otherwise it would compromise what is rendered adding
  an extra whitespace.

  The formatter will consider these tags as inline elements:

    * `<a>`
    * `<abbr>`
    * `<acronym>`
    * `<audio>`
    * `<b>`
    * `<bdi>`
    * `<bdo>`
    * `<big>`
    * `<br>`
    * `<button>`
    * `<canvas>`
    * `<cite>`
    * `<code>`
    * `<data>`
    * `<datalist>`
    * `<del>`
    * `<dfn>`
    * `<em>`
    * `<embed>`
    * `<i>`
    * `<iframe>`
    * `<img>`
    * `<input>`
    * `<ins>`
    * `<kbd>`
    * `<label>`
    * `<map>`
    * `<mark>`
    * `<meter>`
    * `<noscript>`
    * `<object>`
    * `<output>`
    * `<picture>`
    * `<progress>`
    * `<q>`
    * `<ruby>`
    * `<s>`
    * `<samp>`
    * `<select>`
    * `<slot>`
    * `<small>`
    * `<span>`
    * `<strong>`
    * `<sub>`
    * `<sup>`
    * `<svg>`
    * `<template>`
    * `<textarea>`
    * `<time>`
    * `<u>`
    * `<tt>`
    * `<var>`
    * `<video>`
    * `<wbr>`
    * Tags/components that match the `:inline_matcher` option.

  All other tags are considered block elements.

  ## Skip formatting

  In case you don't want part of your HTML to be automatically formatted.
  You can use the special `ceex-no-format` attribute so that the formatter will
  skip the element block. Note that this attribute will not be rendered.

  Therefore:

  ```ceex
  <.textarea ceex-no-format>My content</.textarea>
  ```

  Will be kept as is your code editor, but rendered as:

  ```ceex
  <textarea>My content</textarea>
  ```
  """

  alias Combo.Template.CEExEngine.Formatter

  @behaviour Mix.Tasks.Format

  @impl true
  defdelegate features(opts), to: Formatter

  @impl true
  defdelegate format(source, opts), to: Formatter
end
