require 'optparse'

module SimpleScripting

  module Argv

    # Currently, due to exception handling and message printing being treated the same, there is
    # ambiguity in the following classes being an exception or just a transport class. This will
    # we clarified once the automatic help is made optional.
    #
    class ExitOnCommand < Struct.new(:commands_definition, :error_message)
      # Note that :long_help is not used.
      def print_help(output, long_help)
        output.print "#{error_message}. " if error_message
        output.puts "Valid commands:", "", "  " + commands_definition.keys.join(', ')
      end
    end

    class ExitOnArguments < Struct.new(:commands_stack, :args, :parser_opts_copy, :error_message)
      def print_help(output, long_help)
        output.puts "#{error_message}.", "" if error_message

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

    def decode(*params_definition, arguments: ARGV, long_help: nil, output: $stdout)
      # WATCH OUT! @long_help can also be set in :decode_command!. See issue #17.
      #
      @long_help = long_help

      exit_data = catch(:exit) do
        if params_definition.first.is_a?(Hash)
          return decode_command!(params_definition, arguments)
        else
          return decode_arguments!(params_definition, arguments)
        end
      end

      exit_data.print_help(output, @long_help)

      nil # to be used with the 'decode(...) || exit' pattern
    ensure
      @long_help = nil
    end

    private

    # MAIN CASES ###########################################

    # Input params_definition for a non-nested case:
    #
    #   [{"command1"=>["arg1", {:long_help=>"This is the long help."}], "command2"=>["arg2"]}]
    #
    def decode_command!(params_definition, arguments, commands_stack=[])
      commands_definition = params_definition.first

      # Set the `command` variable only after; in the case where we print the help, this variable
      # must be unset.
      #
      command_for_check = arguments.shift

      if command_for_check == '-h' || command_for_check == '--help'
        throw :exit, ExitOnCommand.new(commands_definition)
      end

      command = command_for_check
      command_params_definition = commands_definition[command]

      case command_params_definition
      when nil
        throw :exit, ExitOnCommand.new(commands_definition, "Invalid command")
      when Hash
        commands_stack << command

        # Nested case! Decode recursively
        #
        decode_command!([command_params_definition], arguments, commands_stack)
      else
        commands_stack << command

        if command_params_definition.last.is_a?(Hash)
          internal_params = command_params_definition.pop # only long_help is here, if present
          @long_help = internal_params.delete(:long_help)
        end

        [
          compose_returned_commands(commands_stack),
          decode_arguments!(command_params_definition, arguments, commands_stack),
        ]
      end
    end

    def decode_arguments!(params_definition, arguments, commands_stack=[])
      result           = {}
      parser_opts_copy = nil  # not available outside the block
      args             = {}   # { 'name' => mandatory? }

      OptionParser.new do |parser_opts|
        params_definition.each do |param_definition|
          case param_definition
          when Array
            process_option_definition!(param_definition, parser_opts, result)
          when String
            process_argument_definition!(param_definition, args)
          else
            # This is an error in the params definition, so it doesn't follow the user error/help
            # workflow.
            #
            raise "Unrecognized value: #{param_definition}"
          end
        end

        parser_opts.on('-h', '--help', 'Help') do
          throw :exit, ExitOnArguments.new(commands_stack, args, parser_opts_copy)
        end

        parser_opts_copy = parser_opts
      end.parse!(arguments)

      first_arg_name = args.keys.first.to_s

      if first_arg_name.start_with?('*')
        process_varargs!(arguments, result, commands_stack, args, parser_opts_copy)
      else
        process_regular_argument!(arguments, result, commands_stack, args, parser_opts_copy)
      end

      result
    end

    # DEFINITIONS PROCESSING ###############################

    def process_option_definition!(param_definition, parser_opts, result)
      if param_definition[1] && param_definition[1].start_with?('--')
        key = param_definition[1].split(' ')[0][2 .. -1].tr('-', '_').to_sym
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

    def process_varargs!(arguments, result, commands_stack, args, parser_opts_copy)
      first_arg_name = args.keys.first.to_s

      # Mandatory argument
      if args.fetch(first_arg_name.to_sym)
        if arguments.empty?
          throw :exit, ExitOnArguments.new(commands_stack, args, parser_opts_copy, "Missing mandatory argument(s)")
        else
          name = args.keys.first[1..-1].to_sym

          result[name] = arguments
        end
      # Optional
      else
        name = args.keys.first[1..-1].to_sym

        result[name] = arguments
      end
    end

    def process_regular_argument!(arguments, result, commands_stack, args, parser_opts_copy)
      min_args_size = args.count { |_, mandatory| mandatory }

      if arguments.size < min_args_size
        throw :exit, ExitOnArguments.new(commands_stack, args, parser_opts_copy, "Missing mandatory argument(s)")
      elsif arguments.size > args.size
        throw :exit, ExitOnArguments.new(commands_stack, args, parser_opts_copy, "Too many arguments")
      else
        arguments.zip(args) do |value, (name, _)|
          result[name] = value
        end
      end
    end

    # HELPERS ##############################################

    def compose_returned_commands(commands_stack)
      commands_stack.join('.')
    end

  end

end
