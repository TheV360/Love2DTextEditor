function setup()
	editor = {
		text = { "" },
		
		-- Stuff about the file
		file = {
			name = "untitled.txt",
			path = love.filesystem.getSaveDirectory(),
			
			lineBreak = "\n",
			tabConvert = "  "
		},
		
		-- Where the heck the mouse is
		mouse = {
			x = 0,
			y = 0
		},
		
		-- Where the heck your cursor is
		cursor = {
			x = 1,
			y = 1,
			
			-- Where the selection is
			select = {
				-- Is the selection a thing?
				enabled = false,
				
				-- Where the selection begins
				from = {
					x = 1,
					y = 1
				},
				
				-- Where the selection ends
				to = {
					x = 1,
					y = 1
				}
				
				-- Note that the selection's end can be before the selection's beginning.
				-- Use getCorrectSelection to get the correct coordinates.
			},
			
			-- h
			blink = {
				time = 0,
				max = 30
			}
		},
		
		-- How big one character is
		character = {
			width = 6,
			height = 8
		},
		
		-- How big the screen is in character units
		screen = {
			width = nil,
			height = nil
		},
		
		-- Where the camera is
		camera = {
			x = 1,
			y = 1
		},
		
		scrollbar = {
			longestLine = 1,
			
			thickness = 2,
			
			fade = {
				total = 0,
				
				stickTime = 90,
				fadeTime = 30
			}
		}
	}
	
	editor.screen.width = window.screen.width / editor.character.width
	editor.screen.height = window.screen.height / editor.character.height
	
	-- Unnecessary effects
	effects = {
		-- Should the screen shake?
		pow = false,
		
		-- Particles go here
		particles = {}
	}
	
	-- The screen can shake anywhere between the ranges you set.
	window.shake.extremes = false
	
	-- I draw my own mouse
	love.mouse.setVisible(false)
	
	-- Here's my mouse
	pointerImage = love.graphics.newImage("resources/pointer.png")
	
	-- Key Repeat
	love.keyboard.setKeyRepeat(true)
	
	-- Click thing???
	typeSound = love.audio.newSource("resources/type.wav", "static")
	
	-- Load from `stdin`
	incomingText = string.gsub(io.stdin:read('*a'), "\t", editor.file.tabConvert)
	editor.text = stringSplitFunky(incomingText, editor.file.lineBreak)
end

-- Add text
function love.textinput(t)
	removeSelection()
	addTo(editor.cursor.x, editor.cursor.y, t)
	moveCursor(1, 0)
	
	typeSoundAround(0.875)
	
	editor.scrollbar.longestLine = getLongestLine()
	showScrollbar()
end

-- Open file
function love.filedropped(file)
	local filename = file:getFilename()
	editor.file.name, editor.file.path = splitFileNamePath(filename)
	editor.text = {}
	
	local line
	for line in file:lines() do
		line = string.gsub(line, "\t", editor.file.tabConvert)
		table.insert(editor.text, line)
	end
	
	editor.cursor.x, editor.cursor.y = 1, 1
end
 
