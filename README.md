# Minetest Package Manager

A package manager written in Lua.

Written by rubenwardy.  
License: LGPL 2.1 or later.

Some code taken from the existing mod manager in builtin/mainmenu/.

## Usage

```Bash
$ sudo apt-get install lua luarocks
$ sudo luarocks install luazip luafilesystem

# You can skip this line if mods are in ~/.minetest/mods/
$ ./init.lua config mod_location /path/to/minetest/mods/

$ ./init.lua install packagename
```

Please note that this does not actually work yet.
