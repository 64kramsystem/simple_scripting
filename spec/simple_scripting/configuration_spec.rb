require_relative '../../lib/simple_scripting/configuration.rb'

require 'tempfile'

module SimpleScripting::ConfigurationSpecHelper

  def with_tempfile(config_content)
    tempfile = Tempfile.new('ss_config_test')
    tempfile.write(config_content)
    tempfile.close

    yield(tempfile.path)
  ensure
    tempfile.unlink
  end

end

describe SimpleScripting::Configuration do

  include SimpleScripting::ConfigurationSpecHelper

  let(:configuration_text) {"
abspath_key=/tmp/bar
relpath_key=foo
encr_key=uTxllKRD2S+IH92oi30luwu0JIqp7kKA

[group1]
g_key=baz

[group2]
g2_key=bang
  "}

  it 'should parse a configuration' do
    with_tempfile(configuration_text) do |config_file|
      configuration = described_class.load(config_file: config_file, passwords_key: 'encryption_key')

      expect(configuration.abspath_key.full_path).to eql('/tmp/bar')

      expect(configuration.relpath_key.full_path).to eql(File.expand_path('foo', '~'))

      expect(configuration.encr_key.decrypted).to eql('encrypted_value')

      expect(configuration.group1.g_key).to eql('baz')
      expect(configuration.group1.g_key).to eql('baz')

      # Make sure the values are converted recursively
      expect(configuration.group2.g2_key.full_path).to eql(File.expand_path('bang', '~'))
    end
  end

end
