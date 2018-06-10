local item_type = os.getenv('item_type')
local item_value = string.lower(os.getenv('item_value'))
local item_dir = os.getenv('item_dir')
local warc_file_base = os.getenv('warc_file_base')

local url_count = 0
local tries = 0
local abortgrab = false

local extracted_data = {}

read_file = function(file)
  if file then
    local f = assert(io.open(file))
    local data = f:read("*all")
    f:close()
    return data
  else
    return ""
  end
end

wget.callbacks.download_child_p = function(urlpos, parent, depth, start_url_parsed, iri, verdict, reason)
  local url = urlpos["url"]["url"]
  local html = urlpos["link_expect_html"]

  return false
end

wget.callbacks.get_urls = function(file, url, is_css, iri)
  local html = read_file(file)

  if string.match(html, 'aria%-label="[0-9]+%s+users?%s+starred%s+this%s+repository"') then
    local repo = string.match(url, "^https?://[^/]*github%.com/([^/]+/[^/]+)")
    local stars = string.match(html, 'aria%-label="([0-9]+)%s+users?%s+starred%s+this%s+repository"')
    local forks = string.match(html, 'aria%-label="([0-9]+)%s+users?%s+forked%s+this%s+repository"')
    local watchers = string.match(html, 'aria%-label="([0-9]+)%s+users?%s+are%s+watching%s+this%s+repository"')
    if repo == nil or stars == nil or forks == nil or watchers == nil then
      abortgrab = true
    end
    extracted_data[repo .. ':' .. watchers ..  ':' .. stars .. ':' .. forks] = true
  end
end

wget.callbacks.httploop_result = function(url, err, http_stat)
  status_code = http_stat["statcode"]

  url_count = url_count + 1
  io.stdout:write(url_count .. "=" .. status_code .. " " .. url["url"] .. "  \n")
  io.stdout:flush()

  if abortgrab == true then
    io.stdout:write("ABORTING...\n")
    return wget.actions.ABORT
  end
  
  if status_code >= 500 or
    (status_code >= 400 and status_code ~= 404) or
    status_code == 0 then
    io.stdout:write("Server returned "..http_stat.statcode.." ("..err.."). Sleeping.\n")
    io.stdout:flush()
    os.execute("sleep 1")
    tries = tries + 1
    if tries >= 5 then
      io.stdout:write("\nI give up...\n")
      io.stdout:flush()
      tries = 0
      return wget.actions.ABORT
    else
      return wget.actions.CONTINUE
    end
  end

  tries = 0

  local sleep_time = 0

  if sleep_time > 0.001 then
    os.execute("sleep " .. sleep_time)
  end

  return wget.actions.NOTHING
end

wget.callbacks.finish = function(start_time, end_time, wall_time, numurls, total_downloaded_bytes, total_download_time)
  local file = io.open(item_dir..'/'..warc_file_base..'_data.txt', 'w')
  for data, _ in pairs(extracted_data) do
    file:write(data .. "\n")
  end
  file:close()
end

wget.callbacks.before_exit = function(exit_status, exit_status_string)
  if abortgrab == true then
    return wget.exits.IO_FAIL
  end
  return exit_status
end
