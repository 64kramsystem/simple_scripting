require 'openssl'
require 'base64'

module SimpleScripting

  module Configuration

    # The purpose of encryption in this library is just to avoid displaying passwords in
    # plaintext; it's not considered safe against attacks.
    #
    class Value < String

      ENCRYPTION_CIPHER = 'des3'

      def initialize(string, encryption_key = nil)
        super(string)

        if encryption_key
          @encryption_key = encryption_key + '*' * (24 - encryption_key.bytesize)
        end
      end

      def full_path
        start_with?('/') ? self : File.expand_path(self, '~')
      end

      def full_paths
        split(':').map { |value| self.class.new(value).full_path }
      end

      def decrypted
        raise "Encryption key not provided!" if @encryption_key.nil?

        ciphertext = Base64.decode64(self)

        cipher = OpenSSL::Cipher::Cipher.new(ENCRYPTION_CIPHER)
        cipher.decrypt

        cipher.key = @encryption_key

        cipher.iv = ciphertext[0...cipher.iv_len]
        plaintext = cipher.update(ciphertext[cipher.iv_len..-1]) + cipher.final

        plaintext
      end

      def encrypted
        cipher = OpenSSL::Cipher::Cipher.new(ENCRYPTION_CIPHER)
        cipher.encrypt

        iv = cipher.random_iv

        cipher.key = @encryption_key
        cipher.iv  = iv

        ciphertext = iv + cipher.update(self) + cipher.final

        Base64.encode64(ciphertext).rstrip
      end

    end

  end

end
