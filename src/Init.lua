--- Divvy's Simulation for Balatro - Init.lua
--
-- Global values that must be present for the rest of this mod to work.

if not DV then DV = {} end

DV.SIM = {
   running = false,

   TYPES = {
      EXACT = -1,
      MIN   = 0,
      MAX   = 1,
   },
   running_type = 0,

   --
   -- TODO: Not the biggest fan of this table structure but it works for now...
   --

   -- MAIN_TABLES = {"GAME", "play", "hand", "jokers", "consumeables", "deck"},
   IGNORED_KEYS = {role = true, children = true, parent = true, alignment = true},

   real = {
      global = nil, -- Real global `G` table
      main = {GAME={}, play={}, hand={}, jokers={}, consumeables={}, deck={}},   -- Real game tables (from MAIN_TABLES)
   },

   fake = {
      global = nil, -- Shadow global `G` table
      main = {GAME={}, play={}, hand={}, jokers={}, consumeables={}, deck={}},   -- Top-level shadow tables (from MAIN_TABLES)
      cached = {}, -- Other shadow tables
   },

   DEBUG = {},
}
