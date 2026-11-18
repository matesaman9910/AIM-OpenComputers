-- Terminal article viewer for AIM.
-- Copyright (C) 2026 AIM contributors
-- SPDX-License-Identifier: GPL-3.0-or-later

local viewer = {}

local unicodeOk, unicode = pcall(require, "unicode")
local textLength = unicodeOk and unicode.len or string.len
local textSub = unicodeOk and unicode.sub or string.sub

local function appendWrapped(lines, paragraph, width)
  if paragraph == "" then lines[#lines + 1] = "" return end
  local remaining = paragraph:gsub("\t", "  ")
  while textLength(remaining) > width do
    local split = width
    while split > 1 and textSub(remaining, split, split) ~= " " do split = split - 1 end
    if split == 1 then split = width end
    lines[#lines + 1] = textSub(remaining, 1, split):gsub("%s+$", "")
    remaining = textSub(remaining, split + 1):gsub("^%s+", "")
  end
  lines[#lines + 1] = remaining
end

function viewer.lines(article, width)
  width = math.max(20, tonumber(width) or 80)
  local lines = {}
  appendWrapped(lines, article.title, width)
  appendWrapped(lines, string.rep("=", math.min(textLength(article.title), width)), width)
  for paragraph in (article.text .. "\n"):gmatch("(.-)\n") do
    appendWrapped(lines, paragraph, width)
  end
  lines[#lines + 1] = ""
  appendWrapped(lines, "Author(s): " .. table.concat(article.authors, ", "), width)
  appendWrapped(lines, "Source: " .. article.url, width)
  appendWrapped(lines, "Article content is licensed CC BY-SA 3.0:", width)
  appendWrapped(lines, "https://creativecommons.org/licenses/by-sa/3.0/", width)
  return lines
end

local function clear(gpu, width, height)
  gpu.fill(1, 1, width, height, " ")
  gpu.set(1, 1, "")
end

function viewer.read(article)
  local component = require("component")
  local term = require("term")
  local gpu = component.gpu
  local width, height = gpu.getResolution()
  local pageHeight = math.max(4, height - 2)
  local lines = viewer.lines(article, width)
  local pages = math.max(1, math.ceil(#lines / pageHeight))
  local page = 1

  while true do
    clear(gpu, width, height)
    local first = (page - 1) * pageHeight + 1
    for row = 1, pageHeight do
      local line = lines[first + row - 1]
      if not line then break end
      gpu.set(1, row, line)
    end
    term.setCursor(1, height)
    io.write(string.format("Page %d/%d | Enter/N next | P previous | Q menu: ", page, pages))
    local command = (io.read() or ""):lower()
    if command == "q" then return end
    if command == "p" or command == "b" then
      page = math.max(1, page - 1)
    elseif command == "" or command == "n" then
      if page < pages then page = page + 1 else return end
    end
  end
end

return viewer
