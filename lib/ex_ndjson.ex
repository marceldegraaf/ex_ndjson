defmodule ExNdjson do
  @moduledoc """
  Implements encoding and decoding of NDJSON as defined in [NDJSON Spec](https://github.com/ndjson/ndjson-spec).
  """

  use GenServer
  import ExNdjson.Serializer
  alias ExNdjson.NdJSONParser

  #
  # Client API
  #

  @type t :: nil | true | false | list | float | integer | String.t() | map

  @doc """
  Returns the NDJSON encoding of v, raises an exception on error.

  ## Examples

      iex> ExNdjson.marshal!([%{id: 1}, [1, 2, 3]])
      "{\"id\": \"1\"}\\n[1, 2, 3]\\n"
  """
  @spec marshal!([t()]) :: String.t() | no_return()
  def marshal!(v) when is_list(v) do
    GenServer.call(__MODULE__, {:marshal!, v})
  end

  @doc """
  Parses the NDJSON-encoded data and returns a list of decoded JSON values.

  ## Examples

      iex> ExNdjson.unmarshal('{"id": "1"}\\n[1, 2, 3]\\r\\n')
      [%{"id" => "1"}, [1, 2, 3]]
  """
  @spec unmarshal(iodata()) :: [t()]
  def unmarshal(v) do
    GenServer.call(__MODULE__, {:unmarshal, v})
  end

  @doc """
  Parses the NDJSON-encoded lines in the given path and returns a list of decoded JSON values.
  Raises an exception if failed to open the file.
  ## Examples

      iex> ExNdjson.unmarshal_from_file!("./fixtures/file.txt")
      [%{"id" => "1"}, [1, 2, 3]]
  """
  @spec unmarshal_from_file!(Path.t()) :: [t()] | no_return()
  def unmarshal_from_file!(path) do
    GenServer.call(__MODULE__, {:unmarshal_from_file, path})
  end

  #
  # Callbacks
  #

  def start_link(_args), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  def init(:ok), do: {:ok, []}

  def handle_call({:marshal!, v}, _from, state) do
    pid = start()

    v
    |> Stream.each(fn record -> pid |> write!(record) end)
    |> Stream.run()

    {:reply, serialize(pid), state}
  end

  def handle_call({:unmarshal, v}, _from, state) do
    result =
      case NdJSONParser.parse(v) do
        {:valid, decoded} -> decoded
        error -> error
      end

    {:reply, result, state}
  end

  def handle_call({:unmarshal_from_file, path}, _from, state) do
    lines =
      path
      |> File.stream!()
      |> Enum.to_list()

    result =
      case NdJSONParser.parse(lines) do
        {:valid, decoded} -> decoded
        error -> error
      end

    {:reply, result, state}
  end
end
