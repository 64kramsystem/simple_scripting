[![Build Status][BS img]](https://travis-ci.org/saveriomiroddi/simple_optparse)

Simple Option Parser
====================

SOP is a library which acts as frontend to the standard Option Parser library (`optparse`), giving a very convenient format for specifying the arguments, along with automatic help.

SOP is very useful for people who frequently write small scripts (eg. devops) and want to handle options parsing in a compact and automated way.

This is an example:

    decode_argv(
      ['-s', '--only-scheduled-days',     'Only print scheduled days'                           ],
      ['-d', '--print-defaults TEMPLATE', 'Print the default activities from the named template'],
      'schedule',
      '[weeks]',
      long_help: LONG_HELP
    )

This snippet:

- optionally accepts the `-s`/`--only-scheduled-days` switch, interpreting it as boolean,
- optionally accepts the `-d`/`--print-defaults` switch, interpreting it as string,
- requires the `schedule` argument,
- optionally accepts the `weeks` argument,
- automatically adds the `-h` and `--help` switches,
- when the help is invoked, it prints all the options, and `LONG_HELP`,
- if invalid parameters are passed (eg. too many), the help is printed.

it generates a result like:

    {
      only_scheduled_days: true,
      print_defaults:      'my_defaults',
      schedule:            'schedule.txt',
      weeks:               '3',
    }

and provides the help:

    ARGS: <schedule> [<weeks>]

    Usage: tmpfile [options]
        -s, --only-scheduled-days        Only print scheduled days
        -d, --print-defaults TEMPLATE    Print the default activities from the named template
        -h, --help                       Help

    << Here starts the provided long help... >>


Status
------

This library is work in progress.

I've been using this library in almost all my scripts for years, but I need to convert it to a library, and fix one bug.

The expected release is July 2017.

[BS img]: https://travis-ci.org/saveriomiroddi/simple_optparse.svg?branch=master
