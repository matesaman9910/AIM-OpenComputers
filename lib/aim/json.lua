-- Minimal JSON codec for AIM.
-- Copyright (C) 2026 AIM contributors
-- SPDX-License-Identifier: GPL-3.0-or-later

local json = {}

local escapes = {
  ['"'] = '\\"', ['\\'] = '\\\\', ['\b'] = '\\b', ['\f'] = '\\f',
  ['\n'] = '\\n', ['\r'] = '\\r', ['\t'] = '\\t'
}

local function encodeString(value)
  return '"' .. value:gsub('[%z\1-\31\\"]', function(char)
    return escapes[char] or string.format("\\u%04x", char:byte())
  end) .. '"'
end

local function isArray(value)
  local count, maximum = 0, 0
  for key in pairs(value) do
    if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
      return false
    end
    count = count + 1
    if key > maximum then maximum = key end
  end
  return count == maximum
end

local function encodeValue(value, seen)
  local kind = type(value)
  if kind == "nil" then return "null" end
  if kind == "boolean" then return value and "true" or "false" end
  if kind == "number" then
    if value ~= value or value == math.huge or value == -math.huge then
      error("cannot encode a non-finite number")
    end
    return tostring(value)
  end
  if kind == "string" then return encodeString(value) end
  if kind ~= "table" then error("cannot encode " .. kind) end
  if seen[value] then error("cannot encode a circular table") end

  seen[value] = true
  local parts = {}
  if isArray(value) then
    for index = 1, #value do
      parts[#parts + 1] = encodeValue(value[index], seen)
    end
    seen[value] = nil
    return "[" .. table.concat(parts, ",") .. "]"
  end

  for key, item in pairs(value) do
    if type(key) ~= "string" then error("JSON object keys must be strings") end
    parts[#parts + 1] = encodeString(key) .. ":" .. encodeValue(item, seen)
  end
  seen[value] = nil
  return "{" .. table.concat(parts, ",") .. "}"
end

function json.encode(value)
  return encodeValue(value, {})
end

local function utf8(codepoint)
  if codepoint <= 0x7f then
    return string.char(codepoint)
  elseif codepoint <= 0x7ff then
    return string.char(0xc0 + math.floor(codepoint / 0x40), 0x80 + codepoint % 0x40)
  elseif codepoint <= 0xffff then
    return string.char(0xe0 + math.floor(codepoint / 0x1000),
      0x80 + math.floor(codepoint / 0x40) % 0x40, 0x80 + codepoint % 0x40)
  elseif codepoint <= 0x10ffff then
    return string.char(0xf0 + math.floor(codepoint / 0x40000),
      0x80 + math.floor(codepoint / 0x1000) % 0x40,
      0x80 + math.floor(codepoint / 0x40) % 0x40, 0x80 + codepoint % 0x40)
  end
  error("invalid Unicode codepoint")
end

local function decoder(source)
  local position, length = 1, #source

  local function fail(message)
    error("invalid JSON at byte " .. position .. ": " .. message, 0)
  end

  local function whitespace()
    local _, finish = source:find("^[ \n\r\t]*", position)
    position = (finish or position - 1) + 1
  end

  local parseValue

  local function parseString()
    position = position + 1
    local output = {}
    while position <= length do
      local start = position
      while position <= length do
        local byte = source:byte(position)
        if byte == 34 or byte == 92 or byte < 32 then break end
        position = position + 1
      end
      output[#output + 1] = source:sub(start, position - 1)
      local byte = source:byte(position)
      if byte == 34 then
        position = position + 1
        return table.concat(output)
      end
      if byte ~= 92 then fail("unterminated or invalid string") end
      local escaped = source:sub(position + 1, position + 1)
      local simple = { ['"']='"', ['\\']='\\', ['/']='/', b='\b', f='\f', n='\n', r='\r', t='\t' }
      if simple[escaped] then
        output[#output + 1] = simple[escaped]
        position = position + 2
      elseif escaped == "u" then
        local hex = source:sub(position + 2, position + 5)
        local codepoint = tonumber(hex, 16)
        if not codepoint or #hex ~= 4 then fail("bad Unicode escape") end
        position = position + 6
        if codepoint >= 0xd800 and codepoint <= 0xdbff then
          if source:sub(position, position + 1) ~= "\\u" then fail("missing low surrogate") end
          local low = tonumber(source:sub(position + 2, position + 5), 16)
          if not low or low < 0xdc00 or low > 0xdfff then fail("bad low surrogate") end
          codepoint = 0x10000 + (codepoint - 0xd800) * 0x400 + (low - 0xdc00)
          position = position + 6
        elseif codepoint >= 0xdc00 and codepoint <= 0xdfff then
          fail("unexpected low surrogate")
        end
        output[#output + 1] = utf8(codepoint)
      else
        fail("bad escape")
      end
    end
    fail("unterminated string")
  end

  local function parseNumber()
    local value = source:match("^-?%d+%.?%d*[eE]?[+-]?%d*", position)
    if not value or not value:match("^-?%d") then fail("bad number") end
    local number = tonumber(value)
    if not number then fail("bad number") end
    position = position + #value
    return number
  end

  local function parseArray()
    position = position + 1
    whitespace()
    local result = {}
    if source:sub(position, position) == "]" then position = position + 1 return result end
    while true do
      result[#result + 1] = parseValue()
      whitespace()
      local char = source:sub(position, position)
      if char == "]" then position = position + 1 return result end
      if char ~= "," then fail("expected ',' or ']'") end
      position = position + 1
      whitespace()
    end
  end

  local function parseObject()
    position = position + 1
    whitespace()
    local result = {}
    if source:sub(position, position) == "}" then position = position + 1 return result end
    while true do
      if source:sub(position, position) ~= '"' then fail("expected object key") end
      local key = parseString()
      whitespace()
      if source:sub(position, position) ~= ":" then fail("expected ':'") end
      position = position + 1
      whitespace()
      result[key] = parseValue()
      whitespace()
      local char = source:sub(position, position)
      if char == "}" then position = position + 1 return result end
      if char ~= "," then fail("expected ',' or '}'") end
      position = position + 1
      whitespace()
    end
  end

  function parseValue()
    whitespace()
    local char = source:sub(position, position)
    if char == '"' then return parseString() end
    if char == "{" then return parseObject() end
    if char == "[" then return parseArray() end
    if char == "-" or char:match("%d") then return parseNumber() end
    if source:sub(position, position + 3) == "true" then position = position + 4 return true end
    if source:sub(position, position + 4) == "false" then position = position + 5 return false end
    if source:sub(position, position + 3) == "null" then position = position + 4 return nil end
    fail("unexpected token")
  end

  local value = parseValue()
  whitespace()
  if position <= length then fail("trailing content") end
  return value
end

function json.decode(source)
  if type(source) ~= "string" then error("JSON input must be a string") end
  return decoder(source)
end

return json
