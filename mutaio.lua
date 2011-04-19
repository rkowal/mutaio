------------------------------------------------------------------------------
-- (c) 2011 Radosław Kowalski <rk@bixbite.pl>                               --
-- mutaio "MUltiple TAble IO" module v0.11                                  --
-- Licensed under the same terms as Lua (MIT license).                      --
------------------------------------------------------------------------------

require"miscfuncs"

module(..., package.seeall)


--- Iterates over entries with specified localization. Single and multiple files are supported. There may be specified directory path as well.
-- @param where file or files paths, or directory where entries are located
-- @param r recursively flag
-- @param f filtering function - it gets a entry table as argument and its
-- @param callbackname name for entry callback function, it's optional
-- results deicide if entry is returned
-- @return an iterator returning entries in unspecified order
function entries(where, r, f, callbackname)
  assert(type(where) == "string", "where must be a string!")
  r = r or false
  assert(type(r) == "boolean", "r must be a boolean when specified!")
  callbackname = callbackname or "Entry"
  assert(type(callbackname) == "string", "callbackname must be a string when specified!")

  -- Variables to save (eventual) previous assignments to entry so multiple
  -- iterators can work at the same time.
  local entryfunc
  local entrycopy

  -- Set _G.entry function to intercept callback from data description files.
  if f == nil then                      -- no filtering function given, yield all entries
    entryfunc = function(t)
      _G[callbackname] = entrycopy
      coroutine.yield(t)
      entrycopy = _G[callbackname]
      _G[callbackname] = entryfunc
    end
  elseif type(f) == "function" then     -- entries filtering using f function
    entryfunc = function(t)
      _G[callbackname] = entrycopy
      if f(t) then
        coroutine.yield(t)
        entrycopy = _G[callbackname]
        _G[callbackname] = entryfunc
      end
    end
  else
    assert(true, "f must be a function when specified!")
  end

  return coroutine.wrap(function()
    for filepath in miscfuncs.list_dir(where, r and "r" or "") do
      -- TODO Think about encapsulating description files and handling parsing
      -- errors.
      local chunk = loadfile(filepath)
      entrycopy = _G[callbackname]
      _G[callbackname] = entryfunc
      if chunk then chunk() end
      _G[callbackname] = entrycopy
    end
  end)
end


-- Written data is partitioned in multiple files. It's so because every
-- write_entry has to read, parse, compare, modify entries as Lua tables and
-- then write them to file again. Too big single file would result in
-- increasing writing times. When entries are spread into multiple smaller
-- ones that time should be a lot more constant.
MAX_FILE_SIZE = 8192 * 4


--- Helper function. Returns a file path where the new entries can be written.
-- There are two major modes of operation:
--  * uses a strict filename with added postfix increments
--    (this needs to a filename to be explicitly specified) 
--  * uses randomly generated filenames
--    (this needs only a directory to be specified)
-- @param where file or files paths, or directory where entries are located
-- @return a filename to
local function filename_write_to(where)
  assert(type(where) == "string", "where must be a string!")

  local ftype = miscfuncs.filename_type(where)
  assert(ftype, "not existing file nor directory found!")
  local writeto
  -- TODO Encapsulate some repeating code below in a function or reorganize
  -- loop to the same effect.
  if ftype == "f" then
    -- Do incremental postfix filename.
    -- split file path to directory and name parts
    local dirpart, namepart = string.match(where, '^(.-)([^/]+)$')
    -- Find last used prefix (if at all) and smallest file to write.
    local f
    local increments = {}
    for finfo in miscfuncs.list_dir(dirpart, "i") do
      f = f or finfo                -- for first iteration set f just to first file info
      if string.match(finfo.filename, "^" .. namepart .. "%.?%d-$") then
        -- store postfix increments
        table.insert(increments, tonumber((string.match(finfo.filename, '%.(%d+)$')) or -1))
        -- if iterated file has smaller size then assign it to f
        if tonumber(f.size) > tonumber(finfo.size) then f = finfo end
      end
    end
    -- check if file is over threshold
    if tonumber(f.size) >= MAX_FILE_SIZE then
      -- then create a new one
      -- TODO math.max with unpack should work well but to what table size?
      writeto = namepart .. "." .. math.max(unpack(increments)) + 1
    else
      -- file size is under threshold, use the one found before 
      writeto = f.filename
    end
    -- add directory part to the result
    writeto = miscfuncs.join_paths(dirpart, writeto)
  elseif ftype == "d" then
    -- Do randomly generated filename.
    -- find potential smallest  file to write
    local f
    for finfo in miscfuncs.list_dir(where, "i") do
      f = f or finfo                -- for first iteration set f just to first file info
      -- if iterated file has smaller size then assign it to f
      if tonumber(f.size) > tonumber(finfo.size) then f = finfo end
    end
    if f then
      -- check if file is over threshold
      if tonumber(f.size) >= MAX_FILE_SIZE then
        writeto = miscfuncs.rand_filename(where)
      else
        -- file size is under threshold, use the one found before 
        writeto = f.filename
      end
    else    -- not file found in a directory so just generate the first one
        writeto = miscfuncs.rand_filename(where)
    end
    -- add directory part to the result
    writeto = miscfuncs.join_paths(where, writeto)
  end
  return writeto
