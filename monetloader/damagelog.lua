script_name("Damage Log by Loganzo")
script_author("Loganzo")

local sampev = require 'samp.events'
local imgui = require 'mimgui'
local encoding = require 'encoding'
encoding.default = 'CP1251'
local u8 = encoding.UTF8

local showWindow = imgui.new.bool(false)
local showChatLogReceived = imgui.new.bool(true)
local showChatLogDealt = imgui.new.bool(true)
local selectedRowReceived = imgui.new.int(-1)
local selectedRowDealt = imgui.new.int(-1)

local damageReceived = {}
local damageDealt = {}
local MAX_LOGS = 500

local config_path = getWorkingDirectory() .. "/config/DamageLogConfig.txt"
local history_path = getWorkingDirectory() .. "/config/DamageLogHistory.txt"

local weaponNames = {
    [0] = "Fist", [1] = "Brass Knuckles", [2] = "Golf Club", [3] = "Nightstick",
    [4] = "Knife", [5] = "Baseball Bat", [6] = "Shovel", [7] = "Pool Cue",
    [8] = "Katana", [9] = "Chainsaw", [10] = "Purple Dildo", [11] = "Small Dildo",
    [12] = "Medium Dildo", [13] = "Long Dildo", [14] = "Flowers", [15] = "Cane",
    [16] = "Grenade", [17] = "Tear Gas", [18] = "Molotov", [22] = "9mm",
    [23] = "Silenced 9mm", [24] = "Desert Eagle", [25] = "Shotgun", [26] = "Sawnoff Shotgun",
    [27] = "Combat Shotgun", [28] = "Micro UZI", [29] = "MP5", [30] = "AK-47",
    [31] = "M4", [32] = "Tec-9", [33] = "Country Rifle", [34] = "Sniper Rifle",
    [35] = "Rocket Launcher", [36] = "HS Rocket", [37] = "Flamethrower", [38] = "Minigun",
    [39] = "Satchel Charge", [40] = "Detonator", [41] = "Spraycan", [42] = "Fire Extinguisher",
    [43] = "Camera", [44] = "Night Vision", [45] = "Thermal Goggles", [46] = "Parachute",
    [49] = "Vehicle", [50] = "Helicopter Rotor", [51] = "Explosion", [53] = "Drowned", [54] = "Splat (Fall)"
}

local bodypartNames = {
    [3] = "Torso", [4] = "Groin", [5] = "Left Arm",
    [6] = "Right Arm", [7] = "Left Leg", [8] = "Right Leg", [9] = "Head"
}

local function checkConfigDirectory()
    local dir = getWorkingDirectory() .. "/config"
    if not doesDirectoryExist(dir) then
        createDirectory(dir)
    end
end

local function saveLogs()
    checkConfigDirectory()
    local file = io.open(history_path, "w")
    if not file then return end
    
    file:write("[SETTINGS]\n")
    file:write(string.format("%s|%s\n", tostring(showChatLogReceived[0]), tostring(showChatLogDealt[0])))

    file:write("[RECEIVED]\n")
    for _, log in ipairs(damageReceived) do
        file:write(string.format("%s|%d|%s|%s|%s|%.2f\n",
            log.datetime, log.id or -1, log.attacker or "Unknown", log.weapon or "Unknown", log.bodypart or "Unknown", log.damage or 0))
    end

    file:write("[DEALT]\n")
    for _, log in ipairs(damageDealt) do
        file:write(string.format("%s|%d|%s|%s|%s|%.2f\n",
            log.datetime, log.id or -1, log.victim or "Unknown", log.weapon or "Unknown", log.bodypart or "Unknown", log.damage or 0))
    end

    file:close()
end

local function loadLogs()
    if not doesFileExist(history_path) then return end
    local file = io.open(history_path, "r")
    if not file then return end

    damageReceived = {}
    damageDealt = {}
    local section = nil

    for line in file:lines() do
        line = line:gsub("\r", "")
        if line == "[SETTINGS]" then
            section = "settings"
        elseif line == "[RECEIVED]" then
            section = "received"
        elseif line == "[DEALT]" then
            section = "dealt"
        elseif line and #line > 0 and section then
            local t = {}
            for part in line:gmatch("([^|]+)") do
                table.insert(t, part)
            end
            
            if section == "settings" and #t >= 2 then
                showChatLogReceived[0] = (t[1] == "true")
                showChatLogDealt[0] = (t[2] == "true")
            elseif (section == "received" or section == "dealt") and #t >= 6 then
                local entry = {
                    datetime = t[1],
                    id = tonumber(t[2]) or -1,
                    weapon = t[4] or "Unknown",
                    bodypart = t[5] or "Unknown",
                    damage = tonumber(t[6]) or 0.00
                }
                if section == "received" then
                    entry.attacker = t[3]
                    table.insert(damageReceived, entry)
                elseif section == "dealt" then
                    entry.victim = t[3]
                    table.insert(damageDealt, entry)
                end
            end
        end
    end
    file:close()
end

function sampev.onSendTakeDamage(issuerId, damage, weapon, bodypart)
    if damage <= 0 then return end
    local name = issuerId ~= -1 and sampGetPlayerNickname(issuerId) or "Unknown"
    local wname = weaponNames[weapon] or ("Weapon " .. weapon)
    local bname = bodypartNames[bodypart] or "Torso"

    table.insert(damageReceived, 1, {
        datetime = os.date("%d/%m/%Y %H:%M:%S"),
        id = issuerId,
        attacker = name,
        weapon = wname,
        bodypart = bname,
        damage = damage
    })
    if #damageReceived > MAX_LOGS then table.remove(damageReceived) end

    if showChatLogReceived[0] then
        sampAddChatMessage(string.format("{FF3333}[Damage Received] {FFFFFF}%s (ID:%d) | %s | %s | {FF6666}%.2f", 
            name, issuerId, wname, bname, damage), -1)
    end
