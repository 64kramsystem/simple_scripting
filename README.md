[![Build Status][BS img]](https://travis-ci.org/saveriomiroddi/simpleoptparse)

Simple Option Parser
====================

SOP is a library which acts as frontend to the standard Option Parser library (`optparse`), giving a very convenient format for specifying the arguments, along with automatic help.

SOP is very useful for people who frequently write small scripts (eg. devops) and want to handle options parsing in a compact and automated way.

This is a definition example:

    result = SimpleOptParse.decode_argv(
      ['-s', '--only-scheduled-days',     'Only print scheduled days'                           ],
      ['-d', '--print-defaults TEMPLATE', 'Print the default activities from the named template'],
      'schedule',
      '[weeks]',
      long_help: 'This is the long help! It can span multiple lines.'
    )

which:

- optionally accepts the `-s`/`--only-scheduled-days` switch, interpreting it as boolean,
- optionally accepts the `-d`/`--print-defaults` switch, interpreting it as string,
- requires the `schedule` argument,
- optionally accepts the `weeks` argument,
- automatically adds the `-h` and `--help` switches,
- prints all the options and the long help if the help is invoked,
- prints the help and exits if invalid parameters are passed (eg. too many).

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

Guide
-----

For the guide, see the [wiki page](https://github.com/saveriomiroddi/simpleoptparse/wiki/Guide).

[BS img]: https://travis-ci.org/saveriomiroddi/simpleoptparse.svg?branch=master
