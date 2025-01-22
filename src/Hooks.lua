--- Divvy's Simulation for Balatro - Engine.lua
--
-- Hook into functions to either disable or modify them during simulation, 
--     or to use them to track events

DV.SIM._event_manager_update = EventManager.update
DV.SIM.new_event_manager_update = function(self, dt, forced)
   DV.SIM._event_manager_update(self, dt, forced)
   if DV.SIM.waiting then
      local event_count = 0
      local max_delay = 0
      for k, v in pairs(G.E_MANAGER.queues) do
         if type(v) == "table" then
            event_count = event_count + #v
            for k2, v2 in pairs(v) do
               if v2 and type(v2.delay) == "number" and v2.delay > max_delay then
                  max_delay = v2.delay
               end
            end
         end
      end
      if max_delay > 0.1 then
         --print("STALLING RUN TO LET EVENTS QUEUE EMPTY - " .. event_count .. " - " .. max_delay)
      else
         --print("QUEUE IS EMPTY ENOUGH")
         DV.SIM.waiting = false
         G.E_MANAGER:add_event(Event({ trigger = "after", delay = max_delay + 0.1, func = DV.SIM.begin_simulation }))
      end
   end
end
EventManager.update = DV.SIM.new_event_manager_update

-- Runtime hooks to limit performance hits

function DV.SIM.hook_functions()
   -- LHS: Balatro's default functions
   -- RHS: this mod's modified versions
   pseudorandom = DV.SIM.new_pseudorandom
   ease_dollars = DV.SIM.new_ease_dollars
   check_for_unlock = DV.SIM.new_check_for_unlock
   play_sound = DV.SIM.new_play_sound
   update_hand_text = DV.SIM.new_update_hand_text
   EventManager.add_event = DV.SIM.new_add_event
end

function DV.SIM.unhook_functions()
   -- LHS: Balatro's (presumably hooked) functions
   -- RHS: this mod's saved default Balatro functions
   pseudorandom = DV.SIM._pseudorandom
   ease_dollars = DV.SIM._ease_dollars
   check_for_unlock = DV.SIM._check_for_unlock
   play_sound = DV.SIM._play_sound
   update_hand_text = DV.SIM._update_hand_text
   EventManager.add_event = DV.SIM._add_event
end

DV.SIM._add_event = EventManager.add_event
DV.SIM.new_add_event = function(self, event, queue, front)
   if not DV.SIM.running then
      return DV.SIM._add_event(self, event, queue, front)
   end
end

DV.SIM._ease_dollars = ease_dollars
DV.SIM.new_ease_dollars = function(mod, instant)
   if DV.SIM.running then
      instant = true
   end
   return DV.SIM._ease_dollars(mod, instant)
end

DV.SIM._update_hand_text = update_hand_text
DV.SIM.new_update_hand_text = function(config, vals)
   if not DV.SIM.running then
      return DV.SIM._update_hand_text(config, vals)
   end
end

DV.SIM._play_sound = play_sound
DV.SIM.new_play_sound = function(sound_code, per, vol)
   if not DV.SIM.running then
      return DV.SIM._play_sound(sound_code, per, vol)
   end
end

DV.SIM._check_for_unlock = check_for_unlock
DV.SIM.new_check_for_unlock = function(args)
   if not DV.SIM.running then
      return DV.SIM._check_for_unlock(args)
   end
end
