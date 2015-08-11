-- Search in specific repo
-- @return boolean, true is success
function mtpm.search_in_repo(repo, details)
	-- JSON Bower
	if repo.format == "json-bower" then
		local tmp = os.tempfolder()
		if not core.download_file(repo.url, tmp .. "tmp.json") then
			return false
		end

		local f = io.open(tmp .. "tmp.json", "r")
		if not f then
			return false
		end
		local data = core.parse_json(f:read("*all"))
		f:close()

		if not data or #data <= 0 then
			return false
		end

		for i = 1, #data do
			local entry = data[i]

			-- TODO: check author

			if entry.name and entry.url and details.basename == entry.name then
				details.basename = entry.name
				local author, repon = string.match(entry.url, "github.com/([%a%d_-]+)/([%a%d_-]+)")
				if author and repon then
					entry.url = "http://github.com/" .. author .. "/" .. repon .. "/archive/master.zip"
				end
				details.url = entry.url
				details.repo = repo.title
				return true
			end
		end

	-- JSON-QUERY
	elseif repo.format == "json-q" then
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

		if not data or data.error or not data.title then
			return false
		end

		if details.author and data.author:lower() ~= details.author:lower() then
			return false
		end

		if details.basename then
			local basename = string.match(data.title, "%[([%a%d_]+)%]")
			if details.basename ~= basename then
				print("   - Wrong result: " .. data.title .. ". Wanted " .. details.basename)
				return false
			end
		end

		if data and not data.error and data.download then
			details.url = data.download
			details.repo = repo.title
			return true
		end

	-- CSV-ABU (Author, Basename, URL)
	elseif repo.format == "csv-abu" then
		local tmp = os.tempfolder()
		if not core.download_file(repo.url, tmp .. "tmp.csv") then
			return false
		end

		local f = io.open(tmp .. "tmp.csv", "r")
		if not f then
			return false
		end

		for line in f:lines() do
			local data = line:split(",")
			if #data >= 3 and #data <= 5 then
				local author = data[1]:trim()
				local basename = data[2]:trim()
				local url = data[3]:trim()

				if details.basename == basename and
						(not details.author or author:lower() == details.author:lower()) then
					details.author = author
					details.basename = basename
					local author, repon = string.match(url, "github.com/([%a%d_-]+)/([%a%d_-]+)")
					if author and repon then
						url = "http://github.com/" .. author .. "/" .. repon .. "/archive/master.zip"
					end
					details.url = url
					details.repo = repo.title
					return true
				end
			end
		end

		return false

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
		details.repo = repo.title
		return true
	end
	return false
end


-- Search all repos for a package described by details
-- @return boolean, true is success
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
	return false
end


-- Actually installs a mod
-- @return 0, msg - failed
-- @return 1, nil - done
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


-- Installs package from its extracted folder
-- @return 0, msg - failed
-- @return 1, nil - done
-- @return 2, msg - up to date / already installed
function mtpm.install_folder(details, dir, override)
	local basefolder = mtpm.get_base_folder(dir)

	-- Check package type is correct
	if details.type then
		if details.type == "mod" and basefolder.type ~= "mod" and basefolder.type ~= "modpack" then
			return 0, fgettext("Failed to install $1 : it is not a mod or modpack", modpath)
		elseif details.type ~= basefolder.type then
			return 0, fgettext("Failed to install $1 : it is not $2", modpath, check_is_type)
		end
	end

	-- Install modpack
	if basefolder.type == "modpack" then
		local clean_packname

		if details.basename then
			clean_packname = "mp_" .. details.basename
		else
			-- TODO: better basename creation.
			clean_packname = "mp_1"
		end

		return doinstall_mod(dir, basefolder, clean_packname, override)

	-- Install mod
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

	-- Invalid package type
	else
		return 0, fgettext("Unrecognised package type at $1!", dir)
	end
end


-- Installs a package from its archive
-- @return 0, msg - failed
-- @return 1, nil - done
-- @return 2, msg - up to date / already installed
function mtpm.install_archive(details, override)
	-- Extract
	local tempfolder = os.tempfolder()
	if core.extract_zip(details.archive, tempfolder) then
		return mtpm.install_folder(details, tempfolder, override)
	else
		return 0, fgettext("Could not extract archive $1", details.archive)
	end
end


-- Installs a package from its details
-- @return 0, msg - failed
-- @return 1, nil - done
-- @return 2, msg - up to date
-- @return 3, msg - not found
function mtpm.install(details)
	--if details.basename == "default" then
	--	return 2, fgettext("$1 is already installed (minetest_game)", details.basename)
	--end

	-- Search in repositories
	if not details.url and not details.archive and details.basename then
		if mtpm.search_repos(details) then
			print("   - Found " .. details.basename .. " in " .. details.repo)
		else
			return 3, "Could not find " .. details.basename
		end
	end

	-- Download
	if details.url and not details.archive then
		print("   - Downloading from " .. details.url)
		local tmp = os.tempfolder()
		if core.download_file(details.url, tmp .. "tmp.zip") then
			details.archive = tmp .. "tmp.zip"
		else
			return 0, "Could not download " .. details.url
		end
	end

	if details.archive then
		print("   - Installing...")
		return mtpm.install_archive(details, override)
	else
		return 0, "Error getting archive for " .. details.basename
	end
end


-- Parse query like `username/password>=version@repo`
-- @return `details, nil`
-- @return `nil, msg` on error
function mtpm.parse_query(query)
	if not query then
		return nil, fgettext("Invalid empty query $1", query)
	end

	query = query:trim()
	local retval = {}

	-- Look for HTTP queries
	if query:sub(1, 4) == "http" and query:find(":") <= 6 then
		return {
			url = query
		}

	-- Look for file system queries
	elseif core.file_exists(query) then
		return {
			archive = query
		}
	end

	-- Look for author/basename queries
	local author, basename = string.match(query, "^([%a%d_]+)/([%a%d_]+)")
	if author and basename then
		retval.author = author:trim()
		retval.basename = basename:trim()
		query = query:sub(#author + #basename + 2, #query):trim()

	-- Look for basename queries
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

	-- Get repo selectors
	retval.repo = string.match(query, "@([%a%d_-]+)")

	-- TODO: get versions selectors (>version, >=version)
	-- TODO: get type selects (#type)

	return retval, nil
end

-- Parses and runs a query
-- @return `0, nil` - success
-- @return `1, msg` - failure
-- @return `2, msg` - up to date
-- @return `3, msg` - not found
function mtpm.run_query(query)
	local details, msg = mtpm.parse_query(query)
	if not details then
		return 1, msg
	end

	return mtpm.install(details)
end
