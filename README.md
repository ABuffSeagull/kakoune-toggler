# Kakoune Toggler

A la [toggler-vscode](https://github.com/HiDeoo/toggler-vscode),
this plugin allows you to toggle words.

## Features

- Toggle between words!
- Toggle between multiple words!
- Toggle with multiple cursors!
- Supports TOML config, the **best** config!

## Requirements

A C++ compiler, and I think that's it. I tried to make as little dependencies as possible.

## Installation

It is *highly* recommended to use [plug.kak](https://github.com/andreyorst/plug.kak).
If so, add this to your kakrc
```sh
plug "abuffseagull/kakoune-toggler" %do{ make }
```
Otherwise, just stick in wherever, and make sure to run `make`.

Then you must make a symbolic link to the `toggler` binary from a `bin` folder in your kak config directory.
(Idea lifted from [kakoune-snippets](https://github.com/JJK96/kakoune-snippets),
if you know how to skip this step and make it automated without pulloting `$PATH`, *please* let me know).

Example, considering defaults:
```sh
$ ln -s ~/.config/kak/plugins/kakoune-toggler/toggler ~/.config/kak/bin/toggler
```

## Configuration

Your togglabe words can be configured in a `toggles.toml` file in your kak config directory.
 
The toggles are in an array of arrays of strings, 
under the `toggles` key under a table named by the filetype you would like them to be available under.

Or to better explain it:
```toml
[javascript]
toggles = [
  ["setTimout", "setInterval"],
]

# There's a special global table that will work in every filetype
[global]
toggles = [
  ["true", "false"],
  ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"],
]

# You can also extend filetypes
[html]
extends = ["javascript", "css"]
toggles = [
  ["div", "span"],
]
```

Recommended config for plugin:
```
map global user t ': toggle-word<ret>' -docstring 'toggle word'
map global user T ': toggle-WORD<ret>' -docstring 'toggle WORD'
```
The only difference between the two commands is whether it uses `<a-i>w` or `<a-i><a-w>` for selecting the word you're on.


#### Issues and Pull Requests welcome!
