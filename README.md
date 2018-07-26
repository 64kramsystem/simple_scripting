[![Gem Version][GV img]](https://rubygems.org/gems/simple_scripting)
[![Build Status][BS img]](https://travis-ci.org/saveriomiroddi/simple_scripting)
[![Code Climate][CC img]](https://codeclimate.com/github/saveriomiroddi/simple_scripting)
[![Coverage Status][CS img]](https://coveralls.io/r/saveriomiroddi/simple_scripting)

# SimpleScripting

`SimpleScripting` is a library composed of three modules (`TabCompletion`, `Argv` and `Configuration`) that simplify three common scripting tasks:

- writing autocompletion scripts
- implementing the commandline options parsing (and the related help)
- loading and decoding the configuration for the script/application

`SimpleScripting` is an interesting (and useful) exercise in design, aimed at finding the simplest and most expressive data/structures that accomplish the given task(s). For this reason, the library can be useful for people who frequently write small scripts (eg. devops or nerds).

## SimpleScripting::TabCompletion

`TabCompletion` makes trivial to define tab-completion for terminal commands on Linux/Mac systems; it's so easy that an example is much simpler than an explanation.

`TabCompletion` supports Bash, and Zsh (with `bashcompinit`).

### Example

Suppose we have the command:

```sh
open_project [-e|--with-editor EDITOR] <project_name>
```

We want to add tab completion both for the option and the project name. Easy!!

Install the gem (`simple_scripting`), then create this class (`/my/completion_scripts/open_project_completion.rb`):

```ruby
#!/usr/bin/env ruby

require 'simple_scripting/tab_completion'

class OpenProjectTabCompletion
  SYSTEM_EDITORS = `update-alternatives --list editor`.split("\n").map { |filename| File.basename(filename) }

  def with_editor(prefix, suffix, context)
    SYSTEM_EDITORS.grep /^#{prefix}/
  end

  def project_name(prefix, suffix, context)
    Dir["/my/home/my_projects/#{prefix}*"]
  end
end

if __FILE__ == $PROGRAM_NAME
  completion_definition = [
    ["-e", "--with-editor EDITOR"],
    'project_name'
  ]

  SimpleScripting::TabCompletion.new(completion_definition).complete(OpenProjectTabCompletion.new)
end
```

then chmod and register it:

```sh
$ chmod +x /my/completion_scripts/open_project_completion.rb
$ complete -C /my/completion_scripts/open_project_completion.rb -o default open_project
```

Done!

Now type the following, and get:

```sh
$ open_project g<tab>           # lists: "geet", "gitlab-ce", "gnome-terminal"
$ open_project --with-editor v  # lists: "vim.basic", "vim.tiny"
$ open_project --wi<tab>        # autocompletes "--with-editor"; this is built-in!
```

Happy completion!

### Zsh

`TabCompletion` on Zsh requires `bashcompinit`; add the following to your `~/.zshrc`:

```sh
autoload bashcompinit
bashcompinit
```

Note that a **recent version of Zsh is required**; the stock Ubuntu 16.04 version (5.1.1-1ubuntu2.2) has bug that breaks bash tab completion.

### More complex use cases

For a description of the more complex use cases, including edge cases and error handling, see the [wiki](https://github.com/saveriomiroddi/simple_scripting/wiki/SimpleScripting::TabCompletion-Guide).

## SimpleScripting::Argv

`Argv` is a module which acts as frontend to the standard Option Parser library (`optparse`), giving a very convenient format for specifying the arguments. `Argv` also generates the help.

This is a definition example:

    require 'simple_scripting/argv'

    result = SimpleScripting::Argv.decode(
      ['-s', '--only-scheduled-days',     'Only print scheduled days'                           ],
      ['-d', '--print-defaults TEMPLATE', 'Print the default activities from the named template'],
      'schedule',
      '[weeks]',
      long_help: 'This is the long help! It can span multiple lines.'
    ) || exit

which:

- optionally accepts the `-s`/`--only-scheduled-days` switch, interpreting it as boolean,
- optionally accepts the `-d`/`--print-defaults` switch, interpreting it as string,
- requires the `schedule` argument,
- optionally accepts the `weeks` argument,
- automatically adds the `-h` and `--help` switches,
- prints all the options and the long help if the help is invoked,
- exits with a descriptive error if invalid parameters are passed.

This is a sample result:

    {
      only_scheduled_days: true,
      print_defaults:      'my_defaults',
      schedule:            'schedule.txt',
      weeks:               '3',
    }

This is the corresponding help:

    Usage: tmpfile [options] <schedule> [<weeks>]
        -s, --only-scheduled-days        Only print scheduled days
        -d, --print-defaults TEMPLATE    Print the default activities from the named template
        -h, --help                       Help

    This is the long help! It can span multiple lines.

Commands are also supported (with unlimited depth), by using a hash:

    commands, result = SimpleScripting::Argv.decode(
      'pr' => {
        'create' => [
          'title',
          'description',
          long_help: 'This is the create PR command help.'
        ]
      },
      'issues' => {
        'list' => []
      }
    ) || exit

For the guide, see the [wiki page](https://github.com/saveriomiroddi/simple_scripting/wiki/SimpleScripting::Argv-Guide).

## SimpleScripting::Configuration

`Configuration` is a module which acts as frontend to the ParseConfig gem (`parseconfig`), giving compact access to the configuration and its values, and adding a few helpers for common tasks.

Say one writes a script (`foo_my_bar.rb`), with a corresponding (`$HOME/.foo_my_bar`) configuration, which contains:

    some_relative_file_path=foo
    some_absolute_file_path=/path/to/bar
    multiple_paths=foo:/path/to/bar
    my_password=uTxllKRD2S+IH92oi30luwu0JIqp7kKA

    [a_group]
    group_key=baz

This is the workflow and functionality offered by `Configuration`:

    require 'simple_scripting/configuration'

    # Picks up automatically the configuration file name, based on the calling program
    #
    configuration = SimpleScripting::Configuration.load(passwords_key: 'encryption_key')

    configuration.some_relative_file_path.full_path # '$HOME/foo'
    configuration.some_absolute_file_path           # '/path/to/bar'
    configuration.some_absolute_file_path.full_path # '/path/to/bar' (recognized as absolute)
    configuration.multiple_paths.full_paths         # ['$HOME/foo', '/path/to/bar']

    configuration.my_password.decrypted             # 'encrypted_value'

    configuration.a_group.group_key                 # 'baz'; also supports #full_path and #decrypted

### Encryption note

The purpose of encryption in this library is just to avoid displaying passwords in plaintext; it's not considered safe against attacks.

## Help

See the [wiki](https://github.com/saveriomiroddi/simple_scripting/wiki) for additional help.

[GV img]: https://badge.fury.io/rb/simple_scripting.png
[BS img]: https://travis-ci.org/saveriomiroddi/simple_scripting.svg?branch=master
[CC img]: https://codeclimate.com/github/saveriomiroddi/simple_scripting.png
[CS img]: https://coveralls.io/repos/saveriomiroddi/simple_scripting/badge.png?branch=master
