defmodule PiAi.Message do
  @moduledoc """
  Defines the standard message structure used to communicate with LLMs.
  """

  @enforce_keys [:role, :content]
  defstruct [:role, :content, :name, :tool_calls, :tool_call_id]

  @type role :: :system | :user | :assistant | :tool
  @type t :: %__MODULE__{
          role: role(),
          content: String.t() | nil,
          name: String.t() | nil,
          tool_calls: list(map()) | nil,
          tool_call_id: String.t() | nil
        }
end
