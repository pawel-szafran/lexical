defmodule Lexical.RemoteControl.Search.Indexer.Entry do
  @type entry_type :: :module
  @type subject :: String.t()
  @type entry_subtype :: :reference | :definition
  @type version :: String.t()
  @type entry_id :: pos_integer() | nil
  @type block_id :: pos_integer() | :root

  defstruct [
    :application,
    :id,
    :block_id,
    :path,
    :range,
    :subject,
    :subtype,
    :type,
    :updated_at
  ]

  @type t :: %__MODULE__{
          application: module(),
          subject: subject(),
          block_id: block_id(),
          path: Path.t(),
          range: Lexical.Document.Range.t(),
          subtype: entry_subtype(),
          type: entry_type(),
          updated_at: :calendar.datetime()
        }

  alias Lexical.Identifier
  alias Lexical.RemoteControl.Search.Indexer.Source.Block
  alias Lexical.StructAccess

  use StructAccess

  defguard is_structure(entry) when entry.type == :metadata and entry.subtype == :block_structure
  defguard is_block(entry) when entry.id == entry.block_id

  def block_structure(path, structure) do
    %__MODULE__{
      path: path,
      subject: structure,
      type: :metadata,
      subtype: :block_structure,
      updated_at: timestamp()
    }
  end

  def reference(path, %Block{} = block, subject, type, range, application) do
    new(path, Identifier.next_global!(), block.id, subject, type, :reference, range, application)
  end

  def block_definition(path, %Block{} = block, subject, type, range, application) do
    definition(
      path,
      block.id,
      block.parent_id,
      subject,
      type,
      range,
      application
    )
  end

  defp definition(path, id, block_id, subject, type, range, application) do
    new(path, id, block_id, subject, type, :definition, range, application)
  end

  defp new(path, id, block_id, subject, type, subtype, range, application) do
    %__MODULE__{
      application: application,
      block_id: block_id,
      id: id,
      path: path,
      range: range,
      subject: subject,
      subtype: subtype,
      type: type,
      updated_at: timestamp()
    }
  end

  def block?(%__MODULE__{} = entry) do
    is_block(entry)
  end

  defp timestamp do
    :calendar.universal_time()
  end
end
