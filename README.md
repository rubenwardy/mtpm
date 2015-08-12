# Minetest Package Manager

A package manager written in Lua.

Written by rubenwardy.  
License: LGPL 2.1 or later.

Some code taken from the existing mod manager in builtin/mainmenu/.

## Installation

```Bash
$ sudo apt-get install lua5.1 luarocks libzzip-dev
$ sudo luarocks install luazip
$ sudo luarocks install luafilesystem
$ sudo luarocks install luajson
# Alternatively you could use sudo luarocks install

$ git clone https://github.com/rubenwardy/mtpm/
$ cd mtpm

# You could skip this and use "./mtpm.lua" instead of "mtpm"
$ sudo make install

# You can skip this line if minetest is in ~/.minetest/
$ mtpm set minetest_root /path/to/minetest/
```

## Usage

```Bash
    # Install multiple packages
    mtpm install homedecor food tutorial

    # Specify the type of a package
    mtpm install food#mod
    mtpm install tutorial#subgame

    # Specify the author
    mtpm install tenplus1/mobs
    mtpm install PilzAdam/mobs

    # Specify the repository
    mtpm install carts@ModSearch
    mtpm install boost_cart@minetest-bower
    mtpm install technic_game@mtpm_sg

    # From github
    mtpm install PilzAdam/farming_plus@github
    mtpm install https://github.com/PilzAdam/farming_plus

    # From url
    mtpm install https://example.com/archive.zip

    # From file
    mtpm install archive.zip

# A query can be in one of these forms:
#	basename - gets from repos (eg: mmdb, ModSearch)
#	author/basename - gets from repos (eg: mmdb, ModSearch)
#	basename@repo - gets the package from the repo specified.
#	http://url/to/download/ - downloads archive from this url
#	http://github.com/author/repo/
#	http://github.com/author/repo.git
#	git://git/url.git - git links
# 	basename#type - eg basename#mod
# Planned (not done yet):
#	base* - wildchars
#	basename>1.0 - versions. Spaces are ignored around >, >=, =.
# Order for non-url queries:
# 	* author/ must be before basename
#	* versions (eg: =1.0.3) must be after basename
#	* @repo must be after basename.
# 	* #type must be after basename.
# See mtpm --help
```

Please note that this is a work in progress.
Some mods may install incorrectly.


### Example

```lua
-- Initialise mtpm
-- Paths can be relative to PWD
mtpm.init("/path/to/mtpm/resources/")

-- Install from query
mtpm.run_query("VanessaE/homedecor")

-- Install from archive
mtpm.install_archive({
	archive = "/path/to/archive/"
})
```
