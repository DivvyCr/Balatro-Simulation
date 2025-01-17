--- Divvy's Simulation for Balatro - Engine.lua
--
-- Disable some functions during simulations (eg. UI updates).

DV.SIM._add_event = EventManager.add_event
DV.SIM.new_add_event = function(self, event, queue, front)
   if not DV.SIM.running then
      return DV.SIM._add_event(self, event, queue, front)
   end
end
EventManager.add_event = DV.SIM.new_add_event


DV.SIM._update_hand_text = update_hand_text
DV.SIM.new_update_hand_text = function(config, vals)
   if not DV.SIM.running then
      return DV.SIM._update_hand_text(config, vals)
   end
end
update_hand_text = DV.SIM.new_update_hand_text


DV.SIM._play_sound = play_sound
DV.SIM.new_play_sound = function(sound_code, per, vol)
   if not DV.SIM.running then
      return DV.SIM._play_sound(sound_code, per, vol)
   end
end
play_sound = DV.SIM.new_play_sound


DV.SIM._check_for_unlock = check_for_unlock
DV.SIM.new_check_for_unlock = function(args)
   if not DV.SIM.running then
      return DV.SIM._check_for_unlock(args)
   end
end
check_for_unlock = DV.SIM.new_check_for_unlock
