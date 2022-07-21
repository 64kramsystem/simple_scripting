# frozen_string_literal: true

require_relative '../../lib/simple_scripting/tab_completion.rb'

describe SimpleScripting::TabCompletion do
  include TabCompletionCustomRSpecMatchers

  let(:output_buffer) {
    StringIO.new
  }

  let(:switches_definition) {
    [
      ["-o", "--opt1 ARG"],
      ["-O", "--opt2"],
      "arg1",               # this and the following are internally converted to optional, as
      "arg2",               # according to the Argv spec, without brackets they are mandatory.
    ]
  }

  let(:execution_target) {
    # Simplistic implementation. In real world, regex are not to be used this way, for multiple
    # reasons.
    #
    Class.new do
      def opt1(prefix, suffix, context)
        %w(opt1v1 _opt1v2).select { |entry| entry =~ /^#{prefix}#{suffix}/ }
      end

      def arg1(prefix, suffix, context)
        # A value starting with space is valid.
        #
        ['arg1v1', 'arg1v2', '_arg1v3', ' _argv1spc'].select { |entry| entry =~ /^#{prefix}#{suffix}/ }
      end

      def arg2(prefix, suffix, context)
        # A value starting with minus is valid.
        #
        %w(arg2v1 arg2v2 --arg2v3).select { |entry| entry =~ /^#{prefix}#{suffix}/ }
      end
    end.new
  }

  subject { described_class.new(switches_definition, output: output_buffer) }

  context "with a correct configuration" do
    context "standard cases" do
      # Note that the conversion of mandatory to optional argument is defined by most of the cases.
      #
      STANDARD_CASES = {
        "<tab>"             => ["arg1v1", "arg1v2", "_arg1v3", " _argv1spc"],
        "a<tab>"            => %w(arg1v1 arg1v2),
        "--opt2 <tab>"      => ["arg1v1", "arg1v2", "_arg1v3", " _argv1spc"],
        "-- <tab>"          => ["arg1v1", "arg1v2", "_arg1v3", " _argv1spc"],

        "a <tab>"           => %w(arg2v1 arg2v2 --arg2v3),
        "a -- --<tab>"      => %w(--arg2v3),
        "-- --aaa <tab>"    => %w(arg2v1 arg2v2 --arg2v3),

        "--<tab>"           => %w(--opt1 --opt2),
        "--<tab> a"         => %w(--opt1 --opt2),
        "--<tab> -- a"      => %w(--opt1 --opt2),
        "--<tab> -- b"      => %w(--opt1 --opt2),
        "--<tab> --xyz"     => %w(--opt1 --opt2),
        "--opt1 <tab> a"    => %w(opt1v1 _opt1v2),
        "--opt1 o<tab> a"   => %w(opt1v1),

        "-o<tab>"           => %w(opt1v1 _opt1v2),
        "-o <tab>"          => %w(opt1v1 _opt1v2),
        "-o -O <tab>"       => ["arg1v1", "arg1v2", "_arg1v3", " _argv1spc"],
        "-O <tab>"          => ["arg1v1", "arg1v2", "_arg1v3", " _argv1spc"],
      }

      STANDARD_CASES.each do |symbolic_commandline_options, expected_entries|
        it "should output the entries for #{symbolic_commandline_options.inspect}" do
          expect(symbolic_commandline_options).to complete_with(expected_entries)
        end
      end
    end # context "standard cases"

    context "suffix management" do
      SUFFIX_CASES = {
        "arg1<tab>v"        => %w(arg1v1 arg1v2), # the execution target of the test suite doesn't
        "arg1<tab>x"        => %w(),              # ignore the suffix; programmer-defined

        "--o<tab>p"         => %w(--opt1 --opt2), # options ignore the suffix (like bash); can't be
        "--o<tab>x"         => %w(--opt1 --opt2), # currently changed by the programmer.
      }

      SUFFIX_CASES.each do |symbolic_commandline_options, expected_entries|
        it "should output the entries for #{symbolic_commandline_options.inspect}, ignoring the suffix" do
          expect(symbolic_commandline_options).to complete_with(expected_entries)
        end
      end
    end # context "suffix management"

    context "escaped cases" do
      ESCAPED_CASES = {
        "\ <tab>"           => [" _argv1spc"],
        '\-<tab>'           => %w(),                       # this is the result of typing `command "\-<tab>`
        'a \-<tab>'         => %w(--arg2v3),
      }

      ESCAPED_CASES.each do |symbolic_commandline_options, _|
        it "should output the entries for #{symbolic_commandline_options.inspect}"
      end
    end # context "escaped cases"

    it "should support multiple values for an option"

    it "should keep parsing also when --help is passed" do
      expect("--help a<tab>").to complete_with(%w(arg1v1 arg1v2))
    end
  end # context "with a correct configuration"

  context "with an incorrect configuration" do
    INCORRECT_CASES = [
      "a b <tab>",        # too many args
      "-O<tab>",          # no values for this option
    ]

    INCORRECT_CASES.each do |symbolic_commandline_options|
      it "should not output any entries for #{symbolic_commandline_options.inspect}" do
        expect(symbolic_commandline_options).to not_complete
      end
    end
  end # context "with an incorrect configuration"
end # describe SimpleScripting::TabCompletion
