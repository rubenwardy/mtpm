#!/usr/bin/lua

function string:trim()
	return (self:gsub("^%s*(.-)%s*$", "%1"))
end

function string.split(str, delim, include_empty, max_splits, sep_is_pattern)
	delim = delim or ","
	max_splits = max_splits or -1
	local items = {}
	local pos, len, seplen = 1, #str, #delim
	local plain = not sep_is_pattern
	max_splits = max_splits + 1
	repeat
		local np, npe = str:find(delim, pos, plain)
		np, npe = (np or (len+1)), (npe or (len+1))
		if (not np) or (max_splits == 1) then
			np = len + 1
			npe = np
		end
		local s = str:sub(pos, np - 1)
		if include_empty or (s ~= "") then
			max_splits = max_splits - 1
			table.insert(items, s)
		end
		pos = npe + 1
	until (max_splits == 0) or (pos > (len + 1))
	return items
end

core = core or (function()
	local zip  = require("zip")
	local lfs  = require("lfs")
	--local curl = require "luacurl"
	return {
		is_standalone = true,
		is_dir = function(directory)
			return (lfs.attributes(directory, "mode") == "directory")
		end,
		create_dir = function(directory)
			os.execute("mkdir " .. directory)
		end,
		get_dir_list = function(directory)
			if not directory then
					return
			end
			local retval = {}
			for file in lfs.dir(directory) do
				if lfs.attributes(file, "mode") == "directory" and
				 		file ~= "." and file ~= ".." then
					table.insert(retval, file)
					print(file)
				end
			end
			return retval
		end,
		download_file = function(url, filename)
			os.execute("wget " .. url .. " -O " .. filename)
			if true then
				return true
			end

			print("doing")
			local c = curl.new()
			c:setopt(curl.OPT_URL, url)
			c:setopt(curl.OPT_USERAGENT, "mtpm/0.1")
			local file = io.open(filename, "wb")
			c:setopt(curl.OPT_WRITEFUNCTION, function(param, buf)
				print("receiving!")
				file:write(buf)
				return #buf
			end)
			c:perform()
			c:close()
			file:close()
			print("done")
		end,
		extract_zip = function(filepath, path)
			local zfile, err = zip.open(filepath)

			local function writefile(file)
				local idx = #file.filename
				if file.filename:sub(idx, idx) == mtpm.DIR_DELIM then
					-- Is a directory
					core.create_dir(path .. file.filename)
				else
					-- Is a file
					local currFile, err = zfile:open(file.filename)
					local currFileContents = currFile:read("*a")
					local hBinaryOutput = io.open(path .. file.filename, "wb")

					-- write current file inside zip to a file outside zip
					if(hBinaryOutput)then
						hBinaryOutput:write(currFileContents)
						hBinaryOutput:close()
					end
					currFile:close()
				end
			end

			-- iterate through each file inside the zip file
			for file in zfile:files() do
				writefile(file)
			end

			zfile:close()
		end
	}
end)()

mtpm = {
	DIR_DELIM = "/"
}

dofile("identify.lua")

function mtpm.isValidModname(modpath)
	return (modpath:find("-") == nil)
end

function mtpm.fetch(package_name, skip_check_repos)
	print("Searching for " .. package_name)
	local tmp
	local username, repo = string.match(package_name:trim(), "github.com/([%a%d_]+)/([%a%d_]+)/?$")
	if username and repo then
		tmp = tmp or os.tempfolder()
		if core.download_file("https://github.com/" .. username .. "/" .. repo .. "/archive/master.zip", tmp .. "tmp.zip") then
			return tmp .. "tmp.zip"
		end
	end

	local username, packagename = string.match(package_name:trim(), "^([%a%d_]+)/([%a%d_]+)$")
	if username and packagename then
		tmp = tmp or os.tempfolder()
		if core.download_file("https://github.com/" .. username .. "/" .. packagename .. "/archive/master.zip", tmp .. "tmp.zip") then
			return tmp .. "tmp.zip"
		end
	end

	if package_name:sub(1, 4) == "http" and package_name:find(":") <= 6 then
		tmp = tmp or os.tempfolder()
		core.download_file(package_name, tmp .. "tmp.zip")
		return tmp .. "tmp.zip"
	end

	local file = io.open(package_name, "rb")
	if file then
		file:close()
		return package_name
	end
	
	local repos = io.open("repositories.csv", "r")
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
					print("Comparing against " .. fields[1]:trim())
					if fields[1]:trim():find(package_name) then
						print("Found " .. fields[1]:trim())
						return mtpm.fetch(fields[2]:trim(), true)
					end
				end
				repo:close()
			end
		end
	end
