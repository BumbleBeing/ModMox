-- Builds 16 x 16 pixel icons from a text grid. Run it through tools/sprites/build.sh.
--
-- For each icon in the grid file it makes <out>/<name>.aseprite, unless that file already
-- exists (a hand-edited .aseprite is the source of truth, so it is only replaced when the
-- icon is named in `force`). It then exports <out>/<name>.png from the .aseprite file and
-- draws every icon onto one contact sheet.
--
-- Params: grid, out, preview (all absolute paths), force ("", "all" or "name,name").

local SIZE = 16
local SCALES = { 1, 2, 4 }
local PAD = 8
local TONES = {
	["#"] = { 255, 255, 255 },
	["+"] = { 154, 163, 181 },
}
-- The contact sheet imitates a chip as CardShapes.chip draws it, over a stand-in for art.
local SHEET = { 96, 112, 88 }
local PANEL = { 20, 20, 26, 0.88 }
local OUTLINE = { 255, 255, 255, 0.55 }
local RADIUS = 4

local function fail(message)
	print("ERROR: " .. message)
	error(message)
end

local function read_icons(path)
	local icons = {}
	local current = nil
	for line in io.lines(path) do
		line = line:gsub("%s+$", "")
		if line:sub(1, 1) == "=" then
			current = { name = line:match("^=%s*([%w_]+)"), rows = {} }
			if current.name == nil then fail("bad name line: " .. line) end
			icons[#icons + 1] = current
		elseif line ~= "" and line:sub(1, 1) ~= ";" then
			if current == nil then fail("row before any '= name' line") end
			current.rows[#current.rows + 1] = line
		end
	end
	for _, icon in ipairs(icons) do
		if #icon.rows ~= SIZE then
			fail(icon.name .. " has " .. #icon.rows .. " rows, not " .. SIZE)
		end
		for y, row in ipairs(icon.rows) do
			if #row ~= SIZE then
				fail(icon.name .. " row " .. y .. " is " .. #row .. " wide, not " .. SIZE)
			end
			if row:find("[^%.#%+]") then
				fail(icon.name .. " row " .. y .. " has a character that is not . # or +")
			end
		end
	end
	return icons
end

local function is_forced(name, force)
	if force == "all" then return true end
	for wanted in force:gmatch("[^,]+") do
		if wanted == name then return true end
	end
	return false
end

local function draw_grid(icon, path)
	local sprite = Sprite(SIZE, SIZE, ColorMode.RGB)
	local palette = Palette(3)
	palette:setColor(0, Color { r = 0, g = 0, b = 0, a = 0 })
	palette:setColor(1, Color { r = TONES["#"][1], g = TONES["#"][2], b = TONES["#"][3], a = 255 })
	palette:setColor(2, Color { r = TONES["+"][1], g = TONES["+"][2], b = TONES["+"][3], a = 255 })
	sprite:setPalette(palette)
	local image = Image(SIZE, SIZE, ColorMode.RGB)
	for y, row in ipairs(icon.rows) do
		for x = 1, SIZE do
			local tone = TONES[row:sub(x, x)]
			if tone ~= nil then
				image:drawPixel(x - 1, y - 1, app.pixelColor.rgba(tone[1], tone[2], tone[3], 255))
			end
		end
	end
	sprite:newCel(sprite.layers[1], 1, image, Point(0, 0))
	sprite:saveAs(path)
	sprite:close()
end

local function mix(under, over, alpha)
	return {
		math.floor(under[1] + (over[1] - under[1]) * alpha + 0.5),
		math.floor(under[2] + (over[2] - under[2]) * alpha + 0.5),
		math.floor(under[3] + (over[3] - under[3]) * alpha + 0.5),
	}
end

-- Whether pixel (x, y) lies inside the chip's rounded square.
local function in_chip(x, y)
	if x < 0 or y < 0 or x >= SIZE or y >= SIZE then return false end
	local cx = math.max(RADIUS - 0.5, math.min(SIZE - RADIUS - 0.5, x))
	local cy = math.max(RADIUS - 0.5, math.min(SIZE - RADIUS - 0.5, y))
	return (x - cx) ^ 2 + (y - cy) ^ 2 <= (RADIUS - 0.5) ^ 2 + 0.5
end

-- The 16 x 16 colors of one chip with [param flat] (the icon's pixels) on it.
local function chip_pixels(flat)
	local pixels = {}
	local panel = mix(SHEET, PANEL, PANEL[4])
	local outline = mix(panel, OUTLINE, OUTLINE[4])
	for y = 0, SIZE - 1 do
		for x = 0, SIZE - 1 do
			local color = SHEET
			if in_chip(x, y) then
				local on_edge = not (in_chip(x - 1, y) and in_chip(x + 1, y)
					and in_chip(x, y - 1) and in_chip(x, y + 1))
				color = on_edge and outline or panel
				local pixel = flat:getPixel(x, y)
				local alpha = app.pixelColor.rgbaA(pixel) / 255.0
				if alpha > 0 then
					color = mix(color, {
						app.pixelColor.rgbaR(pixel), app.pixelColor.rgbaG(pixel), app.pixelColor.rgbaB(pixel),
					}, alpha)
				end
			else
				local pixel = flat:getPixel(x, y)
				if app.pixelColor.rgbaA(pixel) > 0 then
					color = { app.pixelColor.rgbaR(pixel), app.pixelColor.rgbaG(pixel), app.pixelColor.rgbaB(pixel) }
				end
			end
			pixels[y * SIZE + x] = color
		end
	end
	return pixels
end

local grid_path = app.params["grid"]
local out_dir = app.params["out"]
local preview_path = app.params["preview"]
local force = app.params["force"] or ""
if grid_path == nil or out_dir == nil or preview_path == nil then
	fail("needs the grid, out and preview params; run tools/sprites/build.sh")
end

local icons = read_icons(grid_path)
app.fs.makeAllDirectories(out_dir)
app.fs.makeAllDirectories(app.fs.filePath(preview_path))

local largest = SCALES[#SCALES] * SIZE
local sheet_height = PAD
for _, scale in ipairs(SCALES) do sheet_height = sheet_height + scale * SIZE + PAD end
local sheet = Image(PAD + #icons * (largest + PAD), sheet_height, ColorMode.RGB)
sheet:clear(app.pixelColor.rgba(SHEET[1], SHEET[2], SHEET[3], 255))

local names = {}
for index, icon in ipairs(icons) do
	local source = app.fs.joinPath(out_dir, icon.name .. ".aseprite")
	local state = "kept"
	if not app.fs.isFile(source) then
		draw_grid(icon, source)
		state = "new"
	elseif is_forced(icon.name, force) then
		draw_grid(icon, source)
		state = "redrawn"
	end
	local sprite = Sprite { fromFile = source }
	if sprite.width ~= SIZE or sprite.height ~= SIZE then
		fail(icon.name .. ".aseprite is not " .. SIZE .. " x " .. SIZE)
	end
	sprite:saveCopyAs(app.fs.joinPath(out_dir, icon.name .. ".png"))
	local flat = Image(SIZE, SIZE, ColorMode.RGB)
	flat:drawSprite(sprite, 1)
	sprite:close()

	local pixels = chip_pixels(flat)
	local top = PAD
	for _, scale in ipairs(SCALES) do
		local left = PAD + (index - 1) * (largest + PAD) + (largest - scale * SIZE) // 2
		for y = 0, SIZE * scale - 1 do
			for x = 0, SIZE * scale - 1 do
				local color = pixels[(y // scale) * SIZE + (x // scale)]
				sheet:drawPixel(left + x, top + y, app.pixelColor.rgba(color[1], color[2], color[3], 255))
			end
		end
		top = top + scale * SIZE + PAD
	end
	names[#names + 1] = icon.name .. " (" .. state .. ")"
end

sheet:saveAs(preview_path)
print("Left to right: " .. table.concat(names, ", "))
print("OK: " .. #icons .. " icons, sheet at " .. preview_path)
