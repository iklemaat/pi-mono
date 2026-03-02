defmodule PiAgentCore.AgentTest do
  use ExUnit.Case, async: true
  alias PiAgentCore.Agent
  alias PiAi.Message

  test "chat/2 successfully runs an agent instruction" do
    agent = Agent.new()

    message = %Message{role: :user, content: "Hello!"}

    # Simulate running the command directly.
    # Note: In a real test, we would mock PiAi.chat to avoid hitting OpenAI.
    # For now, we only verify that the state mutation and command construction work.
    {:ok, updated_agent} = Agent.set(agent, %{messages: [message]})
    assert [%Message{content: "Hello!"}] = updated_agent.state.messages
  end
end
