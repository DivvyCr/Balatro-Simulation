--- Divvy's Simulation for Balatro - Engine.lua
--
-- Shadow the game's main tables to run simulations in an isolated environment.

function DV.SIM.run()
   local null_ret = {
      score   = { min = 0, exact = 0, max = 0 },
      dollars = { min = 0, exact = 0, max = 0 }
   }
   if #G.hand.highlighted < 1 then return null_ret end

   -- Simulation:

   DV.SIM.random.need_reevaluation = false
   DV.SIM.running = true
   DV.SIM.save_state()

   local min   = { chips = 0, mult = 0, dollars = 0 }
   local exact = { chips = 0, mult = 0, dollars = 0 }
   local max   = { chips = 0, mult = 0, dollars = 0 }

   if G.SETTINGS.DV.show_min_max then
      DV.SIM.running_type = DV.SIM.TYPES.MAX
      max = DV.SIM.simulate_play()

      DV.SIM.running_type = DV.SIM.TYPES.MIN
      min = DV.SIM.simulate_play()
   else
      DV.SIM.running_type = DV.SIM.TYPES.EXACT
      exact = DV.SIM.simulate_play()
   end

   DV.SIM.restore_state()
   DV.SIM.running    = false

   if DV.SIM.random.need_reevaluation then
      return DV.SIM.run()
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

   --print("CALCULATED HAND - " .. hand_chips .. "x" .. mult .. " ($" .. cash .. ")")

   return { chips = hand_chips, mult = mult, dollars = cash }
end

-- The following function adjusts values as per `G.FUNCS.play_cards_from_highlighted(e)`
function DV.SIM.prepare_play()
   --print("RESETTING")
   DV.SIM.reset_shadow_tables()

   local highlighted_cards = {}
   for i = 1, #G.hand.highlighted do
      highlighted_cards[i] = G.hand.highlighted[i]
      highlighted_cards[i].T.x = nil
   end

   table.sort(highlighted_cards, function(a, b) return a.T.x < b.T.x end)


   --print("HIGHLIGHT DATA")
   for i = 1, #highlighted_cards do
      local card = highlighted_cards[i]
      --print("Highlight #" .. i .. " = " .. card.base.name .." / card.T.x = " .. card.T.x)
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

   --[[
   print("HAND DATA")
   for i,card in pairs(G.play.cards) do
      print("Shadow PLAY #" .. i .. " = " .. card.base.name .." / card.T.x = " .. card.T.x)
   end
   --]]
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
               --print("NEED TO CREATE NEW VALUE FOR " .. rawget(mt, "debug_orig") .. "." .. k)
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
      --print("CREATING NEW VALUE - " .. k)
      rawset(pt, k, DV.SIM.write_shadow_table(tbl[k], "???." .. k))
   end
end

function DV.SIM.write_shadow_table(tbl, debug)
   debug = debug or ""

   if DV.SIM.shadow.links[tbl] then
      return DV.SIM.shadow.links[tbl]
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

   local pt = DV.SIM.create_shadow_table(tbl, debug)
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
      setmetatable(pt, pt_mt)

      DV.SIM.shadow.links[tbl] = pt
   end

   return pt
end

-- debug print

function TablePrint(t, depth, tabs)
   depth = depth or 3
   tabs = tabs or ''
   if depth == 0 then return end
   for k, v in pairs(t) do
      if type(v) == "table" then
         print(tabs, k, ' = table')
         TablePrint(v, depth - 1, tabs .. '\t')
      else
         print(tabs, k, ': ', tostring(v))
      end
   end
end

function DV.SIM.hook_functions()
   pseudoseed = DV.SIM.new_pseudoseed
   pseudorandom = DV.SIM.new_pseudorandom
   ease_dollars = DV.SIM.new_ease_dollars
   eval_card = DV.SIM.new_eval_card
   check_for_unlock = DV.SIM.new_check_for_unlock
   play_sound = DV.SIM.new_play_sound
   update_hand_text = DV.SIM.new_update_hand_text
   EventManager.add_event = DV.SIM.new_add_event
end

function DV.SIM.unhook_functions()
   pseudoseed = DV.SIM._pseudoseed
   pseudorandom = DV.SIM._pseudorandom
   ease_dollars = DV.SIM._ease_dollars
   eval_card = DV.SIM._eval_card
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
--pseudoseed = DV.SIM.new_pseudoseed