end

function sampev.onSendGiveDamage(playerId, damage, weapon, bodypart)
    if damage <= 0 then return end
    local name = sampGetPlayerNickname(playerId) or "Unknown"
    local wname = weaponNames[weapon] or ("Weapon " .. weapon)
    local bname = bodypartNames[bodypart] or "Torso"

    table.insert(damageDealt, 1, {
        datetime = os.date("%d/%m/%Y %H:%M:%S"),
        id = playerId,
        victim = name,
        weapon = wname,
        bodypart = bname,
        damage = damage
    })
    if #damageDealt > MAX_LOGS then table.remove(damageDealt) end

    if showChatLogDealt[0] then
        sampAddChatMessage(string.format("{3399FF}[Damage Dealt] {FFFFFF}%s (ID:%d) | %s | %s | {66B2FF}%.2f", 
            name, playerId, wname, bname, damage), -1)
    end
end

imgui.OnInitialize(function()
    local style = imgui.GetStyle()
    style.WindowRounding = 0.0
    style.FrameRounding = 2.0
    style.Colors[imgui.Col.WindowBg] = imgui.ImVec4(0.05, 0.05, 0.05, 0.95)
    style.Colors[imgui.Col.Header] = imgui.ImVec4(0.80, 0.10, 0.10, 0.85)
    style.Colors[imgui.Col.HeaderHovered] = imgui.ImVec4(0.90, 0.20, 0.20, 0.85)
    style.Colors[imgui.Col.Button] = imgui.ImVec4(0.20, 0.20, 0.20, 0.80)
    style.Colors[imgui.Col.ButtonHovered] = imgui.ImVec4(0.30, 0.30, 0.30, 1.00)
end)

local function drawTable(logList, isDealt)
    local selectedRow = isDealt and selectedRowDealt or selectedRowReceived

    imgui.BeginChild(u8(isDealt and "LogChildDealt" or "LogChildReceived"), imgui.ImVec2(0, -35), true)
    
    imgui.Columns(4, u8(isDealt and "ListDealt" or "ListReceived"), true)
    
    imgui.SetColumnWidth(0, 195)
    imgui.SetColumnWidth(1, 120)
    imgui.SetColumnWidth(2, 125)

    imgui.Text(u8"Tanggal")
    imgui.NextColumn()
    imgui.Text(u8"Senjata")
    imgui.NextColumn()
    imgui.Text(u8"Damage")
    imgui.NextColumn()
    imgui.Text(u8(isDealt and "Korban" or "Pelaku"))
    imgui.NextColumn()
    imgui.Separator()

    for i, log in ipairs(logList) do
        local isSelected = (selectedRow[0] == i)
        
        if isSelected then
            if imgui.Selectable(u8(log.datetime) .. "##" .. (isDealt and "d_" or "r_") .. i, true, imgui.SelectableFlags.SpanAllColumns) then
                selectedRow[0] = i
            end
        else
            imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(0.75, 0.75, 0.75, 1.0))
            if imgui.Selectable(u8(log.datetime) .. "##" .. (isDealt and "d_" or "r_") .. i, false, imgui.SelectableFlags.SpanAllColumns) then
                selectedRow[0] = i
            end
            imgui.PopStyleColor()
        end
        imgui.NextColumn()

        imgui.TextColored(imgui.ImVec4(1.0, 0.8, 0.2, 1.0), u8(log.weapon or "Unknown"))
        imgui.NextColumn()

        imgui.TextColored(imgui.ImVec4(1.0, 0.45, 0.45, 1.0), u8(string.format("%.2f - %s", log.damage or 0, log.bodypart or "Torso")))
        imgui.NextColumn()

        if isDealt then
            imgui.TextColored(imgui.ImVec4(0.3, 0.9, 0.9, 1.0), u8(log.victim or "Unknown"))
        else
            imgui.TextColored(imgui.ImVec4(0.4, 0.9, 0.4, 1.0), u8(log.attacker or "Unknown"))
        end
        imgui.NextColumn()
    end

    imgui.Columns(1)
    imgui.EndChild()
end

imgui.OnFrame(function() return showWindow[0] end, function(player)
    local displayX, displayY = getScreenResolution()
    
    imgui.SetNextWindowPos(imgui.ImVec2(displayX * 0.5, displayY * 0.5), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
    imgui.SetNextWindowSize(imgui.ImVec2(670, 400), imgui.Cond.FirstUseEver)

    imgui.Begin(u8"Damage Log by Loganzo", showWindow, imgui.WindowFlags.NoCollapse)

    if imgui.BeginTabBar("DamageTabBar") then
        if imgui.BeginTabItem(u8"Damage Diterima") then
            drawTable(damageReceived, false)
            imgui.EndTabItem()
        end
        if imgui.BeginTabItem(u8"Damage Diberikan") then
            drawTable(damageDealt, true)
            imgui.EndTabItem()
        end
        imgui.EndTabBar()
    end

    imgui.Separator()

    imgui.Checkbox(u8"Log Chat (Terima)", showChatLogReceived)
    imgui.SameLine()
    imgui.Checkbox(u8"Log Chat (Beri)", showChatLogDealt)

    imgui.End()
end)

function main()
    while not isSampAvailable() do wait(10) end
    checkConfigDirectory()
    loadLogs()
    
    sampAddChatMessage("{00BFFF}Damage Log by Loganzo loaded! Ketik {FFFFFF}/dlogs", -1)
    sampRegisterChatCommand("dlogs", function() showWindow[0] = not showWindow[0] end)

    while true do
        wait(10000)
        saveLogs()
    end
end

function script.onUnload()
    saveLogs()
end

