require 'optparse'

module SimpleOptParse

  extend self

  def decode_argv(*params_definition, arguments: ARGV, long_help: nil, output: $stdout)
    # If the param is a Hash, we have multiple commands. We check and if the command is correct,
    # recursively call the function with the specific parameters.
    #
    if params_definition.first.is_a?(Hash)
      command = arguments.shift
      commands_definition = params_definition.first

      if command == '-h' || command == '--help'
        print_optparse_commands_help(commands_definition, output: output, is_error: false)
        output == $stdout ? exit : return
      end

      command_params_definition = commands_definition[command]

      if command_params_definition.nil?
        print_optparse_commands_help(commands_definition, output: output, is_error: true)
        output == $stdout ? exit : return
      else
        return [command, decode_argv(*command_params_definition, arguments: arguments, output: output)]
      end
    end

    result           = {}
    parser_opts_ref  = nil  # not available outside the block
    args             = {}   # { 'name' => mandatory? }

    OptionParser.new do | parser_opts |
      params_definition.each do | param_definition |
        case param_definition
        when Array
          if param_definition[1] && param_definition[1].start_with?('--')
            key = param_definition[1].split(' ')[0][2 .. -1].gsub('-', '_').to_sym
          else
            key = param_definition[0][1 .. -1].to_sym
          end

          parser_opts.on(*param_definition) do |value|
            result[key] = value || true
          end
        when String
          if param_definition.start_with?('[')
            arg_name = param_definition[1 .. -2].to_sym

            args[arg_name] = false
          else
            arg_name = param_definition.to_sym

            args[arg_name] = true
          end
        else
          raise "Unrecognized value: #{param_definition}"
        end
      end

      parser_opts.on( '-h', '--help', 'Help' ) do
        print_optparse_help( parser_opts, args, long_help, output )
        output == $stdout ? exit : return
      end

      parser_opts_ref = parser_opts
    end.parse!(arguments)

    first_arg_name = args.keys.first.to_s

    # Varargs
    if first_arg_name.start_with?('*')
      # Mandatory?
      if args.fetch(first_arg_name.to_sym)
        if arguments.empty?
          print_optparse_help( parser_opts_ref, args, long_help, output )
          output == $stdout ? exit : return
        else
          name = args.keys.first[ 1 .. - 1 ].to_sym

          result[ name ] = arguments
        end
      # Optional
      else
        name = args.keys.first[ 1 .. - 1 ].to_sym

        result[ name ] = arguments
      end
    else
      min_args_size = args.count { | name, mandatory | mandatory }

      case arguments.size
      when (min_args_size .. args.size)
        arguments.zip(args) do | value, (name, mandatory) |
          result[name] = value
        end
      else
        print_optparse_help(parser_opts_ref, args, long_help, output)
        output == $stdout ? exit : return
      end
    end

    result
  end

  private

  def print_optparse_commands_help(commands_definition, output:, is_error:)
    output.print "Invalid command. " if is_error
    output.puts "Valid commands:", "", "  " + commands_definition.keys.join(', ')
  end

  def print_optparse_help(parser_opts, args, long_help, output)
    args_display = args.map { | name, mandatory | mandatory ? "<#{ name }>" : "[<#{ name }>]" }.join(' ')
    parser_opts_help = parser_opts.to_s.sub!(/^(Usage: .*)/, "\\1 #{args_display}")

    output.puts parser_opts_help
    output.puts "", long_help if long_help
  end

end
