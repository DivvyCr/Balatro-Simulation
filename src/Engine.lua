--- Divvy's Simulation for Balatro - Engine.lua
--
-- Shadow the game's main tables to run simulations in an isolated environment.

function DV.SIM.run()
   if #G.hand.highlighted == 0 then
      return {
         score   = { min = 0, exact = 0, max = 0 },
         dollars = { min = 0, exact = 0, max = 0 }
      }
   end
   DV.SIM.waiting = true
   return DV.PRE.data
end

function DV.SIM.begin_simulation()
   if #G.hand.highlighted < 1 then
      DV.PRE.data = {
         score   = { min = 0, exact = 0, max = 0 },
         dollars = { min = 0, exact = 0, max = 0 }
      }
      return true
   end

   DV.SIM.total_simulations = 1 + (DV.SIM.total_simulations or 0)

   -- Simulation:
   local t0 = love.timer.getTime() -- Used at the end to get total simulation time!
   DV.SIM.debug_data.t1 = t0

   DV.SIM.running = true
   DV.SIM.save_state()

   debug_timer("SAVE STATE")

   local min   = { chips = 0, mult = 0, dollars = 0 }
   local exact = { chips = 0, mult = 0, dollars = 0 }
   local max   = { chips = 0, mult = 0, dollars = 0 }

   if G.SETTINGS.DV.show_min_max then
      max = DV.SIM.simulate_max()
      min = DV.SIM.simulate_min()
   else
      exact = DV.SIM.simulate_play(DV.SIM.TYPES.EXACT)
      debug_timer("SIM EXACT")
   end

   DV.SIM.restore_state()
   DV.SIM.running = false

   debug_timer("RESTORE STATE")

   DV.SIM.clean_up()

   print("TOTAL SIMULATION TIME: " .. (DV.SIM.debug_data.t2 - t0))

   -- Return:

   local min_score   = math.floor(min.chips * min.mult)
   local exact_score = math.floor(exact.chips * exact.mult)
   local max_score   = math.floor(max.chips * max.mult)

   DV.PRE.data       = {
      score   = { min = min_score, exact = exact_score, max = max_score },
      dollars = { min = min.dollars, exact = exact.dollars, max = max.dollars }
   }
   return true
end

function DV.SIM.simulate_max()
   local max = DV.SIM.simulate_play(DV.SIM.TYPES.MAX)
   debug_timer("SIM MAX")

   -- Random events use different custom seeds, which are usually short strings
   -- like "lucky_money" and "lucky_mult" for lucky card triggers.
   --
   -- Often, higher probabilities are associated with higher scores such as for
   -- the Misprint joker where probability 0 gives +0 mult and probability 1 gives +23 mult;
   -- but sometimes lower probabilities are preferred such as for Lucky Cards
   -- where probabilities under 0.2 give +20 mult.
   --
   -- Therefore, it is important to discern between 'normal' seeds and
   -- 'inverted' seeds (preferring high and low probabilities, respectively).
   --
   -- This is achieved by classifying seeds in DV.SIM.seeds as exactly one of:
   --   unknown[seed]                  First time seeing seed
   --   known[seed].inverted = false   Seed was found to be 'normal'
   --   known[seed].inverted = true    Seed was found to be 'inverted'
   --
   -- During the simulate_play function, seeds will be added to DV.SIM.seeds.unknown
   -- as they are encountered. At this point in the code, any unknown seeds
   -- will be added to the table and read to be checked.
   --
   -- To check an unknown seed, it is sufficient to run an extra simulation
   -- temporarily setting it to inverted: if the results are better
   -- when inverted, then the seed will be classified as inverted;
   -- otherwise, it will be classified as normal.

   for seed, _ in pairs(DV.SIM.seeds.unknown) do
      DV.SIM.seeds.unknown[seed] = nil

      -- If seed is determined to be inverted, a new max will be returned.
      -- If seed is normal, then the current max will be returned.
      -- No additional simulations are needed.
      max = DV.SIM.classify_seed(seed, max)

      debug_timer("SIM SEED (" .. seed .. ") MAX")
   end
   return max
end

function DV.SIM.simulate_min()
   local min = DV.SIM.simulate_play(DV.SIM.TYPES.MIN)
   debug_timer("SIM MIN")
   return min
end

