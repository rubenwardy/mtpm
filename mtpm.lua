#!/usr/bin/lua

string.trim = string.trim or function(self)
	return (self:gsub("^%s*(.-)%s*$", "%1"))
end

string.split = string.split or function(self, delim, include_empty, max_splits, sep_is_pattern)
	delim = delim or ","
	max_splits = max_splits or -1
	local items = {}
	local pos, len, seplen = 1, #self, #delim
	local plain = not sep_is_pattern
	max_splits = max_splits + 1
	repeat
		local np, npe = self:find(delim, pos, plain)
		np, npe = (np or (len+1)), (npe or (len+1))
		if (not np) or (max_splits == 1) then
			np = len + 1
			npe = np
		end
		local s = self:sub(pos, np - 1)
		if include_empty or (s ~= "") then
			max_splits = max_splits - 1
			table.insert(items, s)
		end
		pos = npe + 1
	until (max_splits == 0) or (pos > (len + 1))
	return items
end

fgettext = fgettext or function(str, ...)
	-- TODO: support fgettext in standalone
	return str
end

DIR_DELIM = DIR_DELIM or "/"
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
			lfs.mkdir(directory)
		end,
		delete_dir = function(dir)
			os.execute("rm " .. dir .. " -r")
		end,
		copy_dir = function(from, to)
			-- TODO: fix this (security issue)
			os.execute("cp " .. from .. " " .. to .. " -r")
			return true
		end,
		get_dir_list = function(directory)
			if not directory then
					return
			end
			local retval = {}
			for file in lfs.dir(directory) do
				if core.is_dir(directory .. file) and
				 		file ~= "." and file ~= ".." then
					table.insert(retval, file)
				end
			end
			return retval
		end,
		get_modpath = function()
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
		end,
		download_file = function(url, filename)
			-- TODO: fix this (security issue)
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
				if file.filename:sub(idx, idx) == DIR_DELIM then
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
	DIR_DELIM = "/",
	res = "",
}

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

function command_install(reinstall)
	local modloc = core.get_modpath()
	
	if modloc then
		for i = 2, #arg do
			-- file run directly
			local package_name = arg[i]
			print("Searching for " .. package_name)

			-- Download from the internet
			local details = mtpm.fetch(package_name)
			print(details.path)
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
		command_install(false)
	elseif arg[1]:trim() == "update" then
		command_install(true)
	elseif arg[1]:trim() == "reinstall" then
		command_install(true)
	else
		print("USAGE: mtpm install packagename")
	end
end
