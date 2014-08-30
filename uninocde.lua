local bit = require("bit")
local bor, band, lshift, rshift, bnot = bit.bor, bit.band, bit.lshift, bit.rshift, bit.bnot

local LE = 0x1
local DE = 0x2

local BYTE_1_HEAD = 0x00		-- 0000 0000
local BYTE_2_HEAD = 0xC0		-- 1100 0000
local BYTE_3_HEAD = 0xE0		-- 1110 0000
local BYTE_TAIL_HEAD = 0x80     -- 1000 0000

local BYTE_1_MASK = 0x80		-- 1000 0000
local BYTE_2_MASK = 0xE0		-- 1110 0000
local BYTE_3_MASK = 0xF0		-- 1111 0000

local BYTE_TAIL_MASK = 0x3F		-- 0011 1111

function UTF8To16(utf8, order)
	assert(type(utf8) == 'string')
	local result, tmp = {}, {}
	local i, b1, b2, b3, high, low = 1, 0, 0, 0, 0, 0
	local len = #utf8

	while i <= len do
		b1 = string.byte(utf8, i)
		if band(b1, BYTE_1_MASK) == BYTE_1_HEAD then		-- 0### ####
			low = b1; high = 0
		elseif band(b1, BYTE_2_MASK) == BYTE_2_HEAD then 	-- 110# ####
			b2 = string.byte(utf8, i + 1)
			high = rshift(band(bnot(BYTE_2_MASK), b1), 2)
			low = bor(band(BYTE_TAIL_MASK, b2), lshift(b1, 6))
			i = i + 1
		elseif band(b1, BYTE_3_MASK) == BYTE_3_HEAD then	-- 1110 ####
			b2, b3 = string.byte(utf8, i + 1, i + 2)
			high = bor(lshift(b1, 4), rshift(band(BYTE_TAIL_MASK, b2), 2))
			low = bor(lshift(b2, 6), band(BYTE_TAIL_MASK, b3))
			i = i + 2
		end
		i = i + 1
		if order == DE then
			low, high = high, low
		end
		table.insert(result, string.format("%c%c", low, high))
	end
	return table.concat(result)
end

function UTF16To8(utf16, order)
	local low, high, r = 0, 0, 0
	local result = {}

	for i=1, #utf16, 2 do
		low, high = string.byte(utf16, i, i + 1)
		if order == DE then low, high = high, low end
		r = bor(lshift(high, 8), low)
		
		if r <= 0x7F then
			table.insert(result, string.format("%c", low))
		elseif r >= 0x80 and r <= 0x7FF then
			table.insert(result, string.format("%c%c", bor(BYTE_2_HEAD, band(bnot(BYTE_2_MASK), rshift(r, 6))),
													   bor(BYTE_TAIL_HEAD, band(BYTE_TAIL_MASK, r))))
		elseif r >= 0x800 and r <= 0xFFFF then
			table.insert(result, string.format("%c%c%c", bor(BYTE_3_HEAD, band(bnot(BYTE_3_MASK), rshift(r, 12))),
														 bor(BYTE_TAIL_HEAD, band(BYTE_TAIL_MASK, rshift(r, 6))),
														 bor(BYTE_TAIL_HEAD, band(BYTE_TAIL_MASK, r))))
		end
	end
	return table.concat(result)
end

local test = "a朱a"
local utf16 = UTF8To16(test, LE)
local utf8 = UTF16To8(utf16, LE)
print(utf8)
