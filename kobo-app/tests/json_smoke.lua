package.path = "kobo-app/kaungdashboard/lib/?.lua;" .. package.path

local Json = require("json")
local payload = Json.decode([[{
  "version": 1,
  "active": true,
  "temperature": 31.5,
  "items": ["one", "line\ntwo", null],
  "nested": {"title": "Project \"Alpha\""}
}]])

assert(payload.version == 1)
assert(payload.active == true)
assert(payload.temperature == 31.5)
assert(payload.items[2] == "line\ntwo")
assert(payload.items[3] == Json.null)
assert(payload.nested.title == 'Project "Alpha"')
print("JSON decoder smoke test passed")
