-- AIM installer / upgrader / remover for OpenOS.
-- This script only manages the fixed directory /home/aim.
-- Copyright (C) 2026 AIM contributors
-- SPDX-License-Identifier: GPL-3.0-or-later

local component = require("component")
local filesystem = require("filesystem")
local internet = require("internet")

local ROOT = "/home/aim"
local BASE_URL = "https://raw.githubusercontent.com/matesaman9910/AIM-OpenComputers/main/"
local MAX_FILE_BYTES = 512 * 1024
local FILES = {
  "aim.lua",
  "lib/aim/json.lua",
  "lib/aim/crom.lua",
  "lib/aim/viewer.lua",
  "LICENSE",
  "NOTICE.md",
  "VERSION"
}

local function safeRelative(path)
  return type(path) == "string"
    and path ~= ""
    and path:sub(1, 1) ~= "/"
    and not path:find("..", 1, true)
    and path:match("^[%w%._%-%/]+$") ~= nil
end

local function managed(base, relative)
  assert(ROOT == "/home/aim", "installer root safety check failed")
  assert(base == ROOT or base == ROOT .. "/.stage" or base == ROOT .. "/.backup",
    "refusing to manage a directory outside AIM")
  assert(safeRelative(relative), "unsafe AIM file path")
  return base .. "/" .. relative
end

local function ensureParent(path)
  local parent = filesystem.path(path)
  if parent and not filesystem.exists(parent) then
    assert(filesystem.makeDirectory(parent))
  end
end

local function removeKnownFiles(base)
  for _, relative in ipairs(FILES) do
    local path = managed(base, relative)
    if filesystem.exists(path) then
      local ok, reason = filesystem.remove(path)
      if not ok then return nil, reason end
    end
  end
  for _, relative in ipairs({"lib/aim", "lib"}) do
    local path = managed(base, relative)
    if filesystem.exists(path) then filesystem.remove(path) end
  end
  if filesystem.exists(base) then filesystem.remove(base) end
  return true
end

local function download(relative, destination)
  local handle, reason = internet.request(BASE_URL .. relative)
  if not handle then return nil, reason or "request could not be started" end
  ensureParent(destination)
  local file, openReason = io.open(destination, "w")
  if not file then return nil, openReason end
  local size = 0
  local ok, readReason = pcall(function()
    for chunk in handle do
      size = size + #chunk
      if size > MAX_FILE_BYTES then error("download exceeded 512 KiB limit") end
      assert(file:write(chunk))
    end
  end)
  file:close()
  if not ok then
    filesystem.remove(destination)
    return nil, tostring(readReason)
  end
  local meta = getmetatable(handle)
  local response = meta and meta.__index and meta.__index.response
  if type(response) == "function" then
    local responseOk, status = pcall(response)
    if responseOk and status and (status < 200 or status >= 300) then
      filesystem.remove(destination)
      return nil, "GitHub returned HTTP " .. tostring(status)
    end
  end
  return true
end

local function rollback(activated)
  activated = activated or {}
  for _, relative in ipairs(FILES) do
    local backup = managed(ROOT .. "/.backup", relative)
    if filesystem.exists(backup) then
      local target = managed(ROOT, relative)
      if filesystem.exists(target) then filesystem.remove(target) end
      ensureParent(target)
      filesystem.rename(backup, target)
    elseif activated[relative] then
      local target = managed(ROOT, relative)
      if filesystem.exists(target) then filesystem.remove(target) end
    end
  end
  removeKnownFiles(ROOT .. "/.backup")
end

local function installOrUpgrade()
  if not component.isAvailable("internet") then
    print("An Internet Card is required.")
    return
  end
  if component.internet.isHttpEnabled and not component.internet.isHttpEnabled() then
    print("HTTP access is disabled by the server configuration.")
    return
  end

  filesystem.makeDirectory(ROOT)
  removeKnownFiles(ROOT .. "/.stage")
  removeKnownFiles(ROOT .. "/.backup")
  filesystem.makeDirectory(ROOT .. "/.stage")

  for index, relative in ipairs(FILES) do
    io.write(string.format("[%d/%d] Downloading %s... ", index, #FILES, relative))
    local ok, reason = download(relative, managed(ROOT .. "/.stage", relative))
    if not ok then
      print("failed\n" .. tostring(reason))
      removeKnownFiles(ROOT .. "/.stage")
      print("Existing AIM installation was left unchanged.")
      return
    end
    print("ok")
  end

  filesystem.makeDirectory(ROOT .. "/.backup")
  for _, relative in ipairs(FILES) do
    local target = managed(ROOT, relative)
    if filesystem.exists(target) then
      local backup = managed(ROOT .. "/.backup", relative)
      ensureParent(backup)
      local ok, reason = filesystem.rename(target, backup)
      if not ok then
        print("Could not prepare upgrade: " .. tostring(reason))
        rollback({})
        removeKnownFiles(ROOT .. "/.stage")
        return
      end
    end
  end

  local activated = {}
  for _, relative in ipairs(FILES) do
    local staged = managed(ROOT .. "/.stage", relative)
    local target = managed(ROOT, relative)
    ensureParent(target)
    local ok, reason = filesystem.rename(staged, target)
    if not ok then
      print("Could not activate update: " .. tostring(reason))
      rollback(activated)
      removeKnownFiles(ROOT .. "/.stage")
      return
    end
    activated[relative] = true
  end

  removeKnownFiles(ROOT .. "/.stage")
  removeKnownFiles(ROOT .. "/.backup")
  print("\nAIM is ready. Run: lua /home/aim/aim.lua")
end

local function removeAim()
  if not filesystem.exists(ROOT) then
    print("AIM is not installed.")
    return
  end
  io.write("Remove AIM's files from /home/aim? [y/N] ")
  if (io.read() or ""):lower() ~= "y" then
    print("Removal cancelled.")
    return
  end
  removeKnownFiles(ROOT .. "/.stage")
  removeKnownFiles(ROOT .. "/.backup")
  local ok, reason = removeKnownFiles(ROOT)
  if not ok then
    print("Removal stopped: " .. tostring(reason))
    return
  end
  if filesystem.exists(ROOT) then
    print("Known AIM files were removed, but /home/aim was kept because it contains other files.")
  else
    print("AIM was removed from /home/aim.")
  end
end

print("AIM - Anomaly Information Module")
print("Installer / upgrade / remove wizard")
print("")
print("This wizard only manages: " .. ROOT)
print("1. Install or upgrade AIM")
print("2. Remove AIM")
print("Q. Quit")
io.write("\nSelect: ")
local choice = (io.read() or ""):lower()
if choice == "1" then
  installOrUpgrade()
elseif choice == "2" then
  removeAim()
else
  print("No changes made.")
end