function DV.SIM.save_state()
   DV.SIM.hook_functions()
   -- Swap real global tables with simulation tables via `__index` metamethod;
   -- see comment in `DV.SIM.write_shadow_table` for some details.
   for k, _ in pairs(DV.SIM.real.main) do
      DV.SIM.real.main[k] = G[k]
      DV.SIM.shadow.main[k] = DV.SIM.write_shadow_table(DV.SIM.real.main[k], k)
      G[k] = DV.SIM.shadow.main[k]
   end

   -- Most values in the `G` table aren't needed, so we can do a shadow copy
   -- of just the important values and leave the rest as real references

   -- Save the real `G` table:
   DV.SIM.real.global = G

   if DV.SIM.shadow.global then
      -- Exists, so need to clear it:
      for k, _ in pairs(DV.SIM.shadow.global) do
         DV.SIM.shadow.global[k] = nil
      end
   else
      -- Does not exist, so need to create it:
      DV.SIM.shadow.global = DV.SIM.create_shadow_table(G, "G")
      DV.SIM.shadow.links[G] = nil
   end

   -- Populate the shadow `G` table:
   for k, v in pairs(DV.SIM.shadow.main) do
      DV.SIM.shadow.global[k] = v
   end
   -- Shadow the `G` table:
   G = DV.SIM.shadow.global
end

function DV.SIM.simulate_play(type)
   -- Clear `G.SEED` to prevent seed "scrambling", i.e. 'lucky_mult' -> 'lucky_mult127453'
   G.SEED = ""

   DV.SIM.running_type = type

   DV.SIM.prepare_play()
   G.FUNCS.evaluate_play()

   local cash = G.GAME.dollars - DV.SIM.real.main.GAME.dollars
   return { chips = hand_chips, mult = mult, dollars = cash }
end

-- The following function adjusts values as per `G.FUNCS.play_cards_from_highlighted(e)`
function DV.SIM.prepare_play()
   DV.SIM.reset_shadow_tables()

   local highlighted_cards = {}
   for i = 1, #G.hand.highlighted do
      highlighted_cards[i] = G.hand.highlighted[i]
      highlighted_cards[i].T.x = nil
   end

   table.sort(highlighted_cards, function(a, b) return a.T.x < b.T.x end)

   for i = 1, #highlighted_cards do
      local card = highlighted_cards[i]
      card.base.times_played = card.base.times_played + 1
      card.ability.played_this_ante = true
      G.GAME.round_scores.cards_played.amt = G.GAME.round_scores.cards_played.amt + 1
      G.hand:remove_card(card)
      G.play:emplace(card)
   end

   -- reset card positions for correct order
   for i, card in pairs(G.play.cards) do
      card.T.x = nil
   end
   table.sort(G.play.cards, function(a, b) return a.T.x < b.T.x end)
end

function DV.SIM.restore_state()
   G = DV.SIM.real.global
   for k, _ in pairs(DV.SIM.real.main) do
      G[k] = DV.SIM.real.main[k]
   end

   DV.SIM.unhook_functions()
end

function DV.SIM.reset_shadow_tables()
   local to_create = {}
   for tbl, pt in pairs(DV.SIM.shadow.links) do
      local mt = getmetatable(pt)
      if rawget(mt, "is_shadow_table") == nil then
         print("TABLE IN DV.SIM.shadow.links IS NOT PSEUDO TABLE - " .. rawget(mt, "debug_orig"))
      end


      for k, _ in pairs(pt) do
         rawset(pt, k, nil)
      end
      for k, v in pairs(tbl) do
         if type(v) == "table" and not DV.SIM.IGNORED_KEYS[k] then
            rawset(pt, k, DV.SIM.shadow.links[v])
            if rawget(pt, k) == nil then
               local temp = {}
               temp.tab = tbl
               temp.pseudo = pt
               temp.key = k
               table.insert(to_create, temp)
            end
         end
      end
   end
   for _, v in pairs(to_create) do
      local tbl = v.tab
      local pt = v.pseudo
      local k = v.key
      rawset(pt, k, DV.SIM.write_shadow_table(tbl[k], "???." .. k))
   end
end

function DV.SIM.write_shadow_table(tbl, debug)
   debug = debug or ""
   local pt = nil

   if DV.SIM.shadow.links[tbl] then
      pt = DV.SIM.shadow.links[tbl]
      local pt_mt = getmetatable(pt)
      if pt_mt.creation_timestamp == DV.SIM.total_simulations then
         -- this table has been processed, don't continue
         -- may cause loops if continuing
         return pt
      end

      pt_mt.creation_timestamp = DV.SIM.total_simulations
   else
      pt = DV.SIM.create_shadow_table(tbl, debug)
   end

   -- The key idea is that the `__index` metamethod in shadow tables
   -- allows value look-up in any underlying shadow table (fall-through);
   --
   -- BUT value update only affects the updated shadow table,
   -- without affecting any underlying shadow tables (shadowing).
   -- This should solve most possibilities for 'pointer hell'.
   --
   -- Some tables don't need shadows and can be ignored
   -- to shrink shadow footprint and reduce processing.
   -- Currently ignored are ui elements like 'children' and 'parent'

   for k, v in pairs(tbl) do
      -- Read above on why we ignore values, only writing shadow tables:
      if type(v) == "table" and not DV.SIM.IGNORED_KEYS[k] then
         pt[k] = DV.SIM.write_shadow_table(v, debug .. "." .. k)
      end
   end

   return pt
