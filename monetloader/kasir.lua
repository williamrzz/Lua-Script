script_name("Kasir Pintar by Loganzo")
script_author("Loganzo @williamrzz")

local imgui = require 'mimgui'
local ffi = require 'ffi'
local sampev = require 'samp.events'
local encoding = require 'encoding'

encoding.default = 'CP1251'
u8 = encoding.UTF_8

local config_path = getWorkingDirectory() .. "/config/KasirPintarLoganzo.txt"
local history_path = getWorkingDirectory() .. "/config/HistoryKasir.txt"

local data = {
    presets = {},
    scannedPlayers = {},
    selectedPlayerId = -1,
    history = {},
    show_window = imgui.new.bool(false),
    geledahStage = 0,
    target_ket = "",
    target_money = "",
    cart = {},
}

local inputs = {
    keterangan = imgui.new.char[128](""),
    nominal = imgui.new.char[64](""),
    add_nama = imgui.new.char[128](""),
    add_harga = imgui.new.char[64](""),
    search_preset = imgui.new.char[64](""),
    search_history = imgui.new.char[64](""),
}

local calc = {
    expr = "",
    result = ""
}

local function evaluateMathResult()
    if calc.expr == "" then 
        calc.result = "" 
        return 
    end
    
    local lua_expr = calc.expr:gsub("%.", "")
    
    lua_expr = lua_expr:gsub("×", "*"):gsub("÷", "/")
    
    while lua_expr:find("%d+[%+%-]%d+%%") do
        lua_expr = lua_expr:gsub("(%d+)([%+%-])(%d+)%%", "%1%2(%1*%3/100)")
    end
    
    lua_expr = lua_expr:gsub("(%d+)%%", "(%1/100)")
    
    local safe_expr = lua_expr:gsub("[%+%-%*/]+$", "")
    
    local f = load("return " .. safe_expr)
    if f then
        local success, val = pcall(f)
        if success and type(val) == "number" then
            if val == math.floor(val) then
                local formatted = tostring(math.floor(val))
                local k
                while true do
                    formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1.%2')
                    if k == 0 then break end
                end
                calc.result = formatted
            else
                local formatted = string.format("%.4f", val):gsub("0+$", ""):gsub("%.$", "")
                calc.result = formatted:gsub("%.", ",")
            end
        else
            calc.result = ""
        end
    else
        calc.result = ""
    end
end

local function calcAppend(str)
    calc.expr = calc.expr .. str
    evaluateMathResult()
end

local function calcClear()
    calc.expr = ""
    calc.result = ""
end

local function calcDel()
    if #calc.expr > 0 then
        local byteoffset = utf8 and utf8.offset(calc.expr, -1) or #calc.expr
        calc.expr = calc.expr:sub(1, byteoffset - 1)
        evaluateMathResult()
    end
end

local function calcEqual()
    if calc.result ~= "" then
        calc.expr = calc.result
        calc.result = ""
    end
end

local combo_selection = imgui.new.int(0)

local function savePresets()
    if not doesDirectoryExist(getWorkingDirectory() .. "/config") then
        createDirectory(getWorkingDirectory() .. "/config")
    end
    local f = io.open(config_path, "w")
    if f then
        for _, p in ipairs(data.presets) do
            f:write(p.nama .. "|" .. p.harga .. "\n")
        end
        f:close()
    end
end

local function loadPresets()
    local f = io.open(config_path, "r")
    if f then
        data.presets = {}
        for line in f:lines() do
            local nama, harga = line:match("([^|]+)|([^|]+)")
            if nama and harga then
                table.insert(data.presets, {nama = nama, harga = tonumber(harga) or 0})
            end
        end
        f:close()
    else
        data.presets = {}
        savePresets()
    end
end

local function saveHistory()
    if not doesDirectoryExist(getWorkingDirectory() .. "/config") then
        createDirectory(getWorkingDirectory() .. "/config")
    end
    local f = io.open(history_path, "w")
    if f then
        for _, h in ipairs(data.history) do
            f:write(string.format("%s|%s|%s|%s|%s\n", h.time, h.date or os.date("%d/%m/%Y"), h.player, h.keterangan, h.nominal))
        end
        f:close()
    end
end

local function loadHistory()
    local f = io.open(history_path, "r")
    if f then
        data.history = {}
        for line in f:lines() do
            local time, date, player, ket, nom = line:match("([^|]+)|([^|]+)|([^|]+)|([^|]+)|([^|]+)")
            if time and player and ket and nom then
                table.insert(data.history, {
                    time = time,
                    date = date,
                    player = player,
                    keterangan = ket,
                    nominal = tonumber(nom) or 0
                })
            end
        end
        f:close()
    end
end

