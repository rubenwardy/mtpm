#!/usr/bin/lua

local dofile_args = ...

mtpm = {}

-- \mainpage Welcome to MTPM
-- The Minetest Package Manager
--
-- \section details
-- posible values:
-- 	* `archive` - filepath to archive
-- 	* `basename` optional - modname, worldname, subgame name or texturepack name.
-- 	* `is_basename_certain` optional - true if basename is from repo,
-- 	                                   false if it was deduced from URL
-- 	* `author` optional - package must match this author
-- 	* `type` optional - the type of package you want to install
-- 		* `mod` - mods or modpack
-- 		* `game`
-- 		* `texture`
-- 		* `world`

function Config(path)
	local f = io.open(path, "r")
	local data = {}
	if f then
		local lineno = 0
		for line in f:lines() do
			lineno = lineno + 1
			local arr = line:split("=")
			if #arr == 2 then
				data[arr[1]:trim()] = arr[2]:trim()
			else
				print("Config: More than one deliminator (=) on line " .. lineno .. " of " .. path)
			end
		end
		f:close()
	end

	return {
		_data = data,
		get = function(self, name)
			return self._data[name]
		end,
		set = function(self, name, value)
			self._data[name] = value
		end,
		save = function(self, save_path)
			if not save_path then
				save_path = path
			end

			local f = io.open(save_path, "w")
			if f then
				for name, value in pairs(self._data) do
					f:write(name .. " = " .. value .. "\n")
				end
				f:close()
			end
		end
	}
end


-- Initialise MTPM
-- @param res_path Path to MTPM's resources
function mtpm.init(res_path)
	if not res_path then
		local f = io.open("core.lua", "rb")
		if f then
			f:close()
			res_path = ""
		else
			local f = io.open("/usr/local/share/mtpm/core.lua", "rb")
			if f then
				f:close()
				res_path = "/usr/local/share/mtpm/"
			else
				local f = io.open("/usr/share/mtpm/core.lua", "rb")
				if f then
					f:close()
					res_path = "/usr/share/mtpm/"
				else
					print("Unable to find MTPM's resources!")
					return
				end
			end
		end
	end

	mtpm.res = res_path
	mtpm.repos = {}

	if not core then
		dofile(mtpm.res .. "core.lua")
	end
	dofile(mtpm.res .. "install.lua")
	dofile(mtpm.res .. "identify.lua")

	-- Read repository lists
	local repos = io.open(mtpm.res .. "repositories.csv", "r")
	if repos then
		for line in repos:lines() do
			local fields = line:split(",")
			if line:trim():sub(1, 1) ~= "#" and #fields == 4
					and fields[1]:lower() ~= "title" then
				table.insert(mtpm.repos, {
					title = fields[1]:trim(),
					type = fields[2]:trim(),
					format = fields[3]:trim(),
					url = fields[4]:trim()
				})
			end
		end
		repos:close()
	else
		print("Unable to read " .. mtpm.res .. "repositories.csv")
	end
end


-- Validate basename
-- @return boolean, true is success
function mtpm.isValidBasename(basename)
	return string.match(basename, "^([%a%d_]+)$") == basename
end


if debug.getinfo(2) then
	local function command_install(args, options, reinstall, override)
		override = override or reinstall
		mtpm._done     = 0
		mtpm._failed   = 0
		mtpm._notfound = 0
		mtpm._uptodate = 0

		-- Read from arguments
		for i = 2, #args do
			mtpm.run_query_wrapper(args[i], override, options.yes)
		end

		-- Look for depends.txt files to read
		if options.depends then
			mtpm.run_depends_txt(options.depends, override, options.yes)
		end

		print(mtpm._done .. " installed, " .. mtpm._uptodate .. " already installed, "
				.. mtpm._failed .. " failed and " .. mtpm._notfound
				.. " could not be found.")
	end

	mtpm.init()

	local count = 0
	function os.tempfolder()
		count = count + 1
		if core.is_dir("/tmp/tmp_" .. count) then
			core.delete_dir("/tmp/tmp_" .. count)
		end
		core.create_dir("/tmp/tmp_" .. count)
		return "/tmp/tmp_" .. count .. "/"
	end

	--
	-- Command Line Arguments and Options parser
	--
	local OptionParser = dofile(mtpm.res .. "optparse.lua")
	local opt = OptionParser.OptionParser({
			usage="%prog [options] <command> [<args>]",
			version="MTPM 0.1",
			add_help_option=false
	})
	local tmp_help = opt.print_help
	function opt.print_help()
		tmp_help()

		print("\nCommands:")
		print("  install package1 [package2] ...")
		print("  update package1 [package2] ...")
		print("  set setting [value]")
	end
	opt.add_option({
		"-h", "--help",
		action = "store_true",
		dest   = "help",
		help   = "show this information"
	})
	opt.add_option({
		"--reinstall",
		dest   = "reinstall",
		action = "store_true",
		help   = "reinstall the package"
	})
	opt.add_option({
		"-m",  "--mod_location",
		dest   = "mod_location",
		action = "store",
		help   = "change mod location (isn't stored, only for this session)"
	})
	opt.add_option({
		"-r",  "--read",
		dest   = "depends",
		action = "store",
		help   = "install mods in depends.txt. Asks whether to install optional mods (-y to just install)"
	})
	opt.add_option({
		"-y",  "--yes",
		dest   = "yes",
		action = "store_true",
		help   = "Skip questions, answer yes"
	})

	local options, args = opt.parse_args()
	local command = args[1]

	if options.mod_location then
		function core.get_modpath()
			return options.mod_location
		end
	end

	if not command or options.help then
		opt.print_help()
		os.exit(1)
	end

	--
	-- Do Commands
	--
	if command == "set" or command == "config" then
		local conf = Config(os.getenv("HOME") .. "/.mtpm.conf")
		if #arg == 3 then
			conf:set(arg[2]:trim(), arg[3]:trim())
			print(arg[2]:trim() .. " = " .. conf:get(arg[2]))
			conf:save()
		elseif #arg == 2 then
			print(arg[2]:trim() .. " = " .. conf:get(arg[2]))
		else
			opt.print_help()
			os.exit(1)
		end
	else
		local modloc = core.get_modpath()
		if not modloc or not core.is_dir(modloc) then
			print("Unable to find the mods/ directory. Fix using:")
			print("mtpm set minetest_root /path/to/minetest/")
			print(" (if you have already done this, check that the directory exists.")
			print("     Don't include bin/minetest)")
			os.exit(-1)
		end

		if command == "install" then
			command_install(args, options, options.reinstall, options.reinstall)
		elseif command == "update" then
			command_install(args, options, false, true)
		else
			opt.print_help()
			os.exit(1)
		end
	end
end
