require "test_helper"

class MessageTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

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

  test "broadcasts create using messages/message partial regardless of role" do
    %w[user assistant system tool].each do |role|
      message = Message.new(chat: chats(:one), role: role, content: "hi")

      assert_nothing_raised do
        perform_enqueued_jobs { message.save! }
      end
    end
  end
end
