require_relative 'configuration/value'

require 'fileutils'
require 'ostruct'
require 'parseconfig'

module SimpleScripting

  module Configuration

    extend self

    # `required`: list of strings. this currently support only keys outside a group; group names
    #             are not considered keys.
    #
    def load(config_file: default_config_file, passwords_key: nil, required: [])
      create_empty_file(config_file) if !File.exist?(config_file)

      params = ParseConfig.new(config_file).params

      local_config_file = "#{config_file}.local"

      if File.exist?(local_config_file)
        local_params = ParseConfig.new(local_config_file).params

        params = params.merge(local_params) do |_, value, local_value|
          value.is_a?(Hash) && local_value.is_a?(Hash) ? value.merge(local_value) : local_value
        end
      end

      enforce_required_keys(params, required)

      convert_to_cool_format(OpenStruct.new, params, passwords_key)
    end

    private

    def create_empty_file(file)
      FileUtils.touch(file)
    end

    def default_config_file
      base_config_filename = '.' + File.basename($PROGRAM_NAME).chomp('.rb')

      File.expand_path(base_config_filename, '~')
    end

    def enforce_required_keys(configuration, required)
      missing_keys = required - configuration.select { |key, value| !value.is_a?(Hash) }.keys

      raise "Missing required configuration key(s): #{missing_keys.join(', ')}" if !missing_keys.empty?
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