DV.SIM._pseudorandom = pseudorandom
DV.SIM.new_pseudorandom = function(seed, min, max)
   if not DV.SIM.running or not G.SETTINGS.DV.show_min_max then
      return DV.SIM._pseudorandom(seed, min, max)
   end

   local ret = 0
   if DV.SIM.random.seeds[seed] then
      if DV.SIM.random.seeds[seed].inverted then
         ret = (DV.SIM.running_type == DV.SIM.TYPES.MAX and 1) or 0
      else
         ret = (DV.SIM.running_type == DV.SIM.TYPES.MAX and 0) or 1
      end
   else
      print("SEED (" .. seed .. ") IS UNKNOWN")
      if DV.SIM.running_type == DV.SIM.TYPES.MAX then
         table.insert(DV.SIM.random.unknown.max, { seed = seed })
      else
         table.insert(DV.SIM.random.unknown.min, { seed = seed })
      end
      ret = (DV.SIM.running_type == DV.SIM.TYPES.MAX and 0) or 1
   end

   if min and max then
      return (max - min) * ret + min
   end
   return ret
end
--pseudorandom = DV.SIM.new_pseudorandom


-- Force ease_dollars() to trigger instantly during simulations
--    If not instant, some cards trigger using add_event() which is disabled

DV.SIM._ease_dollars = ease_dollars
DV.SIM.new_ease_dollars = function(mod, instant)
   if DV.SIM.running then
      instant = true
   end
   DV.SIM._ease_dollars(mod, instant)
end
--ease_dollars = DV.SIM.new_ease_dollars


function get_name_for_card(card, context)
   -- If it doesn't have a base, I don't know what it is
   if card.base == nil then return "UNKNOWN CARD" end
   -- It's a joker, get it's name
   if card.ability.set == 'Joker' then return card.base.name end
   -- otherwise, it's a playing card, and the modifiers may be random
   local edition = card.edition and card.edition.type
   local enhanced = card.config.center ~= G.P_CENTERS.c_base and card.ability.effect
   local seal = card.seal

   return card.base.name .. " / " .. tostring(edition) .. " / " .. tostring(enhanced) .. " / " .. tostring(seal)
end

function get_table_difference(table1, table2)
   local ret = 0
   for k, _ in pairs(table1) do
      if type(table1[k]) == type(table2[k]) then
         if type(table1[k]) == "number" then
            ret = ret + table1[k] - table2[k]
         elseif type(table1[k]) == "table" then
            ret = ret + get_table_difference(table1[k], table2[k])
         end
      end
   end
   return ret
end

DV.SIM._eval_card = eval_card
DV.SIM.new_eval_card = function(card, context)
   local max_triggers = #DV.SIM.random.unknown.max
   local min_triggers = #DV.SIM.random.unknown.min

   local ret, post_trig = DV.SIM._eval_card(card, context)
   if DV.SIM.running and G.SETTINGS.DV.show_min_max then
      local card_name = get_name_for_card(card)

      -- Max is ran first
      local new_max = #DV.SIM.random.unknown.max - max_triggers
      if new_max > 0 then
         if new_max > 1 then
            print("ERROR - DUPLICATE TRIGGER FOR " .. card_name .. " - UNKNOWN RESULTS")
         end

         -- if duplicate trigger, put results on each. Otherwise, should only affect one table
         while max_triggers < #DV.SIM.random.unknown.max do
            max_triggers = max_triggers + 1
            local seed_table = DV.SIM.random.unknown.max[max_triggers]
            seed_table.effect = ret
            seed_table.post = post_trig
            seed_table.card_name = card_name
         end
      end

      local new_min = #DV.SIM.random.unknown.min - min_triggers
      if new_min > 0 then
         if new_min > 1 then
            print("ERROR - DUPLICATE TRIGGER FOR " .. card_name .. " - UNKNOWN RESULTS")
         end

         while new_min > 0 do
            new_min = new_min - 1
            local seed = table.remove(DV.SIM.random.unknown.min, 1).seed
            local found_max = -1
            for i, v in ipairs(DV.SIM.random.unknown.max) do
               if v.seed == seed and v.card_name == card_name then
                  found_max = i
                  break
               end
            end
            if found_max == -1 then
               print("ERROR - SEED TABLE MISSING - UNKNOWN SEED - " .. seed)
            else
               local seed_table = table.remove(DV.SIM.random.unknown.max, found_max)
               local diff = get_table_difference(seed_table.effect, ret)
               DV.SIM.random.seeds[seed] = {}
               DV.SIM.random.seeds[seed].inverted = diff < 0
               if diff < 0 then
                  DV.SIM.random.need_reevaluation = true
               end
               print("STORING SEED - " .. seed .. " - AS " .. ((diff >= 0 and "NOT") or "") .. " INVERTED")
            end
         end
      end
   end
   return ret, post_trig
end
--eval_card = DV.SIM.new_eval_card
