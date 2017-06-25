require_relative '../../../lib/simple_scripting/configuration/value.rb'

describe SimpleScripting::Configuration::Value do

  # Encrypting won't yield constant values, as the IV is random, therefore, we test the full cycle.
  #
  it 'should encrypt and decrypt a value' do
    plaintext = 'encrypted_value'
    encryption_key = 'encryption_key'

    encrypted_value = described_class.new(plaintext, encryption_key).encrypted
    decrypted_value = described_class.new(encrypted_value, encryption_key).decrypted

    expect(decrypted_value).to eql(plaintext)
  end

end