end

function mtpm.get_modlocation()
	local home = os.getenv("HOME")

	conf = io.open(home .. "/.mtpm.conf")
	if conf then
		for line in conf:lines() do
			local setting = line:split("=")
			if #setting == 2 then
				if setting[1]:trim() == "mod_location" then
					if core.is_dir(setting[2]:trim()) then
						return setting[2]:trim()
					else
						print(home .. "/.mtpm.conf : given modpath does not exist!")
						return
					end
				end
			end
		end
		conf:close()
	end

	local dir = home .. "/.minetest/mods/"
	if core.is_dir(dir) then
		return dir
	end

	return
end

function mtpm.prepare_archive(filepath, basename)
	if modfile.type == "zip" then
		local tempfolder = os.tempfolder()

		if tempfolder ~= nil and
			tempfolder ~= "" then
			core.create_dir(tempfolder)
			if core.extract_zip(modfile.name,tempfolder) then
				return tempfolder
			end
		end
	end
	local modfile = mtpm.identify_filetype(modfilename)
	local modpath = mtpm.extract(modfile)
	return modpath
end

function mtpm.install_mod(modpath, basename)
	if modpath == nil then
		gamedata.errormessage = fgettext("Install Mod: file: \"$1\"", modfile.name) ..
			fgettext("\nInstall Mod: unsupported filetype \"$1\" or broken archive", modfile.type)
		return
	end

	local basefolder = modmgr.getbasefolder(modpath)

	if basefolder.type == "modpack" then
		local clean_path = nil

		if basename ~= nil then
			clean_path = "mp_" .. basename
		end

		if clean_path == nil then
			clean_path = get_last_folder(cleanup_path(basefolder.path))
		end

		if clean_path ~= nil then
			local targetpath = core.get_modpath() .. DIR_DELIM .. clean_path
			if not core.copy_dir(basefolder.path,targetpath) then
				gamedata.errormessage = fgettext("Failed to install $1 to $2", basename, targetpath)
			end
		else
			gamedata.errormessage = fgettext("Install Mod: unable to find suitable foldername for modpack $1", modfilename)
		end
	end

	if basefolder.type == "mod" then
		local targetfolder = basename

		if targetfolder == nil then
			targetfolder = modmgr.identify_modname(basefolder.path,"init.lua")
		end

		--if heuristic failed try to use current foldername
		if targetfolder == nil then
			targetfolder = get_last_folder(basefolder.path)
		end

		if targetfolder ~= nil and modmgr.isValidModname(targetfolder) then
			local targetpath = core.get_modpath() .. DIR_DELIM .. targetfolder
			core.copy_dir(basefolder.path,targetpath)
		else
			gamedata.errormessage = fgettext("Install Mod: unable to find real modname for: $1", modfilename)
		end
	end

	core.delete_dir(modpath)
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

	if arg[1]:trim() == "config" then
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
	elseif arg[1]:trim() == "install" then
		local modloc = mtpm.get_modlocation()

		if modloc then
			-- file run directly
			local package_name = arg[2]
			print("Searching for " .. package_name)

			-- Download from the internet
			local modpath = mtpm.fetch(package_name)
			
			if modpath then
				-- Extract
				local tempfolder = os.tempfolder()
				core.extract_zip(modpath, tempfolder)
				print(mtpm.get_base_folder(tempfolder).type)
			else
				print("Package not found")
			end
		else
			print("Unable to find the mods/ directory. Fix using:")
			print("mtpm config mod_location /path/to/mods/")
		end
	else
		print("USAGE: mtpm install packagename")
	end
end
