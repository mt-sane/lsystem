--[[ 
LSystem - A generic l-system library.

Copyright © 2015 Sane (https://forum.minetest.net/memberlist.php?mode=viewprofile&u=10658)
License:  GNU Affero General Public License version 3 (AGPLv3) (http://www.gnu.org/licenses/agpl-3.0.html)
          See also: COPYING.txt
--]]

LSystem.Rule = {}

-- Returns a new rule.
--
-- axiom -> The default replacement text. 
-- build -> The rule's build function.
-- param -> nil or aditional parameters atored in the param field.
--
-- Returns a table with the following fields:
-- axiom: The text that the default mechanism will use to replace the rule's key in the currently 
--        executing l-system's axiom.
-- param: Parameters passed the New function that constructed the rule.
-- Build: The rule's build function.
--        This function is called whenever the l-system hits the rule's key within the currently 
--        executing l-system's axiom. 
--        If this function is missing or returns nil axiom will be used to replace the key.
--        If a value is returned, that value will replace the key.
--
function LSystem.Rule.New(axiom, build, param)
	local o = {}

	o.axiom = axiom or ""
	o.Build = build
	o.param = param or {}

	return o
end

-- Following are a set common rule build functions.

LSystem.Rule.B = {}

-- Use this to check your l-system inner workings.
--
-- info -> The l-system's current build info.
-- ...  -> Parameters passed to the rule's build function.
--
-- The function will check the folowing info.global fields:
-- diag       -> nil or the log stream to issue the log to.
--               If nil nothing the function does nothing.
--               All other values are passed directly as the first parameter to minetest.log.
-- diagLevels -> nil or a table of log levels per rule key.
--               If nil all rules are logged with level 1.
--
-- Log levels: 
-- 0 - Nothing.
-- 1 - Action.      -> Log the that the rule is called.
--                     Default rules use LSystem.Rule.B.Diag for action log.
-- 2 - 1 + Info.    -> Additionally log what the rules does.
--                     Default rules log when they change info fileds. If they contain a random
--                     component the result will be logged too.
-- 3 - 2 + Verbose. -> Whatever else is deemed necessary to be logged.
--                     Default rules do not log anything verbose.
--               
-- Example: 
-- diagLevels = { a=0, b=1, c=2, } -> Rule a will not be logged.
--                                    Rule b will log it's actions.
--                                    Rule c will log it's actions and decisions.
--                                    All other rules log on level 1.
--
-- The logged informations are: 
-- info.key       -> The key of the rule,
-- info.parameter -> Parameters passed to the rule.
-- info.state.pos -> The current position.
-- info.state.dir -> The current direction.
--
function LSystem.Rule.B:Diag(info, ...)
	local logLevel, diag = info:LogLevel()
	if logLevel == 0 then return end

	local m = {}
	local state = info.state
	m[#m+1] = "LSystem Rule '"
	m[#m+1] = info.key
	
	-- Parameters
	local paramCount = select("#", ...)
	if paramCount > 0 then
		m[#m+1] = "', ...="
		for i = 1, paramCount, 1 do
			if i > 1 then m[#m+1] = ", " end
			m[#m+1] = "'"
			m[#m+1] = tostring(select(i, ...))
			m[#m+1] = "'"
		end
	else
		m[#m+1] = "'"
	end
	
	-- Position
	if state.pos then
		m[#m+1] = ", pos='"
		m[#m+1] = minetest.pos_to_string(state.pos)
		m[#m+1] = "'"
	end
	
	-- Direction
	if state.dir then
		m[#m+1] = ", dir='"
		m[#m+1] = minetest.pos_to_string(state.dir)
		m[#m+1] = "'"
	end
	m[#m+1] = "."
	
	minetest.log(diag, table.concat(m))
end

-- Moves the current position in the current direction.
--
-- info -> The l-system's current build info.
--
-- This simply adds info.state.dir to info.state.pos.
--
function LSystem.Rule.B:Move(info, ...)
	local logLevel, diag = info:LogLevel()
	if logLevel > 0 then LSystem.Rule.B.Diag(self, info, ...) end

	local state = info.state
	state.pos = vector.add(state.pos, state.dir)
	if logLevel > 1 then minetest.log(diag, "\tnew pos="..minetest.pos_to_string(state.pos)) end
end

-- Sets the direction (state.dir) to one of the cardinal directions.
--
-- info     -> The l-system's current build info.
-- cardinal -> This selects the direction. Valid directions are: n,s,e,w,u,d,c
--             Nil selects north.
--
-- Examples:
-- '(w)k' -> dir = west {x=-1,y=0,z=0}
-- '(n)k' -> dir = west {x=-1,y=0,z=0}
--
function LSystem.Rule.B:SetDir(info, cardinal, ...)
	local logLevel, diag = info:LogLevel()
	if logLevel > 0 then LSystem.Rule.B.Diag(self, info, cardinal, ...) end

	info.state.dir = cardinal and Lib.Cardinal.C[cardinal] or Lib.Cardinal.C.n
	if logLevel > 1 then minetest.log(diag, "\tnew dir="..minetest.pos_to_string(info.state.dir)) end
end

local axis_rotation_functions = {
	x = Lib.Mat.RXF,
	y = Lib.Mat.RYF,
	z = Lib.Mat.RZF,
}

local x_rotation_cash = {}
local y_rotation_cash = {}
local z_rotation_cash = {}

local rotation_cashes = {
	x = x_rotation_cash,
	w = x_rotation_cash,
	s = x_rotation_cash,

	y = y_rotation_cash,
	a = y_rotation_cash,
	d = y_rotation_cash,

	z = z_rotation_cash,
	q = z_rotation_cash,
	r = z_rotation_cash,
}

-- Changes the current direction
--
-- info         -> The l-system's current build info.
-- rotation_key -> This selects the turning direction.
--                 If this is an axis key ("x", "y", "z") then rotation is about that axis.
--                 If this is a turn key ("w", "s", "a", "d", "q", "e") you can think of the 
--                 turning direction as the movement keys in computer games: 
--                 w = pitch down, s = pitch up.
--                 a = yaw   left, d = yaw   right.
--                 q = roll  left,  e = roll right.
--                 If non of these the function will do nothing
--  angle       -> If supplied this sets how far the direction is changed.
--                 if this is nil     the angle field in the local  state will be used
--                 if that is nil too the angle field in the global state will be used
--                 if that is nil too 0° will be used
--
-- Examples:
-- todo
--
function LSystem.Rule.B:Turn(info, rotation_key, angle, ...)
	local logLevel, diag = info:LogLevel()
	if logLevel > 0 then LSystem.Rule.B.Diag(self, info, turnKey, angle, ...) end

	-- No parameter supplied 
	
	if not turnKey then return end
	
	-- An unknown key
	
	local cash = rotation_cashes[turnKey]
	if not cash then return end
	
	-- A zero degree turn
	
	angle = angle or state.angle or info.global.angle or 0
	if angle == 0 then return end

	-- Determine the rotation function

	local turns = turnKey and Lib.Cardinal.Turns[turnKey]
	local f = 
		turns and turns.F
		or axis_rotation_functions[turnKey]

	-- Execute the turn
	
	state.dir = vector.new(f(angle, cash)(state.dir)

	if logLevel > 1 then minetest.log(diag, "\tnew dir="..minetest.pos_to_string(state.dir)) end
end

-- Injects a random number parameter.
-- 
-- info -> The l-system's current build info.
--
-- The function will repeat all parameters it is called with, appended by a 'random' number. So 
-- you can use the rule repeated.
-- Note that the random numbers are global. You will get differen number sequences each call to 
-- the l-system's Build function.
-- 
-- Examples:
-- With rule key = 'k'
--      next 'random' numbers = 0.4711, 0.815
--
-- 'kx'           -> will act like '(0.4711)x'
-- 'kkx'          -> will act like '(0.4711)(0.815)x'
-- '(cat)k(dog)x' -> will act like '(cat)(0.4711)(dog)x'
-- 
function LSystem.Rule.B:Random(info, ...)
	local logLevel, diag = info:LogLevel()
	if logLevel > 0 then LSystem.Rule.B.Diag(self, info, ...) end

	local r = info.r.NextReal()
	if logLevel > 1 then minetest.log(diag, "\tr="..r..".") end
	
	return nil, ... and { ..., r } or { r }
end

-- TOdo Select parameter
-- This selects a random character from the parameter and issues it either as axiom or parameter.
--
-- info -> The l-system's current build info.
-- set  -> A set of characters to choose from. An index is chosen randomly and the character at 
--         that position is injected. So if you want it to be more likely to select a specific
--         character, simply repeat it.
--
-- Call the LSystem.Rule.New function with a param table that contains a field asParam to let 
-- Select return the character as a parameter else it will be returned as axiom.
-- For example sys.rules.S = LSystem.Rule.New(".S", LSystem.Rule.B.Select, { asParam = 1, } )
-- 
-- Examples:
-- With rule key = 'k'
--      
-- '(nsew)kx' -> next axiom = '(w)x' with 'w' being the randomly choosen character.
-- 
function LSystem.Rule.B:Select(info, set, ...)
	local logLevel, diag = info:LogLevel()
	if logLevel > 0 then LSystem.Rule.B.Diag(self, info, set, ...) end
	
	if not set then 
		if logLevel > 1 then minetest.log(diag, "\tset=nil.") end
		return 
	end

	local count = #set
	if count == 0 then 
		if logLevel > 1 then minetest.log(diag, "\tset=''.") end
		return 
	end
	
	if count == 1 then 
		if logLevel > 1 then minetest.log(diag, "\tset='"..set.."'.") end
		return nil, { set } 
	end

	local r         = info.r.NextReal()
	local index     = 1 + math.floor(r * count)
	local character = set:sub(index,index)
	
	if logLevel > 1 then minetest.log(diag, "\tindex="..index..", character='"..character.."'.") end
	
	if self.param.asParam then
		return nil, { character }
	end

	return character
end

-- Returns it's param as axiom parameters.
--
-- Examples:
-- With rule key = 'k'
--      s = Select Rule with axiom = ".s", with randoml selection sequence "w", "s".
--      x = some arbitrary rule with axiom = "x" 
--
-- '(nsew)skx' -> next generation axiom = "(nsew)sk(w)x"
--                next generation axiom = "(nsew)sk(s)x"
-- 
function LSystem.Rule.B:P2A(info, ...)
	local logLevel, diag = info:LogLevel()
	if logLevel > 0 then LSystem.Rule.B.Diag(self, info, ...) end

	local axiom = LSystem.P2A({ ... }, Lib.StringToTable(self.axiom))
	return table.concat(axiom)
end






























