RubyLLM.configure do |config|
  # Initial default — overridden by Setting.reconfigure! after app loads
  config.default_model = "gpt-4.1-nano"
  config.use_new_acts_as = true
end
