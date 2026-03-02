defmodule PiAgentCore.Agent do
  @moduledoc """
  A foundational Jido Agent with memory capability.
  """
  use Jido.Agent,
    name: "pi_agent_core",
    description: "Core coding agent that manages conversation state and actions.",
    actions: [PiAgentCore.Action.InvokeLLM],
    schema: [
      messages: [
        type: {:list, :any},
        default: [],
        doc: "Chat history"
      ],
      last_response: [
        type: :any,
        default: nil,
        doc: "The latest response from the LLM"
      ]
    ]

  @doc """
  Updates the agent's history and invokes the LLM.
  """
  def chat(%Jido.Agent{} = agent, message) do
    # Add new user message to the agent's state
    new_messages = agent.state.messages ++ [message]

    case PiAgentCore.Agent.set(agent, %{messages: new_messages}) do
      {:ok, updated_agent} ->
        PiAgentCore.Agent.cmd(
          updated_agent,
          Jido.Instruction.new(%{
            action: PiAgentCore.Action.InvokeLLM,
            params: %{
              messages: updated_agent.state.messages,
              provider: :openai
            }
          })
        )
      error -> error
    end
  end
end
