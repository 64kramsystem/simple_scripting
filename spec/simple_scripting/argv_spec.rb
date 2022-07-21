require_relative '../../lib/simple_scripting/argv.rb'

require 'stringio'

module SimpleScripting
  describe Argv do
    let(:output_buffer) do
      StringIO.new
    end

    describe 'Basic functionality' do
      let(:decoder_params) {[
        ['-a'                                        ],
        ['-b',                     '"-b" description'],
        ['-c', '--c-switch VAL1,VAL2'                ],
        ['-d', '--d-switch',       '"-d" description'],
        ['-e', '--e-switch VALUE'                    ],
        ['-f', '--f-switch VALUE', '"-f" description'],
        'mandatory',
        '[optional]',
        long_help: 'This is the long help!',
        output:     output_buffer,
      ]}

      context 'help' do
        it 'should print help automatically by default' do
          decoder_params.last[:arguments] = ['-h']

          return_value = described_class.decode(*decoder_params)

          expected_output = <<~OUTPUT
            Usage: rspec [options] <mandatory> [<optional>]
                -a
                -b                               "-b" description
                -c, --c-switch VAL1,VAL2
                -d, --d-switch                   "-d" description
                -e, --e-switch VALUE
                -f, --f-switch VALUE             "-f" description
                -h, --help                       Help

            This is the long help!
          OUTPUT

          expect(output_buffer.string).to eql(expected_output)
          expect(return_value).to be(nil)
        end

        it 'should not interpret the --help argument, and not print the help, on auto_help: false' do
          decoder_params.last.merge!(
            arguments: ['--help', 'm_arg'],
            auto_help: false
          )

          actual_result = described_class.decode(*decoder_params)

          expected_result = {
            help: true,
            mandatory: 'm_arg',
          }

          expect(output_buffer.string).to eql('')
          expect(actual_result).to eql(expected_result)
        end

        it "should check all the options/arguments when --help is passed, raising an error when they're not correct" do
          decoder_params.last.merge!(
            arguments: ['--help'],
            auto_help: false,
            raise_errors: true,
          )

          expect {
            described_class.decode(*decoder_params)
          }.to raise_error(Argv::ArgumentError, "Missing mandatory argument(s)")
        end
      end # context 'help'

      it "should implement basic switches, with conversion, and arguments (all set)" do
        decoder_params.last[:arguments] = ['-a', '-b', '-c', 'a,b,c', '-d', '-ev_swt', '-fv_swt', 'm_arg', 'o_arg']

        actual_result = described_class.decode(*decoder_params)

        expected_result = {
          a:          true,
          b:          true,
          c_switch:   %w(a b c),
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

      context "booleans" do
        VALID_BOOLS = {
          'false' => false,
          'true'  => true,
        }

        INVALID_BOOLS = %w[falx FALSE TRUE]

        VALID_BOOLS.each do |user_value, decoded_value|
          it "should decode a #{decoded_value} value" do
            decoder_params = [
              ["-b", "--mybool VAL", TrueClass],
              output:     output_buffer,
              arguments: ['--mybool', 'false']
            ]

            actual_result = described_class.decode(*decoder_params)

            expected_result = {
              mybool: false
            }

            expect(actual_result).to eql(expected_result)
          end
        end # context "booleans"

        INVALID_BOOLS.each do |value|
          it "should raise an error on invalid bool #{value.inspect}" do
            decoder_params = [
              ["-b", "--mybool VAL", TrueClass],
              output:       output_buffer,
              arguments:    ['--mybool', value],
              raise_errors: true,
            ]

            expect {
              described_class.decode(*decoder_params)
            }.to raise_error(OptionParser::InvalidArgument)
          end
        end
      end

      context "multiple optional arguments" do
        let(:decoder_params) {[
          '[optional1]',
          '[optional2]',
          output:     output_buffer,
        ]}

        it "should correctly decode a single argument passed" do
          decoder_params.last[:arguments] = ['o_arg1']

          actual_result = described_class.decode(*decoder_params)

          expected_result = {
            optional1: 'o_arg1',
          }

          expect(actual_result).to eql(expected_result)
        end

        it "should correctly decode all arguments passed" do
          decoder_params.last[:arguments] = ['o_arg1', 'o_arg2']

          actual_result = described_class.decode(*decoder_params)

          expected_result = {
            optional1: 'o_arg1',
            optional2: 'o_arg2',
          }

          expect(actual_result).to eql(expected_result)
        end
      end

      context "error handling" do
        # All the other UTs use error raising, for convenience.
        it "should print the error, with a previx, by default, instead of raising an error" do
          decoder_params.last[:arguments] = []

          actual_result = described_class.decode(*decoder_params)

          # Returning nil is an important specification, as it's part of the Argv protocol of doing
          # so in case of problem/exit.
          expect(actual_result).to be(nil)

          expect(output_buffer.string).to eql("Command error!: Missing mandatory argument(s)\n")
        end

        it "should raise an error when mandatory arguments are missing" do
          decoder_params.last.merge!(
            arguments: [],
            raise_errors: true,
          )

          expect {
            described_class.decode(*decoder_params)
          }.to raise_error(Argv::ArgumentError, "Missing mandatory argument(s)")
        end

        it "should raise an error when there are too many arguments" do
          decoder_params.last.merge!(
            arguments: ['arg1', 'arg2', 'excessive_arg'],
            raise_errors: true,
          )

          expect {
            described_class.decode(*decoder_params)
          }.to raise_error(Argv::ArgumentError, "Too many arguments")
        end
      end # context "error handling"
    end # describe 'Basic functionality'

    describe 'Varargs' do
      describe '(mandatory)' do
        context 'as only parameter' do
          let(:decoder_params) {[
            '*varargs',
            output:     output_buffer,
            arguments:  ['varval1', 'varval2'],
          ]}

          it "should be decoded" do
            actual_result = described_class.decode(*decoder_params)

            expected_result = {
              varargs:   ['varval1', 'varval2'],
            }

            expect(actual_result).to eql(expected_result)
          end
        end

        context 'followed by varargs' do
          let(:decoder_params) {[
            'mandatory',
            '*varargs',
            output:     output_buffer,
            arguments:  ['mandval', 'varval1', 'varval2']
          ]}

          it "should be decoded" do
            actual_result = described_class.decode(*decoder_params)

            expected_result = {
              mandatory: 'mandval',
              varargs:   ['varval1', 'varval2'],
            }

            expect(actual_result).to eql(expected_result)
          end
        end

        context "error handling" do
          let(:decoder_params) {[
            '*varargs',
            output:     output_buffer,
            arguments:  [],
          ]}

          it "should raise an error when they are not specified" do
            decoder_params.last[:raise_errors] = true

            expect {
              described_class.decode(*decoder_params)
            }.to raise_error(Argv::ArgumentError, "Missing mandatory argument(s)")
          end
        end # context "error handling"
      end # describe '(mandatory)'

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
      end # describe '(optional)'
    end # describe 'Varargs'

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

        context "error handling" do
          it "should raise an error on invalid command" do
            decoder_params.merge!(
              arguments: ['pizza'],
              raise_errors: true,
            )

            expect {
              described_class.decode(decoder_params)
            }.to raise_error(an_instance_of(Argv::InvalidCommand).and having_attributes(
              message: "Invalid command: pizza",
              valid_commands: ["command1", "command2"],
            ))
          end

          it "should raise a specific error message on missing command" do
            decoder_params.merge!(
              arguments: [],
              raise_errors: true,
            )

            expect {
              described_class.decode(decoder_params)
            }.to raise_error(an_instance_of(Argv::InvalidCommand).and having_attributes(
              message: "Missing command!",
              valid_commands: ["command1", "command2"],
            ))
          end
        end # context "error handling"

        context "help" do
          it 'should implement the commands help' do
            decoder_params[:arguments] = ['-h']

            described_class.decode(decoder_params)

            expected_output = <<~OUTPUT
              Valid commands:

                command1, command2
            OUTPUT

            expect(output_buffer.string).to eql(expected_output)
          end

          it "should display the command given command's help" do
            decoder_params[:arguments] = ['command1', '-h']

            described_class.decode(decoder_params)

            expected_output = <<~OUTPUT
              Usage: rspec command1 [options] <arg1>
                  -h, --help                       Help

              This is the long help.
            OUTPUT

            expect(output_buffer.string).to eql(expected_output)
          end

          context 'auto_help: false' do
            it 'should not interpret the --help argument, and not print the help' do
              decoder_params.merge!(
                arguments: ['-h'],
                auto_help: false,
              )

              actual_result = described_class.decode(decoder_params)

              expected_result = {
                help: true,
              }

              expect(actual_result).to eql(expected_result)
            end

            it 'should ignore and not return all the other arguments' do
              decoder_params.merge!(
                arguments: ['-h', 'pizza'],
                auto_help: false,
              )

              actual_result = described_class.decode(decoder_params)

              expected_result = {
                help: true,
              }

              expect(actual_result).to eql(expected_result)
            end
          end # context 'auto_help: false'
        end # context 'help'
      end # describe 'regular case'

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

          expected_output = <<~OUTPUT
            Valid commands:

              nested1a, nested1b
          OUTPUT

          expect(output_buffer.string).to eql(expected_output)
        end

        it 'should print the nested1a help, and long help' do
          decoder_params[:arguments] = ['command1', 'nested1a', '-h']

          actual_result = described_class.decode(decoder_params)

          expected_output = <<~OUTPUT
            Usage: rspec command1 nested1a [options] <arg1>
                -h, --help                       Help

            nested1a long help.
          OUTPUT

          expect(output_buffer.string).to eql(expected_output)
        end
      end # describe 'Nested commands'
    end # describe 'Commands'

    # Special case.
    #
    describe 'No definitions given' do
      let(:decoder_params) {{
        output:     output_buffer,
      }}

      it 'should avoid options being interpreted as definitions' do
        decoder_params[:arguments] = ['pizza']
        decoder_params[:raise_errors] = true

        expect {
          described_class.decode(decoder_params)
        }.to raise_error(Argv::ArgumentError, "Too many arguments")
      end
    end # describe 'No definitions given'
  end # describe Argv
end # module SimpleScripting