local function addToHistory(playerName, ket, nominal)
    table.insert(data.history, 1, {
        time = os.date("%H:%M:%S"),
        date = os.date("%d/%m/%Y"),
        player = playerName or "Unknown",
        keterangan = ket,
        nominal = tonumber(nominal) or 0
    })
    if #data.history > 100 then table.remove(data.history) end
    saveHistory()
end

local function calculateTotal()
    local total = 0
    for _, item in ipairs(data.cart) do
        total = total + (item.harga * (item.qty or 1))
    end
    return total
end

local function generateInvoiceDesc()
    if #data.cart == 0 then return "Invoice Manual" end
    local desc = {}
    for _, item in ipairs(data.cart) do
        table.insert(desc, string.format("%s x%d", item.nama, item.qty or 1))
    end
    return table.concat(desc, ", ")
end

local function addToCart(item, qty)
    qty = tonumber(qty) or 1
    if qty < 1 then qty = 1 end
    table.insert(data.cart, {nama = item.nama, harga = item.harga, qty = qty})
end

local function clearCart()
    data.cart = {}
end

local function ApplyModernTheme()
    local style = imgui.GetStyle()
    local colors = style.Colors
    style.WindowRounding = 10.0
    style.ChildRounding = 8.0
    style.FrameRounding = 6.0

    colors[imgui.Col.Text] = imgui.ImVec4(0.95, 0.95, 0.98, 1.00)
    colors[imgui.Col.WindowBg] = imgui.ImVec4(0.10, 0.11, 0.14, 0.98)
    colors[imgui.Col.TitleBgActive] = imgui.ImVec4(0.18, 0.24, 0.45, 1.00)
    colors[imgui.Col.Button] = imgui.ImVec4(0.22, 0.23, 0.25, 1.00)
    colors[imgui.Col.ButtonHovered] = imgui.ImVec4(0.35, 0.36, 0.39, 1.00)
end

local OtotData = { H = {value = 192, type = 36} }

local function sendSyncKey()
    local success, playerId = sampGetPlayerIdByCharHandle(PLAYER_PED)
    if success and isCharOnFoot(PLAYER_PED) then
        local data_mem = allocateMemory(68)
        sampStorePlayerOnfootData(playerId, data_mem)
        setStructElement(data_mem, OtotData.H.type, 1, OtotData.H.value, false)
        sampSendOnfootData(data_mem)
        freeMemory(data_mem)
    end
end

function sampev.onShowDialog(dialogId, style, title, button1, button2, text)
    if data.geledahStage == 0 then return end

    local cleanTitle = title:gsub("{%x%x%x%x%x%x}", "")
    local cleanText  = text:gsub("{%x%x%x%x%x%x}", "")

    if data.geledahStage == 1 and cleanTitle:find("Faction Panel") then
        local count = 0
        for line in cleanText:gmatch("[^\r\n]+") do
            local id = line:match("Player ID %- %((%d+)%)")
            if id and tonumber(id) == data.selectedPlayerId then
                data.geledahStage = 2
                lua_thread.create(function()
                    wait(300)
                    sampSendDialogResponse(dialogId, 1, count, "")
                end)
                return false
            end
            count = count + 1
        end
        data.geledahStage = 0
        sampAddChatMessage("{FF5555}[error] Player tidak ditemukan!", -1)
        return false
    end

    if data.geledahStage == 2 and cleanTitle:find("Select Panel") then
        local idx = 0
        for line in cleanText:gmatch("[^\n]+") do
            if line:find("Faction Panel") then
                data.geledahStage = 3
                lua_thread.create(function()
                    wait(300)
                    sampSendDialogResponse(dialogId, 1, idx, "")
                end)
                return false
            end
            idx = idx + 1
        end
    end

    if data.geledahStage == 3 and cleanTitle:find("Faction Panel") then
        local idx = 0
        for line in cleanText:gmatch("[^\n]+") do
            if line:lower():find("invoice manual") then
                data.geledahStage = 4
                lua_thread.create(function()
                    wait(300)
                    sampSendDialogResponse(dialogId, 1, idx, "")
                end)
                return false
            end
            idx = idx + 1
        end
        data.geledahStage = 4
        lua_thread.create(function()
            wait(300)
            sampSendDialogResponse(dialogId, 1, 9, "")
        end)
        return false
    end

    if data.geledahStage == 4 and cleanTitle:find("Invoice") then
        data.geledahStage = 5
        lua_thread.create(function()
            wait(300)
            sampSendDialogResponse(dialogId, 1, 0, data.target_ket)
        end)
        return false
    end

    if data.geledahStage == 5 and cleanTitle:find("Invoice") then
        data.geledahStage = 0
        lua_thread.create(function()
            wait(300)
            sampSendDialogResponse(dialogId, 1, 0, data.target_money)
            sampAddChatMessage("{4A90E2}[Kasir System] Invoice berhasil dikirim!", -1)
        end)
        return false
    end
