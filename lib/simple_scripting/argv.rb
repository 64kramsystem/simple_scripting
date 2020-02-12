require 'optparse'

module SimpleScripting

  module Argv

    # The fact that the following errors don't descend from OptionParser::InvalidOption is somewhat
    # annoying, however, there should be no practical problem.
    #
    class ArgumentError < StandardError; end

    class InvalidCommand < StandardError

      attr_reader :valid_commands

      def initialize(message, valid_commands)
        super(message)
        @valid_commands = valid_commands
      end

    end

    class ExitWithCommandsHelpPrinting < Struct.new(:commands_definition)
      # Note that :long_help is not used.
      def print_help(output, long_help)
        output.puts "Valid commands:", "", "  " + commands_definition.keys.join(', ')
      end
    end

    class ExitWithArgumentsHelpPrinting < Struct.new(:commands_stack, :args, :parser_opts_copy)
      def print_help(output, long_help)
        parser_opts_help = parser_opts_copy.to_s

        if commands_stack.size > 0
          parser_opts_help = parser_opts_help.sub!('[options]', commands_stack.join(' ') + ' [options]')
        end

        if args.size > 0
          args_display = args.map { |name, mandatory| mandatory ? "<#{ name }>" : "[<#{ name }>]" }.join(' ')
          parser_opts_help = parser_opts_help.sub!(/^(Usage: .*)/) { |text| "#{text} #{args_display}" }
        end

        output.puts parser_opts_help
        output.puts "", long_help if long_help
      end
    end

    extend self

    def decode(*definition_and_options)
      params_definition, options = decode_definition_and_options(definition_and_options)

      arguments = options.fetch(:arguments, ARGV)
      long_help = options[:long_help]
      auto_help = options.fetch(:auto_help, true)
      output    = options.fetch(:output, $stdout)
      raise_errors = options.fetch(:raise_errors, false)

      # WATCH OUT! @long_help can also be set in :decode_command!. See issue #17.
      #
      @long_help = long_help

      exit_data = catch(:exit) do
        if params_definition.first.is_a?(Hash)
          return decode_command!(params_definition, arguments, auto_help)
        else
          return decode_arguments!(params_definition, arguments, auto_help)
        end
      end

      exit_data.print_help(output, @long_help)

      nil # to be used with the 'decode(...) || exit' pattern
    rescue SimpleScripting::Argv::ArgumentError, OptionParser::InvalidOption => error
      raise if raise_errors
        
      output.puts "Command error!: #{error.message}"
    rescue SimpleScripting::Argv::InvalidCommand => error
      raise if raise_errors

      output.puts <<~MESSAGE
        Command error!: #{error.message}"

        Valid commands: #{error.valid_commands.join(", ")}
      MESSAGE
    ensure
      @long_help = nil
    end

    private

    # This is trivial to define with named arguments, however, Ruby 2.6 removed the support for
    # mixing strings and symbols as argument keys, so we're forced to perform manual decoding.
    # The complexity of this code supports the rationale for the removal of the functionality.
    #
    def decode_definition_and_options(definition_and_options)
      # Only a hash (commands)
      if definition_and_options.size == 1 && definition_and_options.first.is_a?(Hash)
        options = definition_and_options.first.each_with_object({}) do |(key, value), current_options|
          current_options[key] = definition_and_options.first.delete(key) if key.is_a?(Symbol)
        end

        # If there is an empty hash left, we remove it, so it's not considered commands.
        #
        definition_and_options = [] if definition_and_options.first.empty?
      # Options passed
      elsif definition_and_options.last.is_a?(Hash)
        options = definition_and_options.pop
      # No options passed
      else
        options = {}
      end

      [definition_and_options, options]
    end

    # MAIN CASES ###########################################

    # Input params_definition for a non-nested case:
    #
    #   [{"command1"=>["arg1", {:long_help=>"This is the long help."}], "command2"=>["arg2"]}]
    #
    def decode_command!(params_definition, arguments, auto_help, commands_stack=[])
      commands_definition = params_definition.first

      # Set the `command` variable only after; in the case where we print the help, this variable
      # must be unset.
      #
      command_for_check = arguments.shift

      # Note that `--help` is baked into OptParse, so without a workaround, we need to always include
      # it.
      #
      if command_for_check == '-h' || command_for_check == '--help'
        if auto_help
          throw :exit, ExitWithCommandsHelpPrinting.new(commands_definition)
        else
          # This is tricky. Since the common behavior of `--help` is to trigger an unconditional
          # help, it's not clear what to do with other tokens. For simplicity, we just return
          # this flag.
          #
          return { help: true }
        end
      end

      command = command_for_check

      raise InvalidCommand.new("Missing command!", commands_definition.keys) if command.nil?

      command_params_definition = commands_definition[command]

      case command_params_definition
      when nil
        raise InvalidCommand.new("Invalid command: #{command}", commands_definition.keys)
      when Hash
        commands_stack << command

        # Nested case! Decode recursively
        #
        decode_command!([command_params_definition], arguments, auto_help, commands_stack)
      else
        commands_stack << command

        if command_params_definition.last.is_a?(Hash)
          internal_params = command_params_definition.pop # only long_help is here, if present
          @long_help = internal_params.delete(:long_help)
        end

        [
          compose_returned_commands(commands_stack),
          decode_arguments!(command_params_definition, arguments, auto_help, commands_stack),
        ]
      end
    end

    def decode_arguments!(params_definition, arg_values, auto_help, commands_stack=[])
      result           = {}
      parser_opts_copy = nil  # not available outside the block
      arg_definitions  = {}   # { 'name' => mandatory? }

      OptionParser.new do |parser_opts|
        params_definition.each do |param_definition|
          case param_definition
          when Array
            process_option_definition!(param_definition, parser_opts, result)
          when String
            process_argument_definition!(param_definition, arg_definitions)
          else
            # This is an error in the params definition, so it doesn't follow the user error/help
            # workflow.
            #
            raise "Unrecognized value: #{param_definition}"
          end
        end

        # See --help note in :decode_command!.
        #
        parser_opts.on('-h', '--help', 'Help') do
          if auto_help
            throw :exit, ExitWithArgumentsHelpPrinting.new(commands_stack, arg_definitions, parser_opts_copy)
          else
            # Needs to be better handled. When help is required, generally, it trumps the
            # correctness of the rest of the options/arguments.
            #
            result[:help] = true
          end
        end

        parser_opts_copy = parser_opts
      end.parse!(arg_values)

      arg_definitions.each do |arg_name, arg_is_mandatory|
        if arg_name.to_s.start_with?('*')
          arg_name = arg_name.to_s[1..-1].to_sym
          process_varargs!(arg_values, result, commands_stack, arg_name, arg_is_mandatory)
        else
          process_regular_argument!(arg_values, result, commands_stack, arg_name, arg_is_mandatory)
        end
      end

      check_no_remaining_arguments(arg_values)

      result
    end

    # DEFINITIONS PROCESSING ###############################

    def process_option_definition!(param_definition, parser_opts, result)
      # Work on a copy; in at least one case (data type definition), we perform destructive
      # operations.
      #
      param_definition = param_definition.dup

      if param_definition[1] && param_definition[1].start_with?('--')
        raw_key, key_argument = param_definition[1].split(' ')
        key = raw_key[2 .. -1].tr('-', '_').to_sym

        if key_argument&.include?(',')
          param_definition.insert(2, Array)
        end
      else
        key = param_definition[0][1 .. -1].to_sym
      end

      parser_opts.on(*param_definition) do |value|
        result[key] = value || true
      end
    end

    def process_argument_definition!(param_definition, args)
      if param_definition.start_with?('[')
        arg_name = param_definition[1 .. -2].to_sym

        args[arg_name] = false
      else
        arg_name = param_definition.to_sym

        args[arg_name] = true
      end
    end

    def process_varargs!(arg_values, result, commands_stack, arg_name, arg_is_mandatory)
      raise ArgumentError.new("Missing mandatory argument(s)") if arg_is_mandatory && arg_values.empty?

      result[arg_name] = arg_values.dup
      arg_values.clear
    end

    def process_regular_argument!(arg_values, result, commands_stack, arg_name, arg_is_mandatory)
      if arg_values.empty?
        if arg_is_mandatory
          raise ArgumentError.new("Missing mandatory argument(s)")
        end
      else
        result[arg_name] = arg_values.shift
      end
    end

    def check_no_remaining_arguments(arg_values)
      raise ArgumentError.new("Too many arguments") if !arg_values.empty?
    end

    # HELPERS ##############################################

    def compose_returned_commands(commands_stack)
      commands_stack.join('.')
    end

  end

end
