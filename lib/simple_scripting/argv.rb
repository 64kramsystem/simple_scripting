require 'optparse'

module SimpleScripting

  module Argv

    class ExitError < StandardError; end

    extend self

    def decode(*params_definition, arguments: ARGV, long_help: nil, output: $stdout)
      @long_help = long_help
      @output = output

      if params_definition.first.is_a?(Hash)
        decode_command!(params_definition, arguments)
      else
        decode_arguments!(params_definition, arguments, nil)
      end
    rescue ExitError
      exit if output == $stdout
    ensure
      # Clean up the instance variables.
      #
      # There is a balance to strike between instance variables, and local variables
      # passed around. One of the options, which is this case, is to set and instance
      # variables only these two, which are constant.

      @long_help = nil
      @output = nil
    end

    private

    # MAIN CASES ###########################################

    def decode_command!(params_definition, arguments)
      commands_definition = params_definition.first

      # Set the `command` variable only after; in the case where we print the help, this variable
      # must be unset.
      #
      command_for_check = arguments.shift

      if command_for_check == '-h' || command_for_check == '--help'
        print_optparse_commands_help(nil, commands_definition)
      end

      command = command_for_check
      command_params_definition = commands_definition[command]

      if command_params_definition.nil?
        print_optparse_commands_help(command, commands_definition)
      else
        [
          command,
          decode_arguments!(command_params_definition, arguments, command),
        ]
      end
    end

    def decode_arguments!(params_definition, arguments, command)
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
            raise "Unrecognized value: #{param_definition}"
          end
        end

        parser_opts.on('-h', '--help', 'Help') do
          print_optparse_arguments_help(command, args, parser_opts_copy)
        end

        parser_opts_copy = parser_opts
      end.parse!(arguments)

      first_arg_name = args.keys.first.to_s

      if first_arg_name.start_with?('*')
        process_varargs!(arguments, result, command, args, parser_opts_copy)
      else
        process_regular_argument!(arguments, result, command, args, parser_opts_copy)
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

    def process_varargs!(arguments, result, command, args, parser_opts_copy)
      first_arg_name = args.keys.first.to_s

      # Mandatory argument
      if args.fetch(first_arg_name.to_sym)
        if arguments.empty?
          print_optparse_arguments_help(command, args, parser_opts_copy)
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

    def process_regular_argument!(arguments, result, command, args, parser_opts_copy)
      min_args_size = args.count { |_, mandatory| mandatory }

      case arguments.size
      when (min_args_size .. args.size)
        arguments.zip(args) do |value, (name, _)|
          result[name] = value
        end
      else
        print_optparse_arguments_help(command, args, parser_opts_copy)
      end
    end

    # HELP #################################################

    def print_optparse_commands_help(command, commands_definition)
      @output.print "Invalid command. " if command
      @output.puts "Valid commands:", "", "  " + commands_definition.keys.join(', ')

      raise ExitError
    end

    def print_optparse_arguments_help(command, args, parser_opts_copy)
      parser_opts_help = parser_opts_copy.to_s

      if command
        parser_opts_help = parser_opts_help.sub!(/(\[options\])/, "#{command} \\1")
      end

      if args.size > 0
        args_display = args.map { |name, mandatory| mandatory ? "<#{ name }>" : "[<#{ name }>]" }.join(' ')
        parser_opts_help = parser_opts_help.sub!(/^(Usage: .*)/, "\\1 #{args_display}")
      end

      @output.puts parser_opts_help
      @output.puts "", @long_help if @long_help

      raise ExitError
    end

  end

end
