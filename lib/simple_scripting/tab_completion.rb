# frozen_string_literal: true

require_relative 'tab_completion/commandline_processor'

module SimpleScripting

  # The naming of each of the the commandline units is not standard, therefore we establish the
  # following arbitrary, but consistent, naming:
  #
  #     executable --option option_parameter argument
  #
  # The commandline is divided into words, as Bash would split them. All the words, except the
  # executable, compose an array that we call `argv` (as Ruby would do).
  #
  # We define each {option name => value} or {argument name => value} as `pair`.
  #
  # In the context of a pair, each pair is composed of a `key` and a `value`.
  #
  class TabCompletion

    def initialize(switches_definition, output: $stdout)
      @switches_definition = switches_definition
      @output = output
    end

    # Currently, any completion suffix is ignored and stripped.
    #
    def complete(execution_target, source_commandline=ENV.fetch('COMP_LINE'), cursor_position=ENV.fetch('COMP_POINT').to_i)
      commandline_processor = CommandlineProcessor.process_commandline(source_commandline, cursor_position, @switches_definition)

      if commandline_processor.completing_an_option?
        complete_option(commandline_processor, execution_target)
      elsif commandline_processor.parsing_error?
        return
      else # completing_a_value?
        complete_value(commandline_processor, execution_target)
      end
    end

    private

    #############################################
    # Completion!
    #############################################

    def complete_option(commandline_processor, execution_target)
      all_switches = @switches_definition.select { |definition| definition.is_a?(Array) }.map { |definition| definition[1][/^--\S+/] }

      matching_switches = all_switches.select { |switch| switch.start_with?(commandline_processor.completing_word_prefix) }

      output_entries(matching_switches)
    end

    def complete_value(commandline_processor, execution_target)
      key, value_prefix, value_suffix, other_pairs = commandline_processor.parsed_pairs

      selected_entries = execution_target.send(key, value_prefix, value_suffix, other_pairs)

      output_entries(selected_entries)
    end

    #############################################
    # Helpers
    #############################################

    def output_entries(entries)
      @output.print entries.join("\n")
    end
  end

end
