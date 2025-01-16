--- Divvy's Simulation for Balatro - Engine.lua
--
-- The heart of this library: it replicates the game's score evaluation.




function DV.SIM.run()
   local null_ret = { score = { min = 0, exact = 0, max = 0 }, dollars = { min = 0, exact = 0, max = 0 } }
   if #G.hand.highlighted < 1 then return null_ret end

   DV.SIM.running = {
      min   = { chips = 0, mult = 0, dollars = 0 },
      exact = { chips = 0, mult = 0, dollars = 0 },
      max   = { chips = 0, mult = 0, dollars = 0 },
      reps  = 0
   }

   --print("FREEZING")
   DV.SIM.frozen = true
   partial_freeze()
   --print("FROZEN")

   if G.SETTINGS.DV.show_min_max then
      prepare_GAME()
      --print("Attempting max value")
      DV.SIM.running.max = test_hand(0)

      prepare_GAME()
      --print("Attempting min value")
      DV.SIM.running.min = test_hand(1)
   else
      prepare_GAME()
      --print("Attempting exact value")
      DV.SIM.running.exact = test_hand(0.5)
   end
   --print("THAWING")
   partial_unfreeze()
   DV.SIM.frozen = false
   --print("THAWED")


   local min_score   = math.floor(DV.SIM.running.min.chips * DV.SIM.running.min.mult)
   local exact_score = math.floor(DV.SIM.running.exact.chips * DV.SIM.running.exact.mult)
   local max_score   = math.floor(DV.SIM.running.max.chips * DV.SIM.running.max.mult)

   return {
      score   = { min = min_score, exact = exact_score, max = max_score },
      dollars = { min = DV.SIM.running.min.dollars, exact = DV.SIM.running.exact.dollars, max = DV.SIM.running.max.dollars }
   }
end

function prepare_GAME()
   --print("RESETTING")
   DV.SIM.DEBUG.check_for_real_fakes = true
   reset_pseudo_tables()
   DV.SIM.DEBUG.check_for_real_fakes = false

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

function test_hand(rng_val)
   DV.SIM.random = rng_val
   G.FUNCS.evaluate_play()

   local cash = DV.SIM.frozen_tables.GAME.dollars - G.GAME.dollars + (G.GAME.dollar_buffer or 0)

   --print("CALCULATED HAND - " .. hand_chips .. "x" .. mult .. " +" .. cash)

   DV.SIM.hands_calculated = DV.SIM.hands_calculated + 1
   return { chips = hand_chips, mult = mult, dollars = cash }
end

function partial_freeze()
   -- initial creation
   for k, _ in pairs(DV.SIM.frozen_tables) do
      DV.SIM.frozen_tables[k] = G[k]
      DV.SIM.pseudo_tables[k] = init_pseudo_table(DV.SIM.frozen_tables[k], k)
      G[k] = DV.SIM.pseudo_tables[k]
   end

   DV.SIM.G_tables.real = G
   if DV.SIM.G_tables.fake then
      -- clear it
      for k, _ in pairs(DV.SIM.G_tables.fake) do
         DV.SIM.G_tables.fake[k] = nil
      end
   else
      DV.SIM.G_tables.fake = create_pseudo_table(G, "G")
      DV.SIM.cached_connections[G] = nil
   end

   for k, v in pairs(DV.SIM.pseudo_tables) do
      DV.SIM.G_tables.fake[k] = v
   end
   G = DV.SIM.G_tables.fake
end

function partial_unfreeze()
   G = DV.SIM.G_tables.real
   for k, _ in pairs(DV.SIM.frozen_tables) do
      G[k] = DV.SIM.frozen_tables[k]
   end
end

function reset_pseudo_tables()
   local to_create = {}
   for tbl, pt in pairs(DV.SIM.cached_connections) do
      local mt = getmetatable(pt)
      if rawget(mt, "is_pseudo_table") == nil then
         print("TABLE IN cached_connections IS NOT PSEUDO TABLE - " .. rawget(mt, "debug_orig"))
      end


      for k, _ in pairs(pt) do
         rawset(pt, k, nil)
      end
      for k, v in pairs(tbl) do
         if type(v) == "table" and DV.SIM.ignore_values[k] == nil then
            rawset(pt, k, DV.SIM.cached_connections[v])
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
      rawset(pt, k, init_pseudo_table(tbl[k], "???." .. k))
   end
end

function init_pseudo_table(tbl, debug)
   debug = debug or ""

   if DV.SIM.cached_connections[tbl] then
      return DV.SIM.cached_connections[tbl]
   end

   local pt = create_pseudo_table(tbl, debug)
   for k, v in pairs(tbl) do
      if type(v) == "table" and DV.SIM.ignore_values[k] == nil then
         pt[k] = init_pseudo_table(v, debug .. "." .. k)
      end
   end

   return pt
end

function create_pseudo_table(tbl, debug)
   local pt = DV.SIM.cached_connections[tbl]
   if pt == nil then
      pt = {}

      local pt_mt = {}
      pt_mt.is_pseudo_table = true
      pt_mt.debug_orig = debug
      pt_mt.__index = tbl
      setmetatable(pt, pt_mt)

      DV.SIM.cached_connections[tbl] = pt
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

-- common_events.lua Hooks

local orig_check_for_unlock = check_for_unlock
function check_for_unlock(args)
   if not DV.SIM.frozen then
      return orig_check_for_unlock(args)
   end
end

local orig_update_hand_text = update_hand_text
function update_hand_text(config, vals)
   if not DV.SIM.frozen then
      return orig_update_hand_text(config, vals)
   end
end

-- event.lua Hook
local orig_add_event = EventManager.add_event
function EventManager:add_event(event, queue, front)
   if not DV.SIM.frozen then
      return orig_add_event(self, event, queue, front)
   end
end
