local function updateDisplay()
    local count = noctalia.state.get("unassigned_count") or 0
    local showLabel = noctalia.getConfig("show_unassigned_label")
    if showLabel == nil then showLabel = true end
    barWidget.setGlyph("ticket")
    if showLabel then
        barWidget.setText(tostring(count) .. " Unassigned")
    else
        barWidget.setText(tostring(count))
    end
end

updateDisplay()

noctalia.state.watch("unassigned_count", function()
    updateDisplay()
end)

function update()
    updateDisplay()
end

function onConfigChanged()
    updateDisplay()
end

function onClick()
    noctalia.togglePanel("awsumatt/syncro-queue:panel")
end
