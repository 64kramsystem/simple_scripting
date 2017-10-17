require_relative '../../lib/simple_scripting/argv.rb'

require 'stringio'

describe SimpleScripting::Argv do

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

      return_value = described_class.decode(*decoder_params)

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
      expect(return_value).to be(nil)
    end

    it "should implement basic switches and arguments (all set)" do
      decoder_params.last[:arguments] = ['-a', '-b', '-c', '-d', '-ev_swt', '-fv_swt', 'm_arg', 'o_arg']

      actual_result = described_class.decode(*decoder_params)

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

      actual_result = described_class.decode(*decoder_params)

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

        actual_result = described_class.decode(*decoder_params)

        expected_result = {
          varargs:   ['varval1', 'varval2'],
        }

        expect(actual_result).to eql(expected_result)
      end

      it "should exit when they are not specified" do
        decoder_params.last[:arguments] = []

        actual_result = described_class.decode(*decoder_params)

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

        actual_result = described_class.decode(*decoder_params)

        expected_result = {
          varargs:   ['varval1', 'varval2'],
        }

        expect(actual_result).to eql(expected_result)
      end

      it "should be allowed not to be specified" do
        decoder_params.last[:arguments] = []

        actual_result = described_class.decode(*decoder_params)

        expected_result = {
          varargs:   [],
        }

        expect(actual_result).to eql(expected_result)
      end

    end

  end

  describe 'Commands' do

    describe 'regular case' do

      let(:decoder_params) {{
        'command1' => [
          'arg1',
          long_help: 'This is the long help.'
        ],
        'command2' => [
          'arg2'
        ],
        output:     output_buffer,
      }}

      it 'should be decoded' do
        decoder_params[:arguments] = ['command1', 'value1']

        actual_result = described_class.decode(decoder_params)

        expected_result = ['command1', arg1: 'value1']

        expect(actual_result).to eql(expected_result)
      end

      it 'print a message on wrong command' do
        decoder_params[:arguments] = ['pizza']

        described_class.decode(decoder_params)

        expected_output = %Q{\
Invalid command. Valid commands:

  command1, command2
}

        expect(output_buffer.string).to eql(expected_output)
      end

      it 'should implement the commands help' do
        decoder_params[:arguments] = ['-h']

        described_class.decode(decoder_params)

        expected_output = %Q{\
Valid commands:

  command1, command2
}

        expect(output_buffer.string).to eql(expected_output)
      end

      it "should display the command given command's help" do
        decoder_params[:arguments] = ['command1', '-h']
$a = true
        described_class.decode(decoder_params)

        expected_output = %Q{\
Usage: rspec command1 [options] <arg1>
    -h, --help                       Help

This is the long help.
}

        expect(output_buffer.string).to eql(expected_output)
      end

    end

    describe 'Nested commands' do

      let(:decoder_params) {{
        'command1' => {
          'nested1a' => [
            'arg1',
            long_help: 'nested1a long help.'
          ],
          'nested1b' => [
            'arg1b'
          ],
        },
        'command2' => [
          'arg2'
        ],
        output:     output_buffer
      }}

      it 'should be decoded (two levels)' do
        decoder_params[:arguments] = ['command1', 'nested1a', 'value1']

        actual_result = described_class.decode(decoder_params)

        expected_result = ['command1.nested1a', arg1: 'value1']

        expect(actual_result).to eql(expected_result)
      end

      it 'should be decoded (one level)' do
        decoder_params[:arguments] = ['command2', 'value2']

        actual_result = described_class.decode(decoder_params)

        expected_result = ['command2', arg2: 'value2']

        expect(actual_result).to eql(expected_result)
      end

      it 'should print the command1 help' do
        decoder_params[:arguments] = ['command1', '-h']

        actual_result = described_class.decode(decoder_params)

        expected_output = "\
Valid commands:

  nested1a, nested1b
"

        expect(output_buffer.string).to eql(expected_output)
      end

      it 'should print the nested1a help, and long help' do
        decoder_params[:arguments] = ['command1', 'nested1a', '-h']

        actual_result = described_class.decode(decoder_params)

        expected_output = "\
Usage: rspec command1 nested1a [options] <arg1>
    -h, --help                       Help

nested1a long help.
"

        expect(output_buffer.string).to eql(expected_output)
      end
    end

    describe 'No argv case' do

      let(:decoder_params) {{
        output:     output_buffer,
      }}

      it 'should avoided options being interpreted as definitions' do
        decoder_params[:arguments] = ['pizza']

        actual_result = described_class.decode(decoder_params)

        expect(actual_result).to be(nil)
      end

    end

  end

end
