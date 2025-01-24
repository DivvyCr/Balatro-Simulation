--
-- Util functions:
--

function DV.SIM.get_length(tbl)
   local ret = 0
   for _, _ in pairs(tbl) do
      ret = ret + 1
   end
   return ret
end

function DV.SIM.start_timer()
   if DV.SIM.DEBUG then
      print("SIMULATION #" .. DV.SIM.total_simulations .. " STARTING")
      DV.SIM.debug_data.t0 = love.timer.getTime()
      DV.SIM.debug_data.t1 = DV.SIM.debug_data.t0
   end
end

function DV.SIM.debug_timer(msg)
   if DV.SIM.DEBUG then
      local time = love.timer.getTime()
      if DV.SIM.DEBUG.immediate then
         print(string.format("%s:  %.2fms", msg, 1000 * (time - DV.SIM.debug_data.t1)))
         DV.SIM.debug_data.t1 = time
      else
         table.insert(DV.SIM.debug_data.t, time)
         table.insert(DV.SIM.debug_data.label, msg)
      end
   end
end

function DV.SIM.stop_timer()
   if DV.SIM.DEBUG then
      local finish = love.timer.getTime()

      if not DV.SIM.DEBUG.immediate then
         local prev = DV.SIM.debug_data.t0
         for i = 1, #DV.SIM.debug_data.t do
            local diff = DV.SIM.debug_data.t[i] - prev
            print(string.format("%s:  %.2fms", DV.SIM.debug_data.label[i], 1000 * diff))
            prev = DV.SIM.debug_data.t[i]
         end
         DV.SIM.debug_data.t = {}
         DV.SIM.debug_data.label = {}
      end

      print(string.format("TOTAL SIMULATION TIME:  %.2fms", 1000 * (finish - DV.SIM.debug_data.t0)))
   end
end

function DV.SIM.get_card_description(card)
   if card and type(card.is) == "function" and card:is(Card) then
      local card_type = card.ability.set or "None"
      if card_type == 'Default' or card_type == 'Enhanced' then
         return {name = "CARD: " .. card.base.name}
      elseif card_type == "Joker" then
         return {name = "JOKER: " .. card.ability.name}
      end
   end
   return card
end

function DV.SIM.DEBUG_RECURSIVE_PRINT(tbl, location, max_depth)
   max_depth = max_depth or 4
   location = location or "BASE"
   print(string.format("%s (%s) = %s", location, type(tbl), tostring(tbl)))
   if max_depth > 1 then
      if type(tbl) == "table" then
         local tbl_mt = getmetatable(tbl)
         if tbl_mt and tbl_mt.is_shadow_table then
            tbl = tbl_mt.real_table
         end
         if type(tbl.is) == "function" and tbl:is(Card) then
            tbl = DV.SIM.get_card_description(tbl)
         end
         for k, v in pairs(tbl) do
            local new_loc = "   " .. location .. "." .. k
            if v == G.jokers then
               print(string.format("%s (%s) = G.jokers", new_loc, type(tbl)))
            elseif v == G.play then
               print(string.format("%s (%s) = G.play", new_loc, type(tbl)))
            elseif v == G.hand then
               print(string.format("%s (%s) = G.hand", new_loc, type(tbl)))
            elseif v == G.consumeables then
               print(string.format("%s (%s) = G.consumeables", new_loc, type(tbl)))
            elseif v == G.deck then
               print(string.format("%s (%s) = G.deck", new_loc, type(tbl)))
            elseif v == G.discard then
               print(string.format("%s (%s) = G.discard", new_loc, type(tbl)))
            else
               DV.SIM.DEBUG_RECURSIVE_PRINT(v, new_loc, max_depth - 1)
            end
         end
      end
   end
end

function DV.SIM.print_cardareas()
   for i, card in ipairs(G.hand.cards) do
      print("HAND #" .. i .. " - " .. tostring(card.base and card.base.name) .. " / " ..
         tostring(card.ability and card.ability.effect) .. " / " .. tostring(card.edition and card.edition.type))
   end
   for i, card in ipairs(G.hand.highlighted) do
      print("HAND HIGHLIGHTED #" .. i .. " - " .. tostring(card.base and card.base.name) .. " / " ..
         tostring(card.ability and card.ability.effect) .. " / " .. tostring(card.edition and card.edition.type))
   end
   for i, card in ipairs(G.play.cards) do
      print("PLAY #" .. i .. " - " .. tostring(card.base and card.base.name) .. " / " ..
         tostring(card.ability and card.ability.effect) .. " / " .. tostring(card.edition and card.edition.type))
   end
end