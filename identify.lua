function mtpm.get_base_folder(path)
	if path == nil or path == "" then
		return {
			type = "invalid",
			path = ""
		}
	end

	local testfile = io.open(path .. mtpm.DIR_DELIM .. "init.lua", "r")
	if testfile then
		testfile:close()
		return {
			type = "mod",
			path = temppath
		}
	end

	testfile = io.open(path .. mtpm.DIR_DELIM .. "modpack.txt", "r")
	if testfile then
		testfile:close()
		return {
			type = "modpack",
			path = temppath
		}
	end

	local subdirs = core.get_dir_list(path, true)

	--only single mod or modpack allowed
	if #subdirs ~= 1 then
		return {
			type = "invalid",
			path = ""
		}
	end

	testfile = io.open(path .. mtpm.DIR_DELIM .. subdirs[1] ..
			mtpm.DIR_DELIM .."init.lua", "r")
	if testfile then
		testfile:close()
		return {
			type = "mod",
			path = path .. mtpm.DIR_DELIM .. subdirs[1]
		}
	end

	testfile = io.open(path .. mtpm.DIR_DELIM .. subdirs[1] ..
			mtpm.DIR_DELIM .. "modpack.txt", "r")
	if testfile then
		testfile:close()
		return {
			type = "modpack",
			path = path .. mtpm.DIR_DELIM .. subdirs[1]
		}
	end

	return {
		type = "invalid",
		path = ""
	}
end

function mtpm.identify_modname(modpath, filename)
	if not filename then
		filename = "init.lua"
	end

	local testfile = io.open(modpath .. mtpm.DIR_DELIM .. filename, "r")
	if testfile then
		local line = testfile:read()

		while line do
			local modname

			if line:find("minetest.register_tool") or
					line:find("minetest.register_craftitem") or
					line:find("minetest.register_node") then
				modname = mtpm.parse_register_line(line)
			end

			if line:find("dofile") then
				modname = mtpm.parse_dofile_line(modpath,line)
			end

			if modname then
				testfile:close()
				return modname
			end

			line = testfile:read()
		end
		testfile:close()
	end
end

function mtpm.parse_register_line(line)
	-- Called by identify_modname, looks at itemname in minetest.register_*()
	local pos1 = line:find("\"")
	local pos2
	if pos1 then
		pos2 = line:find("\"", pos1 + 1)
	end

	if pos1 and pos2 then
		local item = line:sub(pos1 + 1, pos2 - 1)

		if item and item ~= "" then
			local pos3 = item:find(":")

			if pos3 then
				local retval = item:sub(1, pos3 - 1)
				if retval and retval ~= "" then
					return retval
				end
			end
		end
	end
end

function mtpm.parse_dofile_line(modpath,line)
	local pos1 = line:find("\"")
	local pos2
	if pos1 then
		pos2 = line:find("\"", pos1 + 1)
	end

	if pos1 and pos2 then
		local filename = line:sub(pos1 + 1, pos2 - 1)

		if filename and filename ~= "" and filename:find(".lua") then
			return mtpm.identify_modname(modpath,filename)
		end
	end
end

function mtpm.identify_filetype(name)
	if name:sub(-3):lower() == "zip" then
		return {
			name = name,
			type = "zip"
		}
	end

	if name:sub(-6):lower() == "tar.gz" or
		name:sub(-3):lower() == "tgz"then
		return {
			name = name,
			type = "tgz"
		}
	end

	if name:sub(-6):lower() == "tar.bz2" then
		return {
			name = name,
			type = "tbz"
		}
	end

	if name:sub(-2):lower() == "7z" then
		return {
			name = name,
			type = "7z"
		}
	end

	return {
		name = name,
		type = "ukn"
	}
end
