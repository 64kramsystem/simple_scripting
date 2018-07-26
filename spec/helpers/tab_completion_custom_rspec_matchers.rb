require 'stringio'

# Custom matchers for the tab completion test suite.
#
# Require :subject and :output_buffer to be defined/accessible.
#
# The matchers are simplistic (but still adequate); the (most) appropriate choice would be
# [diffable matchers](https://relishapp.com/rspec/rspec-expectations/v/3-6/docs/custom-matchers/define-diffable-matcher)
#
# Note that the semantic of the expected value is different from the standard rspec one, since we
# process it, therefore, we need to use intermediate instance variables.
#
module TabCompletionCustomRSpecMatchers

  extend RSpec::Matchers::DSL

  # Doesn't matter in this context.
  #
  PHONY_EXECUTABLE = '/path/to/executable'

  matcher :complete_with do |expected_entries|
    match do |symbolic_commandline_options|
      commandline = "#{PHONY_EXECUTABLE} #{symbolic_commandline_options}"
      cursor_position = commandline.index("<tab>")
      commandline = commandline.sub("<tab>", "")

      subject.complete(execution_target, commandline, cursor_position)

      @actual_output = output_buffer.string
      expected_output = expected_entries.join("\n")

      expect(@actual_output).to eql(expected_output)
    end

    failure_message do |actual|
      actual_entries = @actual_output.split("\n")

      "#{actual} listed #{actual_entries} instead of #{expected}"
    end
  end

  matcher :not_complete do
    match do |symbolic_commandline_options|
      expect(symbolic_commandline_options).to complete_with([])
    end

    failure_message do |actual|
      @actual_output = output_buffer.string
      actual_entries = @actual_output.split("\n")

      "#{actual} listed #{actual_entries} instead of no entries"
    end
  end

end # TabCompletionCustomRSpecMatchers
