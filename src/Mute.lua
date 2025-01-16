-- Hooks for disabled functions during processing


-- misc_functions.lua
local orig_play_sound = play_sound
function play_sound(sound_code, per, vol)
    if not DV.SIM.frozen then
        return orig_play_sound(sound_code, per, vol)
    end
end

-- misc_functions.lua
local orig_pseudorandom = pseudorandom
function pseudorandom(seed, min, max)
    if not DV.SIM.frozen or not G.SETTINGS.DV.show_min_max then
        return orig_pseudorandom(seed, min, max)
    elseif min and max then
        return (max - min) * DV.SIM.random + min
    end
    return DV.SIM.random
end

--[[
-- misc_function.lua
local orig_copy_table = copy_table
function copy_table(O)
    if DV and DV.SIM and DV.SIM.frozen and type(O) == 'table' then
        local pt = DV.SIM.cached_connections[O]
        if pt == nil then
            local mt = getmetatable(O)
            if rawget(mt, "is_pseudo_table") then
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
    return orig_copy_table(O)
end
--]]