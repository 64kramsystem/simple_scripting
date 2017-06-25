require_relative 'configuration/value'

require 'ostruct'
require 'parseconfig'

module SimpleScripting

  module Configuration

    extend self

    def load(config_file: default_config_file, passwords_key: nil)
      configuration = ParseConfig.new(config_file)

      convert_to_cool_format(OpenStruct.new, configuration.params, passwords_key)
    end

    private

    def default_config_file
      base_config_filename = '.' + File.basename($PROGRAM_NAME).chomp('.rb')

      File.expand_path(base_config_filename, '~')
    end

    # Performs two conversions:
    #
    # 1. the configuration as a whole is converted to an OpenStruct
    # 2. the values are converted to SimpleScripting::Configuration::Value
    #
    def convert_to_cool_format(result_node, configuration_node, encryption_key)
      configuration_node.each do |key, value|
        if value.is_a?(Hash)
          result_node[key] = OpenStruct.new
          convert_to_cool_format(result_node[key], value, encryption_key)
        else
          result_node[key] = Value.new(value, encryption_key)
        end
      end

      result_node
    end

  end

end
