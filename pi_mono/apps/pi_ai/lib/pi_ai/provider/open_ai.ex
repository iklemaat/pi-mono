defmodule PiAi.Provider.OpenAI do
  @moduledoc """
  OpenAI HTTP adapter via Req.
  """
  alias PiAi.Message

  @default_url "https://api.openai.com/v1/chat/completions"

  def chat(messages, options \\ []) do
    api_key = Keyword.get(options, :api_key) || System.get_env("OPENAI_API_KEY")
    model = Keyword.get(options, :model, "gpt-4o")
    base_url = Keyword.get(options, :base_url, @default_url)

    req_body = %{
      "model" => model,
      "messages" => Enum.map(messages, &encode_message/1)
    }

    # Add optional parameters like temperature or tools if they exist
    req_body = add_optional_params(req_body, options)

    request =
      Req.new(url: base_url)
      |> Req.Request.put_header("authorization", "Bearer #{api_key}")
      |> Req.Request.put_header("content-type", "application/json")

    case Req.post(request, json: req_body) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        {:ok, parse_response(body)}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, "API returned #{status}: #{inspect(body)}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def chat_stream(messages, options \\ []) do
    api_key = Keyword.get(options, :api_key) || System.get_env("OPENAI_API_KEY")
    model = Keyword.get(options, :model, "gpt-4o")
    base_url = Keyword.get(options, :base_url, @default_url)

    req_body = %{
      "model" => model,
      "messages" => Enum.map(messages, &encode_message/1),
      "stream" => true
    }

    req_body = add_optional_params(req_body, options)

    request =
      Req.new(url: base_url)
      |> Req.Request.put_header("authorization", "Bearer #{api_key}")
      |> Req.Request.put_header("content-type", "application/json")

    # Handling Server-Sent Events (SSE) chunks
    Req.post(request, json: req_body, into: stream_handler())
  end

  defp encode_message(%Message{role: role, content: content} = msg) do
    map = %{"role" => to_string(role), "content" => content || ""}

    map = if msg.name, do: Map.put(map, "name", msg.name), else: map
    map = if msg.tool_calls, do: Map.put(map, "tool_calls", msg.tool_calls), else: map
    map = if msg.tool_call_id, do: Map.put(map, "tool_call_id", msg.tool_call_id), else: map
    map
  end

  defp parse_response(body) do
    # Simply extract the first choice's message content and tool_calls for now
    choice = List.first(body["choices"]) || %{}
    msg = choice["message"] || %{}

    %Message{
      role: :assistant,
      content: msg["content"],
      tool_calls: msg["tool_calls"]
    }
  end

  defp add_optional_params(body, options) do
    Enum.reduce([:temperature, :tools], body, fn key, acc ->
      if Keyword.has_key?(options, key) do
        Map.put(acc, to_string(key), Keyword.get(options, key))
      else
        acc
      end
    end)
  end

  defp stream_handler do
    fn {:data, chunk}, {req, res} ->
      # Extremely simplified SSE chunk processor for the prototype
      lines = String.split(chunk, "\n", trim: true)

      parsed_chunks =
        Enum.reduce(lines, [], fn line, acc ->
          if String.starts_with?(line, "data: ") do
            data = String.trim_leading(line, "data: ")
            if data == "[DONE]" do
              acc
            else
              case Jason.decode(data) do
                {:ok, json} ->
                  delta = get_in(json, ["choices", Access.at(0), "delta"]) || %{}
                  [delta | acc]
                _ ->
                  acc
              end
            end
          else
            acc
          end
        end)
        |> Enum.reverse()

      # Send chunks back dynamically if we have a parent process to update
      send(self(), {:stream_chunks, parsed_chunks})

      {:cont, {req, res}}
    end
  end
end
