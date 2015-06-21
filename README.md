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
$ sudo luarocks install luajson

# You can skip this line if mods are in ~/.minetest/mods/
$ ./mtpm.lua config mod_location /path/to/minetest/mods/

$ ./mtpm.lua install package1 package2 package3

# A query can be in one of these forms:
#	basename - gets from repos (eg: mmdb, ModSearch)
#	author/basename - tries github then repos.
#	basename@repo - gets the package from the repo specified.
#	http://url/to/download/ - downloads archive from this mod
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

### Major Methods

* `mtpm.init(res_path)`
	* Reads mtpm data (lua files, repository lists) in res_path.
* `mtpm.parse_query(query)`
	* returns `details`, `msg` table.
		* `details` - a details table
		* `msg` - if details is `nil`, this is the error message
	* `query` - a string
		* basename
		* author/basename
		* http://url/to/download/
		* basename@repo (repo, eg: ModSearch)
		* basename#type (type, eg: mod)
		* eg: author/basename#mod@modsearch
		   (note: the #mod above is not needed as modsearch only provides mods.)
* `mtpm.search_repos(details)`
	* Adds `url` to `details`, and any other data fetched from the repo (eg: author)
	* Calls `mtpm.search_in_repo()`
* `mtpm.search_in_repo(repo, details)`
	* Searches for the package described by `details` in `repo`
	* Get `repo` from `mtpm.repos`.
	* You should check that `repo` provides the type of package `details` describes.
* `mtpm.install_archive(details, override)`
	* Extracts archive and calls `mtpm.install_folder()`
	* returns `suc`, `msg` table.
		* `suc` - Success code
			* `0` - failure
			* `1` - success
			* `2` - up to date / already installed
		* `msg` - error message if suc != 1
	* `details`:
		* `archive` - filepath to archive
		* `basename` optional - modname, worldname, subgame name or texturepack name.
		* `is_basename_certain` - true if basename is from repo, false if it was deduced from URL
		* `author` optional
		* `type` optional - the type of package you want to install
			* `mod`
			* `game`
			* `texture`
			* `world`
	* `override` - boolean, should an existing folder be deleted and replaced.
* `mtpm.install_folder(details, dir, override)`
	* returns `suc`, `msg` table.
		* `suc` - Success code
			* `0` - failure
			* `1` - success
			* `2` - up to date / already installed
		* `msg` - error message if suc != 1
	* `details` - see above.
	* `dir` - path to extracted folder
	* `override` - boolean, should an existing folder be deleted and replaced.

### Example

```lua
dofile("mtpm/mtpm.lua")
mtpm.init("mtpm/")

local details, msg = mtpm.parse_query("username/basename")
if not details.url then
	print("Searching repositories...")
	mtpm.search_repos(details)
end

if details.url then
	print("Downloading...")
	if core.download_file(details.url, "tmp.zip") then
		print("Installing...")
		details.archive = "tmp.zip"
		local suc, msg = mtpm.install_archive(details, override)
		if suc ~= 1 then
			print(msg)
		end
	else
		print("Could not download " .. details.url)
	end
else
```

### Helpers

* `mtpm.isValidBasename(basename)`
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
