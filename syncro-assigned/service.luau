local function isTicketResolved(ticket)
    if ticket.resolved_at and ticket.resolved_at ~= "" then return true end
    if ticket.resolved == true or ticket.resolved == "true" or ticket.resolved == 1 then return true end
    if ticket.completed == true or ticket.completed == "true" or ticket.completed == 1 then return true end
    if ticket.closed == true or ticket.closed == "true" or ticket.closed == 1 then return true end
    if ticket.is_resolved == true or ticket.is_resolved == "true" or ticket.is_resolved == 1 then return true end
    
    local status = string.lower(tostring(ticket.status or ""))
    if status == "resolved" or status == "closed" or status == "archived" or status == "cancelled" or status:find("resolved") or status:find("closed") then
        return true
    end
    return false
end

local function fetchTickets()
    local subdomain = noctalia.getConfig("subdomain")
    local api_key = noctalia.getConfig("api_key")
    local user_id = noctalia.getConfig("user_id")

    if not subdomain or subdomain == "" or not api_key or api_key == "" then
        noctalia.state.set("assigned_count", 0)
        noctalia.state.set("assigned_tickets", {})
        noctalia.state.set("unassigned_count", 0)
        noctalia.state.set("unassigned_tickets", {})
        return
    end

    -- 1. Fetch assigned tickets (pages 1 & 2) if user_id is provided
    if user_id and user_id ~= "" then
        local assignedAll = {}
        local assignedFetched = 0
        for p = 1, 2 do
            local url = string.format("https://%s.syncromsp.com/api/v1/tickets?user_id=%s&per_page=100&page=%d", subdomain, user_id, p)
            noctalia.http({
                url = url,
                headers = { "Authorization: Bearer " .. api_key, "Accept: application/json" }
            }, function(res)
                assignedFetched = assignedFetched + 1
                if res.ok then
                    local data = noctalia.json.decode(res.body)
                    if data then
                        local list = data.tickets or data
                        if type(list) == "table" then
                            for _, t in ipairs(list) do table.insert(assignedAll, t) end
                        end
                    end
                end
                if assignedFetched >= 2 then
                    local active = {}
                    local seen = {}
                    for _, t in ipairs(assignedAll) do
                        local tid = t.id or t.number
                        if tid and not seen[tid] then
                            seen[tid] = true
                            if not isTicketResolved(t) then table.insert(active, t) end
                        end
                    end
                    noctalia.state.set("assigned_count", #active)
                    noctalia.state.set("assigned_tickets", active)
                end
            end)
        end
    else
        noctalia.state.set("assigned_count", 0)
        noctalia.state.set("assigned_tickets", {})
    end

    -- 2. Fetch unassigned tickets across pages 1 through 5 (up to 500 tickets) with strict unassigned user filter
    local unassignedAll = {}
    local unassignedFetched = 0
    local targetUnassignedPages = 5
    for p = 1, targetUnassignedPages do
        local unassignedUrl = string.format("https://%s.syncromsp.com/api/v1/tickets?unassigned=true&per_page=100&page=%d", subdomain, p)
        noctalia.http({
            url = unassignedUrl,
            headers = { "Authorization: Bearer " .. api_key, "Accept: application/json" }
        }, function(res)
            unassignedFetched = unassignedFetched + 1
            if res.ok then
                local data = noctalia.json.decode(res.body)
                if data then
                    local list = data.tickets or data
                    if type(list) == "table" then
                        for _, t in ipairs(list) do table.insert(unassignedAll, t) end
                    end
                end
            end

            if unassignedFetched >= targetUnassignedPages then
                local active = {}
                local seen = {}
                for _, t in ipairs(unassignedAll) do
                    local tid = t.id or t.number
                    if tid and not seen[tid] then
                        seen[tid] = true
                        if (t.user_id == nil or t.user_id == "" or t.user == nil) and not isTicketResolved(t) then
                            table.insert(active, t)
                        end
                    end
                end
                noctalia.state.set("unassigned_count", #active)
                noctalia.state.set("unassigned_tickets", active)
            end
        end)
    end
end

local interval = (noctalia.getConfig("poll_interval") or 300) * 1000
noctalia.setUpdateInterval(interval)

function update()
    fetchTickets()
end

function onConfigChanged()
    fetchTickets()
end

noctalia.state.watch("trigger_refresh", function()
    fetchTickets()
end)

fetchTickets()
