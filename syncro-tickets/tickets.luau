local function getConfigValues()
    return noctalia.getConfig("subdomain"),
           noctalia.getConfig("api_key"),
           noctalia.getConfig("time_filter") or "2_weeks",
           noctalia.getConfig("sort_by") or "updated_desc"
end

local function parseIsoDate(dateStr)
    if not dateStr then return 0 end
    local y, m, d, h, min, s = dateStr:match("(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)")
    if not y then
        y, m, d, h, min, s = dateStr:match("(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)")
    end
    if not y then
        y, m, d = dateStr:match("(%d+)-(%d+)-(%d+)")
        h, min, s = 0, 0, 0
    end
    if not y then return 0 end
    
    return os.time({
        year = tonumber(y),
        month = tonumber(m),
        day = tonumber(d),
        hour = tonumber(h) or 0,
        min = tonumber(min) or 0,
        sec = tonumber(s) or 0
    }) or 0
end

local function getCustomerName(ticket)
    if ticket.customer_business_then_name and ticket.customer_business_then_name ~= "" then
        return tostring(ticket.customer_business_then_name)
    end
    if type(ticket.customer) == "table" then
        if ticket.customer.business_and_full_name and ticket.customer.business_and_full_name ~= "" then
            return tostring(ticket.customer.business_and_full_name)
        end
        if ticket.customer.business_then_name and ticket.customer.business_then_name ~= "" then
            return tostring(ticket.customer.business_then_name)
        end
        if ticket.customer.name and ticket.customer.name ~= "" then
            return tostring(ticket.customer.name)
        end
        if ticket.customer.business_name and ticket.customer.business_name ~= "" then
            return tostring(ticket.customer.business_name)
        end
    end
    if ticket.customer_name and ticket.customer_name ~= "" then
        return tostring(ticket.customer_name)
    end
    if ticket.business_name and ticket.business_name ~= "" then
        return tostring(ticket.business_name)
    end
    return "Unknown Customer"
end

local function isTicketResolved(ticket)
    if ticket.resolved_at and ticket.resolved_at ~= "" then return true end
    if ticket.resolved == true or ticket.resolved == "true" or ticket.resolved == 1 then return true end
    if ticket.completed == true or ticket.completed == "true" or ticket.completed == 1 then return true end
    if ticket.closed == true or ticket.closed == "true" or ticket.closed == 1 then return true end
    if ticket.is_resolved == true or ticket.is_resolved == "true" or ticket.is_resolved == 1 then return true end
    
    local status = string.lower(tostring(ticket.status or ""))
    if status:find("resolved") or status:find("closed") or status:find("complete") or status == "archived" or status == "cancelled" then
        return true
    end
    return false
end

local function sortTickets(tickets, sortBy)
    table.sort(tickets, function(a, b)
        local timeA = parseIsoDate(a.updated_at or a.created_at)
        local timeB = parseIsoDate(b.updated_at or b.created_at)

        if sortBy == "created_asc" then
            return parseIsoDate(a.created_at) < parseIsoDate(b.created_at)
        elseif sortBy == "created_desc" then
            return parseIsoDate(a.created_at) > parseIsoDate(b.created_at)
        elseif sortBy == "number_asc" then
            local numA = tonumber(a.number or a.id) or 0
            local numB = tonumber(b.number or b.id) or 0
            return numA < numB
        elseif sortBy == "number_desc" then
            local numA = tonumber(a.number or a.id) or 0
            local numB = tonumber(b.number or b.id) or 0
            return numA > numB
        else -- updated_desc (default)
            return timeA > timeB
        end
    end)
end

