--[[ 
LSystem - A generic l-system library.

Copyright © 2015 Sane (https://forum.minetest.net/memberlist.php?mode=viewprofile&u=10658)
License:  GNU Affero General Public License version 3 (AGPLv3) (http://www.gnu.org/licenses/agpl-3.0.html)
          See also: COPYING.txt
--]]

LSystem.State = {}

-- Returns a new l-system state.
--
-- global -> A the table to store in the info.global field.
-- state  -> A table from which to copy to the values to the info.state field.
-- r      -> A random number generator created with Lib.R.New.
--
-- The returned table will contain the following:
-- axiom         -> The table to collect the next axiom.
-- parameters    -> The table to collect the parameters for the rule's build functions.
-- parameter     -> The currently collected parameter. 
--                  Nil (that is not present) when no parameter is being collected.
-- info.key      -> The rule's axiom key.
-- info.global   -> The general l-system's state.
-- info.state    -> Current build's state.
-- info.LogLevel -> This returnes what an where to to log for the build function.
--                  Two values are returned: the the log level and the log destination.
-- 
LSystem.State.New = function (global, state, r)
	return {
		axiom      = {},
		parameters = {},
		info = {
			key       = "",
			global    = global,
			state     = Lib.CopyValues(state),
			r         = r,
			LogLevel  = function(self)
				local diag = self.global and self.global.diag
				if not diag then return 0 end 
				local diagLevels = global.diagLevels
				if not diagLevels then return 1, diag end
				return diagLevels[self.key] or diagLevels.default or 1, diag
			end,
		}
	} 
end
