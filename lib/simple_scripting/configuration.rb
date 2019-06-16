require_relative 'configuration/value'

require 'fileutils'
require 'ostruct'
require 'parseconfig'

module SimpleScripting

  module Configuration

    extend self

    # A Struct whose members can be defined at any time, via `[key] = value`.
    # Missing member errors are friendly.
    #
    #===
    # This class has requirements which explain the peculiar nature:
    #
    # 1. it needs to be a Struct, not an OpenStruct, since nonexisting key invocations must raise
    #    an error;
    # 2. it's convenient for it to be an OpenStruct, since we don't want to define at instantiation
    #    time the members.
    #
    class ConfigurationStruct < OpenStruct
      def method_missing(method_name)
        raise "Key/group #{method_name.to_s.inspect} not found!"
      end
    end

    # `required`: list of strings. this currently support only keys outside a group; group names
    #             are not considered keys.
    #
    def load(config_file: default_config_file, passwords_key: nil, required: [])
      create_empty_file(config_file) if !File.exists?(config_file)

      configuration = ParseConfig.new(config_file)

      enforce_required_keys(configuration.params, required)

      convert_to_cool_format(ConfigurationStruct.new, configuration.params, passwords_key)
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
    # 1. the configuration as a whole is converted to a ConfigurationStruct
    # 2. the values are converted to SimpleScripting::Configuration::Value
    #
    def convert_to_cool_format(result_node, configuration_node, encryption_key)
      configuration_node.each do |key, value|
        if value.is_a?(Hash)
          result_node[key] = ConfigurationStruct.new
          convert_to_cool_format(result_node[key], value, encryption_key)
        else
          result_node[key] = Value.new(value, encryption_key)
        end
      end

      result_node
    end

  end

end
