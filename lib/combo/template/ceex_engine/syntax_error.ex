defmodule Combo.Template.CEExEngine.SyntaxError do
  @moduledoc false
  defexception [:file, :line, :column, :description]

  @impl true
  def message(exception) do
    location =
      exception.file
      |> Path.relative_to_cwd()
      |> Exception.format_file_line_column(exception.line, exception.column)

    "#{location} #{exception.description}"
  end

  def code_snippet(source, meta, indentation \\ 0) do
    line_start = max(meta.line - 3, 1)
    line_end = meta.line
    digits = line_end |> Integer.to_string() |> byte_size()
    number_padding = String.duplicate(" ", digits)
    indentation = String.duplicate(" ", indentation)

    source
    |> String.split(["\r\n", "\n"])
    |> Enum.slice((line_start - 1)..(line_end - 1))
    |> Enum.map_reduce(line_start, fn
      expr, line_number when line_number == line_end ->
        arrow = String.duplicate(" ", meta.column - 1) <> "^"
        acc = "#{line_number} | #{indentation}#{expr}\n #{number_padding}| #{arrow}"
        {acc, line_number + 1}

      expr, line_number ->
        line_number_padding = String.pad_leading("#{line_number}", digits)
        {"#{line_number_padding} | #{indentation}#{expr}", line_number + 1}
    end)
    |> case do
      {[], _} ->
        ""

      {snippet, _} ->
        Enum.join(["\n #{number_padding}|" | snippet], "\n")
    end
  end
end
