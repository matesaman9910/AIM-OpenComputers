-- Crom GraphQL client for AIM.
-- Copyright (C) 2026 AIM contributors
-- SPDX-License-Identifier: GPL-3.0-or-later

local json = require("aim.json")

local crom = {}

crom.endpoint = "https://apiv1.crom.avn.sh/graphql"
crom.maxResponseBytes = 256 * 1024

local ARTICLE_QUERY = [[
query AimArticle($url: URL!) {
  page(url: $url) {
    url
    wikidotInfo { title textContent }
    attributions { type user { name } }
  }
}
]]

local function responseStatus(handle)
  local meta = getmetatable(handle)
  local response = meta and meta.__index and meta.__index.response
  if type(response) ~= "function" then return nil end
  local ok, code = pcall(response)
  if ok then return code end
  return nil
end

function crom.normalizeDesignation(input)
  local value = tostring(input or ""):upper():gsub("%s+", "")
  local number = value:match("^SCP%-?(%d+)$") or value:match("^(%d+)$")
  if not number then return nil, "use a number such as 173 or SCP-173" end
  if #number > 4 then return nil, "AIM MVP supports 1 to 4 digit SCP designations" end
  local numeric = tonumber(number)
  if not numeric or numeric < 1 then return nil, "designation must be greater than zero" end
  return string.format("SCP-%03d", numeric)
end

function crom.articleUrl(designation)
  return "http://scp-wiki.wikidot.com/" .. designation:lower()
end

function crom.parseResponse(body)
  local ok, decoded = pcall(json.decode, body)
  if not ok then return nil, "Crom returned invalid JSON: " .. tostring(decoded) end
  if decoded.errors and decoded.errors[1] then
    return nil, "Crom GraphQL error: " .. tostring(decoded.errors[1].message or "unknown error")
  end
  local page = decoded.data and decoded.data.page
  local info = page and page.wikidotInfo
  if not info or not info.textContent then return nil, "article was not found or has no readable text" end

  local authors = {}
  for _, attribution in ipairs(page.attributions or {}) do
    local name = attribution.user and attribution.user.name
    if name and name ~= "" then authors[#authors + 1] = name end
  end
  if #authors == 0 then authors[1] = "Unknown" end

  local text = info.textContent:gsub("\r\n", "\n"):gsub("\r", "\n"):gsub("\194\160", " ")
  return {
    title = info.title or "Untitled article",
    text = text,
    url = page.url,
    authors = authors
  }
end

function crom.fetch(designation)
  local component = require("component")
  if not component.isAvailable("internet") then return nil, "an Internet Card is required" end
  if component.internet.isHttpEnabled and not component.internet.isHttpEnabled() then
    return nil, "HTTP access is disabled in the OpenComputers server configuration"
  end

  local internet = require("internet")
  local payload = json.encode({
    query = ARTICLE_QUERY,
    variables = { url = crom.articleUrl(designation) }
  })
  local headers = {
    ["Content-Type"] = "application/json",
    ["Accept"] = "application/json",
    ["User-Agent"] = "AIM-OpenComputers/0.1.0"
  }

  local ok, handle, reason = pcall(internet.request, crom.endpoint, payload, headers, "POST")
  if not ok then return nil, tostring(handle) end
  if not handle then return nil, tostring(reason or "request could not be started") end

  local chunks, size = {}, 0
  local readOk, readError = pcall(function()
    for chunk in handle do
      size = size + #chunk
      if size > crom.maxResponseBytes then error("response exceeds 256 KiB safety limit") end
      chunks[#chunks + 1] = chunk
    end
  end)
  if not readOk then return nil, tostring(readError) end
  local status = responseStatus(handle)
  if status and (status < 200 or status >= 300) then
    return nil, "Crom returned HTTP " .. tostring(status)
  end
  return crom.parseResponse(table.concat(chunks))
end

return crom
