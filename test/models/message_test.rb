require "test_helper"

class MessageTest < ActiveSupport::TestCase
  test "calculates cost based on token usage" do
    message = Message.new(
      chat: chats(:one),
      role: "assistant",
      content: "Test",
      input_tokens: 1000,
      output_tokens: 500,
      model: models(:gpt4)
    )

    message.save!

    assert message.cost > 0
  end
end
