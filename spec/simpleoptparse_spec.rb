require_relative '../lib/simpleoptparse.rb'

require 'stringio'

describe SimpleOptParse do

  let(:output_buffer) do
    StringIO.new
  end

  describe 'Basic functionality' do

    let(:decoder_params) {[
      ['-a'                                        ],
      ['-b',                     '"-b" description'],
      ['-c', '--c-switch'                          ],
      ['-d', '--d-switch',       '"-d" description'],
      ['-e', '--e-switch VALUE'                    ],
      ['-f', '--f-switch VALUE', '"-f" description'],
      'mandatory',
      '[optional]',
      long_help: 'This is the long help!',
      output:     output_buffer,
    ]}

    it 'should implement the help' do
      decoder_params.last[:arguments] = ['-h']

      described_class.decode_argv(*decoder_params)

      expected_output = %Q{\
Usage: rspec [options] <mandatory> [<optional>]
    -a
    -b                               "-b" description
    -c, --c-switch
    -d, --d-switch                   "-d" description
    -e, --e-switch VALUE
    -f, --f-switch VALUE             "-f" description
    -h, --help                       Help

This is the long help!
}

      expect(output_buffer.string).to eql(expected_output)
    end

    it "should implement basic switches and arguments (all set)" do
      decoder_params.last[:arguments] = ['-a', '-b', '-c', '-d', '-ev_swt', '-fv_swt', 'm_arg', 'o_arg']

      actual_result = described_class.decode_argv(*decoder_params)

      expected_result = {
        a:          true,
        b:          true,
        c_switch:   true,
        d_switch:   true,
        e_switch:   'v_swt',
        f_switch:   'v_swt',
        mandatory:  'm_arg',
        optional:   'o_arg',
      }

      expect(actual_result).to eql(expected_result)
    end

    it "should implement basic switches and arguments (no optional argument)" do
      decoder_params.last[:arguments] = ['m_arg']

      actual_result = described_class.decode_argv(*decoder_params)

      expected_result = {
        mandatory: 'm_arg',
      }

      expect(actual_result).to eql(expected_result)
    end

  end

  describe 'Varargs' do

    describe '(mandatory)' do

      let(:decoder_params) {[
        '*varargs',
        output:     output_buffer,
      ]}

      it "should be decoded" do
        decoder_params.last[:arguments] = ['varval1', 'varval2']

        actual_result = described_class.decode_argv(*decoder_params)

        expected_result = {
          varargs:   ['varval1', 'varval2'],
        }

        expect(actual_result).to eql(expected_result)
      end

      it "should exit when they are not specified" do
        decoder_params.last[:arguments] = []

        actual_result = described_class.decode_argv(*decoder_params)

        expected_result = nil

        expect(actual_result).to eql(expected_result)
      end

    end

    describe '(optional)' do

      let(:decoder_params) {[
        '[*varargs]',
        output:     output_buffer,
      ]}

      it "should be decoded" do
        decoder_params.last[:arguments] = ['varval1', 'varval2']

        actual_result = described_class.decode_argv(*decoder_params)

        expected_result = {
          varargs:   ['varval1', 'varval2'],
        }

        expect(actual_result).to eql(expected_result)
      end

      it "should be allowed not to be specified" do
        decoder_params.last[:arguments] = []

        actual_result = described_class.decode_argv(*decoder_params)

        expected_result = {
          varargs:   [],
        }

        expect(actual_result).to eql(expected_result)
      end

    end

  end

  describe 'Multiple commands' do

    it 'should be decoded'

  end

end
