--- Divvy's Simulation for Balatro - Engine.lua
--
-- Shadow the game's main tables to run simulations in an isolated environment.

function DV.SIM.run()
   local null_ret = {
      score   = { min = 0, exact = 0, max = 0 },
      dollars = { min = 0, exact = 0, max = 0 }
   }
   if #G.hand.highlighted < 1 then return null_ret end

   DV.SIM.hands_simulated = 1 + (DV.SIM.hands_simulated or 0)

   -- Simulation:
   local first = love.timer.getTime()
   local prev = first

   DV.SIM.running = true
   DV.SIM.save_state()

   local last = love.timer.getTime()
   if DV.SIM.DEBUG then
      print("SAVE STATE: " .. (last - prev))
      prev = last
   end

   local min   = { chips = 0, mult = 0, dollars = 0 }
   local exact = { chips = 0, mult = 0, dollars = 0 }
   local max   = { chips = 0, mult = 0, dollars = 0 }

   if G.SETTINGS.DV.show_min_max then
      -- some seed titles append G.SEED to randomize seed
      -- blank G.SEED to make seed titles consistent between runs
      G.SEED = ""

      DV.SIM.running_type = DV.SIM.TYPES.MAX
      max = DV.SIM.simulate_play()

      if DV.SIM.DEBUG then
         last = love.timer.getTime()
         print("SIM MAX: " .. (last - prev))
         prev = last
      end

      DV.SIM.running_type = DV.SIM.TYPES.MIN
      min = DV.SIM.simulate_play()

      if DV.SIM.DEBUG then
         last = love.timer.getTime()
         print("SIM MIN: " .. (last - prev))
         prev = last
      end


      local recalculation_needed = false
      for seed, _ in pairs(DV.SIM.seeds.unknown) do
         DV.SIM.seeds.unknown[seed] = nil

         local new_max, need_new = DV.SIM.attempt_to_find_seed(seed, max)
         recalculation_needed = recalculation_needed or need_new
         if need_new then
            max = new_max
         end

         if DV.SIM.DEBUG then
            last = love.timer.getTime()
            print("SIM SEED (" .. seed .. ") MAX: " .. (last - prev))
            prev = last
         end
      end

      if recalculation_needed then
         DV.SIM.running_type = DV.SIM.TYPES.MIN
         min = DV.SIM.simulate_play()

         if DV.SIM.DEBUG then
            last = love.timer.getTime()
            print("SIM NEW MID: " .. (last - prev))
            prev = last
         end
      end
   else
      DV.SIM.running_type = DV.SIM.TYPES.EXACT
      exact = DV.SIM.simulate_play()

      if DV.SIM.DEBUG then
         last = love.timer.getTime()
         print("SIM EXACT: " .. (last - prev))
         prev = last
      end
   end

   DV.SIM.restore_state()
   DV.SIM.running = false

   if DV.SIM.DEBUG then
      last = love.timer.getTime()
      print("RESTORE STATE: " .. (last - prev))
      prev = last
   end

   DV.SIM.clean_up()

   if DV.SIM.DEBUG then
      last = love.timer.getTime()
      print("CLEAN UP: " .. (last - prev))
      print("TOTAL TIME DIFF: " .. (last - first))
   end


   -- Return:

   local min_score   = math.floor(min.chips * min.mult)
   local exact_score = math.floor(exact.chips * exact.mult)
   local max_score   = math.floor(max.chips * max.mult)

   return {
      score   = { min = min_score, exact = exact_score, max = max_score },
      dollars = { min = min.dollars, exact = exact.dollars, max = max.dollars }
   }
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

function DV.SIM.simulate_play()
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

function DV.SIM.attempt_to_find_seed(seed, prev_max)
   -- invert the seed and test it
   DV.SIM.seeds.known[seed] = { inverted = true }
   DV.SIM.running_type = DV.SIM.TYPES.MAX
   local new_max = DV.SIM.simulate_play()

   -- Check the results to see if inverted is not worth it
   -- Three reasons to not invert:
   --   1) Score is worse when inverted
   --   2) Score didn't change, but dollars went down
   --   3) No change (score is the same and dollars are the same)
   local score_diff = new_max.chips * new_max.mult - prev_max.chips * prev_max.mult
   if score_diff < 0 or (score_diff == 0 and new_max.dollars <= prev_max.dollars) then
      DV.SIM.seeds.known[seed].inverted = false
   end

   DV.SIM.save_seed_json()

   return new_max, DV.SIM.seeds.known[seed].inverted
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
      if pt_mt.creation_timestamp == DV.SIM.hands_simulated then
         -- this table has been processed, don't continue
         -- may cause loops if continuing
         return pt
      end

      pt_mt.creation_timestamp = DV.SIM.hands_simulated
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
      pt_mt.creation_timestamp = DV.SIM.hands_simulated
      setmetatable(pt, pt_mt)

      DV.SIM.shadow.links[tbl] = pt
   end

   return pt
end

function DV.SIM.clean_up()
   if DV.SIM.DEBUG then
      print("DATABASE SIZE: " .. get_length(DV.SIM.shadow.links))
   end
   for tbl, pt in pairs(DV.SIM.shadow.links) do
      local pt_mt = getmetatable(pt)
      if pt_mt.creation_timestamp ~= DV.SIM.hands_simulated then
         -- this table is no longer relevant, remove cached links
         DV.SIM.shadow.links[tbl] = nil
      end
   end
end

function DV.SIM.hook_functions()
   pseudoseed = DV.SIM.new_pseudoseed
   pseudorandom = DV.SIM.new_pseudorandom
   ease_dollars = DV.SIM.new_ease_dollars
   check_for_unlock = DV.SIM.new_check_for_unlock
   play_sound = DV.SIM.new_play_sound
   update_hand_text = DV.SIM.new_update_hand_text
   EventManager.add_event = DV.SIM.new_add_event
end

function DV.SIM.unhook_functions()
   pseudoseed = DV.SIM._pseudoseed
   pseudorandom = DV.SIM._pseudorandom
   ease_dollars = DV.SIM._ease_dollars
   check_for_unlock = DV.SIM._check_for_unlock
   play_sound = DV.SIM._play_sound
   update_hand_text = DV.SIM._update_hand_text
   EventManager.add_event = DV.SIM._add_event
end

-- Hook into pseudorandom() and pseudoseed() to force specific random results
DV.SIM._pseudoseed = pseudoseed
DV.SIM.new_pseudoseed = function(key, predict_seed)
   if not DV.SIM.running or not G.SETTINGS.DV.show_min_max then
      return DV.SIM._pseudoseed(key, predict_seed)
   end
   return key
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

-- Force ease_dollars() to trigger instantly during simulations
--    If not instant, some cards trigger using add_event() which is disabled
DV.SIM._ease_dollars = ease_dollars
DV.SIM.new_ease_dollars = function(mod, instant)
   if DV.SIM.running then
      instant = true
   end
   return DV.SIM._ease_dollars(mod, instant)
end

-- debug print

function TablePrint(t, depth, tabs)
   depth = depth or 3
   tabs = tabs or ''
   if depth == 0 then return end
   for k, v in pairs(t) do
      if type(v) == "table" then
         print(tabs, k, ' = table (#' .. tostring(get_length(v)) .. ")")
         TablePrint(v, depth - 1, tabs .. '\t')
      else
         print(tabs, k, ': ', tostring(v))
      end
   end
end

function get_length(tbl)
   local ret = 0
   for _, _ in pairs(tbl) do
      ret = ret + 1
   end
   return ret
end