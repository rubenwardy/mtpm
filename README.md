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
#	username/packagename - tries github then repos
#	http://url/to/download/ - downloads archive from this mod
#	http://github.com/username/packagename/
#	http://github.com/username/packagename.git
# Planned (not done yet):
#	package* - wildchars
#	packagename>1.0 - versions. Spaces are ignored around >, >=, =.
#	git://git/url.git - git links
#	packagename@repo - gets the package from the repo specified. Spaces are ignored around @
#	package* >=1.0 @repo - should be in this order.
# See ./mtpm.lua --help
```

Please note that this is a work in progress.
Some mods may install incorrectly.

## API

You can include mtpm.lua from another lua file.

```lua
dofile("mtpm/mtpm.lua")

-- path to mtpm's resources
mtpm.init("mtpm/")
```

### Methods

* `mtpm.init(res_path)`
	* Reads mtpm data (lua files, repository lists) in res_path.
* `mtpm.install(package_name, reinstall, override)`
	* `package_name` - the package name, see usage section above.
	* `reinstall` - boolean, should a mod be reinstalled. (Don't use versions in packagename)
	* `override` - boolean, should an existing folder be deleted and replaced.
	               Overriden to true if reinstall is true
* `mtpm.install_archive(package_name, details, override)`
	* `package_name` - the package name, see usage section above.
	* `details` - table, minimum `path` to file.
                  May also contain `basename`, `basename_is_certain`, `title`, `author`, `version`.
	* `override` - boolean, should an existing folder be deleted and replaced.
* `mtpm.install_folder(dir, basename, is_basename_certain, check_is_type, override)`
	* `dir` - folder to install
	* `basename` - the basename if already known
	* `is_basename_certain` - true if basename is from repo, false if it was deduced from URL
	* `check_is_type` - one of:
		* `nil` - any package type may be reinstalled
		* "mod" - only install mods and modpacks
		* "game" - only install subgames
		* "texture" - only install texture packs
		* "world" - only install worlds
* `mtpm.fetch(package_name, skip_check_repos)`
	* `package_name` - the package name, see usage section above.
	* `skip_check_repos` - boolean, if true don't look for a package in the repos.
* `mtpm.fetch_from_repo(package_name, fields)`
	* Search for a package in a/the repo(s).
	* `package_name` - the package name, see usage section above.
	* `fields` - optional, if given this is the row in repositories (the function is recursive)
* `mtpm.isValidModname(basename)`
* `mtpm.get_base_folder(path)`
	* `path` - base to extracted zip.
	* Returns a table:
		* `type` - "mod", "modpack", "texture", "game", "world" or "invalid"
		* `path` - path to the folder. Note that it may not be the path in the parameter,
		           as there may be superfluous folders.
                   Eg: parameter was mymod/, init.lua is in mymod/mymod-master/, path passed out is mymod/mymod-master/
* `mtpm.identify_modname(modpath, filename)`
	* Finds the modname / basename by looking in lua files
	* `modpath` - path to the extracted zip.
	* `filename` - optional, this function is recursive through dofiles.
