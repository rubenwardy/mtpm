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
			os.execute("wget " .. url .. " -O " .. filename .. " > /tmp/bleg.txt 2>&1")
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