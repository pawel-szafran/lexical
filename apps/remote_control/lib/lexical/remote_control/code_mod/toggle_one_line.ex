defmodule Lexical.RemoteControl.CodeMod.ToggleOneLine do
  alias Lexical.Ast
  alias Lexical.Document
  alias Lexical.Document.Position
  alias Lexical.Document.Changes
  alias Sourceror.Zipper

  require Logger

  @spec edits(Document.t(), Position.t()) :: {:ok, Changes.t()} | :error
  def edits(%Document{} = document, %Position{} = position) do
    with {:ok, zipper} <- Ast.surround_zipper(document, position),
         {:ok, changes} <- transform_node_or_ancestor(document, zipper) do
      {:ok, changes}
    else
      _ -> :error
    end
  end

  defp transform_node_or_ancestor(_document, nil = _zipper), do: {:error, :no_matching_node}

  defp transform_node_or_ancestor(document, zipper) do
    node = Zipper.node(zipper)

    with {:ok, transformed_ast} <- transform(node),
         replacement = Sourceror.to_string(transformed_ast),
         replacement = apply_original_indent(replacement, node),
         {:ok, edit} <- replace(document, node, replacement) do
      {:ok, Changes.new(document, [edit])}
    else
      _ -> transform_node_or_ancestor(document, Zipper.up(zipper))
    end
  end

  defp apply_original_indent(replacement, node) do
    case {String.split(replacement, "\n"), indent(node)} do
      {[_one_line], _} ->
        replacement

      {_lines, ""} ->
        replacement

      {[first_line | rest_lines], indent} ->
        [first_line | Enum.map(rest_lines, &[indent, &1])]
        |> Enum.intersperse("\n")
        |> IO.iodata_to_binary()
    end
  end

  defp indent(node) do
    start_pos = Sourceror.get_start_position(node)
    String.duplicate(" ", start_pos[:column] - 1)
  end

  defp replace(document, node, replacement) do
    patch = %{range: Sourceror.get_range(node), change: replacement}
    Ast.patch_to_edit(document, patch)
  end

  defp transform(
         {:def, def_opts,
          [
            {fun_name, fun_opts, fun_args},
            [{{:__block__, block_opts, [:do]}, {:__block__, do_block_opts, [do_block_exp]}}]
          ]}
       ) do
    if Keyword.has_key?(def_opts, :do) do
      {:ok,
       {:def, Keyword.drop(def_opts, ~w(do end)a),
        [
          {fun_name, fun_opts, fun_args},
          [
            {{:__block__, Keyword.put(block_opts, :format, :keyword), [:do]},
             {:__block__, do_block_opts, [do_block_exp]}}
          ]
        ]}}
    else
      {:ok,
       {:def, Keyword.merge(def_opts, do: [], end: []),
        [
          {fun_name, fun_opts, fun_args},
          [
            {{:__block__, Keyword.delete(block_opts, :format), [:do]},
             {:__block__, do_block_opts, [do_block_exp]}}
          ]
        ]}}
    end
  end

  defp transform(_), do: {:error, :not_applicable}
end
