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

   if DV.SIM.thread then
      print("SENDING A MESSAGE")
      DV.SIM.channels.shadow:push("SIMULATE THE GAME")
   end
end

local delay = 0

function DV.SIM.love_update(dt)
   delay = delay + dt
   if DV.SIM.thread then
      -- In the real world
      local msg = DV.SIM.channels.main:pop()
      if msg then
         print("CONFIRMATION RECEIVED: " .. tostring(msg))
      end

      if delay > 0.2 then
         print("real loop - "..tostring(delay))
         delay = 0
      end
   else
      -- In the shadow realm
      local msg = DV.SIM.channels.shadow:pop()
      if msg then
         print("MESSAGE RECEIVED: " .. tostring(msg))
         DV.SIM.channels.main:push("RECEIVED")
      end

      if delay > 0.2 then
         print("shadow loop - "..tostring(delay))
         delay = 0
      end
   end

   DV.SIM._love_update(dt)
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
