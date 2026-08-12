-- Version 2 seam. Version 1 deliberately exposes no network methods.
local Api = { enabled = false }

function Api.assertOffline()
    assert(not Api.enabled, "Network access is disabled in Version 1")
end

return Api
