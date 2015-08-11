# Minetest Package Manager

A package manager written in Lua.

Written by rubenwardy.  
License: LGPL 2.1 or later.

Some code taken from the existing mod manager in builtin/mainmenu/.

## Usage

```Bash
$ sudo apt-get install lua luarocks libzzip-dev

$ luarocks --local install luazip
$ luarocks --local install luafilesystem
$ luarocks --local install luajson
# Alternatively you could use sudo luarocks install

$ sudo make install

# You can skip this line if minetest is in ~/.minetest/
$ mtpm set minetest_root /path/to/minetest/


# Install packages
$ mtpm install package1 package2 package3

# Install mods from depends.txt
$ mtpm -r depends.txt

# A query can be in one of these forms:
#	basename - gets from repos (eg: mmdb, ModSearch)
#	author/basename - gets from repos (eg: mmdb, ModSearch)
#	basename@repo - gets the package from the repo specified.
#	http://url/to/download/ - downloads archive from this url
# Planned (not done yet):
#	http://github.com/author/repo/
#	http://github.com/author/repo.git
#	git://git/url.git - git links
#	base* - wildchars
#	basename>1.0 - versions. Spaces are ignored around >, >=, =.
# Order for non-url queries:
# 	* author/ must be before basename
#	* versions (eg: =1.0.3) must be after basename
#	* @repo must be after basename.
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
