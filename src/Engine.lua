--- Divvy's Simulation for Balatro - Engine.lua
--
-- Shadow the game's main tables to run simulations in an isolated environment.

function DV.SIM.run()
   local null_ret = {
      score   = { min = 0, exact = 0, max = 0 },
      dollars = { min = 0, exact = 0, max = 0 }
   }
   if #G.hand.highlighted < 1 then return null_ret end
   if #G.play.cards > 0 then
      G.E_MANAGER:add_event(Event({
         trigger = "immediate",
         func = function()
            if #G.play.cards == 0 then
               DV.PRE.data = DV.SIM.run()
               return true
            end
            return false
         end
      }))
      return DV.PRE.data
   end

   -- Simulation:
   local min      = { chips = 0, mult = 0, dollars = 0 }
   local exact    = { chips = 0, mult = 0, dollars = 0 }
   local max      = { chips = 0, mult = 0, dollars = 0 }

   DV.SIM.running = true

   DV.SIM.start_timer()

   if G.SETTINGS.DV.show_min_max then
      max = DV.SIM.simulate_max()
      min = DV.SIM.simulate_min()
   else
      exact = DV.SIM.simulate_play(DV.SIM.TYPES.EXACT)
      DV.SIM.debug_timer("SIM EXACT")
   end

   DV.SIM.restore_state()
   DV.SIM.running = false

   DV.SIM.debug_timer("RESTORE STATE")

   DV.SIM.clean_up()

   DV.SIM.debug_timer("CLEAN UP")

   DV.SIM.stop_timer()

   -- Return:

   local min_score   = math.floor(min.chips * min.mult)
   local exact_score = math.floor(exact.chips * exact.mult)
   local max_score   = math.floor(max.chips * max.mult)

   return {
      score   = { min = min_score, exact = exact_score, max = max_score },
      dollars = { min = min.dollars, exact = exact.dollars, max = max.dollars }
   }
end

function DV.SIM.simulate_max()
   local max = DV.SIM.simulate_play(DV.SIM.TYPES.MAX)
   DV.SIM.debug_timer("SIM MAX")

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

      DV.SIM.debug_timer("SIM SEED (" .. seed .. ") MAX")
   end
   return max
end

function DV.SIM.simulate_min()
   local min = DV.SIM.simulate_play(DV.SIM.TYPES.MIN)
   DV.SIM.debug_timer("SIM MIN")
   return min
end

function DV.SIM.simulate_play(type)
   -- Clear `G.SEED` to prevent seed "scrambling", i.e. 'lucky_mult' -> 'lucky_mult127453'
   G.SEED = ""

   DV.SIM.running_type = type

   DV.SIM.prepare_play()
   DV.SIM.debug_timer("PLAY PREPARED")
   G.FUNCS.evaluate_play()

   DV.SIM.total_simulations = 1 + (DV.SIM.total_simulations or 0)

   local cash = G.GAME.dollars - DV.SIM.real.main.GAME.dollars
   return { chips = hand_chips, mult = mult, dollars = cash }
end

