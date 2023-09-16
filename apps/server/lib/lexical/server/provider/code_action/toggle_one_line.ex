defmodule Lexical.Server.Provider.CodeAction.ToggleOneLine do
  @moduledoc """
  A code action that toggles to and from one-line representation
  """
  alias Lexical.Document.Changes
  alias Lexical.Protocol.Requests.CodeAction
  alias Lexical.Protocol.Types.CodeAction, as: CodeActionResult
  alias Lexical.Protocol.Types.Workspace
  alias Lexical.RemoteControl
  alias Lexical.Server.Provider.Env

  require Logger

  @spec apply(CodeAction.t(), Env.t()) :: [CodeActionResult.t()]
  def apply(%CodeAction{} = action, %Env{} = env) do
    case RemoteControl.Api.toggle_one_line(env.project, action.document, action.range.start) do
      {:ok, %Changes{} = document_edits} ->
        [
          CodeActionResult.new(
            title: "Toggle one-line",
            kind: :refactor_rewrite,
            edit: Workspace.Edit.new(changes: %{action.document.uri => document_edits})
          )
        ]

      _ ->
        []
    end
  end
end
