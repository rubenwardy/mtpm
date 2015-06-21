#!/usr/bin/lua

local dofile_args = ...

mtpm = {}

function mtpm.init(res)
	mtpm.res = res
	mtpm.repos = {}
	dofile(mtpm.res .. "core.lua")
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

function mtpm.isValidBasename(basename)
	return string.match(basename, "^([%a%d_]+)$") == basename
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
		return 0, fgettext("Install Mod: unable to find suitable foldername for $1", dir)
	end

	core.delete_dir(dir)
	return 1, nil
end

function mtpm.install_folder(details, dir, override)
	local basefolder = mtpm.get_base_folder(dir)

	if details.type then
		if details.type == "mod" and basefolder.type ~= "mod" and basefolder.type ~= "modpack" then
			return 0, fgettext("Failed to install $1 : it is not a mod or modpack", modpath)
		elseif details.type ~= basefolder.type then
			return 0, fgettext("Failed to install $1 : it is not $2", modpath, check_is_type)
		end
	end

	if basefolder.type == "modpack" then
		local clean_packname

		if details.basename then
			clean_packname = "mp_" .. details.basename
		else
			-- TODO: better basename creation.
			clean_packname = "mp_1"
		end

		return doinstall_mod(dir, basefolder, clean_packname, override)
	elseif basefolder.type == "mod" then
		local clean_modname = details.basename

		if not clean_modname or not details.is_basename_certain or
				not mtpm.isValidBasename(clean_modname) then
			local res = mtpm.identify_modname(basefolder.path)
			if res and res ~= clean_modname then
				clean_modname = res
			end
		end

		return doinstall_mod(dir, basefolder, clean_modname, override)
	else
		return 0, fgettext("Invalid folder type!", modpath, check_is_type)
	end
end

function mtpm.install_archive(details, override)
	-- Extract
	local tempfolder = os.tempfolder()
	if core.extract_zip(details.archive, tempfolder) then
		return mtpm.install_folder(details, tempfolder, override)
	else
		return 0, fgettext("Could not extract archive $1", details.archive)
	end
end

-- username/password>=version@repo
function mtpm.parse_query(query)
	if not query then
		return nil, fgettext("Invalid empty query $1", query)
	end

	query = query:trim()
	local retval = {}

	if query:sub(1, 4) == "http" and query:find(":") <= 6 then
		return {
			url = query
		}
	end

	if core.file_exists(query) then
		return {
			archive = query
		}
	end


	local username, packagename = string.match(query, "^([%a%d_]+)/([%a%d_]+)")
	if username and packagename then
		retval.author = username:trim()
		retval.basename = packagename:trim()
		query = query:sub(#username + #packagename + 2, #query):trim()
	else
		local packagename = string.match(query, "^([%a%d_]+)")
		if packagename and packagename:trim() ~= "" then
			retval.basename = packagename:trim()
			query = query:sub(#packagename + 1, #query):trim()
		else
			return nil, fgettext("Invalid query $1; Needs to start with" ..
					" packagename or username/packagename", query)
		end
	end

	retval.repo = string.match(query, "@([%a%d_]+)")

	return retval, nil
end

function mtpm.search_in_repo(repo, details)
	-- JSON-QUERY
	if repo.format == "json-q" then
		local tmp = os.tempfolder()
		if not core.download_file(repo.url .. "?q=" .. details.basename,
				tmp .. "tmp.json") then
			return false
		end

		local f = io.open(tmp .. "tmp.json", "r")
		if not f then
			return false
		end
		local data = core.parse_json(f:read("*all"))
		f:close()

		if details.author and data.author ~= details.author then
			return false
		end

		if data and not data.error and data.download then
			details.url = data.download
			return true
		end

	-- DIRECT downloads
	elseif repo.format == "direct" then
		local retval = repo.url
		if details.author then
			retval = retval:replace("<author>", details.author)
		elseif retval:find("<author>") > 0 then
			return false
		end
		retval = retval:replace("<basename>", details.basename)

		-- TODO: check URL is not 404, somehow. (it still downloads 404 webpage)
		details.url = retval
		return true
	end
	return false
end

function mtpm.search_repos(details)
	for i = 1, #mtpm.repos do
		local repo = mtpm.repos[i]

		if not details.repo or repo.title:lower() == details.repo:lower() then
			if not details.type or repo.type == "" or
					(details.type == repo.type) then
				if mtpm.search_in_repo(repo, details) then
					return details
				end
			end
		end
	end
end

if debug.getinfo(2) then
	local function command_install(args, reinstall, override)
		override = override or reinstall
		local done     = 0
		local failed   = 0
		local notfound = 0
		local uptodate = 0
		for i = 2, #args do
			-- file run directly
			local query = args[i]

			-- Parse query and get URL
			local details, msg = mtpm.parse_query(query)
			if details then
				if not details.url and not details.archive then
					print("Searching repositories...")
					mtpm.search_repos(details)
				end

				-- Download
				if details.archive or details.url then
					if not details.archive then
						print("Downloading from " .. details.url)
						local tmp = os.tempfolder()
						if core.download_file(details.url, tmp .. "tmp.zip") then
							details.archive = tmp .. "tmp.zip"
						else
							failed = failed + 1
							print("Could not download " .. details.url)
						end
					end

					if details.archive then
						print("Installing...")
						local suc, msg = mtpm.install_archive(details, override)
						if suc == 1 then
							done = done + 1
						elseif suc == 2 then
							uptodate = uptodate + 1
							print(msg)
						else
							failed = failed + 1
							print(msg)
						end
					end
				else
					print("Could not find " .. details.basename)
					notfound = notfound + 1
				end
			else
				print(msg)
			end -- end if
		end -- end for
		print(done .. " installed, " .. uptodate .. " already installed, "
				.. failed .. " failed and " .. notfound
				.. " could not be found.")
	end

	mtpm.init("")

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
		print("Set setting " .. arg[2]:trim() .. "!")
	end

	local modloc = core.get_modpath()
	if not modloc or not core.is_dir(modloc) then
		print("Unable to find the mods/ directory. Fix using:")
		print("mtpm config mod_location /path/to/mods/")
		print(" (if you have already done this, check that the directory exists.)")
		os.exit(-1)
	end

	if command == "install" then
		command_install(args, options.reinstall, options.reinstall)
	elseif command == "update" then
		command_install(args, false, true)
	end
end
