Watch = {}

function Watch.new(keyTable, checkFunction)
	local watch = {
		downTime = {},
		down = {},
		press = {},
		release = {},
		
		keys = keyTable,
		check = checkFunction
	}
	
	-- Might be nice code style
	function watch:setup()
		local _, value
		
		for _, value in ipairs(self.keys) do
			self.downTime[value] = 0
			self.down[value]     = false
			self.press[value]    = false
			self.release[value]  = false
		end
	end
	
	function watch:update()
		local index, value, _
		
		for _, value in ipairs(self.keys) do
			self.down[value] = self.check(value)
			self.press[value] = false
			self.release[value] = false
			
			if self.down[value] then
				if self.downTime[value] == 0 then
					self.press[value] = true
				end
				self.downTime[value] = self.downTime[value] + 1
			else
				if self.downTime[value] > 0 then
					self.release[value] = true
				end
				self.downTime[value] = 0
			end
		end
	end
	
	watch:setup()
	
	return watch
end