end


--- Saves entry to a new file, existing file or a automatically chosen filename in specified directory.
-- There are two major modes of operation:
--  * uses a strict filename with added postfix increments
--    (this needs to a filename to be explicitly specified) 
--  * uses randomly generated filenames
--    (this needs only a directory to specified)
-- @param t a table containing an entry to be saved
-- @param callbackname name for entry callback function, it's optional
-- @return a value which evaluated to true means a completed save, a
-- nil or false when it has failed
function write_entry(t, where, callbackname)
  assert(type(t) == "table", "t must be a table!")
  assert(type(where) == "string", "where must be a string!")
  callbackname = callbackname or "Entry"
  assert(type(callbackname) == "string", "callbackname must be a string when specified!")

  local writeto = filename_write_to(where)
  if writeto then
    local f = io.open(writeto, "a+")
    if f then
      f:write("\n", miscfuncs.table_to_lua(t, callbackname), "\n")
      f:close()
    end
  end
end


--- Iterates and modify entries with specified localization. File fragmentation is supported. Entries modification is via callback function.
-- @param where file or files paths, or directory where entries are located
-- @param r recursively flag
-- @param f Rewriting function - it gets a entry table as argument and has to return:
--              - false if entry is to be omitted basically deleting it
--              - a table which replace current entry (modify)
--              - true or nil if entry should be retained
-- @param callbackname name for entry callback function, it's optional
-- Boolean "dichotomy" where only false deletes and true or nil retain is by
-- design.
-- If f function isn't specified then entries will read and written without
-- modifications.
-- @return number of read entries, number of rewrites, number of potential modified entries 
function rewrite_entries(where, r, f, callbackname)
  assert(type(where) == "string", "where must be a string!")
  r = r or false
  assert(type(r) == "boolean", "r must be a boolean when specified!")
  f = f or function(e) return true end
  assert(type(f) == "function", "f must be a function when specified!")
  callbackname = callbackname or "Entry"
  assert(type(callbackname) == "string", "callbackname must be a string when specified!")

  local read_count = 0
  local rewrite_count = 0
  local mod_count = 0
  local entrieslist

  local callbackcopy = _G[callbackname]

  _G[callbackname] = function(t)
    read_count = read_count + 1
    table.insert(entrieslist, t)
  end

  for filepath in miscfuncs.list_dir(where, r and "r" or "") do
    -- clear entrieslist
    entrieslist = {}
    -- load and parse data file into a Lua chunk
    local chunk = loadfile(filepath)
    if chunk then
      -- execute so entry callback function will be called
      chunk()
      -- now it's time to do rewriting
      local file = io.open(filepath, "w")
      for _, e in ipairs(entrieslist) do
        -- call rewriting function
        local res = f(e)
        -- only false boolean results in skipping writing (effectively delete)
        if res ~= false then
          rewrite_count = rewrite_count + 1
          if res == nil or res == true then         -- don't modify anything
            file:write("\n", miscfuncs.table_to_lua(e), "\n")
          elseif type(res) == "table" then          -- write potentially modified entry (modification)
            mod_count = mod_count + 1
            file:write("\n", miscfuncs.table_to_lua(res), "\n")
          else                                      -- if none of above then it is error...
            assert(false, "ERROR in entryio.rewrite_entries! Rewrite function has returned invalid value of type: '" .. type(res) .. "'")
          end
        end
      end
      file:close()
    end
  end
  -- set the call back function to previous state
  _G[callbackname] = callbackcopy
  -- return stats
  return read_count, rewrite_count, mod_count
end
