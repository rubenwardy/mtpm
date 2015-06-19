# Minetest Package Manager

A package manager written in Lua.

Written by rubenwardy.  
License: LGPL 2.1 or later.

Some code taken from the existing mod manager in builtin/mainmenu/.

## Usage

```Bash
$ sudo apt-get install lua luarocks libzzip-dev
$ sudo luarocks install luazip
$ sudo luarocks install luafilesystem

# You can skip this line if mods are in ~/.minetest/mods/
$ ./mtpm.lua config mod_location /path/to/minetest/mods/

$ ./mtpm.lua install package1 package2 package3

# A package name can be in one of these forms:
#	packagename - gets from repos (eg: mmdb, MT-GitSync)
#	package* - you can use wildchars.
#	username/packagename - tries github then repos
#	http://url/to/download/ - downloads archive from this mod
#	http://github.com/username/packagename/
#	http://github.com/username/packagename.git
# See ./mtpm.lua --help
```

Please note that this is a work in progress.
Some mods may install incorrectly.
