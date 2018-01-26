require_relative '../../lib/simple_scripting/configuration.rb'

require 'tempfile'
require 'tmpdir'

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
mixed_multiple_paths_key=/tmp/bar:foo
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

      expect(configuration.mixed_multiple_paths_key.full_paths).to eql(['/tmp/bar', File.expand_path('foo', '~')])

      expect(configuration.encr_key.decrypted).to eql('encrypted_value')

      expect(configuration.group1.g_key).to eql('baz')
      expect(configuration.group1.g_key).to eql('baz')

      # Make sure the values are converted recursively
      expect(configuration.group2.g2_key.full_path).to eql(File.expand_path('bang', '~'))
    end
  end

  it "should create the configuration file if it doesn't exist" do
    temp_config_file = File.join(Dir.tmpdir, '.test_simple_scripting_config')

    File.delete(temp_config_file) if File.exists?(temp_config_file)

    begin
      described_class.load(config_file: temp_config_file)
    ensure
      File.delete(temp_config_file)
    end
  end

end
