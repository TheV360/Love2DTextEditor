function setup()
	editor = {
		text = {
			"-- Might be nice code style",
			"function watch:setup()",
			"  local _, value",
			"  ",
			"  for _, value in ipairs(self.keys) do",
			"    self.downTime[value] = 0",
			"    self.down[value]     = false",
			"    self.press[value]    = false",
			"    self.release[value]  = false",
			"  end",
			"end",
			"",
			"function watch:update()",
			"  local index, value, _",
			"  ",
			"  for _, value in ipairs(self.keys) do",
			"    self.down[value] = self.check(value)",
			"    self.press[value] = false",
			"    self.release[value] = false",
			"    ",
			"    if self.down[value] then",
			"      if self.downTime[value] == 0 then",
			"        self.press[value] = true",
			"      end",
			"      self.downTime[value] = self.downTime[value] + 1",
			"    else",
			"      if self.downTime[value] > 0 then",
			"        self.release[value] = true",
			"      end",
			"      self.downTime[value] = 0",
			"    end",
			"  end",
			"end"
		},
		
		mouse = {
			x = 0,
			y = 0
		},
		
		cursor = {
			x = 1,
			y = 1,
			
			select = {
				enabled = false,
				from = {
					x = 1,
					y = 1
				},
				to = {
					x = 1,
					y = 1
				}
			},
			
			blink = {
				time = 0,
				max = 30
			}
		},
		
		character = {
			width = 6,
			height = 8
		},
		
		screen = {
			width = window.screen.width / 6,
			height = window.screen.height / 8
		},
		
		camera = {
			x = 1,
			y = 1
		},
		
		lineBreak = "\n"
	}
	
	effects = {
		pow = false,
		particles = {}
	}
	
	window.shake.extremes = false
	
	love.mouse.setVisible(false)
    love.keyboard.setKeyRepeat(true)
end

function love.textinput(t)
	removeSelection()
	addTo(editor.cursor.x, editor.cursor.y, t)
	moveCursor(1, 0)
end
 
