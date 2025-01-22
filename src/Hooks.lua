--- Divvy's Simulation for Balatro - Engine.lua
--
-- Disable some functions during simulations (eg. UI updates).

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
