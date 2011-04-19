------------------------------------------------------------------------------
-- README for 0.11 version                                                  --
------------------------------------------------------------------------------

Mutaio stands for MUltiple TAble IO. Basically it implements ways of saving,
iterating and modifying tables (called "entries") stored as Lua files. I've
focused on simplicity and ease of use. Portability and performance have yet to
improve thought it should be good enough for few thousand records as now.

The best way to start it's to look mutaio_examples.lua file first. Mutaio
module implements interface of just three functions:
  entries               -- that one for iterating over entries
  write_entry           -- writing new entry to disk
  rewrite_entries       -- modifying (and erasing) entries

Every entry is just serialized Lua table in Lua source format. Entries are
saved over multiple files adding new when existing ones grow over set
threshold (mutaio.MAX_FILE_SIZE). Because parsing is done via loadfile such
fragmentation helps to have memory usage and latency at constant level.

Serialization function supports tables within tables but cycles will results
in empty table constructors.

Multiple entries iterators may be used at the same time however mixing in
writes to the same location will generate (obviously) erroneous results.


-- Dependencies --------------------------------------------------------------

  * Lua curl module with easy interface
  * Lua file system module

------------------------------------------------------------------------------


For feedback, criticism or ideas please write to: rk@bixbite.pl
