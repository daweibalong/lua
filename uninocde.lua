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
			low = b1; high = 0; i = i + 1
		elseif band(b1, BYTE_2_MASK) == BYTE_2_HEAD then 	-- 110# ####
			b2 = string.byte(utf8, i + 1)
			high = rshift(band(bnot(BYTE_2_MASK), b1), 2)
			low = bor(band(BYTE_TAIL_MASK, b2), lshift(b1, 6))
			i = i + 2
		elseif band(b1, BYTE_3_MASK) == BYTE_3_HEAD then	-- 1110 ####
			b2, b3 = string.byte(utf8, i + 1, i + 2)
			high = bor(lshift(b1, 4), rshift(band(BYTE_TAIL_MASK, b2), 2))
			low = bor(lshift(b2, 6), band(BYTE_TAIL_MASK, b3))
			i = i + 3
		end
		if order == DE then low, high = high, low end
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
			table.insert(result, string.format("%c%c",
			bor(BYTE_2_HEAD, band(bnot(BYTE_2_MASK), rshift(r, 6))),
			bor(BYTE_TAIL_HEAD, band(BYTE_TAIL_MASK, r))))
		elseif r >= 0x800 and r <= 0xFFFF then
			table.insert(result, string.format("%c%c%c", 
			bor(BYTE_3_HEAD, band(bnot(BYTE_3_MASK), rshift(r, 12))),
			bor(BYTE_TAIL_HEAD, band(BYTE_TAIL_MASK, rshift(r, 6))),
			bor(BYTE_TAIL_HEAD, band(BYTE_TAIL_MASK, r))))
		end
	end
	return table.concat(result)
end

-- Tail Call
function UTF8To16_TailCall(utf8, order)
	function tail(utf8, start, result)
		if start > #utf8 then
			return result
		end

		local b1 = string.byte(utf8, start)
		local low, high = 0, 0

		if band(b1, BYTE_1_MASK) == BYTE_1_HEAD then		-- 0### ####
			low = b1; high = 0; start = start + 1
		elseif band(b1, BYTE_2_MASK) == BYTE_2_HEAD then 	-- 110# ####
			b2 = string.byte(utf8, start + 1)
			high = rshift(band(bnot(BYTE_2_MASK), b1), 2)
			low = bor(band(BYTE_TAIL_MASK, b2), lshift(b1, 6))
			start = start + 2
		elseif band(b1, BYTE_3_MASK) == BYTE_3_HEAD then	-- 1110 ####
			b2, b3 = string.byte(utf8, start + 1, start + 2)
			high = bor(lshift(b1, 4), rshift(band(BYTE_TAIL_MASK, b2), 2))
			low = bor(lshift(b2, 6), band(BYTE_TAIL_MASK, b3))
			start = start + 3
		end
		if order == DE then low, high = high, low end
		table.insert(result, string.format("%c%c", low, high))
		return tail(utf8, start, result)
	end
	
	return table.concat(tail(utf8, 1, {}))
end

function UTF16To8_TailCall(utf16, order)
	function tail(utf16_str, start, result)
		if start > #utf16_str then
			return result
		end

		local low, high = string.byte(utf16_str, start, start + 1)
		if order == DE then low, high = high, low end
		local r = bor(lshift(high, 8), low)

		if r <= 0x7F then
			table.insert(result, string.format("%c", low))
		elseif r >= 0x80 and r <= 0x7FF then
			table.insert(result, string.format("%c%c",
			bor(BYTE_2_HEAD, band(bnot(BYTE_2_MASK), rshift(r, 6))),
			bor(BYTE_TAIL_HEAD, band(BYTE_TAIL_MASK, r))))
		elseif r >= 0x800 and r <= 0xFFFF then
			table.insert(result, string.format("%c%c%c",
			bor(BYTE_3_HEAD, band(bnot(BYTE_3_MASK), rshift(r, 12))),
			bor(BYTE_TAIL_HEAD, band(BYTE_TAIL_MASK, rshift(r, 6))),
			bor(BYTE_TAIL_HEAD, band(BYTE_TAIL_MASK, r))))
		end
		return tail(utf16_str, start + 2, result)
	end
	
	return table.concat(tail(utf16, 1, {}))
end

-- Test
local test = "a朱a"
do
	local r = UTF8To16_TailCall(test, LE)
	local r2 = UTF16To8_TailCall(r, LE)
	print(r2)
end

do
	local r = UTF8To16(test, LE)
	local r2 = UTF16To8(r, LE)
	print(r2)
end
