local lovely_temp = ...
package.preload['lovely'] = function() return lovely_temp end
love.IS_SHADOW_REALM = true

Fake_Object = { __FAKE__TABLE__NAME = "love" }

function Fake_Object.__index(tbl, key)
   --print("ATTEMPTED READ: " .. tbl.__FAKE__TABLE__NAME .. "[" .. tostring(key) .. "]")
   local ret = { __FAKE__TABLE__NAME = tbl.__FAKE__TABLE__NAME .. "." .. tostring(key) }
   setmetatable(ret, Fake_Object)
   rawset(tbl, key, ret)
   return ret
end

function Fake_Object.__newindex(tbl, key, value)
   --print("ATTEMPTED WRITE " .. tbl.__FAKE__TABLE__NAME .. "[" .. tostring(key) .. "] = " .. tostring(value))
end

function Fake_Object.__call(...)
   local name = "new_obj("
   if arg and #arg > 0 and type(arg[1]) == "table" and type(arg[1].__FAKE__TABLE__NAME) == "string" then
      name = arg[1].__FAKE__TABLE__NAME .. "("
   end
   local ret = {}
   for i = 1, 6 do
      ret[i] = { __FAKE__TABLE__NAME = name .. i .. ")" }
      setmetatable(ret[i], Fake_Object)
   end
   return unpack(ret)
end

function Fake_Object.__add(a, b)
   if type(b) == "table" then
      local b_mt = getmetatable(b)
      if b_mt == Fake_Object then
         return a
      end
   end
   return b
end

function Fake_Object.__eq(a, b)
   return true
end

Fake_Object.__mul = Fake_Object.__add
Fake_Object.__sub = Fake_Object.__add
Fake_Object.__div = Fake_Object.__add
Fake_Object.__unm = Fake_Object.__add
Fake_Object.__pow = Fake_Object.__add
Fake_Object.__concat = Fake_Object.__add
Fake_Object.__le = Fake_Object.__add
Fake_Object.__lt = Fake_Object.__add

setmetatable(Fake_Object, Fake_Object)

require "love.system"
require "love.timer"
require "love.filesystem"
require "main"
love.keyboard = Fake_Object.keyboard
love.joystick = Fake_Object.joystick
love.graphics = Fake_Object.graphics
love.window = Fake_Object.window
love.mouse = Fake_Object.mouse
love.image = Fake_Object.image

-- fake functions:
local get2Numbers = function() return 1, 1 end
local getNumber = function() return 1 end
rawset(love.window, "getMode", get2Numbers)
rawset(love.graphics, "getWidth", getNumber)
rawset(love.graphics, "getHeight", getNumber)

love.load()
local temp = love.load
love.load = nil
local main_loop = love.run()
love.load = temp

G.SAVED_GAME = get_compressed('1/save.jkr')
if G.SAVED_GAME ~= nil then
    G.SAVED_GAME = STR_UNPACK(G.SAVED_GAME)
end
G:start_run({
    savetext = G.SAVED_GAME
})
G.GAME.blind = Blind(0,0,2, 1)

local main_channel = love.thread.getChannel("DV_SIMULATE_TO_MAIN")
local shadow_channel = love.thread.getChannel("DV_SIMULATE_TO_SHADOW")

love.RUNNING = true

while love.RUNNING do
   main_loop()
end
