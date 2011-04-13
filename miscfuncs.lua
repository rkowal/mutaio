------------------------------------------------------------------------------
-- (c) 2011 Radosław Kowalski <rk@bixbite.pl>                               --
-- miscellaneous functions module v0.3                                      --
-- Licensed under the same terms as Lua (MIT license).                      --
------------------------------------------------------------------------------

module(..., package.seeall)


-- Lua's reserved words
RESERVED_WORDS = {"local", "and", "break", "do", "else", "elseif", "end", "false", "for", "function", "if", "in", "local", "nil", "not", "or", "repeat", "return", "then", "true", "until", "while", "end"}

setmetatable(RESERVED_WORDS, {
  __index = function(t, k)
    for _, v in pairs(t) do
      if v == k then return true end
    end
  end
})


--- Try to determine if given string is url link.
-- @param s a string
-- @return true if s looks like url, false otherwise
function is_link(s)
  assert(type(s) == "string", "s must be a string!")
  -- Check for http prefix, length (too long shouldn't be a link) and spaces
  -- within.
  return ((string.match(s, '^http://') or string.len(s) <= 128) and not string.match(s, "%s")) and true or false
end


--- Quotes string using single, double quote or "[[]]" characters when applicable.
-- @param s string to be quoted
-- @return quoted string
function quote_string(s)
  assert(type(s) == "string", "s must be a string!")

  local ismultiline = string.match(s, "\n") and true or false
  local hassingleq = string.match(s, "'") and true or false
  local hasdoubleq = string.match(s, '"') and true or false

  if ismultiline or (hassingleq and hasdoubleq) then
    local l = 0
    for m in s:gmatch("]=-]") do l = math.max(l, #m - 1) end
    l = string.rep("=", l)
    return "[" .. l .. "[" .. s .. "]" .. l .. "]"
  elseif hasdoubleq then
    return "'" .. s .. "'"
  end

  return '"' .. s .. '"'
end


--- Utility for printing content of a table. Nested tables aren't supported for now.
-- @param t a table
-- @param trimto an optional number of characters used to triming values
-- @param noprint if set to true then function will not print anything (default is false)
-- @return prints list of table content
function dir(t, trimto, noprint)
  -- TODO improve this function
  assert(type(t) == "table", "t should be a table!")
  assert(trimto == nil or type(trimto) == "number", "trimto must be a number when specified!")
  noprint = noprint or false
  assert(type(noprint) == "boolean", "noprint must be a boolean when specified!")

  local res = {}

  for k, v in pairs(t) do
    table.insert(res, tostring(k) .. ": '" .. (trimto and string.sub(tostring(v), 1, trimto) or tostring(v)) .. "'")
  end

  res = table.concat(res, "\n")
  if not noprint then print(res) end
  return res
end


-- Put table constructor instead of nil to enable caching for load_url.
local cache_load_url = nil

--- Download and return (usually it'll be HTML) url content.
-- Just do as in a title. For now a external program (wget) is used
-- for that.
-- @param url The url address of page to be downloaded and returned.
-- @return String containing HTML content of a web page.
--         nil if it couldn't be finished.
function load_url(url)
  -- add some simple memoizing... (was useful for testing)
  if cache_load_url and cache_load_url[url] then return cache_load_url[url] end
--  print("load_url:", url)
  assert(type(url) == "string", "url parameter should be string!")
  local html
  local tmpname = os.tmpname()
  if tmpname then
    -- TODO eliminate this wget depedency
    if os.execute("wget -q '"..url.."' --output-document="..tmpname) == 0 then
      local f = io.open(tmpname, "r")
      html = f:read("*a")
      f:close()
    end
  end
  os.remove(tmpname)
  if cache_load_url then cache_load_url[url] = html end
  return html
end


--- Converts table to Lua source (serialize). Inner tables are supported. Cycles should get resolved in a literal way.
-- @param t a table to convert to Lua source
-- @entryname Naming of entry function prefixing table constructor. The
-- default is just "Entry".
-- @return Lua source
function table_to_lua(t, entryname)
  assert(type(t) == "table", "t must be a string!")
  entryname = entryname or "Entry"
  assert(type(entryname) == "string", "entryname must be a string when specified!")

  local list = {}
  local visited = {}

  local function do_table(t, lvl)
    -- check for possible cycles...
    if visited[t] then return end
    visited[t] = true

    for k, v in pairs(t) do
      -- check and quote (if needed) the key
      local key
      if type(k) == "string" then
        -- Just to be safe check if a key isn't one of Lua's reserved words.
        if RESERVED_WORDS[k] then                   -- if so put in "[]" with quotes
          key = '["' .. k .. '"]'
        elseif string.match(k, "[^%d%a_]+") then    -- check if there is just one non alphanumeric (and _) character
          key = '[' .. string.format("%q", k) .. ']'
        else                                        -- not special quoting needed
          key = k
        end
      elseif type(k) == "number" then
        key = '[' .. k .. ']'                       -- "[]" with number index
      else                                          -- no proper key type so assert an error
        assert(false, "only keys being number or string are supported!")
      end

      local spaces = string.rep(" ", lvl * 2)
      -- check the value
      local val
      if type(v) == "string" then       -- quote string
        val = quote_string(v)
        table.insert(list,  spaces .. key .. " = " .. val .. ",")
      elseif type(v) == "number" then   -- number to string
        val = tostring(v)
        table.insert(list, spaces .. key .. " = " .. val .. ",")
      elseif type(v) == "table" then    -- inner table
        table.insert(list, spaces .. key .. " = {")
        do_table(v, lvl + 1)
        table.insert(list, spaces .. "},")
      end
    end
    -- done with this table so uncheck as visited
    visited[t] = nil
  end

  do_table(t, 1)
  -- and opening and closing "{}" and concat results
  table.insert(list, 1, entryname .. " {")
  table.insert(list, "}")
  return table.concat(list, "\n")
end


--- Join multiple paths with correct number of '/' separators.
-- The first and last subpath will have theirs first and last '/' characters
-- retained.
-- @param ... multiple string arguments to be joined
-- @return ready path
function join_paths(...)
  local last = select("#", ...)
  assert(last > 0, "got no argument to join!")
  local paths = {}

  if last == 1 then return select(1, ...) end

  for idx = 1, last do
    -- don't trim prefix '/' of the first path
    if idx ~= 1 then
      paths[idx] = string.gsub(select(idx, ...), "^/+", "")
    end
    -- don't trim postfix '/' of the last path
    if idx ~= last then
      paths[idx] = string.gsub(select(idx, ...), "/+$", "")
    end
  end
  return table.concat(paths, "/")
end


--- Escape Lua pattern magic characters "[().%+-*?[^$]" using escape "%".
-- @param s a string to be escaped
-- @return just an escaped string
function escape_magic_chars(s)
  assert(type(s) == "string", "s must be a string!")

  return (string.gsub(s, '([().%+-*?^$%]%[%%])', '%%%1'))
end


--- Splits a path into parts in table. The slash ("/") character is used as delimiter.
-- @param path a path to be split into parts
function split_path(path)
  assert(type(path) == "string", "s must be a string!")

  local reslist = {}
  for part in string.gmatch(path, '([^/]+)') do
    table.insert(reslist, part)
  end
  return reslist
end


--- Try to extract a filename part from a path.
-- @param path a path in the file system
-- @return file name of a path, or nil if there isn't one
function path_filename(path)
  assert(type(path), "path must be a string!")

  return string.match(path, '([^/]+)$')
end


--- Add next number postfix to filename. It must exists and itself doesn't end with increment postfix.
-- @param path Path to a file. 
-- @return incremented path, incremented number 
function increment_filename(path)
  assert(type(path) == "string", "path must be a string!")
  -- Does this file exist at all?
  assert((function()
    local f = io.open(path, "r")
    if f then f:close() return true end
    return false
  end)(), "path must point to an existing file!")
  assert(not string.match(path, '%.%d+$'), "filename in path can not have postfix increment!")

  -- split file path to directory and name parts
  local dirpart, namepart = string.match(trimpath, '^(.-)([^/]+)$')
  local lastnum = -1
  -- check all files in directory
  for f in list_dir(dirpart) do
    -- and within those only ones matching given filename
    if string.match(f, '^[./]-' .. namepart) then
      -- try to extract last number
      local num = tonumber(string.match(f, '%.(%d+)$'))
      -- remember the largest one
      if num and num > lastnum then lastnum = num end
    end
  end
  -- if there wasn't any numbering scheme before start with default "2"
  lastnum = lastnum >= 0 and lastnum + 1 or 2
  return trimpath .. "." .. lastnum, lastnum
end


--- Generate pseudo random filename which will not collide with other filenames in directory.
-- @param dirpath A path to a target directory for the new randomized
-- filename. Can be omitted when check for existing files isn't needed.
-- @param length the length a length of generated filename (default is 8)
-- @param ext the extension of generated filename (default is "lua")
-- @return a new random file name
function rand_filename(dirpath, length, ext)
  assert(dirpath == nil or type(dirpath) == "string", "dirpath must be a string if specified!")
  length = length or 8
  assert(type(length) == "number", "length should be a number if specified!")
  ext = ext or "lua"
  assert(type(ext) == "string", "ext should be a string if specified!")

  local existingnames = {}
  if dirpath then
    for f in list_dir(dirpath, "i") do          -- get file list with details
      -- just remember filenames alone with removed extensions
      table.insert(existingnames, (string.gsub(f.filename, '%..-$', '')))
    end
  end

  local randname
  repeat
    randname = ""
    for i = 1, length do
      -- characters to be used, for other than first add digits too
      local c = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ' .. (i > 1 and "0123456789" or "")
      local rnd = math.random(#c)
      randname = randname .. string.sub(c, rnd, rnd)
    end
  until dirpath == nil or (function()
    -- check if there isn't such name already
    for _, v in ipairs(existingnames) do if v == randname then return false end end
    return true
  end)()

  return randname .. "." .. ext
end


--- Return file type at the given path.
-- @param path to a file to be checked for
-- @return a nil if file isn't found, "f" if it's a file, "d" if it's a directory
function filename_type(path)
  assert(type(path) == "string", "path must be a string!")

  -- TODO eliminate file command dependency
  local cmd = io.popen("file " .. path)
  if cmd then
    local s = cmd:read("*a")
    cmd:close()
    if string.match(s, '%(No such file or directory%)') then
      return nil
    elseif string.match(s, '^[^:]-:%s+directory') then
      return 'd'
    end
    -- if previous conditions weren't met then it must be a file
    return "f"
  end
end


--- Just return file length.
-- @param path a path to the file
-- @return file length in bytes or nil if it couldn't be found
function file_lenght(path)
  assert(type(path) == "string", "path must be a string!")

  local f = io.open(path, "r")
  if f then
    local size = f:seek("end")
    f:close()
    return size
  end
end


--- Iterates over files located in path specified directory. Global like characters "*" and "?" supported. They should be entered in file name part and will be used only when matching file names only (don't have any effect on directories).
-- @param path a path to a directory
-- @param options there actually two additional supported options (case insensitive):
--                "r" - list recursively
--                "i" - returns a table containing detailed file information 
-- @return iterator returning filenames in arbitrary order
function list_dir(path, options)
  assert(type(path) == "string", "path must be a string!")
  options = options or ""
  assert(type(options) == "string", "mode must be a string when specified!")

  -- check if a table with detailed file info has to returned
  local fullinfo = string.match(options, "[iI]") and true or false
  -- check if directory listing has to work recursively
  local recursively = string.match(options, "[rR]") and true or false
  local globpat

  -- Check if there are global ("*" and "?") characters in a path?
  do
    -- split path into two parts where the latter is the last
    local p, lastpart = string.match(path, '^(.-)([^/]+)$')
    -- Check if there was a lone name specified it wasn't a directory.
    if (p == nil or #p == 0 or p == "./") and filename_type(path) == "d" then
      p = path
      lastpart = nil
    end
    -- it's enough to have lastpart only to consider it as glob pattern
    if lastpart then
      -- substitute glob character to pattern ones
      globpat = string.gsub(lastpart, '.', function(c)
        if c == "*" then return '.-'
        elseif c == '?' then return '.'
        else return escape_magic_chars(c) end
      end)
      -- pattern should be anchored for both sides
      globpat = "^" .. globpat .. "$"
      -- effectively trim path from the last part being used as glob
      path = p
    end
  end

  return coroutine.wrap(function()
    -- As Lua doesn't have library options for that use shell one.
    -- TODO eliminate this dependency
    local dirio = io.popen("ls -l --time-style=long-iso " .. (recursively and "-R " or "") .. path)
    if dirio then
      -- Assume that if dirname in ls output will not be found then just use
      -- starting path.
      local dirname = path
      for line in dirio:lines() do
        -- Try to match current ls directory path but only if in recursive
        -- mode.
        if recursively then
          dirname = string.match(line, '^([./]?.*):$') or dirname
        end
        -- try to match an output of "ls" command
        local mode, hardlinks, user, group, size, date, time, filename = string.match(line, '^([-d][r-][w-][x-][r-][w-][x-][r-][w-][x-])%s+(%d+)%s+([^%s]+)%s+([^%s]+)%s+(%d+)%s([^%s]+)%s+([^%s]+)%s+(.+)$')
        if mode then
          local isdir = string.match(mode, "^d") and true or false
          local fileinfo = {mode = mode, hardlinks = hardlinks, user = user, group = group,
                                size = size, date = date, time = time, filename = filename,
                                isdir = isdir, dirname = dirname}
          -- Directories should be omitted as well as filenames what don't fit
          -- a glob pattern (if specified).
          if not isdir and (not globpat or string.match(filename, globpat)) then
            if fullinfo then
              coroutine.yield(fileinfo)
            else
              coroutine.yield(join_paths(dirname, filename))
            end
          end
        end
      end
    end
  end)
end


--- Generate randomized table based on provided template.
-- @t A template in table format. Keys are constant and should have string
-- type. Their values may be list of strings or just strings. The latter will
-- be split using "," as delimiter. Eventually instead of list/string a
-- function can be given. It should return a (supposedly random) value or list
-- of possible values to chosen randomly.
-- @return randomized table
function rand_table(t)
  assert(type(t) == "table", "t must be a table!")

  local randtab = {}
  for k, v in pairs(t) do
    -- check keys, values (or generate them)
    assert(type(k) == "string", "key within t must have a string type!")
    -- value can be a string, then try split it using a "," as delimiter
    if type(v) == "string" then
      local values = {}
      -- split, trim and insert values into list
      string.gsub(v, '([^,]+)', function(s) table.insert(values, string.match(s, '%s-(%S+)%s-')) end)
      v = values
    elseif type(v) == "function" then
      v = v()
      -- enclose returned value in a table for code below to work correctly
      if type(v) ~= "table" then v = {v} end
    end
    assert(type(v) == "table", "couldn't find or generate value table within t!")
    -- put randomly chosen value into table
    randtab[k] = v[math.random(#v)]
  end
  return randtab
end


--- Return table size including list and dictionary elements.
-- @param t table to be counted for its size
-- @return size of table
function table_size(t)
  assert(type(t) == "table", "t must be a table!")

  local count = 0
  for _, _ in pairs(t) do count = count + 1 end
  return count
end


--- Similarity of two tables returning number in 0.0 - 1.0 range. One means both tables are exactly the same. Both keys and values are used for that computation.
-- @param t1 table to be compared
-- @param t2 table to be compared
-- @return similarity number in 0.0 - 1.0 range
function table_similarity(t1, t2)
  assert(type(t1) == "table", "t1 must be a table!")
  assert(type(t2) == "table", "t2 must be a table!")

  local commonkeys = 0
  local commonvalues = 0
  for k, _ in pairs(t1) do
    -- check if key is common
    if t2[k] then
      commonkeys = commonkeys + 1
      -- compare common keys values and count them when equal
      if t1[k] == t2[k] then commonvalues = commonvalues + 1 end
    end
  end

  local maxkeynum = math.max(table_size(t1), table_size(t2))
  local similarity = (commonkeys + commonvalues) / (maxkeynum * 2)
  return similarity
end


--- Similarity of two tables including possible inner tables. Return number in range of 0.0 - 1.0. One means both tables have identical keys and values.
-- @param t1 table to be compared
-- @param t2 table to be compared
-- @return similarity number in 0.0 - 1.0 range
function table_similarity2(t1, t2)
  assert(type(t1) == "table", "t1 must be a table!")
  assert(type(t2) == "table", "t2 must be a table!")

  -- split t into table and nontable values
  local function splittable(t)
    local tables = {}
    local nontables = {}
    for k, v in pairs(t) do
      if type(v) == "table" then tables[k] = v
      else nontables[k] = v end
    end
    return tables, nontables
  end

  -- split t1 and t2 tables
  local tab1, non1 = splittable(t1)
  local tab2, non2 = splittable(t2)
  -- compare nontable values and put in the list
  local sims = {table_similarity(non1, non2)}

  -- if there are any inner tables within arguments...
  for k1, v1 in pairs(tab1) do
    local hasbreak = false
    for k2, v2 in pairs(tab2) do
      if k1 == k2 then
        hasbreak = true
        table.insert(sims, table_similarity2(v1, v2))
        break
      end
    end
    if not hasbreak then table.insert(sims, 0) end
  end

  local sum = 0
  -- count and return average of all accumulated similarities
  for _, v in ipairs(sims) do sum = sum + v end
  return sum / #sims
end


--- Merges multiple specified tables.
-- @param ... tables to merge, the first ones' entries will take precedence
-- @return a new table with merged entries
function table_merge(...)

  local function hasvalue(t, v)
    for _, _v in ipairs(t) do
      if _v == v then
        return true
      end
    end
    return false
  end

  local res = {}
  local indexed = {}
  -- Iterate in reverse order so first function arguments will take
  -- precedence.
  for i = select("#", ...), 1, -1 do
    local t = select(i, ...)
    assert(type(t) == "table", "only tables are possible to merge!")
    -- first add list like data
    for i, v in ipairs(t) do
      -- don't duplicate elements in list
      if not hasvalue(indexed, v) then
        table.insert(res, v)
        table.insert(indexed, v)
      end
    end
    -- second add key and value pairs
    for k, v in pairs(t) do
      -- don't duplicate indexed values
      if type(k) ~= "number" or not hasvalue(indexed, v) then res[k] = v end
    end
  end
  return res
end
