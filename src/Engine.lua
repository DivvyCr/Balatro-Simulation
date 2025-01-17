--- Divvy's Simulation for Balatro - Engine.lua
--
-- Shadow the game's main tables to run simulations in an isolated environment.

function DV.SIM.run()
   local null_ret = {
      score   = {min = 0, exact = 0, max = 0},
      dollars = {min = 0, exact = 0, max = 0}
   }
   if #G.hand.highlighted < 1 then return null_ret end

   -- Simulation:

   DV.SIM.running = true
   DV.SIM.save_state()

   local min   = {chips = 0, mult = 0, dollars = 0}
   local exact = {chips = 0, mult = 0, dollars = 0}
   local max   = {chips = 0, mult = 0, dollars = 0}

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
   DV.SIM.running = false

   -- Return:

   local min_score   = math.floor(min.chips   * min.mult)
   local exact_score = math.floor(exact.chips * exact.mult)
   local max_score   = math.floor(max.chips   * max.mult)

   return {
      score   = {min = min_score,   exact = exact_score,   max = max_score},
      dollars = {min = min.dollars, exact = exact.dollars, max = max.dollars}
   }
end

function DV.SIM.simulate_play()
   DV.SIM.prepare_play()

   G.FUNCS.evaluate_play()

   local cash = G.GAME.dollars - DV.SIM.real.main.GAME.dollars

   --print("CALCULATED HAND - " .. hand_chips .. "x" .. mult .. " ($" .. cash .. ")")

   return {chips = hand_chips, mult = mult, dollars = cash}
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
      print("Fake PLAY #" .. i .. " = " .. card.base.name .." / card.T.x = " .. card.T.x)
   end
   --]]
end

function DV.SIM.save_state()
   -- Swap real global tables with simulation tables via `__index` metamethod;
   -- see comment in `DV.SIM.write_shadow_table` for some details.
   for k, _ in pairs(DV.SIM.real.main) do
      DV.SIM.real.main[k] = G[k]
      DV.SIM.fake.main[k] = DV.SIM.write_shadow_table(DV.SIM.real.main[k], k)
      G[k] = DV.SIM.fake.main[k]
   end

   -- Save the real `G` table:
   DV.SIM.real.global = G

   if DV.SIM.fake.global then
      -- Exists, so need to clear it:
      for k, _ in pairs(DV.SIM.fake.global) do
         DV.SIM.fake.global[k] = nil
      end
   else
      -- Does not exist, so need to create it:
      DV.SIM.fake.global = DV.SIM.create_shadow_table(G, "G")
      DV.SIM.fake.links[G] = nil
   end

   -- Populate the shadow `G` table:
   for k, v in pairs(DV.SIM.fake.main) do
      DV.SIM.fake.global[k] = v
   end
   -- Shadow the `G` table:
   G = DV.SIM.fake.global
end

function DV.SIM.restore_state()
   G = DV.SIM.real.global
   for k, _ in pairs(DV.SIM.real.main) do
      G[k] = DV.SIM.real.main[k]
   end
end

function DV.SIM.reset_shadow_tables()
   local to_create = {}
   for tbl, pt in pairs(DV.SIM.fake.links) do
      local mt = getmetatable(pt)
      if rawget(mt, "is_shadow_table") == nil then
         print("TABLE IN DV.SIM.fake.links IS NOT PSEUDO TABLE - " .. rawget(mt, "debug_orig"))
      end


      for k, _ in pairs(pt) do
         rawset(pt, k, nil)
      end
      for k, v in pairs(tbl) do
         if type(v) == "table" and not DV.SIM.IGNORED_KEYS[k] then
            rawset(pt, k, DV.SIM.fake.links[v])
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

   if DV.SIM.fake.links[tbl] then
      return DV.SIM.fake.links[tbl]
   end

   -- The key idea is that the `__index` metamethod in shadow tables
   -- allows value look-up in any underlying shadow table (fall-through);
   --
   -- BUT value update only affects the updated shadow table,
   -- without affecting any underlying shadow tables (shadowing).
   -- This should solve most possibilities for 'pointer hell'.

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
   local pt = DV.SIM.fake.links[tbl]

   if pt == nil then
      pt = {}

      local pt_mt = {}
      pt_mt.__index = tbl
      pt_mt.is_shadow_table = true
      pt_mt.debug_orig = debug
      setmetatable(pt, pt_mt)

      DV.SIM.fake.links[tbl] = pt
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
         print(tabs, k, ' = ', type(v))
         TablePrint(v, depth - 1, tabs .. '\t')
      else
         print(tabs, k, ': ', t[k])
      end
   end
end



-- Hook into pseudorandom() to force specific random results

DV.SIM._pseudorandom = pseudorandom
DV.SIM.new_pseudorandom = function(seed, min, max)
   if not DV.SIM.running or not G.SETTINGS.DV.show_min_max then
      return DV.SIM._pseudorandom(seed, min, max)
   elseif min and max then
      return (max - min) * DV.SIM.running_type + min
   end
   return DV.SIM.running_type
end
pseudorandom = DV.SIM.new_pseudorandom


-- Force ease_dollars() to trigger instantly during simulations
--    If not instant, some cards trigger using add_event() which is disabled

DV.SIM._ease_dollars = ease_dollars
DV.SIM.new_ease_dollars = function(mod, instant)
   if DV.SIM.frozen then
      instant = true
   end
   DV.SIM._ease_dollars(mod, instant)
end
ease_dollars = DV.SIM.new_ease_dollars