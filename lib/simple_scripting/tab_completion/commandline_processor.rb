# frozen_string_literal: true

require 'shellwords'

require_relative '../argv'

module SimpleScripting

  class TabCompletion

    class CommandlineProcessor < Struct.new(:processed_argv, :cursor_marker, :switches_definition, :escaped_dash)

      # Arbitrary; can be anything (except an empty string).
      BASE_CURSOR_MARKER = "<tab>"

      OPTIONS_TERMINATOR = "--"
      LONG_OPTIONS_PREFIX = "--"

      def self.process_commandline(source_commandline, cursor_position, switches_definition)
        # An input string with infinite "<tabN>" substrings will cause an infinite cycle (hehe).
        0.upto(Float::INFINITY) do |i|
          cursor_marker = BASE_CURSOR_MARKER.sub(">", "#{i}>")

          if !source_commandline.include?(cursor_marker)
            commandline_with_marker = source_commandline[0...cursor_position] + cursor_marker + source_commandline[cursor_position..-1].to_s

            # Remove the executable.
            processed_argv = Shellwords.split(commandline_with_marker)[1..-1]

            # Shellwords strips the backslash, losing the information that the word is a value, not
            # an option.
            #
            escaped_dash = commandline_with_marker.match?(/(?:\A|\s)\\-\S*#{Regexp.escape(cursor_marker)}/)

            return new(processed_argv, cursor_marker, switches_definition, escaped_dash)
          end
        end
      end

      # We're abstracted from the commandline, with this exception. This is because while an option
      # is being completed, the decoder would not recognize the key.
      #
      def completing_an_option?
        processed_argv[marked_word_position].start_with?(LONG_OPTIONS_PREFIX) && marked_word_position < options_terminator_position
      end

      def parsing_error?
        parse_argv.nil?
      end

      def completing_word_prefix
        word = processed_argv[marked_word_position]

        # Regex alternative: [/\A(.*?)#{cursor_marker}/m, 1]
        word[0, word.index(cursor_marker)]
      end

      # Returns key, value prefix (before marker), value suffix (after marker), other_pairs
      #
      def parsed_pairs
        parsed_pairs = parse_argv || raise("Parsing error")

        key, value = parsed_pairs.detect do |_, value|
          if value.is_a?(Array)
            value.any? { |entry| entry.include?(cursor_marker) }
          else
            !boolean?(value) && value.include?(cursor_marker)
          end
        end

        # Impossible case, unless there is a programmatic error.
        #
        key || raise("Guru meditation! (#{self.class}##{__method__}:#{__LINE__})")

        value = value.detect { |entry| entry.include?(cursor_marker) } if value.is_a?(Array)

        value_prefix, value_suffix = value.split(cursor_marker)

        value_prefix = "-#{value_prefix}" if escaped_dash

        parsed_pairs.delete(key)

        [key, value_prefix || "", value_suffix || "", parsed_pairs]
      end

      private

      def marked_word_position
        processed_argv.index { |word| word.include?(cursor_marker) }
      end

      # Returns Float::INFINITY when there is no options terminator.
      #
      def options_terminator_position
        processed_argv.index(OPTIONS_TERMINATOR) || Float::INFINITY
      end

      #############################################
      # Helpers
      #############################################

      def parse_argv
        # We need to convert all the arguments to optional, otherwise it's not possible to
        # autocomplete arguments when not all the mandatory ones are not typed yet, eg:
        #
        #   `my_command <tab>` with definition ['mand1', 'mand2']
        #
        adapted_switches_definition = switches_definition.dup

        adapted_switches_definition.each_with_index do |definition, i|
          adapted_switches_definition[i] = "[#{definition}]" if definition.is_a?(String) && !definition.start_with?('[')
        end

        adapted_argv = processed_argv.dup
        adapted_argv[marked_word_position] = adapted_argv[marked_word_position].delete_prefix("-") if escaped_dash

        SimpleScripting::Argv.decode(*adapted_switches_definition, arguments: adapted_argv, auto_help: false)
      rescue Argv::InvalidCommand, Argv::ArgumentError, OptionParser::InvalidOption
        # OptionParser::InvalidOption: see case "-O<tab>" in test suite.

        # return nil
      end

      # For the lulz.
      #
      def boolean?(value)
        !!value == value
      end

    end # CommandlineProcessor

  end # TabCompletion

end # SimpleScripting
