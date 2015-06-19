#!/usr/bin/lua

mtpm = {
	res = ""
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

local function doinstall(dir, basefolder, basename, reinstall)
	if basename then
		local targetpath = core.get_modpath() .. DIR_DELIM .. basename
		
		if core.is_dir(targetpath) then
			if reinstall then
				core.delete_dir(targetpath)
			else
				return false, fgettext("$1 is already installed at $2!", basename, targetpath)
			end
		end
		
		if not core.copy_dir(basefolder.path, targetpath) then
			return false, fgettext("Failed to install $1 to $2", basename, targetpath)
		end
	else
		return false, fgettext("Install Mod: unable to find suitable foldername for modpack $1", basename)
	end
	core.delete_dir(dir)
	return true, nil
end

function mtpm.reinstall(dir, basename, is_basename_certain, check_is_type)
	mtpm.install(dir, basename, is_basename_certain, check_is_type, true)
end

function mtpm.install(dir, basename, is_basename_certain, check_is_type, reinstall)
	local basefolder = mtpm.get_base_folder(dir)
	
	if check_is_type then
		if check_is_type == "mod" and basefolder.type ~= "mod" and basefolder.type ~= "modpack" then
			return false, fgettext("Failed to install $1 : it is not a mod or modpack", modpath)
		elseif check_is_type ~= basefolder.type then
			return false, fgettext("Failed to install $1 : it is not $2", modpath, check_is_type)
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

		return doinstall(dir, basefolder, clean_packname, reinstall)
	end

	if basefolder.type == "mod" then
		local clean_modname = basename

		if not clean_modname or not is_basename_certain or not mtpm.isValidModname(clean_modname) then
			local res = mtpm.identify_modname(basefolder.path, "init.lua")
			if res and res ~= clean_modname then
				clean_modname = res
			end
		end

		return doinstall(dir, basefolder, clean_modname, reinstall)
	end
end

function command_install(args, reinstall)
	local modloc = core.get_modpath()
	
	if modloc then
		for i = 2, #args do
			-- file run directly
			local package_name = arg[i]
			print("Searching for " .. package_name)

			-- Download from the internet
			local details = mtpm.fetch(package_name)
			if details then
				-- Extract
				local tempfolder = os.tempfolder()
				core.extract_zip(details.path, tempfolder)
				
				-- Check
				print(mtpm.get_base_folder(tempfolder).path)
				
				-- Install
				local suc, msg = mtpm.install(tempfolder, details.basename,
						details.basename_is_certain, nil, reinstall)
				if not suc then
					print(msg)
				end
			else
				print("Package not found")
			end
		end
	else
		print("Unable to find the mods/ directory. Fix using:")
		print("mtpm config mod_location /path/to/mods/")
	end
end

if core.is_standalone then
	local count = 0
	function os.tempfolder()
		count = count + 1
		if core.is_dir("tmp/tmp_" .. count) then
			os.execute("rm tmp/tmp_" .. count .. " -r")
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
		command_install(args, options.reinstall)
	elseif command == "update" then
		command_install(args, true)
	end
end
