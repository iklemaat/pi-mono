defmodule PiAi.Provider.OpenAITest do
  use ExUnit.Case, async: true
  alias PiAi.Message
  alias PiAi.Provider.OpenAI

  setup do
    bypass = Bypass.open()
    {:ok, bypass: bypass}
  end

  test "chat/2 correctly parses a successful response", %{bypass: bypass} do
    Bypass.expect(bypass, "POST", "/v1/chat/completions", fn conn ->
      Plug.Conn.put_resp_content_type(conn, "application/json")
      |> Plug.Conn.resp(200, ~s({
        "id": "chatcmpl-123",
        "object": "chat.completion",
        "created": 1677652288,
        "choices": [{
          "index": 0,
          "message": {
            "role": "assistant",
            "content": "Hello there, how may I assist you today?"
          },
          "finish_reason": "stop"
        }],
        "usage": {
          "prompt_tokens": 9,
          "completion_tokens": 12,
          "total_tokens": 21
        }
      }))
    end)

    messages = [
      %Message{role: :user, content: "Hello!"}
    ]

    base_url = "http://localhost:#{bypass.port}/v1/chat/completions"

    assert {:ok, %Message{} = response_msg} =
             OpenAI.chat(messages, api_key: "test_key", base_url: base_url)

    assert response_msg.role == :assistant
    assert response_msg.content == "Hello there, how may I assist you today?"
    assert response_msg.tool_calls == nil
  end

  test "chat/2 handles error responses", %{bypass: bypass} do
    Bypass.expect(bypass, "POST", "/v1/chat/completions", fn conn ->
      Plug.Conn.put_resp_content_type(conn, "application/json")
      |> Plug.Conn.resp(401, ~s({"error": {"message": "Invalid API Key"}}))
    end)

    messages = [
      %Message{role: :user, content: "Hello!"}
    ]

    base_url = "http://localhost:#{bypass.port}/v1/chat/completions"

    assert {:error, error_msg} =
             OpenAI.chat(messages, api_key: "invalid_key", base_url: base_url)

    assert error_msg =~ "API returned 401"
  end
end
