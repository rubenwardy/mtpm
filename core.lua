string.trim = string.trim or function(self)
	return (self:gsub("^%s*(.-)%s*$", "%1"))
end

string.replace = string.replace or function(self, from, to)
	return self:gsub("%" .. from, to)
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
	for i = 1, #arg do
		local item = arg[i]
		if item then
			str = str:replace("$" .. i, item)
		end
	end
	return str
end

local function findpath(settingname, mtname)
	return (function()
		local home = os.getenv("HOME")
		local conf = Config(home .. "/.mtpm.conf")

		-- Check mod_location
		local path = conf:get(settingname.."_location")
		if path then
			if core.is_dir(path) then
				return path .. "/"
			else
				print(home .. "/.mtpm.conf : given " .. settingname .. " path does not exist!")
				return
			end
		end

		-- Check minetest_root
		path = conf:get("minetest_root")
		if path then
			path = path  .. "/" .. mtname .. "/"
			if core.is_dir(path) then
				return path .. "/"
			else
				print(home .. "/.mtpm.conf : $(minetest_root)/" .. mtname .. "/ does not exist!")
				return
			end
		end

		-- Check ~/.minetest/
		local dir = home .. "/.minetest/" .. mtname .. "/"
		if core.is_dir(dir) then
			return dir
		else
			return
		end
	end)
end

DIR_DELIM = DIR_DELIM or "/"
core = core or (function()
	package.path = package.path .. os.getenv("HOME") .. ";" .. "/.luarocks/lib/lua/5.1/?.lua;"
	package.path = package.path .. os.getenv("HOME") .. "/.luarocks/lib/lua/5.1/?/init.lua;"
	package.cpath = package.cpath .. ";" .. os.getenv("HOME") .. "/.luarocks/lib/lua/5.1/?.so;"
	local zip  = require("zip")
	local lfs  = require("lfs")
	local json = require("json")

	--local curl = require "luacurl"
	return {
		parse_json = json.decode,
		is_standalone = true,
		file_exists = function(filepath)
			f = io.open(filepath, "rb")
			if f then
				f:close()
				return true
			end
			return false
		end,
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
				if core.is_dir(directory .. DIR_DELIM .. file) and
				 		file ~= "." and file ~= ".." then
					table.insert(retval, file)
				end
			end
			return retval
		end,
		get_modpath = findpath("mod", "mods"),
		get_gamepath = findpath("subgame", "games"),
		download_file = function(url, filename)
			-- TODO: fix this (security issue)
			os.execute("wget " .. url .. " -O " .. filename .. " > /tmp/bleg.txt 2>&1")
			if true then
				f = io.open(filename, "rb")
				if f then
					f:close()
					return true
				end
				print("Download failed: " .. url)
				return false
			end

			--[[print("doing")
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
			print("done")]]--
		end,
		extract_zip = function(filepath, path)
			local zfile, err = zip.open(filepath)

			if not zfile then
				return false
			end

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

			return true
		end
	}
end)()