function _keypressed(key)
	-- Solid cursor when any key pressed, this is a QoL improvement in many text editors.
	editor.cursor.blink.time = 0
	
	if love.keyboard.isDown("lshift", "rshift") then
		if key == "up" then
			moveSelection(0, -1)
		elseif key == "down" then
			moveSelection(0, 1)
		elseif key == "left" then
			moveSelection(-1, 0)
		elseif key == "right" then
			moveSelection(1, 0)
		elseif key == "home" then
			moveSelection(1 - editor.cursor.x, 0)
		elseif key == "end" then
			moveSelection(#editor.text[editor.cursor.y] + 1 - editor.cursor.x, 0)
		end
	elseif love.keyboard.isDown("lctrl", "rctrl") then
		if key == "up" then
			editor.camera.y = editor.camera.y - 1
		elseif key == "down" then
			editor.camera.y = editor.camera.y + 1
		elseif key == "x" then
			love.system.setClipboardText(getSelectionText())
			removeSelection()
		elseif key == "c" then
			love.system.setClipboardText(getSelectionText())
		elseif key == "v" then
			local c = fixEOL(love.system.getClipboardText())
			
			removeSelection()
			addTo(editor.cursor.x, editor.cursor.y, c)
			moveCursorWithWrap(#c, 0)
		elseif key == "a" then
			editor.cursor.select.enabled = true
			editor.cursor.x, editor.cursor.y = #editor.text[#editor.text] + 1, #editor.text
			editor.cursor.select.from.x, editor.cursor.select.from.y = 1, 1
			editor.cursor.select.to.x, editor.cursor.select.to.y = editor.cursor.x, editor.cursor.y
		end
	elseif love.keyboard.isDown("lalt", "ralt") then
		if key == "up" then
			if editor.cursor.y > 1 then
				editor.text[editor.cursor.y - 1], editor.text[editor.cursor.y] = editor.text[editor.cursor.y], editor.text[editor.cursor.y - 1]
				editor.cursor.y = editor.cursor.y - 1
			end
		elseif key == "down" then
			if editor.cursor.y < #editor.text then
				hellYes()
				editor.text[editor.cursor.y], editor.text[editor.cursor.y + 1] = editor.text[editor.cursor.y + 1], editor.text[editor.cursor.y]
				editor.cursor.y = editor.cursor.y + 1
			end
		end
	else
		if key == "up" then
			moveCursorWithWrap(0, -1)
			editor.cursor.select.enabled = false
		elseif key == "down" then
			moveCursorWithWrap(0, 1)
			editor.cursor.select.enabled = false
		elseif key == "left" then
			moveCursorWithWrap(-1, 0)
			editor.cursor.select.enabled = false
		elseif key == "right" then
			moveCursorWithWrap(1, 0)
			editor.cursor.select.enabled = false
		elseif key == "home" then
			editor.cursor.x = 1
			moveCameraToCursor()
		elseif key == "end" then
			editor.cursor.x = #editor.text[editor.cursor.y] + 1
			moveCameraToCursor()
		elseif key == "pageup" then
			moveCursor(0, -editor.screen.height)
		elseif key == "pagedown" then
			moveCursor(0, editor.screen.height)
		elseif (key == "delete" or key == "backspace") and editor.cursor.select.enabled then
			removeSelection()
		elseif key == "delete" then
			if editor.cursor.x < #editor.text[editor.cursor.y] + 1 then
				removeFromTo(editor.cursor.x, editor.cursor.y, editor.cursor.x + 1)
			elseif editor.cursor.y < #editor.text then
				editor.text[editor.cursor.y] = editor.text[editor.cursor.y] .. table.remove(editor.text, editor.cursor.y + 1)
			end
		elseif key == "backspace" then
			if editor.cursor.x > 1 then
				removeFromTo(editor.cursor.x - 1, editor.cursor.y, editor.cursor.x)
				moveCursor(-1, 0)
			elseif editor.cursor.y > 1 then
				local before = #editor.text[editor.cursor.y - 1] + 1
				editor.text[editor.cursor.y - 1] = editor.text[editor.cursor.y - 1] .. table.remove(editor.text, editor.cursor.y)
				editor.cursor.y = editor.cursor.y - 1
				editor.cursor.x = before
				moveCameraToCursor()
			end
		elseif key == "return" then
			addTo(editor.cursor.x, editor.cursor.y, editor.lineBreak)
			moveCursorWithWrap(1, 0)
		end
	end
end

function love.wheelmoved(x, y)
	editor.camera.x = math.max(1, editor.camera.x + x)
	editor.camera.y = math.max(1, editor.camera.y - y)
end

function update()
	-- Get mouse coordinates
	editor.mouse.x, editor.mouse.y = mouseConvert(mouse.x, mouse.y)
	
	-- Moving cursor with mouse
	if mouse.down[1] then
		local x, y = getMouseCharacter()
		
		editor.cursor.x, editor.cursor.y = x, y
		
		if mouse.press[1] then
			editor.cursor.select.enabled = false
			editor.cursor.select.from.x, editor.cursor.select.from.y = x, y
			editor.cursor.select.to.x, editor.cursor.select.to.y = x, y
			editor.cursor.blink.time = 0
		else
			if x ~= editor.cursor.select.to.x or y ~= editor.cursor.select.to.y then
				editor.cursor.select.enabled = true
				editor.cursor.blink.time = 0
				editor.cursor.select.to.x, editor.cursor.select.to.y = x, y
			end
		end
	end
	
	-- Blink cursor
	editor.cursor.blink.time = (editor.cursor.blink.time + 1) % editor.cursor.blink.max
	
	-- Screen shake
	if effects.pow then
		window.shake.x = 4
		window.shake.y = 4
		effects.pow = false
	else
		window.shake.x = 0
		window.shake.y = 0
	end
	
	-- Particles
	for i = #effects.particles, 1, -1 do
		effects.particles[i].x = effects.particles[i].x + effects.particles[i].vx
		effects.particles[i].y = effects.particles[i].y + effects.particles[i].vy
		effects.particles[i].vy = effects.particles[i].vy + 0.2
		effects.particles[i].l = effects.particles[i].l - 1
		
		if effects.particles[i].l <= 0 then table.remove(effects.particles, i) end
	end
end

function draw()
	love.graphics.clear()
	
	-- Background Pattern
	for j = 0, editor.screen.height - 1 do
		if editor.text[editor.camera.y + j] then
			if (editor.camera.y + j) % 2 == 0 then
				love.graphics.setColor(0.05, 0.05, 0.05)
			else
				love.graphics.setColor(0.1, 0.1, 0.1)
			end
			
			love.graphics.rectangle("fill", 0, j * editor.character.height, window.screen.width, editor.character.height)
		end
	end
	
	-- Particles
	for i = 1, #effects.particles do
		local s = math.floor(effects.particles[i].size / 2)
		love.graphics.setColor(1, 1, 1, effects.particles[i].l / effects.particles[i].lmax)
		love.graphics.rectangle("fill", (effects.particles[i].x - s) - (editor.camera.x * editor.character.width), (effects.particles[i].y - s) - (editor.camera.y * editor.character.height), effects.particles[i].size, effects.particles[i].size)
	end
	
	-- Text
	for j = 0, editor.screen.height - 1 do
		if editor.text[editor.camera.y + j] then
			local text = string.sub(editor.text[editor.camera.y + j], editor.camera.x, editor.camera.x + editor.screen.width)
			
			-- if window.screen.scale > 1 then
			-- 	love.graphics.setColor(1, 1, 1, 0.5)
			-- 	love.graphics.print(text, 1, j * editor.character.height + 1)
			-- end
			
			love.graphics.setColor(1, 1, 1, 1)
			love.graphics.print(text, 0, j * editor.character.height)
		end
	end
	
	-- Selection
	if editor.cursor.select.enabled then
		local fx, fy, tx, ty = getCorrectSelection()
		
		love.graphics.setColor(0.75, 0.75, 0.25, 0.5)
		if fy == ty then
			love.graphics.rectangle("fill",
				(fx - editor.camera.x) * editor.character.width,
				(fy - editor.camera.y) * editor.character.height,
				(tx - fx) * editor.character.width,
				editor.character.height
			)
		else
			for j = fy, ty do
				if j == fy then
					love.graphics.rectangle("fill",
						(fx - editor.camera.x) * editor.character.width,
						(fy - editor.camera.y) * editor.character.height,
						(#editor.text[j] + 1 - fx) * editor.character.width,
						editor.character.height
					)
				elseif j == ty then
					love.graphics.rectangle("fill",
						0,
						(ty - editor.camera.y) * editor.character.height,
						(tx - editor.camera.x) * editor.character.width,
						editor.character.height
					)
				else
					love.graphics.rectangle("fill",
						(1 - editor.camera.x) * editor.character.width,
						(j - editor.camera.y) * editor.character.height,
						#editor.text[j] * editor.character.width,
						editor.character.height
					)
				end
			end
		end
	end
	
	-- Cursor
	love.graphics.setColor(0.25, 0.5, 1, cosine(editor.cursor.blink.time, editor.cursor.blink.max, 0.75))
	love.graphics.rectangle(
		"fill",
		(editor.cursor.x - editor.camera.x) * editor.character.width,
		(editor.cursor.y - editor.camera.y) * editor.character.height,
		editor.character.width,
		editor.character.height
	)
	
	-- Mouse
	love.graphics.setColor(1, 0.25, 0.5, 1)
	line(editor.mouse.x, editor.mouse.y, editor.mouse.x + 5, editor.mouse.y + 5)
	line(editor.mouse.x, editor.mouse.y + 1, editor.mouse.x, editor.mouse.y + 3)
	line(editor.mouse.x + 1, editor.mouse.y, editor.mouse.x + 3, editor.mouse.y)
	
	-- Debug stuff
	-- love.graphics.print("Cursor at {" .. editor.cursor.x .. ", " .. editor.cursor.y .. "}", editor.screen.width / 2 * editor.character.width, 25 * editor.character.height)
	-- love.graphics.print("Cursor blink time: " .. editor.cursor.blink.time .. " / " .. editor.cursor.blink.max, editor.screen.width / 2 * editor.character.width, 26 * editor.character.height)
	-- if editor.cursor.select.enabled then
	-- 	love.graphics.print("Selection From {" .. editor.cursor.select.from.x .. ", " .. editor.cursor.select.from.y .. "}", 0, 25 * editor.character.height)
	-- 	love.graphics.print("To {" .. editor.cursor.select.to.x .. ", " .. editor.cursor.select.to.y .. "}", 0, 26 * editor.character.height)
	-- end
	-- if #debug_HECK > 1 then
	-- 	local sum = "{["
	-- 	for i = 1, #debug_HECK do
	-- 		if i > 1 then sum = sum .. "], [" end
	-- 		sum = sum .. debug_HECK[i]
	-- 	end
	-- 	sum = sum .. "]}"
	-- 	love.system.setClipboardText(sum)
	-- 	debug_HECK = {}
	-- end
end

function moveCursor(x, y)
	editor.cursor.y = math.max(1, math.min(editor.cursor.y + y, #editor.text                     ))
	editor.cursor.x = math.max(1, math.min(editor.cursor.x + x, #editor.text[editor.cursor.y] + 1))
	
	moveCameraToCursor()
end

function moveCursorWithWrap(x, y)
	if     y < 0 then
		if editor.cursor.y > 1 then
			moveCursor(0, -1)
		else
			editor.cursor.x = 1
			moveCameraToCursor()
		end
	elseif y > 0 then
		if editor.cursor.y < #editor.text then
			moveCursor(0, 1)
		else
			editor.cursor.x = #editor.text[editor.cursor.y] + 1
			moveCameraToCursor()
		end
	end
	
	while x ~= 0 do
		if     x < 0 then
			if editor.cursor.x > 1 then
				moveCursor(-1, 0)
			elseif editor.cursor.y > 1 then
				editor.cursor.y = editor.cursor.y - 1
				editor.cursor.x = #editor.text[editor.cursor.y] + 1
				moveCameraToCursor()
			end
		elseif x > 0 then
			if editor.cursor.x < #editor.text[editor.cursor.y] + 1 then
				moveCursor(1, 0)
			elseif editor.cursor.y < #editor.text then
				editor.cursor.y = editor.cursor.y + 1
				editor.cursor.x = 1
				moveCameraToCursor()
			end
		end
		
		x = x - sign(x)
	end
end

function moveSelection(x, y)
	if not editor.cursor.select.enabled then
		editor.cursor.select.from.x = editor.cursor.x
		editor.cursor.select.from.y = editor.cursor.y
		
		editor.cursor.select.enabled = true
	end
	
	moveCursorWithWrap(x, y)
	
	editor.cursor.select.to.x = editor.cursor.x
	editor.cursor.select.to.y = editor.cursor.y
end

function moveCameraToCursor()
	if editor.camera.y                            > editor.cursor.y then editor.camera.y = editor.cursor.y                              end
	if editor.camera.y + editor.screen.height - 1 < editor.cursor.y then editor.camera.y = editor.cursor.y - (editor.screen.height - 1) end
	if editor.camera.x                            > editor.cursor.x then editor.camera.x = editor.cursor.x                              end
	if editor.camera.x + editor.screen.width - 1  < editor.cursor.x then editor.camera.x = editor.cursor.x - (editor.screen.width  - 1) end
end

function getCorrectSelection()
	local fx, fy, tx, ty
	
	if editor.cursor.select.from.y < editor.cursor.select.to.y then
		fx, tx = editor.cursor.select.from.x, editor.cursor.select.to.x
		fy, ty = editor.cursor.select.from.y, editor.cursor.select.to.y
	elseif editor.cursor.select.from.y > editor.cursor.select.to.y then
		fx, tx = editor.cursor.select.to.x, editor.cursor.select.from.x
		fy, ty = editor.cursor.select.to.y, editor.cursor.select.from.y
	else
		fy, ty = editor.cursor.select.from.y, editor.cursor.select.to.y
		
		if editor.cursor.select.from.x < editor.cursor.select.to.x then
			fx, tx = editor.cursor.select.from.x, editor.cursor.select.to.x
		else
			fx, tx = editor.cursor.select.to.x, editor.cursor.select.from.x
		end
	end
	
	return fx, fy, tx, ty
end

function getTextFromTo(fx, fy, tx, ty)
	local j
	local r = ""
	
	if fy == ty then
		r = string.sub(editor.text[fy], fx, tx - 1)
	else
		r = string.sub(editor.text[fy], fx)
		for j = fy + 1, ty do
			r = r .. editor.lineBreak
			if j == ty then
				r = r .. string.sub(editor.text[j], 1, tx - 1)
			else
				r = r .. editor.text[j]
			end
		end
	end
	
	return r
end

function getSelectionText()
	if not editor.cursor.select.enabled then return end
	
	local fx, fy, tx, ty = getCorrectSelection()
	
	return getTextFromTo(fx, fy, tx, ty)
end

function getMouseCharacter()
	local x, y = editor.cursor.x, editor.cursor.y
	
	y = math.max(1, math.min(math.floor(editor.mouse.y / editor.character.height) + editor.camera.y, #editor.text))
	x = math.max(1, math.min(math.floor(editor.mouse.x / editor.character.width) + editor.camera.x, #editor.text[y] + 1))
	
	return x, y
end

function addTo(x, y, t)
	hellYes(x, y)
	
	local j
	local lines = {}
	
	lines = stringSplitFunky(t, editor.lineBreak)
	
	if #lines == 1 then
		editor.text[y] = string.sub(editor.text[y], 1, x - 1) .. t .. string.sub(editor.text[y], x)
	else
		local after = string.sub(editor.text[y], x)
		editor.text[y] = string.sub(editor.text[y], 1, x - 1) .. lines[1]
		for j = #lines, 2, -1 do
			if j == #lines then
				table.insert(editor.text, y + 1, lines[j] .. after)
			else
				table.insert(editor.text, y + 1, lines[j])
			end
		end
	end
end

function removeFromTo(fx, fy, tx, ty)
	local j
	
	tx = tx or fx
	ty = ty or fy
	
	if fy == ty then
		editor.text[fy] = string.sub(editor.text[fy], 1, fx - 1) .. string.sub(editor.text[ty], tx)
	else
		editor.text[fy] = string.sub(editor.text[fy], 1, fx - 1)
		for j = ty, fy + 1, -1 do
			if j == ty then
				editor.text[fy] = editor.text[fy] .. string.sub(table.remove(editor.text, j), tx)
			else
				table.remove(editor.text, j)
			end
		end
	end
	
	hellYes(fx, fy)
	particleExplodeAtCharacter(tx, ty)
end

function removeSelection()
	if not editor.cursor.select.enabled then return end
	
	local fx, fy, tx, ty = getCorrectSelection()
	
	removeFromTo(fx, fy, tx, ty)
	
	editor.cursor.x = fx
	editor.cursor.y = fy
	
	editor.cursor.select.enabled = false
	
	hellYes(tx, ty)
end

function fixEOL(s)
	return string.gsub(s, "[\r\n]+", "\n")
end

-- String split function because it includes empty strings.
-- Seems pretty slow. Optimize?
function stringSplitFunky(string, delimiter, max)
	local result = {}
	local next = string.find(string, delimiter)
	local current = 0
	
	if not next then return {string} end
	
	repeat
		table.insert(result, string.sub(string, current, next - 1))
		current = next + 1
		
		if max and #result > max then
			break
		end
		
		next = string.find(string, delimiter, current)
	until not next
	
	if not (max and #result > max) then
		table.insert(result, string.sub(string, current))
	end
	
	return result
end

function particle(x, y, vx, vy)
	local p = {
		x = x,
		y = y,
		vx = vx,
		vy = vy,
		size = math.floor(math.random(1, 3)),
		lmax = math.floor(math.random(30, 60))
	}
	p.l = p.lmax
	
	table.insert(effects.particles, p)
end

function particleExplode(x, y)
	local i
	
	for i = 0, 15 do
		particle(x + math.random() * 2 - 1, y + math.random() * 2 - 1, math.random() * 8 - 4, -3 - math.random())
	end
end

function particleExplodeAtCharacter(x, y)
	particleExplode((x + 0.5) * editor.character.width, (y + 0.5) * editor.character.height)
end

function hellYes(x, y)
	effects.pow = true
	particleExplodeAtCharacter(x or editor.cursor.x, y or editor.cursor.y)
end