-- Oops, my template has overridden the love.keypressed function.
function _keypressed(key)
	-- Solid cursor when any key pressed, this is a QoL improvement in many text editors.
	editor.cursor.blink.time = 0
	
	if love.keyboard.isDown("lshift", "rshift") then
		if key == "up" then
			-- Select in every direction.
			moveSelection(0, -1)
		elseif key == "down" then
			moveSelection(0, 1)
		elseif key == "left" then
			moveSelection(-1, 0)
		elseif key == "right" then
			moveSelection(1, 0)
		elseif key == "home" then
			-- Select to the beginning of this line.
			moveSelection(1 - editor.cursor.x, 0)
		elseif key == "end" then
			-- Select to the end of this line.
			moveSelection(#editor.text[editor.cursor.y] + 1 - editor.cursor.x, 0)
		else
			return
		end
	elseif love.keyboard.isDown("lctrl", "rctrl") then
		if key == "up" then
			-- Scroll up
			moveCamera(0, -1)
		elseif key == "down" then
			-- Scroll down
			moveCamera(0, 1)
		elseif key == "o" then
			-- Open
			love.window.showMessageBox("Hey!", "I'm too lazy to add a file browser. Drop a file onto this and it'll open it.", "info")
		elseif key == "s" then
			-- Save
			love.filesystem.write(editor.file.name, getTextFromTo(1, 1, #editor.text[#editor.text] + 1, #editor.text))
			love.window.showMessageBox("Hey!", "saved as " .. editor.file.name, "info")
		elseif key == "x" then
			-- Cut
			love.system.setClipboardText(getSelectionText())
			removeSelection()
		elseif key == "c" then
			-- Copy
			love.system.setClipboardText(getSelectionText())
		elseif key == "v" then
			-- Paste
			-- The fixEOL function removes any CRLFs Windows may have added while SDL wasn't looking
			local c = fixEOL(love.system.getClipboardText())
			
			removeSelection()
			addTo(editor.cursor.x, editor.cursor.y, c)
			moveCursorWithWrap(#c, 0)
		elseif key == "a" then
			-- Select all
			editor.cursor.select.enabled = true
			editor.cursor.x, editor.cursor.y = #editor.text[#editor.text] + 1, #editor.text
			editor.cursor.select.from.x, editor.cursor.select.from.y = 1, 1
			editor.cursor.select.to.x, editor.cursor.select.to.y = editor.cursor.x, editor.cursor.y
		else
			return
		end
	elseif love.keyboard.isDown("lalt", "ralt") then
		if key == "up" then
			-- Move line up
			if editor.cursor.y > 1 then
				hellYes()
				editor.text[editor.cursor.y - 1], editor.text[editor.cursor.y] = editor.text[editor.cursor.y], editor.text[editor.cursor.y - 1]
				editor.cursor.y = editor.cursor.y - 1
			end
		elseif key == "down" then
			-- Move line down
			if editor.cursor.y < #editor.text then
				hellYes()
				editor.text[editor.cursor.y], editor.text[editor.cursor.y + 1] = editor.text[editor.cursor.y + 1], editor.text[editor.cursor.y]
				editor.cursor.y = editor.cursor.y + 1
			end
		else
			return
		end
		
		-- It's safe to say that any of these operations destroy the selection.
		editor.cursor.select.enabled = false
	else
		if key == "up" then
			moveCursorWithWrap(0, -1)
		elseif key == "down" then
			moveCursorWithWrap(0, 1)
		elseif key == "left" then
			moveCursorWithWrap(-1, 0)
		elseif key == "right" then
			moveCursorWithWrap(1, 0)
		elseif key == "home" then
			moveCursor(1 - editor.cursor.x, 0)
			moveCameraToCursor()
		elseif key == "end" then
			moveCursor(#editor.text[editor.cursor.y] + 1 - editor.cursor.x, 0)
			moveCameraToCursor()
		elseif key == "pageup" then
			moveCursor(0, -editor.screen.height)
		elseif key == "pagedown" then
			moveCursor(0, editor.screen.height)
		elseif (key == "delete" or key == "backspace") and editor.cursor.select.enabled then
			-- This kills the selection
			removeSelection()
		elseif key == "delete" then
			-- Needs to be refactored with all these new functions.
			
			if editor.cursor.x < #editor.text[editor.cursor.y] + 1 then
				removeFromTo(editor.cursor.x, editor.cursor.y, editor.cursor.x + 1)
			elseif editor.cursor.y < #editor.text then
				editor.text[editor.cursor.y] = editor.text[editor.cursor.y] .. table.remove(editor.text, editor.cursor.y + 1)
			end
		elseif key == "backspace" then
			-- Needs to be refactored with all these new functions.
			
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
			
			typeSoundAround(0.25)
		elseif key == "return" then
			-- If there's whitespace at the far left of this line, put it on the end of the thing I'm about to add
			-- string.find returns start and end indexes
			local s, e = string.find(editor.text[editor.cursor.y], "^[%s]*")
			
			-- Screw it, I'm repurposing variables like this
			s = editor.file.lineBreak
			if e > 0 then
				s = s .. string.sub(editor.text[editor.cursor.y], 1, e)
			end
			
			addTo(editor.cursor.x, editor.cursor.y, s)
			moveCursorWithWrap(#s, 0)
	
			typeSoundAround(0.5)
		else
			-- Stop this before it reaches the selection-destroying part.
			return
		end
		
		-- It's safe to say that any of these operations destroy the selection.
		editor.cursor.select.enabled = false
	end
end

-- Move 
function love.wheelmoved(x, y)
	if love.keyboard.isDown("lshift", "rshift") then x, y = -y, -x end
	moveCamera(x, -y)
end

function update()
	-- Get mouse coordinates
	editor.mouse.x, editor.mouse.y = mouseConvert(mouse.x, mouse.y)
	
	-- Moving cursor with mouse
	if mouse.down[1] then
		local x, y = getMouseCharacter()
		
		editor.cursor.x, editor.cursor.y = x, y
		
		-- Selecting stuff with mouse
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
		-- See main.lua:371
		window.shake.x = 4
		window.shake.y = 4
		effects.pow = false
	else
		window.shake.x = 0
		window.shake.y = 0
	end
	
	-- Scrollbar fade
	if editor.scrollbar.fade.total > 0 then
		editor.scrollbar.fade.total = editor.scrollbar.fade.total - 1
	end
	
	-- Particles
	for i = #effects.particles, 1, -1 do
		-- Turns out you don't have to make velocity slowly decay to have pretty particles.
		
		-- Move x and y by velocity x and velocity y
		effects.particles[i].x = effects.particles[i].x + effects.particles[i].vx
		effects.particles[i].y = effects.particles[i].y + effects.particles[i].vy
		
		-- Fake gravity
		effects.particles[i].vy = effects.particles[i].vy + 0.2
		
		-- The end is near
		effects.particles[i].l = effects.particles[i].l - 1
		
		-- The end is here
		if effects.particles[i].l <= 0 then table.remove(effects.particles, i) end
		
		-- Ominous comments but okay
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
			
			-- Shadow that only appears at high window scale (found this made it look worse)
			-- if window.screen.scale > 1 then
			-- 	love.graphics.setColor(1, 1, 1, 0.5)
			-- 	love.graphics.print(text, 1, j * editor.character.height + 1)
			-- end
			
			love.graphics.setColor(1, 1, 1, 1)
			love.graphics.print(text, 0, j * editor.character.height)
		end
	end
	
	-- Selection
	drawSelection()
	
	-- Cursor
	love.graphics.setColor(0.25, 0.5, 1, cosine(editor.cursor.blink.time, editor.cursor.blink.max, 0.75))
	love.graphics.rectangle(
		"fill",
		(editor.cursor.x - editor.camera.x) * editor.character.width,
		(editor.cursor.y - editor.camera.y) * editor.character.height,
		editor.character.width,
		editor.character.height
	)
	
	-- Scrollbar
	if editor.scrollbar.fade.total > 0 then
		if editor.scrollbar.fade.total <= editor.scrollbar.fade.fadeTime then
			love.graphics.setColor(0.75, 0.75, 0.75, (editor.scrollbar.fade.total / editor.scrollbar.fade.fadeTime) / 2)
		else
			love.graphics.setColor(0.75, 0.75, 0.75, 0.5)
		end
		
		local realX, realY = editor.scrollbar.longestLine - editor.screen.width + 30, #editor.text-- - editor.screen.height + 1
		
		if editor.camera.x <= realX then
			love.graphics.rectangle(
				"fill",
				((editor.camera.x - 1) / realX) * (window.screen.width - editor.scrollbar.thickness),
				window.screen.height - editor.scrollbar.thickness,
				(1 / realX) * (window.screen.width - editor.scrollbar.thickness),
				editor.scrollbar.thickness
			)
		end
		if editor.camera.y <= realY then
			love.graphics.rectangle(
				"fill",
				window.screen.width - editor.scrollbar.thickness,
				((editor.camera.y - 1) / realY) * (window.screen.height - editor.scrollbar.thickness),
				editor.scrollbar.thickness,
				(1 / realY) * (window.screen.height - editor.scrollbar.thickness)
			)
		end
		love.graphics.rectangle(
			"fill",
			window.screen.width - editor.scrollbar.thickness,
			window.screen.height - editor.scrollbar.thickness,
			editor.scrollbar.thickness,
			editor.scrollbar.thickness
		)
	end
	
	-- Mouse
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.draw(pointerImage, editor.mouse.x, editor.mouse.y)
	
	-- Debug stuff
	-- love.graphics.setColor(0, 0, 0, 0.75)
	-- love.graphics.rectangle("fill", 0, 25 * editor.character.height, editor.screen.width * editor.character.width, 5 * editor.character.height)
	-- love.graphics.setColor(1, 0.25, 0.5, 1)
	-- local half = editor.screen.width / 2
	-- love.graphics.print("Cursor at {" .. editor.cursor.x .. ", " .. editor.cursor.y .. "}", half * editor.character.width, 25 * editor.character.height)
	-- love.graphics.print("Cursor blink time: " .. editor.cursor.blink.time .. " / " .. editor.cursor.blink.max, half * editor.character.width, 26 * editor.character.height)
	-- if editor.cursor.select.enabled then
	-- 	love.graphics.print("Selection From {" .. editor.cursor.select.from.x .. ", " .. editor.cursor.select.from.y .. "}", 0, 25 * editor.character.height)
	-- 	love.graphics.print("To {" .. editor.cursor.select.to.x .. ", " .. editor.cursor.select.to.y .. "}", 0, 26 * editor.character.height)
	-- end
end

-- Move cursor without thinking
function moveCursor(x, y)
	editor.cursor.y = math.max(1, math.min(editor.cursor.y + y, #editor.text                     ))
	editor.cursor.x = math.max(1, math.min(editor.cursor.x + x, #editor.text[editor.cursor.y] + 1))
	
	moveCameraToCursor()
end

-- Move cursor with thinking
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
	
	-- hack solution to this problem
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

function moveCamera(x, y)
	editor.camera.x = math.max(1, editor.camera.x + x)
	editor.camera.y = math.max(1, editor.camera.y + y)
	
	showScrollbar()
end

function moveCameraToCursor()
	if editor.camera.y                            > editor.cursor.y then editor.camera.y = editor.cursor.y                              end
	if editor.camera.y + editor.screen.height - 1 < editor.cursor.y then editor.camera.y = editor.cursor.y - (editor.screen.height - 1) end
	if editor.camera.x                            > editor.cursor.x then editor.camera.x = editor.cursor.x                              end
	if editor.camera.x + editor.screen.width - 1  < editor.cursor.x then editor.camera.x = editor.cursor.x - (editor.screen.width  - 1) end
end

function withinCameraX(x)
	return x > editor.camera.x - 1 and x < editor.camera.x + editor.screen.width
end

function withinCameraY(y)
	return y > editor.camera.y - 1 and y < editor.camera.y + editor.screen.height
end

function withinCamera(x, y)
	return withinCameraX(x) and withinCameraY(y)
end

function drawSelection()
	if not editor.cursor.select.enabled then return end
	
	local fx, fy, tx, ty = getCorrectSelection()
	
	love.graphics.setColor(0.75, 0.75, 0.25, 0.5)
	if fy == ty then
		if not withinCameraY(fy) then return end
		
		love.graphics.rectangle("fill",
			(fx - editor.camera.x) * editor.character.width,
			(fy - editor.camera.y) * editor.character.height,
			(tx - fx) * editor.character.width,
			editor.character.height
		)
	else
		for j = fy, ty do
			if withinCameraY(j) then
				if j == fy then
					love.graphics.rectangle("fill",
						(fx - editor.camera.x) * editor.character.width,
						(fy - editor.camera.y) * editor.character.height,
						(#editor.text[j] + 1.5 - fx) * editor.character.width,
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
						(#editor.text[j] + 0.5) * editor.character.width,
						editor.character.height
					)
				end
			end
		end
	end
end

-- this is a mess
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

function getLongestLine()
	local j
	local l = 1
	
	for j = 1, #editor.text do
		l = math.max(l, #editor.text[j])
	end
	
	return l
end

function getTextFromTo(fx, fy, tx, ty)
	local j
	local r = ""
	
	if fy == ty then
		-- There's only one line, don't need to do much
		r = string.sub(editor.text[fy], fx, tx - 1)
	else
		-- Get first line's text
		r = string.sub(editor.text[fy], fx)
		
		-- Get all the other text
		for j = fy + 1, ty do
			r = r .. editor.file.lineBreak
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

-- Find what character the mouse is on top of
function getMouseCharacter()
	local x, y = editor.cursor.x, editor.cursor.y
	
	y = math.max(1, math.min(math.floor(editor.mouse.y / editor.character.height) + editor.camera.y, #editor.text))
	x = math.max(1, math.min(math.floor(editor.mouse.x / editor.character.width) + editor.camera.x, #editor.text[y] + 1))
	
	return x, y
end

-- Add some text at some point
function addTo(x, y, t)
	hellYes(x, y)
	
	local j
	local lines = {}
	
	lines = stringSplitFunky(t, editor.file.lineBreak)
	
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

-- Remove some text
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

-- Converts CRLF to LF, removes the mysterious invisible characters that sometimes appear when pasting text
function fixEOL(s)
	return string.gsub(s, "[\r\n]+", "\n")
end

function showScrollbar()
	editor.scrollbar.fade.total = editor.scrollbar.fade.stickTime + editor.scrollbar.fade.fadeTime
end

-- Copied from L2DSBL
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

function splitFileNamePath(filename)
	local lastSlash = #filename
	
	while lastSlash > 0 and string.sub(filename, lastSlash, lastSlash) ~= "/" do
		lastSlash = lastSlash - 1
	end
	
	return string.sub(filename, 1, lastSlash - 1), string.sub(filename, lastSlash + 1)
end

-- Particle at place
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

function typeSoundAround(n, m)
	typeSound:setPitch(n + love.math.random() * (m or 0.125))
	love.audio.play(typeSound)
end
