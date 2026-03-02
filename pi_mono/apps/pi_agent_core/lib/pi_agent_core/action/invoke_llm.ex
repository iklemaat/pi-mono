defmodule PiAgentCore.Action.InvokeLLM do
  @moduledoc """
  Jido Action that communicates with the LLM via PiAi.
  """
  use Jido.Action,
    name: "invoke_llm",
    description: "Sends the conversation history to the LLM and retrieves the response.",
    schema: [
      messages: [
        type: {:list, :any},
        required: true,
        doc: "List of PiAi.Message representing the conversation history"
      ],
      provider: [
        type: :atom,
        required: false,
        default: :openai,
        doc: "The LLM provider to use"
      ]
    ]

  @impl true
  def run(%{messages: messages, provider: provider}, _context) do
    case PiAi.chat(messages, provider: provider) do
      {:ok, response_msg} ->
        {:ok, %{latest_response: response_msg}}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
