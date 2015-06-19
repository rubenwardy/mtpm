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
$ ./init.lua config mod_location /path/to/minetest/mods/

$ ./init.lua install package1 package2 package3

# A package name can be in one of these forms:
#	packagename - if in mmdb or another repo
#	package* - you can use wildchars.
#	username/packagename - tries github then repos
#	http://url/to/download/ - downloads archive from this mod
#	http://github.com/username/packagename/
#	http://github.com/username/packagename.git
#   git://url/to/git
```

Please note that this does not actually work yet.
The above is just planned usage.
