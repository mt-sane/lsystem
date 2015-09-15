--[[ 
LSystem - A generic l-system library.

Copyright © 2015 Sane (https://forum.minetest.net/memberlist.php?mode=viewprofile&u=10658)
License:  GNU Affero General Public License version 3 (AGPLv3) (http://www.gnu.org/licenses/agpl-3.0.html)
          See also: COPYING.txt
--]]

-- Converts a parameter table to an axiom parameter table.
-- 
-- parameters -> A table of string values.
-- axiom      -> nil or a table to append to.
--
-- Examples:
-- { "a", "b", "c", } -> { "(", "a", ")", "(", "b", ")", "(", "c", ")"      } -> as string -> "(a)(b)(c)"
-- { "(a)", "bc",   } -> { "(", "(", "a", "\", ")", ")", "(", "b", "c", ")" } -> as string -> "((a\))(bc)"
-- 
function LSystem.P2A(parameters, axiom)
	local axiom = axiom or {}
	
	for _, param in ipairs(parameters) do
		axiom[#axiom+1] = "("
		local length = #param
		for i = 1, length do 
			local c = param:sub(i,i)
			if c == ")" then
				axiom[#axiom+1] = "\\"
			end
			axiom[#axiom+1] = c
		end
		axiom[#axiom+1] = ")"
	end
	
	return axiom
end

-- Executes the l-system's inital 'rules'.
-- 
local function BuildInternal(state, stack)
	local key = state.info.key
	
	-- Collecting the parameters

	if state.parameter then
		local parameter = state.parameter
		if key ~= ")" or #parameter == 0 then
			parameter[#parameter+1] = key
		elseif parameter[#parameter] == "\\" then
			parameter[#parameter] = key
		else
			state.parameters[#state.parameters+1] = table.concat(parameter)
			state.parameter = nil
		end
	elseif  key == "(" then
		state.parameter = {}

	-- Push & Pop
	
	elseif key == "[" then
		local n = #stack
		stack[n+1] = Lib.CopyValues(state.info.state)
		stack[n+2] = Lib.CopyValues(state.parameters)

		state.axiom[#state.axiom+1] = key
	
	elseif key == "]" then
		local n = #stack
		state.parameters = stack[n]
		state.info.state = stack[n-1]
		stack[n  ]=nil
		stack[n-1]=nil

		state.axiom[#state.axiom+1] = key
	
	--
	else 
		return false
	end

	return true
end

-- Builds the next generation by excuting the current axiom.
--
local function Build(lsystem, depoys)
	local stack     = lsystem.stack
	local global    = lsystem.global
	local depoys    = depoys or global.depoys
	local state     = LSystem.State.New(lsystem.global, lsystem.state, lsystem.r)
	local info      = state.info
	local nextAxiom = state.axiom
	local axiom     = lsystem.axiom
	local count     = #axiom

	if info.global.diag then
		minetest.log(info.global.diag, "LSystem axiom='"..table.concat(axiom).."'.")
	end

	for index = 1, count do
		local key = axiom[index]
		info.key = key
		
		if not BuildInternal(state, stack) then
			local depoy = depoys and depoys[key]
			if depoy then depoy(info) end

			local rule = lsystem.rules[key]
			local build = rule and rule.Build or LSystem.Rule.B.Diag
			local a, p = build(rule, info, unpack(state.parameters))
			a = Lib.StringToTable(a or rule and rule.axiom or key)
			local length = #a
			if length > 1 and a[1] == "." then
				local pa = LSystem.P2A(state.parameters)
				local length = #a
				for i = 2, length do pa[#pa+1] = a[i] end
				a = pa
			end

			length = #a
			for i = 1, length do nextAxiom[#nextAxiom+1] = a[i] end
			
			state.parameters = p or {}
		end
	end
	
	lsystem.axiom = nextAxiom
	lsystem.generation = lsystem.generation + 1
	
	return state
end


-- Returns a new l-system.
--
-- axiom  -> The axiom that is executed when Build is called.
-- global -> Nil or a the table to store in the global field.
-- state  -> Nil or the inital values for the each build's state.
-- seed   -> Nil or a seed to initialize the l-system own random number generator.
-- rules  -> Nil or a table of rules.
--
-- Returnes a table with the following fields:
-- axiom      -> The axiom that is executed when Build is called.
-- global     -> A table that is passed to the rule's build functions. 
--               Rules can use this table to store information that needs to be kept from build to 
--               build. The l-system will never touch this table's content directly.
-- state      -> For each build the values of this table will be copied to an internal table which
--               is then passed to the rule's build functions. The internal table's  values will 
--               be copied to the stack and restored from it with the '[' and ']' axiom keys.
--               Rules can use the passed table to store information for the current build.
-- stack      -> Stack to store the current state in.
-- generation -> Current generation of the l-system. This is increased every time Build is called.
-- rules      -> A table of l-system rules.
-- r          -> A random number generator created by Lib.R.New.
-- Build      -> The function to build the next generation of the l-system.
--
LSystem.New = function(axiom, global, state, seed, rules)
	return {
		axiom  = Lib.StringToTable(axiom),
		global = global or {},
		state  = Lib.CopyValues(state) or {},
		stack  = {},
		generation = 1,
		rules = rules or {},
		r = Lib.Random.New(seed),
		Build = Build,
	}
end
