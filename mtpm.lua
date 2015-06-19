#!/usr/bin/lua

local dofile_args = ...

mtpm = {
	res = ... or ""
}

dofile(mtpm.res .. "core.lua")
dofile(mtpm.res .. "identify.lua")

function mtpm.isValidModname(modpath)
	return (modpath:find("-") == nil)
end

function mtpm.fetch(package_name, skip_check_repos)
	print("Searching for " .. package_name)
	local tmp
	local username, packagename = string.match(package_name:trim(), "github.com/([%a%d_]+)/([%a%d_]+)/?$")
	if username and packagename then
		tmp = tmp or os.tempfolder()
		if core.download_file("https://github.com/" .. username .. "/" .. packagename .. "/archive/master.zip", tmp .. "tmp.zip") then
			return {
				path = tmp .. "tmp.zip",
				basename = packagename,
				basename_is_certain = false
			}
		end
	end

	local username, packagename = string.match(package_name:trim(), "^([%a%d_]+)/([%a%d_]+)$")
	if username and packagename then
		tmp = tmp or os.tempfolder()
		if core.download_file("https://github.com/" .. username .. "/" .. packagename .. "/archive/master.zip", tmp .. "tmp.zip") then
			return {
				path = tmp .. "tmp.zip",
				basename = packagename,
				basename_is_certain = false
			}
		end
	end

	local username, packagename = string.match(package_name:trim(), "github.com/([%a%d_]+)/([%a%d_]+).git$")
	if username and packagename then
		tmp = tmp or os.tempfolder()
		if core.download_file("https://github.com/" .. username .. "/" .. packagename .. "/archive/master.zip", tmp .. "tmp.zip") then
			return {
				path = tmp .. "tmp.zip",
				basename = packagename,
				basename_is_certain = false
			}
		end
	end

	if package_name:sub(1, 4) == "http" and package_name:find(":") <= 6 then
		tmp = tmp or os.tempfolder()
		core.download_file(package_name, tmp .. "tmp.zip")
		return {
			path = tmp .. "tmp.zip"
		}
	end

	local file = io.open(package_name, "rb")
	if file then
		file:close()
		return {
			path = package_name
		}
	end
	
	local repos = io.open(mtpm.res .. "repositories.csv", "r")
	if not skip_check_repos and repos then
		for line in repos:lines() do
			local fields = line:split(",")
			if fields[1]:trim():lower() ~= "title" then
				print("Looking in " .. fields[1]:trim())
				local res = mtpm.fetch_from_repo(package_name, fields)
				if res then
					return res
				end
			end
		end
		repos:close()
	end
end

function mtpm.fetch_from_repo(package_name, fields)
	if fields[3]:trim() == "CSV" then
		local tmp = os.tempfolder()
		if core.download_file(fields[4], tmp .. "repo.csv") then
			local repo = io.open(tmp .. "repo.csv", "r")
			if repo then
				for line in repo:lines() do
					local fields = line:split(",")
					if fields[1]:trim():find(package_name) then
						print("Found " .. fields[1]:trim())
						local res = mtpm.fetch(fields[2]:trim(), true)
						local basename = string.match(package_name:trim(), "^([%a%d_]+)$")
						if basename then
							res.basename = basename
							res.basename_is_certain = true
						end
						res.title = fields[1]:trim()
						res.forum = fields[3]:trim()
						return res
					end
				end
				repo:close()
			end
		end
	end
end

local function doinstall_mod(dir, basefolder, basename, override)
	if basename then
		local targetpath = core.get_modpath() .. DIR_DELIM .. basename
		
		if core.is_dir(targetpath) then
			if override then
				core.delete_dir(targetpath)
			else
				return 2, fgettext("$1 is already installed at $2!", basename, targetpath)
			end
		end
		
		if not core.copy_dir(basefolder.path, targetpath) then
			return 0, fgettext("Failed to install $1 to $2", basename, targetpath)
		end
	else
		return 0, fgettext("Install Mod: unable to find suitable foldername for modpack $1", basename)
	end

	core.delete_dir(dir)
	return 1, nil
end

function mtpm.install_folder(dir, basename, is_basename_certain, check_is_type, override)
	local basefolder = mtpm.get_base_folder(dir)
	
	if check_is_type then
		if check_is_type == "mod" and basefolder.type ~= "mod" and basefolder.type ~= "modpack" then
			return 0, fgettext("Failed to install $1 : it is not a mod or modpack", modpath)
		elseif check_is_type ~= basefolder.type then
			return 0, fgettext("Failed to install $1 : it is not $2", modpath, check_is_type)
		end
	end

	if basefolder.type == "modpack" then
		local clean_packname

		if basename then
			clean_packname = "mp_" .. basename
		else
			-- TODO: better basename creation.
			clean_packname = "mp_1"
		end

		return doinstall_mod(dir, basefolder, clean_packname, override)
	end

	if basefolder.type == "mod" then
		local clean_modname = basename

		if not clean_modname or not is_basename_certain or not mtpm.isValidModname(clean_modname) then
			local res = mtpm.identify_modname(basefolder.path, "init.lua")
			if res and res ~= clean_modname then
				clean_modname = res
			end
		end

		return doinstall_mod(dir, basefolder, clean_modname, override)
	end
