defmodule PiAi do
  @moduledoc """
  Unified LLM API Client.
  Delegates `chat/2` and `chat_stream/2` to the respective provider.
  """
  alias PiAi.Message

  @doc """
  Sends a chat completion request to the given provider.

  Options:
  - `:provider` (default: :openai)
  - `:model`
  - `:api_key`
  - `:base_url`
  """
  def chat(messages, options \\ []) do
    provider = Keyword.get(options, :provider, :openai)

    case provider do
      :openai -> PiAi.Provider.OpenAI.chat(messages, options)
      _ -> {:error, "Unsupported provider: #{provider}"}
    end
  end

  @doc """
  Streams a chat completion request.
  Options are identical to `chat/2`.
  """
  def chat_stream(messages, options \\ []) do
    provider = Keyword.get(options, :provider, :openai)

    case provider do
      :openai -> PiAi.Provider.OpenAI.chat_stream(messages, options)
      _ -> {:error, "Unsupported provider: #{provider}"}
    end
  end
end