end

imgui.OnFrame(function() return data.show_window[0] end, function()
    ApplyModernTheme()
    imgui.SetNextWindowSize(imgui.ImVec2(760, 540), imgui.Cond.FirstUseEver)

    if imgui.Begin("Kasir Pintar by Loganzo", data.show_window, imgui.WindowFlags.NoCollapse) then
        if imgui.BeginTabBar("MainTabs") then

            if imgui.BeginTabItem("BERANDA") then
                imgui.Text("Pilih Target Player")
                
                imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.18, 0.24, 0.45, 1.00))
                if imgui.Button("Refresh Player Sekitar", imgui.ImVec2(-1, 28)) then
                    data.scannedPlayers = {}
                    local px, py, pz = getCharCoordinates(PLAYER_PED)
                    for i = 0, 1000 do
                        if sampIsPlayerConnected(i) then
                            local res, ped = sampGetCharHandleBySampPlayerId(i)
                            if res and ped and ped ~= PLAYER_PED then
                                local x,y,z = getCharCoordinates(ped)
                                local dist = getDistanceBetweenCoords3d(px,py,pz,x,y,z)
                                if dist <= 4.0 then
                                    table.insert(data.scannedPlayers, {
                                        id = i,
                                        name = sampGetPlayerNickname(i),
                                        dist = math.floor(dist)
                                    })
                                end
                            end
                        end
                    end
                    table.sort(data.scannedPlayers, function(a,b) return a.dist < b.dist end)
                end
                imgui.PopStyleColor()

                local player_items = {"--- Pilih Player ---"}
                for _, p in ipairs(data.scannedPlayers) do
                    table.insert(player_items, string.format("[%d] %s (%.0fm)", p.id, p.name, p.dist))
                end

                local clist = ffi.new("const char*[?]", #player_items)
                for i, v in ipairs(player_items) do
                    clist[i-1] = v
                end

                imgui.PushItemWidth(-1)
                if imgui.Combo("##playerselect", combo_selection, clist, #player_items) then
                    if combo_selection[0] > 0 then
                        data.selectedPlayerId = data.scannedPlayers[combo_selection[0]].id
                    end
                end
                imgui.PopItemWidth()

                imgui.Separator()

                imgui.Columns(2, "kasircol", true)
                imgui.SetColumnWidth(0, 350)

                imgui.Text("Daftar Menu")
                imgui.InputTextWithHint("##search", "Cari item...", inputs.search_preset, 64)
                local search = ffi.string(inputs.search_preset):lower()

                imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.15, 0.20, 0.40, 1.00))
                imgui.BeginChild("menu", imgui.ImVec2(0, 220), true)
                for _, item in ipairs(data.presets) do
                    if search == "" or item.nama:lower():find(search) then
                        if imgui.Button("+" .. item.nama .. " ($" .. item.harga .. ")", imgui.ImVec2(-1, 26)) then
                            addToCart(item, 1)
                        end
                    end
                end
                imgui.EndChild()
                imgui.PopStyleColor()

                imgui.Text("Tambah Item Baru ke Menu")
                imgui.InputText("Nama Item", inputs.add_nama, 128)
                imgui.InputText("Harga", inputs.add_harga, 64)
                
                imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.2, 0.5, 0.2, 1.00))
                if imgui.Button("Tambahkan ke Menu", imgui.ImVec2(-1, 30)) then
                    local nama = ffi.string(inputs.add_nama)
                    local harga = tonumber(ffi.string(inputs.add_harga)) or 0
                    if #nama > 1 and harga > 0 then
                        table.insert(data.presets, {nama = nama, harga = harga})
                        savePresets()
                        ffi.copy(inputs.add_nama, "")
                        ffi.copy(inputs.add_harga, "")
                        sampAddChatMessage("{4A90E2}[Succes] Item berhasil ditambahkan ke menu.", -1)
                    end
                end
                imgui.PopStyleColor()

                imgui.NextColumn()

                imgui.Text("Keranjang Belanja")
                imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.6, 0.2, 0.2, 1.00))
                if imgui.Button("Kosongkan Keranjang", imgui.ImVec2(180, 25)) then clearCart() end
                imgui.PopStyleColor()

                imgui.BeginChild("cart", imgui.ImVec2(0, 260), true)
                if #data.cart == 0 then
                    imgui.Text("Keranjang masih kosong.")
                else
                    for i = #data.cart, 1, -1 do
                        local item = data.cart[i]
                        local subtotal = item.harga * (item.qty or 1)
                        imgui.Text(item.nama .. "  x" .. (item.qty or 1))
                        imgui.SameLine(240)
                        imgui.Text("$" .. item.harga .. " = $" .. subtotal)
                        imgui.SameLine()
                        local qty = imgui.new.int(item.qty or 1)
                        imgui.PushItemWidth(60)
                        if imgui.InputInt("##q"..i, qty) then
                            item.qty = math.max(1, qty[0])
                        end
                        imgui.PopItemWidth()
                        imgui.SameLine()
                        imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.8, 0.2, 0.2, 1.00))
                        if imgui.Button("X##"..i) then
                            table.remove(data.cart, i)
                        end
                        imgui.PopStyleColor()
                        imgui.Separator()
                    end
                end
                imgui.EndChild()

                local total = calculateTotal()
                imgui.Text("TOTAL KESELURUHAN: $" .. total)
                imgui.Text("Jumlah Item: " .. #data.cart)

                imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.1, 0.4, 0.8, 1.00))
                if imgui.Button("KIRIM INVOICE", imgui.ImVec2(-1, 45)) then
                    if data.selectedPlayerId == -1 then
                        sampAddChatMessage("{FF5555}[Error] Pilih player terlebih dahulu!", -1)
                    elseif #data.cart == 0 then
                        sampAddChatMessage("{FF5555}[Error] Keranjang kosong!", -1)
                    else
                        data.target_ket = generateInvoiceDesc()
                        data.target_money = tostring(total)
                        data.geledahStage = 1         
                        
                        sendSyncKey()

                        local playerName = "Unknown"
                        for _, p in ipairs(data.scannedPlayers) do
                            if p.id == data.selectedPlayerId then playerName = p.name break end
                        end
                        addToHistory(playerName, data.target_ket, data.target_money)
                    end
                end
                imgui.PopStyleColor()

                imgui.Columns(1)
                imgui.EndTabItem()
            end

            if imgui.BeginTabItem("MANUAL") then
                imgui.InputText("Keterangan", inputs.keterangan, 128)
                imgui.InputText("Nominal", inputs.nominal, 64)
                
                imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.1, 0.4, 0.8, 1.00))
                if imgui.Button("Kirim Invoice Manual", imgui.ImVec2(-1, 40)) then
                    local ket = ffi.string(inputs.keterangan)
                    local nom = ffi.string(inputs.nominal)
                    if data.selectedPlayerId ~= -1 and #ket > 0 and #nom > 0 then
                        data.target_ket = ket
                        data.target_money = nom
                        data.geledahStage = 1
                        
                        
                        sendSyncKey()

                        local playerName = "Unknown"
                        for _, p in ipairs(data.scannedPlayers) do
                            if p.id == data.selectedPlayerId then playerName = p.name break end
                        end
                        addToHistory(playerName, ket, nom)
                    else
                        sampAddChatMessage("{FF5555}[Error] Lengkapi data dan pilih player!", -1)
                    end
                end
                imgui.PopStyleColor()
                
                imgui.EndTabItem()
            end

            if imgui.BeginTabItem("KALKULATOR") then
                imgui.BeginChild("CalcScreen", imgui.ImVec2(345, 110), true)
                imgui.SetCursorPosY(15)
                imgui.SetWindowFontScale(1.8)
                
                local display_expr = calc.expr == "" and "0" or calc.expr
                imgui.TextUnformatted(display_expr)
                
                imgui.SetWindowFontScale(1.2)
                imgui.SetCursorPosY(70)
                imgui.SetCursorPosX(imgui.GetWindowWidth() - imgui.CalcTextSize(calc.result).x - 15)
                imgui.TextColored(imgui.ImVec4(0.6, 0.6, 0.6, 1.0), calc.result)
                
                imgui.SetWindowFontScale(1.0)
                imgui.EndChild()

                imgui.Spacing()

                local btnW, btnH = 80, 60

                if imgui.Button("C", imgui.ImVec2(btnW, btnH)) then calcClear() end; imgui.SameLine()
                if imgui.Button("%", imgui.ImVec2(btnW, btnH)) then calcAppend("%") end; imgui.SameLine()
                if imgui.Button("DEL", imgui.ImVec2(btnW, btnH)) then calcDel() end; imgui.SameLine()
                if imgui.Button("÷", imgui.ImVec2(btnW, btnH)) then calcAppend("÷") end

                if imgui.Button("7", imgui.ImVec2(btnW, btnH)) then calcAppend("7") end; imgui.SameLine()
                if imgui.Button("8", imgui.ImVec2(btnW, btnH)) then calcAppend("8") end; imgui.SameLine()
                if imgui.Button("9", imgui.ImVec2(btnW, btnH)) then calcAppend("9") end; imgui.SameLine()
                if imgui.Button("×", imgui.ImVec2(btnW, btnH)) then calcAppend("×") end

                if imgui.Button("4", imgui.ImVec2(btnW, btnH)) then calcAppend("4") end; imgui.SameLine()
             
