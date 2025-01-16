--- Divvy's Simulation for Balatro - Engine.lua
--
-- Disable some functions during simulations (eg. UI updates).

DV.SIM._check_for_unlock = check_for_unlock
function check_for_unlock(args)
   if not DV.SIM.running then
      return DV.SIM._check_for_unlock(args)
   end
end

DV.SIM._update_hand_text = update_hand_text
function update_hand_text(config, vals)
   if not DV.SIM.running then
      return DV.SIM._update_hand_text(config, vals)
   end
end

DV.SIM._add_event = EventManager.add_event
function EventManager:add_event(event, queue, front)
   if not DV.SIM.running then
      return DV.SIM._add_event(self, event, queue, front)
   end
end

DV.SIM._play_sound = play_sound
function play_sound(sound_code, per, vol)
    if not DV.SIM.running then
        return DV.SIM._play_sound(sound_code, per, vol)
    end
end

DV.SIM._pseudorandom = pseudorandom
function pseudorandom(seed, min, max)
    if not DV.SIM.running or not G.SETTINGS.DV.show_min_max then
        return DV.SIM._pseudorandom(seed, min, max)
    elseif min and max then
        return (max - min) * DV.SIM.running_type + min
    end
    return DV.SIM.running_type
end

--[[
-- misc_function.lua
DV.SIM._copy_table = copy_table
function copy_table(O)
    if DV and DV.SIM and DV.SIM.frozen and type(O) == 'table' then
        local pt = DV.SIM.cached_connections[O]
        if pt == nil then
            local mt = getmetatable(O)
            if rawget(mt, "is_shadow_table") then
                pt = O
            end
        end

        if pt then
            local copy = {}
            for k, v in next, O, nil do
                copy[k] = copy_table(v)
            end
            setmetatable(copy, getmetatable(pt))
            return copy
        end
    end
    return DV.SIM._copy_table(O)
end
--]]
