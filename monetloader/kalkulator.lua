script_name("Kalkulator by Loganzo")
script_author("Loganzo @williamrzz")

local imgui = require 'mimgui'
local encoding = require 'encoding'

encoding.default = 'CP1251'
local u8 = encoding.UTF_8

local show_window = imgui.new.bool(false)

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

imgui.OnFrame(function() return show_window[0] end, function()
    ApplyModernTheme()
    imgui.SetNextWindowSize(imgui.ImVec2(380, 480), imgui.Cond.FirstUseEver)

    if imgui.Begin("Kalkulator by Loganzo", show_window, imgui.WindowFlags.NoResize + imgui.WindowFlags.NoCollapse) then
        
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
        if imgui.Button("5", imgui.ImVec2(btnW, btnH)) then calcAppend("5") end; imgui.SameLine()
        if imgui.Button("6", imgui.ImVec2(btnW, btnH)) then calcAppend("6") end; imgui.SameLine()
        if imgui.Button("-", imgui.ImVec2(btnW, btnH)) then calcAppend("-") end

        if imgui.Button("1", imgui.ImVec2(btnW, btnH)) then calcAppend("1") end; imgui.SameLine()
        if imgui.Button("2", imgui.ImVec2(btnW, btnH)) then calcAppend("2") end; imgui.SameLine()
        if imgui.Button("3", imgui.ImVec2(btnW, btnH)) then calcAppend("3") end; imgui.SameLine()
        if imgui.Button("+", imgui.ImVec2(btnW, btnH)) then calcAppend("+") end

        if imgui.Button("00", imgui.ImVec2(btnW, btnH)) then calcAppend("00") end; imgui.SameLine()
        if imgui.Button("0", imgui.ImVec2(btnW, btnH)) then calcAppend("0") end; imgui.SameLine()
        if imgui.Button(".", imgui.ImVec2(btnW, btnH)) then calcAppend(".") end; imgui.SameLine()
        
        imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.1, 0.4, 1.0, 1.00))
        imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.2, 0.5, 1.0, 1.00))
        if imgui.Button("=", imgui.ImVec2(btnW, btnH)) then calcEqual() end
        imgui.PopStyleColor(2)

        imgui.End()
    end
end)

sampRegisterChatCommand("kal", function()
    show_window[0] = not show_window[0]
end)

function main()
    while not isSampAvailable() do wait(100) end
    sampAddChatMessage("{4A90E2}[Kalkulator by Loganzo] Loaded! Ketik /kal untuk menggunakan.", -1)
    wait(-1)
end

