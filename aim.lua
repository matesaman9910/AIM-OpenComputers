-- AIM - Anomaly Information Module
-- Copyright (C) 2026 AIM contributors
-- SPDX-License-Identifier: GPL-3.0-or-later

local component = require("component")
local filesystem = require("filesystem")
local shell = require("shell")
local term = require("term")

local running = shell.getRunningProgram and shell.getRunningProgram() or "/home/aim/aim.lua"
local root = filesystem.path(running) or "/home/aim/"
package.path = root .. "?.lua;" .. root .. "lib/?.lua;" .. package.path

local crom = require("aim.crom")
local viewer = require("aim.viewer")

local function clear()
  term.clear()
  term.setCursor(1, 1)
end

local function pause()
  io.write("\nPress Enter to continue...")
  io.read()
end

local function showAbout()
  clear()
  print("AIM - Anomaly Information Module 0.1.0")
  print("")
  print("A small, live SCP article reader for OpenComputers.")
  print("AIM stores no article database or persistent article cache.")
  print("")
  print("AIM code: GPL-3.0-or-later")
  print("AIM is provided with ABSOLUTELY NO WARRANTY.")
  print("SCP article content: CC BY-SA 3.0")
  print("Data supplied by the independent Crom API.")
  print("AIM is unofficial and is not endorsed by the SCP Wiki or Crom.")
  pause()
end

local function lookup()
  clear()
  print("SCP designation lookup")
  io.write("Enter a number or designation (example: 173 or SCP-173): ")
  local input = io.read()
  local designation, reason = crom.normalizeDesignation(input)
  if not designation then
    print("\nInvalid designation: " .. reason)
    pause()
    return
  end

  print("\nRetrieving " .. designation .. " from Crom...")
  local article, err = crom.fetch(designation)
  if not article then
    print("Unable to retrieve article: " .. tostring(err))
    pause()
    return
  end

  viewer.read(article)
end

local function main()
  while true do
    clear()
    print("========================================")
    print(" AIM - Anomaly Information Module")
    print("========================================")
    print("")
    print("1. Look up an SCP designation")
    print("2. About and licences")
    print("Q. Quit")
    io.write("\nSelect: ")

    local choice = (io.read() or ""):lower()
    if choice == "1" then
      lookup()
    elseif choice == "2" then
      showAbout()
    elseif choice == "q" or choice == "quit" then
      clear()
      print("AIM closed.")
      return
    end
  end
end

main()
