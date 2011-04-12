------------------------------------------------------------------------------
-- (c) 2011 Radosław Kowalski <rk@bixbite.pl>                               --
-- mutaio example/tests                                                     --
-- Licensed under the same terms as Lua (MIT license).                      --
------------------------------------------------------------------------------

require"miscfuncs"
require"mutaio"


------------------------------------------------------------------------------
-- few utility things                                                       --
------------------------------------------------------------------------------

-- where data has to be written
TEST_DIRECTORY = "test_data/"
-- how many entries use for tests?
ENTRIES_NUMBER = 200


-- a object for convenient generating randomized tables
RandomTable = {
  alphabet = "abcdefghijklmnopqrstuvwxyz",
  colors = {"black", "blue", "red", "magenta", "green", "cyan", "yellow", "white"},
  otherwords = {"airplane", "foobar", "chair", "table", "door", "pencil", "sheet"},
  count = 0,

  template = {
    count = function()
      RandomTable.count = RandomTable.count + 1
      return RandomTable.count
    end,

    hash = function()
      local res = ""
      for i = 1, 16 do
        local idx = math.random(#RandomTable.alphabet)
        res = res .. string.sub(RandomTable.alphabet, idx, idx)
      end
      return res
    end,

    color = function() return RandomTable.colors end,

    word = function() return RandomTable.otherwords end,

    words = function()
      local allwords = miscfuncs.table_merge(RandomTable.colors, RandomTable.otherwords)
      local howmany = math.random(2, 20)
      local res = {}
      for i = 1, howmany do
        table.insert(res, allwords[math.random(#allwords)])
      end
      return table.concat(res, " ")
    end,
  },

  rand_template = function(self)
    local t = miscfuncs.rand_table(self.template)
    t.inner_table = miscfuncs.rand_table(self.template)
    return t
  end,

  new = function(self, o)
    o = o or {}
    o = miscfuncs.table_merge(o, self:rand_template())
    setmetatable(o, {__index = self})
    return o
  end,

  to_lua = function(self)
    local s = miscfuncs.table_to_lua(self)
    return s
  end,
}
setmetatable(RandomTable, {__index = RandomTable})


function progress_printer(fullcount, printper)
  assert(type(fullcount) == "number" and fullcount >= 1, "fullcount must be number equal or bigger than 1!")
  if printper then
    assert(type(printper) == "number", "printper must be a number when specified!")
    printper = printper > 1 and math.floor(printper) or 1
  else
    printper = 1
  end

  local count = 0
  print(count .. "/" .. fullcount)

  return function()
    count = count + 1
    assert(count <= fullcount, "count get over limit: " .. fullcount .. "!")
    if count % printper == 0 or count == fullcount then print(count .. "/" .. fullcount) end
  end
end


------------------------------------------------------------------------------
-- examples/tests begin here                                                --
------------------------------------------------------------------------------

-- generate random tables and write them...
print("generating random entries...")
local prog = progress_printer(ENTRIES_NUMBER, 50)
for i = 1, ENTRIES_NUMBER do
  local t = RandomTable:new()
  mutaio.write_entry(t, TEST_DIRECTORY)
  prog()
end

-- try just read and count them back
print("checking number of generated entries...")
prog = progress_printer(ENTRIES_NUMBER, 50)
local count = 0
for e in mutaio.entries(TEST_DIRECTORY) do
  count = count + 1
  prog()
end
assert(count == ENTRIES_NUMBER, "entries number mismatch!")

-- compare entries with themselves and print most similar ones
print("comparing entries using table_similarity2 function...")
prog = progress_printer(ENTRIES_NUMBER, 10)
for e1 in mutaio.entries(TEST_DIRECTORY) do
  for e2 in mutaio.entries(TEST_DIRECTORY) do
    local similarity = miscfuncs.table_similarity2(e1, e2)
    -- print ones which are similar
    if e1.count ~= e2.count and similarity >= 0.7 then
      print(string.rep("-", 70))
      print(miscfuncs.table_to_lua(e1))
      print("is similar by " .. similarity .. " to:")
      print(miscfuncs.table_to_lua(e2))
    end
  end
  prog()
end

-- upper case all string fields in every second entry
print("changing case of all string fields to upper every second entry...")
prog = progress_printer(ENTRIES_NUMBER, 50)
count = 0
mutaio.rewrite_entries(TEST_DIRECTORY, nil, function(e)
  prog()
  if e.count % 2 > 0 then
    local upped = false
    for k, v in pairs(e) do
      if type(v) == "string" then
        upped = true
        e[k] = string.upper(v)
      end
    end
    if upped then count = count + 1 end
    return e
  end
end)

-- check if it was really done
print("checking if upping was done correctly...")
prog = progress_printer(ENTRIES_NUMBER, 50)
local count2 = 0
for e in mutaio.entries(TEST_DIRECTORY) do
  local hasbreak = false
  for k, v in pairs(e) do
    if type(v) == "string" then
      -- upped string shouldn't have matched any lower case character...
      if string.match(v, "[a-z]") then
        hasbreak = true
        break
      end
    end
  end
  -- no lower case characters were found so increment counter2
  if not hasbreak then count2 = count2 + 1 end
  prog()
end
assert(count == count2, "counters mismatch!")

-- Finally erase all entries using filter function returning false explicitly
-- (nil will not have any effect by design).
-- Note that actual files will not be erased just emptied. This isn't a
-- problem because mutaio.write_entry will reuse preexisting files which fall
-- under size threshold.
print("erasing all entries...")
prog = progress_printer(ENTRIES_NUMBER, 50)
mutaio.rewrite_entries(TEST_DIRECTORY, nil, function()
  prog()
  return false
end)

-- check if all entries have been deleted
print("checking if all entries have been deleted...")
count = 0
mutaio.entries(TEST_DIRECTORY, nil, function() count = count + 1 end)
assert(count == 0, "there is/are " .. count .. " entry(ies) left when all should be deleted!")

print("all steps have been done without errors")