-- The following function adjusts values as per `G.FUNCS.play_cards_from_highlighted(e)`
function DV.SIM.prepare_play()
   DV.SIM.save_state()
   --DV.SIM.debug_timer("SAVE STATE")
   DV.SIM.store_events = {}

   G.GAME.current_round.hands_left = G.GAME.current_round.hands_left - 1
   G.GAME.hands_played = G.GAME.hands_played + 1
   G.GAME.current_round.hands_played = G.GAME.current_round.hands_played + 1

   G.GAME.blind.triggered = false
   for k, v in ipairs(G.playing_cards) do
      v.ability.forced_selection = nil
   end

   table.sort(G.hand.highlighted, function(a, b) return a.T.x < b.T.x end)

   for i = 1, #G.hand.highlighted do
      G.hand.highlighted[i].base.times_played = G.hand.highlighted[i].base.times_played + 1
      G.hand.highlighted[i].ability.played_this_ante = true
      G.GAME.round_scores.cards_played.amt = G.GAME.round_scores.cards_played.amt + 1
      draw_card(G.hand, G.play, i * 100 / #G.hand.highlighted, 'up', nil, G.hand.highlighted[i])
   end

   -- draw_card create events to actually move the cards over
   -- after creating them, trigger them all
   local temp = DV.SIM.store_events
   DV.SIM.store_events = nil
   if #temp > 0 then
      for _, event in pairs(temp) do
         event.func()
      end
   end

   DV.SIM.store_events = {}
   -- trigger blind effects
   G.GAME.blind:press_play()

   -- Just like draw_card, press_play creates events to trigger the blind effect
   local temp = DV.SIM.store_events
   DV.SIM.store_events = nil
   if #temp > 0 then
      for _, event in pairs(temp) do
         event.func()
      end
   end
end

function DV.SIM.save_state()
   DV.SIM.hook_functions()

   -- save G if not already saved
   DV.SIM.real.global = DV.SIM.real.global or G
   -- reset previous links
   DV.SIM.shadow.links = DV.SIM.shadow.links or {}
   for _, st in pairs(DV.SIM.shadow.links) do
      local st_mt = getmetatable(st)
      for k, _ in pairs(st) do
         st[k] = nil
      end
   end

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

   for k, _ in pairs(DV.SIM.MAIN_TABLES) do
      DV.SIM.real.main[k] = DV.SIM.real.global[k]
      DV.SIM.shadow.main[k] = DV.SIM.fill_shadow_tables(DV.SIM.real.main[k], "G." .. k)
      DV.SIM.shadow.global[k] = DV.SIM.shadow.main[k]
   end

   G = DV.SIM.shadow.global
end

function DV.SIM.restore_state()
   G = DV.SIM.real.global

   -- Shouldn't be needed, as the links should already exist, but best to be safe
   --    plus it's only a few assignments
   for k, _ in pairs(DV.SIM.real.main) do
      G[k] = DV.SIM.real.main[k]
   end

   DV.SIM.unhook_functions()
end

-- Simply create an empty shadow table with the proper connections
-- "debug" is the full location of the table, i.e. "G.hand.cards.1"
function DV.SIM.create_shadow_table(tbl, debug)
   local st = DV.SIM.shadow.links[tbl]

   -- The key idea is that the `__index` metamethod in shadow tables
   -- allows value look-up in any underlying shadow table (fall-through);
   --
   -- BUT setting values (i.e. tbl[key] = value) affect the shadown table,
   -- and don't make it to the real tables underneath, keeping it unchanged.
   -- This should solve most possibilities for 'pointer hell'.
   --
   -- However, pairs and ipairs don't fall through with Lua 5.1.
   -- For most cases, this isn't an issues, but anytime a table
   -- is used as an array, the changing of indexes causes weird cases.
   --
   -- To address this, we'll create a custom __index function that doesn't
   -- send array requests (type(key) == "number") through to the real table.
   -- Also, we'll copy over any array index values, so the shadow has the values.

   if st == nil then
      st = {}
      local st_mt = {}
      st_mt.real_table = tbl
      st_mt.__index = DV.SIM.shadow_index
      st_mt.is_shadow_table = true
      st_mt.debug_orig = debug
      st_mt.last_simulation = DV.SIM.total_simulations
      setmetatable(st, st_mt)

      DV.SIM.shadow.links[tbl] = st
   end

   return st
end

-- This will be our custom __index function
-- When called, it will be given the shadow table, and the index
--   i.e. tbl[k] => DV.SIM.shadow_index(tbl,k)
function DV.SIM.shadow_index(shadow, key)
   if type(key) == "number" then return nil end
   local shadow_mt = getmetatable(shadow)
   if shadow_mt and shadow_mt.real_table then
      return shadow_mt.real_table[key]
   end
   return nil
end

-- recursively do a deep copy of the shadow tables
-- Shadow tables will be initially nil, as the DV.SIM.shadow.links was reset
function DV.SIM.fill_shadow_tables(tbl, debug)
   debug = debug or ""
   local st = DV.SIM.shadow.links[tbl]
   if st then
      local st_mt = getmetatable(st)
      if st_mt.last_simulation == DV.SIM.total_simulations then
         return st
      end
      st_mt.last_simulation = DV.SIM.total_simulations
   else
      st = DV.SIM.create_shadow_table(tbl, debug)
   end

   local is_basic = true
   for k, v in pairs(tbl) do
      if type(v) == "table" and not DV.SIM.IGNORED_KEYS[k] then
         is_basic = false
         st[k] = DV.SIM.fill_shadow_tables(v, debug .. "." .. k)
      elseif type(k) == "number" then
         st[k] = v
      end
   end

   return st
end

function DV.SIM.clean_up()
   if DV.SIM.DEBUG then
      --print("DATABASE SIZE: " .. DV.SIM.get_length(DV.SIM.shadow.links))
   end

   -- remove all uneeded elements to keep size of DV.SIM.shadow.links down
   for tbl, st in pairs(DV.SIM.shadow.links) do
      local st_mt = getmetatable(st)
      -- If this shadow table wasn't used in the most recent simulation, remove it
      if st_mt.last_simulation ~= DV.SIM.total_simulations then
         DV.SIM.shadow.links[tbl] = nil
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

-- Hook into pseudorandom() and pseudoseed() to force specific random results
-- pseudoseed normally returns a number, but we'll return the seed string so that pseudorandom can read it raw
--   However, pseudorandom_element needs the number, so we'll hook that as well
DV.SIM._pseudoseed = pseudoseed
DV.SIM.new_pseudoseed = function(key, predict_seed)
   if not DV.SIM.running or not G.SETTINGS.DV.show_min_max then
      return DV.SIM._pseudoseed(key, predict_seed)
   end
   return key
end

DV.SIM._pseudorandom_element = pseudorandom_element
DV.SIM.new_pseudorandom_element = function(_t, seed)
   if not DV.SIM.running or not G.SETTINGS.DV.show_min_max then
      return DV.SIM._pseudorandom_element(_t, seed)
   end
   return DV.SIM._pseudorandom_element(_t, DV.SIM._pseudoseed(seed))
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
