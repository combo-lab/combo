defmodule Combo.Template do
  @moduledoc """
  Compiling and rendering templates.

  > In practice, we rarely use `Combo.Template` directly. Instead, we use
  > `Combo.HTML` which is built on top of it.

  ## Template languages

  A template language is a specialized markup language for building templates.

  ## Templates

  Templates are the content written in various template languages.

  ## Template files

  A template file is a file containing template, and filename has the following
  structure: `<NAME>.<FORMAT>.<ENGINE>`, such as `welcome.html.eex`.

  ## Template engines

  A template engine is a module for compiling template files into Elixir's
  quoted expressions.

  > And, some engines supports template sigils, which are for compiling
  > inline templates into Elixir's quoted expressions.

  ### Custom template engines

  Combo supports custom template engines.

  See `Combo.Template.Engine` for more information on the API required to
  be implemented by custom engines.

  Once template engines are defined, you can use them via the `:engines`
  option:

  ```elixir
  config :combo, :template,
    engines: [
      eex: CustomEExEngine,
      exs: CustomExsEngine
    ]
  ```

  ## Format encoders

  Besides template engines, Combo has the concept of format encoders.

  Format encoders work per format and are responsible for encoding a given
  format to a string. For example, when rendering JSON, templates may return
  a regular Elixir map. Then, the JSON format encoder is invoked to convert
  it to JSON.

  See `Combo.Template.FormatEncoder` for more information on the API required
  to be implemented by custom format encoders.

  Once format encoders are defined, you can use them via the `:format_encoders`
  option:

  ```elixir
  config :combo, :template,
    format_encoders: [
      html: CustomHTMLEncoder
      json: CustomJSONEncoder
    ]
  ```
  """

  alias Combo.Env

  @type path :: binary()
  @type root :: binary()

  @default_pattern "*"

  @doc """
  Ensures that `__mix_recompile__?/0` will be defined.
  """
  defmacro __using__(_opts) do
    quote do
      Combo.Template.__idempotent_setup__(__MODULE__, %{})
    end
  end

  @doc """
  Embeds external template files into the module as functions.

  This macro is built on top of `compile_all/3`.

  ## Options

    * `:root` - The root directory to embed template files. Defaults to the
      directory of current module (`__DIR__`).
    * `:suffix` - The string value to append to the embedded function names.
      By default, function names will be the name of the template file
      excluding the format and engine.

  ## Examples

  Imagine a directory listing:

      ├── pages
      │   ├── about.html.ceex
      │   └── sitemap.xml.eex

  To embed the templates into a module, we can define a module like this:

  ```elixir
  defmodule DemoWeb.Pages do
    import Combo.Template, only: [embed_templates: 1]

    # a wildcard pattern is used to select all files within a directory
    embed_templates "pages/*"
  end
  ```

  Now, the module will have `about/1` and `sitemap/1` functions.

  Multiple invocations of `embed_templates` is also supported, which can be
  useful if we have more than one template format. For example:

  ```elixir
  defmodule DemoWeb.Pages do
    import Combo.Template, only: [embed_templates: 2]

    embed_templates "pages/*.html", suffix: "_html"
    embed_templates "pages/*.xml", suffix: "_xml"
  end
  ```

  Now, the module will have `about_html` and `sitemap_xml` functions.
  """
  @doc type: :macro
  defmacro embed_templates(pattern, opts \\ []) do
    quote bind_quoted: [pattern: pattern, opts: opts] do
      Combo.Template.compile_all(
        &Combo.Template.__embed__(&1, opts[:suffix]),
        Path.expand(opts[:root] || __DIR__, __DIR__),
        pattern
      )
    end
  end

  @doc false
  def __embed__(path, suffix),
    do:
      path
      |> Path.basename()
      |> Path.rootname()
      |> Path.rootname()
      |> Kernel.<>(suffix || "")

  @doc """
  Renders the template and returns iodata.
  """
  def render_to_iodata(module, template, format, assigns) do
    module
    |> render(template, format, assigns)
    |> encode_to_iodata(format)
  end

  defp encode_to_iodata(content, format) do
    if encoder = format_encoder(format) do
      encoder.encode_to_iodata!(content)
    else
      content
    end
  end

  @doc """
  Renders the template to string.
  """
  def render_to_string(module, template, format, assigns) do
    module
    |> render_to_iodata(template, format, assigns)
    |> IO.iodata_to_binary()
  end

  @doc """
  Renders template from module.

  For a module called `DemoWeb.UserHTML` and template "index.html.ceex",
  it will:

    * First attempt to call `DemoWeb.UserHTML.index(assigns)`

    * Then fallback to `DemoWeb.UserHTML.render("index.html", assigns)`

    * Raise otherwise

  It expects the the module, the template as a string, the format, and a
  set of assigns.

  Notice that this function returns the inner representation of a template.
  If you want the encoded template as a result, use `render_to_iodata/4`
  instead.

  ## Examples

      Combo.Template.render(DemoWeb.UserHTML, "index", "html", name: "Charie Brown")
      #=> {:safe, "Hello, Charlie Brown"}

  """
  def render(module, template, format, assigns) do
    assigns = to_map(assigns)
    render_with_fallback(module, template, format, assigns)
  end

  defp to_map(assigns) when is_map(assigns), do: assigns
  defp to_map(assigns) when is_list(assigns), do: :maps.from_list(assigns)

  defp render_with_fallback(module, template, format, assigns)
       when is_atom(module) and is_binary(template) and is_binary(format) and is_map(assigns) do
    :erlang.module_loaded(module) or :code.ensure_loaded(module)

    try do
      String.to_existing_atom(template)
    catch
      _, _ -> fallback_render(module, template, format, assigns)
    else
      atom ->
        if function_exported?(module, atom, 1) do
          apply(module, atom, [assigns])
        else
          fallback_render(module, template, format, assigns)
        end
    end
  end

  @compile {:inline, fallback_render: 4}
  defp fallback_render(module, template, format, assigns) do
    if function_exported?(module, :render, 2) do
      module.render(template <> "." <> format, assigns)
    else
      reason =
        if Code.ensure_loaded?(module) do
          " (the module exists but does not define #{template}/1 nor render/2)"
        else
          " (the module does not exist)"
        end

      raise ArgumentError,
            "no \"#{template}\" #{format} template defined for #{inspect(module)} #{reason}"
    end
  end

  ## Configuration API

  @doc """
  Returns all template engines as a map.
  """
  @spec engines() :: %{atom => module}
  def engines do
    compiled_engines()
  end

  defp compiled_engines do
    case Env.fetch_env(:template, :compiled_engines) do
      {:ok, engines} ->
        engines

      :error ->
        custom_engines = Env.get_env(:template, :engines, [])

        engines =
          default_engines()
          |> Keyword.merge(custom_engines)
          |> Enum.filter(fn {_, v} -> v end)
          |> Enum.into(%{})

        Env.put_env(:template, :compiled_engines, engines)
        engines
    end
  end

  defp default_engines do
    [
      exs: Combo.Template.ExsEngine,
      eex: Combo.Template.EExEngine,
      ceex: Combo.Template.CEExEngine
    ]
  end

  @doc """
  Returns all format encoders as a map.
  """
  @spec format_encoders() :: %{String.t() => module}
  def format_encoders do
    compiled_format_encoders()
  end

  @doc """
  Returns the format encoder for a given format.
  """
  @spec format_encoder(format :: String.t()) :: module | nil
  def format_encoder(format) when is_binary(format) do
    Map.get(compiled_format_encoders(), format)
  end

  defp compiled_format_encoders do
    case Env.fetch_env(:template, :compiled_format_encoders) do
      {:ok, encoders} ->
        encoders

      :error ->
        custom_encoders = Env.get_env(:template, :format_encoders, [])

        encoders =
          default_encoders()
          |> Keyword.merge(custom_encoders)
          |> Enum.filter(fn {_, v} -> v end)
          |> Enum.into(%{}, fn {k, v} -> {to_string(k), v} end)

        Env.put_env(:template, :compiled_format_encoders, encoders)
        encoders
    end
  end

  defp default_encoders do
    [
      html: Combo.Template.HTMLEncoder,
      json: Combo.json_library(),
      js: Combo.Template.HTMLEncoder
    ]
  end

  ## Lookup API

  @doc """
  Returns all template paths in a given template root.
  """
  @spec find_all(root, pattern :: String.t(), %{atom => module}) :: [path]
  def find_all(root, pattern \\ @default_pattern, engines \\ engines()) do
    extensions = engines |> Map.keys() |> Enum.join(",")

    root
    |> Path.join(pattern <> ".{#{extensions}}")
    |> Path.wildcard()
  end

  @doc """
  Returns the hash of all template paths in the given root.

  Used by Combo to check if a given root path requires recompilation.
  """
  @spec hash(root, pattern :: String.t(), %{atom => module}) :: binary
  def hash(root, pattern \\ @default_pattern, engines \\ engines()) do
    find_all(root, pattern, engines)
    |> Enum.sort()
    |> :erlang.md5()
  end

  @doc """
  Compiles a function for each template in the given `root`.

  `converter` is an anonymous function that receives the template path and
  returns the function name (as a string).

  For example, to compile all `.eex` templates in a given directory, you might
  do:

  ```elixir
  Combo.Template.compile_all(
    &(&1 |> Path.basename() |> Path.rootname(".eex")),
    __DIR__,
    "*.eex"
  )
  ```

  If the directory has templates named `foo.eex` and `bar.eex`,
  they will be compiled into the functions `foo/1` and `bar/1`
  that receive the template `assigns` as argument.

  You may optionally pass a keyword list of engines. If a list
  is given, we will lookup and compile only this subset of engines.
  If none is passed (`nil`), the default list returned by `engines/0`
  is used.
  """
  defmacro compile_all(converter, root, pattern \\ @default_pattern, engines \\ nil) do
    quote bind_quoted: binding() do
      for {path, name, body} <-
            Combo.Template.__compile_all__(__MODULE__, converter, root, pattern, engines) do
        @external_resource path
        @file path
        def unquote(String.to_atom(name))(var!(assigns)) do
          _ = var!(assigns)
          unquote(body)
        end

        {name, path}
      end
    end
  end

  @doc false
  def __compile_all__(module, converter, root, pattern, given_engines) do
    engines = given_engines || engines()
    paths = find_all(root, pattern, engines)

    {triplets, {paths, engines}} =
      Enum.map_reduce(paths, {[], %{}}, fn path, {acc_paths, acc_engines} ->
        ext = Path.extname(path) |> String.trim_leading(".") |> String.to_atom()
        engine = Map.fetch!(engines, ext)
        name = converter.(path)
        body = engine.compile(path, name)
        map = {path, name, body}
        reduce = {[path | acc_paths], Map.put(acc_engines, engine, true)}
        {map, reduce}
      end)

    # Store the engines so we define compile-time deps
    __idempotent_setup__(module, engines)

    # Store the hashes so we define __mix_recompile__?
    hash = paths |> Enum.sort() |> :erlang.md5()

    args =
      if given_engines, do: [root, pattern, Macro.escape(given_engines)], else: [root, pattern]

    Module.put_attribute(module, :combo_template_hashes, {hash, args})
    triplets
  end

  @doc false
  def __idempotent_setup__(module, engines) do
    # Store the used engines so they become requires on before_compile
    if used_engines = Module.get_attribute(module, :combo_template_engines) do
      Module.put_attribute(module, :combo_template_engines, Map.merge(used_engines, engines))
    else
      Module.register_attribute(module, :combo_template_hashes, accumulate: true)
      Module.put_attribute(module, :combo_template_engines, engines)
      Module.put_attribute(module, :before_compile, Combo.Template)
    end
  end

  @doc false
  defmacro __before_compile__(env) do
    hashes = Module.get_attribute(env.module, :combo_template_hashes)
    engines = Module.get_attribute(env.module, :combo_template_engines)

    body =
      Enum.reduce(hashes, false, fn {hash, args}, acc ->
        quote do
          unquote(acc) or unquote(hash) != Combo.Template.hash(unquote_splicing(args))
        end
      end)

    compile_time_deps =
      for {engine, _} <- engines do
        quote do
          unquote(engine).__info__(:module)
        end
      end

    quote do
      unquote(compile_time_deps)

      @doc false
      def __mix_recompile__? do
        unquote(body)
      end
    end
  end
end
