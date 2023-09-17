defmodule Lexical.RemoteControl.CodeMod.ToggleOneLineTest do
  use Lexical.Test.CodeMod.Case

  alias Lexical.Document
  alias Lexical.Document.Position
  alias Lexical.RemoteControl.CodeMod.ToggleOneLine

  import Lexical.Test.CursorSupport

  def apply_code_mod(original_text, _ast, opts) do
    document = Document.new("file:///file.ex", original_text, 0)

    {line, character} = Keyword.fetch!(opts, :cursor)
    position = Position.new(document, line, character)

    with {:ok, document_edits} <- ToggleOneLine.edits(document, position) do
      {:ok, document_edits.edits}
    end
  end

  test "toggles only the node at the cursor" do
    assert_toggle(
      %{
        code: """
        defmodule Some.App do
          def just_like_foo(%{elems: []}, val, _), do: {:ok, val}

          def foo(%{elems: []}, val, _) do
            {:ok, val}
          end

          def also_just_like_foo(%{elems: []}, val, _) do
            {:ok, val}
          end
        end
        """,
        cursor: [
          [{4, 3}, {4, 4}, {4, 8}, {4, 19}, {4, 29}, {4, 33}],
          [{5, 5}, {5, 12}],
          [{6, 3}, {6, 5}]
        ]
      },
      %{
        code: """
        defmodule Some.App do
          def just_like_foo(%{elems: []}, val, _), do: {:ok, val}

          def foo(%{elems: []}, val, _), do: {:ok, val}

          def also_just_like_foo(%{elems: []}, val, _) do
            {:ok, val}
          end
        end
        """,
        cursor: [{4, 3}, {4, 4}, {4, 8}, {4, 19}, {4, 29}, {4, 33}, {4, 43}, {4, 46}]
      }
    )
  end

  describe "function definition" do
    test "toggles with args and tuple" do
      assert_toggle(
        """
          d|ef foo(%{elems: []}, val, _) do
            {:ok, val}
          end
        """,
        """
          d|ef foo(%{elems: []}, val, _), do: {:ok, val}
        """
      )
    end

    test "toggles when private" do
      assert_toggle(
        """
          d|efp foo(%{elems: []}, val, _) do
            {:ok, val}
          end
        """,
        """
          d|efp foo(%{elems: []}, val, _), do: {:ok, val}
        """
      )
    end

    test "toggles without args" do
      assert_toggle(
        """
          d|ef foo do
            {:ok, val}
          end
        """,
        """
          d|ef foo, do: {:ok, val}
        """
      )
    end

    test "toggles with fun call" do
      assert_toggle(
        """
          d|ef foo(val) do
            bar(val)
          end
        """,
        """
          d|ef foo(val), do: bar(val)
        """
      )
    end

    test "toggles with external fun call" do
      assert_toggle(
        """
          d|ef foo(val) do
            String.downcase(val)
          end
        """,
        """
          d|ef foo(val), do: String.downcase(val)
        """
      )
    end

    test "toggles with a pipe" do
      assert_toggle(
        """
          d|ef foo(val) do
            val |> String.trim() |> String.downcase()
          end
        """,
        """
          d|ef foo(val), do: val |> String.trim() |> String.downcase()
        """
      )
    end

    test "doesn't toggle when multi-line" do
      code =
        normalize_code("""
          d|ef foo(val) do
            val = String.trim(val)
            String.downcase(val)
          end
        """)

      assert :error = modify(code.code, cursor: code.cursor, trim: false)
    end
  end

  defp assert_toggle(long, short) do
    assert_transform(long, short)
    assert_transform(short, long)
  end

  defp assert_transform(from, to) do
    from = normalize_code(from)
    to = normalize_code(to)

    for cursor <- from.cursor |> List.wrap() |> List.flatten() do
      toggled = modify(from.code, cursor: cursor, trim: false)
      assert {cursor, toggled} == {cursor, {:ok, to.code}}
    end
  end

  defp normalize_code(code) when is_binary(code) do
    %{code: strip_cursor(code), cursor: cursor_position(code)}
  end

  defp normalize_code(code), do: code
end
