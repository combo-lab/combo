# Installation

In order to build a Combo project, you need a few dependencies installed in your OS.

Please take a look at this list and make sure to install anything necessary for your system. Having dependencies installed in advance can prevent frustrating problems later on.

## Install runtimes

- Elixir
- Node.js

## Install PostgreSQL

PostgreSQL is a relational database management system.

Combo only supports PostgreSQL. SQLite3, MySQL or MSSQL are not supported.

## Install inotify-tools (for Linux users)

Combo provides a feature called Live Reloading. As you change views or assets, it automatically reloads the page in the browser. In order for this functionality to work, you need a filesystem watcher.

macOS and Windows users already have a filesystem watcher, but Linux users must install inotify-tools. Please consult the [inotify-tools wiki](https://github.com/rvoicilas/inotify-tools/wiki) for distribution-specific installation instructions.

## Install combo_new

`combo_new` is the project generator for Combo. Install it like this:

```console
$ mix archive.install hex combo_new
```

The `combo.new` generator is now available to generate new projects in the next guide, called [Up and Running](up_and_running.html).

You can see all available options by calling `mix help combo.new`.

## Summary

At the end of this section, you must have installed all the dependecies. Let's get [up and running](up_and_running.html).
