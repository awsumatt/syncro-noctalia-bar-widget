local function updateDisplay()
    local count = noctalia.state.get("unassigned_count") or 0
    barWidget.setGlyph("ticket")
    barWidget.setText(tostring(count) .. " Unassigned")
end

updateDisplay()

noctalia.state.watch("unassigned_count", function()
    updateDisplay()
end)

function update()
    updateDisplay()
end

function onClick()
    noctalia.togglePanel("awsumatt/syncro-queue:panel")
end