end

function DV.SIM.create_shadow_table(tbl, debug)
   local pt = DV.SIM.shadow.links[tbl]

   if pt == nil then
      pt = {}
      local pt_mt = {}
      pt_mt.__index = tbl
      pt_mt.is_shadow_table = true
      pt_mt.debug_orig = debug
      pt_mt.creation_timestamp = DV.SIM.total_simulations
      setmetatable(pt, pt_mt)

      DV.SIM.shadow.links[tbl] = pt
   end

   return pt
end

function DV.SIM.clean_up()
   if DV.SIM.DEBUG then
      print("DATABASE SIZE: " .. get_length(DV.SIM.shadow.links))
   end

   -- remove all uneeded elements to keep size of DV.SIM.shadow.links down
   for tbl, pt in pairs(DV.SIM.shadow.links) do
      local pt_mt = getmetatable(pt)
      if pt_mt.creation_timestamp ~= DV.SIM.total_simulations then
         -- this table is no longer relevant, remove cached links
         DV.SIM.shadow.links[tbl] = nil
      end
   end

   -- search for any "misplaced" shadows and clear them
   DV.SIM.search_for_shadows(G)
end

function DV.SIM.search_for_shadows(tbl, debug)
   -- keep track of previous tables to prevent looping
   debug = debug or {}
   debug[tbl] = true
   for k, v in pairs(tbl) do
      if type(v) == "table" then
         -- get the real table from the shadow
         local v_mt = getmetatable(v)
         if v_mt and v_mt.is_shadow_table then
            -- restore the proper links
            tbl[k] = v_mt.__index
         end

         if debug[v] == nil then
            DV.SIM.search_for_shadows(v, debug)
         end
      end
   end
end

--
-- RNG Handling:
--

function DV.SIM.classify_seed(seed, prev_max)
   -- Invert the seed to test it:
   DV.SIM.seeds.known[seed] = { inverted = true }
   local new_max = DV.SIM.simulate_play(DV.SIM.TYPES.MAX)

   -- Check the results to see if inverted is not worth it
   -- Three reasons to not invert:
   --   * Score is lower;
   --   * Score is unchanged, but money is lower;
   --   * No change.
   local ret_max = new_max
   local score_diff = new_max.chips * new_max.mult - prev_max.chips * prev_max.mult
   if score_diff < 0 or (score_diff == 0 and new_max.dollars <= prev_max.dollars) then
      -- The results are either unchanged or worse
      -- Return the previous values and assume 'normal'
      DV.SIM.seeds.known[seed].inverted = false
      ret_max = prev_max
   end

   DV.SIM.save_seed_json()

   return ret_max
end

DV.SIM._pseudorandom = pseudorandom
DV.SIM.new_pseudorandom = function(seed, min, max)
   if not DV.SIM.running or not G.SETTINGS.DV.show_min_max then
      return DV.SIM._pseudorandom(seed, min, max)
   end
   min = min or 0
   max = max or 1

   -- if it's not known, document it
   -- if it's known and inverted, return inverted random
   -- if nothing returned,  return normal
   if not DV.SIM.seeds.known[seed] then
      DV.SIM.seeds.unknown[seed] = true
   elseif DV.SIM.seeds.known[seed].inverted then
      return (DV.SIM.running_type == DV.SIM.TYPES.MAX and max) or min
   end
   return (DV.SIM.running_type == DV.SIM.TYPES.MAX and min) or max
end

--
-- Util functions:
--

function get_length(tbl)
   local ret = 0
   for _, _ in pairs(tbl) do
      ret = ret + 1
   end
   return ret
end

function debug_timer(msg)
   if DV.SIM.DEBUG then
      DV.SIM.debug_data.t2 = love.timer.getTime()
      print(msg .. ": " .. (DV.SIM.debug_data.t2 - DV.SIM.debug_data.t1))
      DV.SIM.debug_data.t1 = DV.SIM.debug_data.t2
   end
end