end

function mtpm.install(package_name, reinstall, override)
	override = override or reinstall
	-- TODO: if reinstall is true, make it get the same version.
	local details = mtpm.fetch(package_name)
	return mtpm.install_archive(package_name, details, override)
end

function mtpm.install_archive(package_name, details, override)
	if details then
		-- Extract
		local tempfolder = os.tempfolder()
		core.extract_zip(details.path, tempfolder)

		-- Install
		return mtpm.install_folder(tempfolder, details.basename,
				details.basename_is_certain, nil, override)
	else
		return 3, fgettext("Unable to locate $1!", package_name)
	end
end

function command_install(args, reinstall, override)
	local modloc = core.get_modpath()
	
	if modloc and core.is_dir(modloc) then
		local done     = 0
		local failed   = 0
		local notfound = 0
		local uptodate = 0
		for i = 2, #args do
			-- file run directly
			local package_name = arg[i]

			-- Download from the internet
			local suc, msg = mtpm.install(package_name, install, override)
			if suc == 1 then
				done = done + 1
			elseif suc == 2 then
				uptodate = uptodate + 1
				print(msg)
			elseif suc == 3 then
				notfound = notfound + 1
				print(msg)
			else
				failed = failed + 1
				print(msg)
			end
		end
		print(done .. " installed, " .. uptodate .. " already installed, " .. failed .. " failed and " .. notfound .. " could not be found.")
	else
		print("Unable to find the mods/ directory. Fix using:")
		print("mtpm config mod_location /path/to/mods/")
		print(" (if you have already done this, check that the directory exists.)")
	end
end

if core.is_standalone then
	local count = 0
	function os.tempfolder()
		count = count + 1
		if core.is_dir("tmp/tmp_" .. count) then
			core.delete_dir("tmp/tmp_" .. count)
		end
		core.create_dir("tmp/tmp_" .. count)
		return "tmp/tmp_" .. count .. "/"
	end
	
	--
	-- Command Line Arguments and Options parser
	--
	local OptionParser = dofile(mtpm.res .. "optparse.lua")
	local opt = OptionParser.OptionParser({
			usage="%prog [options] <command> [<args>]",
			version="mtpm 0.1",
			add_help_option=false
	})
	local tmp_help = opt.print_help
	function opt.print_help()
		tmp_help()
		
		print("\nCommands:")
		print("  install package1 [package2] ...")
		print("  update package1 [package2] ...")
		print("  config setting value")
	end
	opt.add_option({
		"-h", "--help",
		action = "store_true",
		dest   = "help",
		help   = "show this information"
	})
	opt.add_option({
		"--version",
		action = "store_true",
		dest   = "version",
		help   = "show version number"
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
	local options, args = opt.parse_args()
	local command = args[1]
	if options.mod_location then
		function core.get_modpath()
			return options.mod_location
		end
	end
	if options.version then
		opt.print_version()
		os.exit(1)
	end
	if not command or options.help then
		opt.print_help()
		os.exit(1)
	end
	
	--
	-- Do Commands
	--
	if command == "config" then
		local home = os.getenv("HOME")

		local conf = io.open(home .. "/.mtpm.conf")
		if conf then
			local added = false
			local retval = ""
			for line in conf:lines() do
				local setting = line:split("=")
				if #setting == 2 then
					if not added and setting[1]:trim() == arg[2]:trim() then
						retval = retval .. arg[2]:trim() .. " = " ..
								arg[3]:trim() .. "\n"
						added = true
					else
						retval = retval .. setting[1]:trim() .. " = " ..
								setting[2]:trim() .. "\n"
					end
				end
			end
			if not added then
				retval = retval .. arg[2]:trim() .. " = " ..
						arg[3]:trim() .. "\n"
			end
			conf:close()
			conf = io.open(home .. "/.mtpm.conf", "w")
			conf:write(retval)
			conf:close()
		else
			conf = io.open(home .. "/.mtpm.conf", "w")
			conf:write(arg[2]:trim() .. " = " ..
						arg[3]:trim() .. "\n")
			conf:close()
		end
	elseif command == "install" then
		command_install(args, options.reinstall, options.reinstall)
	elseif command == "update" then
		command_install(args, false, true)
	end
end