function onQuery(text)
    local subdomain, api_key, timeFilter, sortBy = getConfigValues()

    if not subdomain or subdomain == "" or not api_key or api_key == "" then
        launcher.setResults(text, {
            {
                id = "config_error",
                title = "Syncro plugin not configured",
                subtitle = "Please set Subdomain and API Key in Noctalia Plugin Settings",
                glyph = "alert-triangle"
            }
        })
        return
    end

    if not text or text == "" or string.len(text) < 2 then
        launcher.setResults(text, {
            {
                id = "prompt",
                title = "Type to search Syncro tickets...",
                subtitle = "Search by ticket number, subject, or customer",
                glyph = "search"
            }
        })
        return
    end

    launcher.setResults(text, {
        {
            id = "loading",
            title = "Searching Syncro tickets...",
            glyph = "loader"
        }
    })

    -- Step 1: Call /search endpoint
    local searchUrl = string.format("https://%s.syncromsp.com/api/v1/search?query=%s", subdomain, noctalia.string.urlEncode(text))

    noctalia.http({
        url = searchUrl,
        headers = {
            "Authorization: Bearer " .. api_key,
            "Accept: application/json"
        }
    }, function(res)
        if not res.ok then
            launcher.setResults(text, {
                {
                    id = "error",
                    title = "Syncro API Error (" .. tostring(res.status) .. ")",
                    subtitle = res.body and string.sub(res.body, 1, 100) or "Unknown error",
                    glyph = "alert-circle"
                }
            })
            return
        end

        local data, err = noctalia.json.decode(res.body)
        if not data or not data.results or type(data.results) ~= "table" then
            launcher.setResults(text, {
                {
                    id = "empty",
                    title = "No results found for \"" .. text .. "\"",
                    subtitle = "Try a different search query",
                    glyph = "inbox"
                }
            })
            return
        end

        -- Collect ticket numbers from search results (limit to top 6 to minimize calls)
        local ticketNumbers = {}
        for _, hitWrapper in ipairs(data.results) do
            local hit = hitWrapper.table or hitWrapper
            local entityType = hit._type and string.lower(tostring(hit._type)) or nil
            local sourceWrapper = hit._source
            local source = sourceWrapper and (sourceWrapper.table or sourceWrapper) or {}
            if type(source) == "table" and source.table then source = source.table end

            if entityType == "ticket" then
                local num = source.number or hit._id
                if num then
                    table.insert(ticketNumbers, tostring(num))
                    if #ticketNumbers >= 6 then break end
                end
            end
        end

        if #ticketNumbers == 0 then
            launcher.setResults(text, {
                {
                    id = "empty",
                    title = "No tickets found for \"" .. text .. "\"",
                    subtitle = "Try a different search query",
                    glyph = "inbox"
                }
            })
            return
        end

        -- Step 2: Fetch details for each ticket number using /tickets?number=...
        local fetchedTickets = {}
        local pending = #ticketNumbers
        local isTicketNumber = text:match("^#?%d+$") ~= nil

        for _, num in ipairs(ticketNumbers) do
            local ticketUrl = string.format("https://%s.syncromsp.com/api/v1/tickets?number=%s", subdomain, num)
            noctalia.http({
                url = ticketUrl,
                headers = {
                    "Authorization: Bearer " .. api_key,
                    "Accept: application/json"
                }
            }, function(tRes)
                pending = pending - 1
                if tRes.ok then
                    local tData = noctalia.json.decode(tRes.body)
                    if tData then
                        local list = tData.tickets or tData
                        if type(list) == "table" then
                            for _, ticket in ipairs(list) do
                                local resolved = isTicketResolved(ticket)
                                if isTicketNumber or not resolved then
                                    table.insert(fetchedTickets, ticket)
                                end
                            end
                        end
                    end
                end

                if pending <= 0 then
                    if #fetchedTickets == 0 then
                        launcher.setResults(text, {
                            {
                                id = "empty",
                                title = "No active tickets found for \"" .. text .. "\"",
                                subtitle = "All matching tickets are resolved or closed",
                                glyph = "inbox"
                            }
                        })
                        return
                    end

                    sortTickets(fetchedTickets, sortBy)

                    local results = {}
                    for _, ticket in ipairs(fetchedTickets) do
                        local ticketId = tostring(ticket.id or ticket.number or "")
                        local ticketNum = tostring(ticket.number or ticket.id or "")
                        if ticketId ~= "" then
                            local subject = ticket.subject or "No Subject"
                            local customer = getCustomerName(ticket)
                            local status = ticket.status or "Open"

                            table.insert(results, {
                                id = ticketId .. ":" .. ticketNum,
                                title = string.format("#%s: %s", ticketNum, subject),
                                subtitle = string.format("Customer: %s | Status: %s", customer, status),
                                glyph = "ticket"
                            })
                        end
                    end

                    launcher.setResults(text, results)
                end
            end)
        end
    end)
end

function onActivate(id)
    if not id or id == "config_error" or id == "prompt" or id == "loading" or id == "error" or id == "empty" then
        return
    end

    local subdomain, _, _, _ = getConfigValues()
    if subdomain and subdomain ~= "" then
        local ticketId, ticketNum = id:match("^(%d+):(%d+)$")
        if not ticketId then
            ticketId = id
            ticketNum = id
        end
        local url = string.format("https://%s.syncromsp.com/tickets/%s", subdomain, ticketId)
        noctalia.runAsync("xdg-open " .. url)
        noctalia.notify("Syncro Tickets", "Opening ticket #" .. ticketNum)
    end
end
