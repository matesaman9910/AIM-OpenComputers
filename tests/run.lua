-- AIM host-side MVP tests. No OpenComputers installation is required.
-- SPDX-License-Identifier: GPL-3.0-or-later

package.path = "./lib/?.lua;" .. package.path

local json = require("aim.json")
local crom = require("aim.crom")
local viewer = require("aim.viewer")

local passed = 0
local function check(name, condition)
  if not condition then error("FAILED: " .. name, 0) end
  passed = passed + 1
  print("ok - " .. name)
end

local encoded = json.encode({query = "hello\nworld", variables = {url = "https://example.test/a"}})
local decoded = json.decode(encoded)
check("JSON round trip", decoded.query == "hello\nworld" and decoded.variables.url:match("example"))
check("JSON Unicode escape", json.decode('"A\\u00a0B"') == "A\194\160B")
check("JSON rejects malformed input", not pcall(json.decode, '{"x":]'))

check("normalizes bare number", crom.normalizeDesignation("173") == "SCP-173")
check("normalizes designation", crom.normalizeDesignation(" scp-001 ") == "SCP-001")
check("rejects non-numeric designation", crom.normalizeDesignation("SCP-ABC") == nil)
check("builds canonical page URL", crom.articleUrl("SCP-173") == "http://scp-wiki.wikidot.com/scp-173")

local fixture = json.encode({
  data = { page = {
    url = "http://scp-wiki.wikidot.com/scp-173",
    wikidotInfo = { title = "SCP-173", textContent = "Synthetic test text only." },
    attributions = { { type = "AUTHOR", user = { name = "Test Author" } } }
  } }
})
local article, reason = crom.parseResponse(fixture)
check("parses Crom response", article and not reason and article.title == "SCP-173")
check("preserves attribution", article.authors[1] == "Test Author")
check("does not bundle real article text", not fixture:match("Special Containment"))

local lines = viewer.lines(article, 20)
check("wraps article for terminal", #lines >= 7)
check("includes source attribution", table.concat(lines, "\n"):match("Source:"))
check("includes CC notice", table.concat(lines, " "):match("CC BY%-SA 3%.0"))

local installer = assert(io.open("installer.lua", "r")):read("*a")
check("installer has fixed root", installer:match('local ROOT = "/home/aim"'))
check("installer rejects parent traversal", installer:match('not path:find%("%.%."'))
check("installer has no shell execution", not installer:match("os%.execute") and not installer:match("shell%.execute"))

print(string.format("\n%d tests passed", passed))
