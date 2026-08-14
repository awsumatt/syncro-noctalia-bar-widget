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
    end
    if ticket.customer_name and ticket.customer_name ~= "" then
        return tostring(ticket.customer_name)
    end
    return "Unknown Customer"
end

local function truncate(str, maxLen)
    if not str then return "" end
    if string.len(str) > maxLen then
        return string.sub(str, 1, maxLen - 3) .. "..."
    end
    return str
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

local function render()
    local currentTab = noctalia.state.get("current_tab") or "assigned"
    local assignedTickets = noctalia.state.get("assigned_tickets") or {}
    local unassignedTickets = noctalia.state.get("unassigned_tickets") or {}

    local refreshButton = ui.button({
        glyph = "refresh",
        onClick = function()
            noctalia.state.set("trigger_refresh", noctalia.nowMs())
            noctalia.notify("Assigned Tickets", "Refreshing tickets...")
        end
    })

    local assignedLabel = (currentTab == "assigned") and "▶ Assigned (" .. #assignedTickets .. ")" or "Assigned (" .. #assignedTickets .. ")"
    local unassignedLabel = (currentTab == "unassigned") and "▶ Unassigned (" .. #unassignedTickets .. ")" or "Unassigned (" .. #unassignedTickets .. ")"

    local tabHeader = ui.row({ align = "center", justify = "space_between", gap = 8 }, {
        ui.row({ gap = 8 }, {
            ui.button({
                text = assignedLabel,
                onClick = function()
                    noctalia.state.set("current_tab", "assigned")
                    render()
                end
            }),
            ui.button({
                text = unassignedLabel,
                onClick = function()
                    noctalia.state.set("current_tab", "unassigned")
                    render()
                end
            }),
        }),
        refreshButton
    })

    local tickets = (currentTab == "unassigned") and unassignedTickets or assignedTickets

    if #tickets == 0 then
        panel.render(ui.column({ flexGrow = 1, gap = 16, padding = 16 }, {
            tabHeader,
            ui.label({ text = "No " .. currentTab .. " tickets found.", color = "on_surface_variant" }),
        }))
        return
    end

    local children = { tabHeader }

    local groups = {}
    local statusOrder = {}

    for _, ticket in ipairs(tickets) do
        local status = ticket.status or "Open"
        if not groups[status] then
            groups[status] = {}
            table.insert(statusOrder, status)
        end
        table.insert(groups[status], ticket)
    end

    table.sort(statusOrder, function(a, b)
        local aLower = string.lower(a)
        local bLower = string.lower(b)
        local aIsNew = aLower:find("new") ~= nil
        local bIsNew = bLower:find("new") ~= nil
        local aIsReply = aLower:find("customer reply") ~= nil
        local bIsReply = bLower:find("customer reply") ~= nil
        local aIsHold = aLower:find("cse hold") ~= nil
        local bIsHold = bLower:find("cse hold") ~= nil

        if currentTab == "unassigned" then
            if aIsNew and not bIsNew then return true end
            if not aIsNew and bIsNew then return false end
        end

        if aIsReply and not bIsReply then return true end
        if not aIsReply and bIsReply then return false end

        if aIsHold and not bIsHold then return false end
        if not aIsHold and bIsHold then return true end

        return aLower < bLower
    end)

    for _, status in ipairs(statusOrder) do
        local statusTickets = groups[status]
        if currentTab == "unassigned" then
            table.sort(statusTickets, function(a, b)
                return parseIsoDate(a.created_at) > parseIsoDate(b.created_at)
            end)
        end

        table.insert(children, ui.column({ gap = 4 }, {
            ui.label({ text = string.upper(status) .. " (" .. #statusTickets .. ")", fontWeight = "bold", color = "primary", fontSize = 12 }),
            ui.box({ height = 1, fill = "outline_variant", opacity = 0.5 })
        }))

        for _, ticket in ipairs(statusTickets) do
            local ticketId = tostring(ticket.id or "")
            local ticketNum = tostring(ticket.number or ticket.id or "")
            local subject = truncate(ticket.subject or "No Subject", 32)
            local customer = truncate(getCustomerName(ticket), 45)

            table.insert(children, ui.button({
                contentAlign = "start",
                text = string.format("#%s: %s\n%s", ticketNum, subject, customer),
                onClick = function()
                    local subdomain = noctalia.getConfig("subdomain")
                    if subdomain and subdomain ~= "" and ticketId ~= "" then
                        local url = string.format("https://%s.syncromsp.com/tickets/%s", subdomain, ticketId)
                        noctalia.runAsync("xdg-open " .. url)
                        noctalia.notify("Syncro Tickets", "Opening ticket #" .. ticketNum)
                    end
                end
            }))
        end
    end

    panel.render(ui.column({ flexGrow = 1, gap = 16, padding = 16 }, {
        ui.scroll({ flexGrow = 1, gap = 8 }, children)
    }))
end

function onOpen(_context)
    render()
end

noctalia.state.watch("assigned_tickets", function()
    render()
end)

noctalia.state.watch("unassigned_tickets", function()
    render()
end)

noctalia.state.watch("current_tab", function()
    render()
end)
