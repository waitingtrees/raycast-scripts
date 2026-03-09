-- Auto Rename (External) — adapted from Nizar's Auto Rename v1.1
-- Connects to running DaVinci Resolve and renames unnamed Fusion nodes
-- Run via fuscript: fuscript -l lua auto-rename-fusion-nodes.lua

local resolve = bmd.scriptapp("Resolve")
if not resolve then
    print("ERROR: Could not connect to DaVinci Resolve")
    os.exit(1)
end

fusion = resolve:Fusion()
if not fusion then
    print("ERROR: Could not get Fusion context — make sure you're on the Fusion page")
    os.exit(1)
end

comp = fusion:GetCurrentComp()
if not comp then
    print("ERROR: No Fusion composition open — select a clip on the Fusion page first")
    os.exit(1)
end

-- [Media In-Nodes]

function rename_mediain_node(tool)
    if tool:GetAttrs("TOOLS_RegID") == "MediaIn" then
        new_node_name = tool:GetAttrs().TOOLS_Clip_Name

        new_node_name = string.gsub(new_node_name, " ", "_")

        if string.find(new_node_name, "%.") then
            local final_dot_index = (new_node_name:reverse()):find("%.")
            new_node_name = string.sub(new_node_name, 1, #new_node_name - final_dot_index)
        end

        if new_node_name:match("^%d+$") then
            new_node_name = "_" .. new_node_name
        end

        tool:SetAttrs({TOOLS_Name = new_node_name})
    end
end

-- [Background Nodes]

BG_NODE_PREFIX = ""
BG_NODE_SUFFIX = ""

COLORS = {White={1.0,1.0,1.0}, Silver={0.75,0.75,0.75}, Gray={0.5,0.5,0.5}, Black={0.0,0.0,0.0}, Red={1.0,0.0,0.0}, Maroon={0.5,0.0,0.0}, Yellow={1.0,1.0,0.0}, Olive={0.5,0.5,0}, Lime={0.0,1.0,0.0}, Green={0.0,0.5,0.0}, Cyan={0.0,1.0,1.0}, Teal={0.0,0.5,0.5}, Blue={0.0,0.0,1.0}, Navy={0.0,0.0,0.5}, Magenta={1.0,0.0,1.0}, Purple={0.5,0.0,0.5}, Pink={1.0,0.75,0.8}, OrangeRed={1.0,0.27,0.0}, Orange={1.0,0.55,0.0},Gold={1.0,0.84,0.0}, Brown={0.55,0.27,0.07}}

function rename_background_node(tool)
    if tool:GetAttrs("TOOLS_RegID") == "Background" then
        local r,g,b,a = tool.TopLeftRed[comp.CurrentTime], tool.TopLeftGreen[comp.CurrentTime], tool.TopLeftBlue[comp.CurrentTime], tool.TopLeftAlpha[comp.CurrentTime]

        local est_color = guess_color(r,g,b,a)
        local new_node_name = BG_NODE_PREFIX .. est_color .. BG_NODE_SUFFIX

        tool:SetAttrs({TOOLS_Name = new_node_name})
    end
end

function guess_color(r,g,b,a)
    if a == 0 then
        return "Transparent"
    end

    similarity_table = {}
    for color_name, color_rgb_table in pairs(COLORS) do
        similarity_table[color_name] = similarity(color_rgb_table[1], color_rgb_table[2], color_rgb_table[3], r,g,b)
    end

    local est_color = get_best_match_from_sim_table(similarity_table)

    if a < 1 then
        return est_color .. "_Transparent"
    else
        return est_color
    end
end

function get_best_match_from_sim_table(t)
    local key = next(t)
    local minv = t[key]

    for k, v in pairs(t) do
        if t[k] < minv then
            key, minv = k, v
        end
    end

    return key
end

function similarity(r1,g1,b1,r2,g2,b2)
    return _cielab_similarity(r1,g1,b1,r2,g2,b2)
end

function _cielab_similarity(r1,g1,b1,r2,g2,b2)
    local x1,y1,z1 = sRGBtoLab(r1,g1,b1)
    local x2,y2,z2 = sRGBtoLab(r2,g2,b2)

    return math.sqrt((y1-y2)^2 + (z1-z2)^2) + math.abs(x1-x2)
end

function sRGBtoLab(r,g,b)
    if r > 0.04045 then
        r = ((r+0.055)/1.055)^2.4
    else
        r = r/12.92
    end
    if g > 0.04045 then
        g = ((g+0.055)/1.055)^2.4
    else
        g = g/12.92
    end
    if b > 0.04045 then
        b = ((b+0.055)/1.055)^2.4
    else
        b = b/12.92
    end

    r = r*100
    g = g*100
    b = b*100

    local x = r * 0.4124 + g * 0.3576 + b * 0.1805
    local y = r * 0.2126 + g * 0.7152 + b * 0.0722
    local z = r * 0.0193 + g * 0.1192 + b * 0.9505

    local refx,refy,refz = 95.047,100.000,108.883

    x,y,z = x/refx,y/refy,z/refz

    if x > 0.008856 then
        x = x^(1/3)
    else
        x = (7.787*x) + (16/116)
    end
    if y > 0.008856 then
        y = y^(1/3)
    else
        y = (7.787*y) + (16/116)
    end
    if z > 0.008856 then
        z = z^(1/3)
    else
        z = (7.787*z) + (16/116)
    end

    L = (116*y) - 16
    a = 500*(x-y)
    b = 200*(y-z)
    return L,a,b
end

-- [Text Nodes]

NODE_PREFIX_TEXTPLUS = "Text_"
NODE_PREFIX_TEXT3D = "Text3D_"

function rename_textplus_node(tool)
    if tool:GetAttrs("TOOLS_RegID") == "TextPlus" or tool:GetAttrs("TOOLS_RegID") == "Text3D" then
        local styledtext = tool.StyledText[comp.CurrentTime]

        if styledtext ~= "" then
            local new_node_name = shorten_text_node_name(styledtext)

            if tool:GetAttrs("TOOLS_RegID") == "TextPlus" then
                new_node_name = NODE_PREFIX_TEXTPLUS .. new_node_name
            elseif tool:GetAttrs("TOOLS_RegID") == "Text3D" then
                new_node_name = NODE_PREFIX_TEXT3D .. new_node_name
            end

            tool:SetAttrs({TOOLS_Name = new_node_name})
        end
    end
end

function shorten_text_node_name(styledtext)
    local words = {}

    for matchgroup in string.gmatch(styledtext, "%S+") do
        words[#words+1] = matchgroup
    end

    if(#words == 1) then
        return styledtext
    end

    if(#words >= 2) then
        return(words[1] .. "_" .. words[2])
    end
end

-- [Transform Nodes]

function rename_transform_node(tool)
    if tool:GetAttrs("TOOLS_RegID") == "Transform" then
        local input = tool.Input:GetConnectedOutput()

        if input then
            local input_tool = input:GetTool()
            if input_tool then
                local input_name = input_tool:GetAttrs("TOOLS_Name")
                local new_node_name = input_name .. "_Transform"
                tool:SetAttrs({TOOLS_Name = new_node_name})
            end
        end
    end
end

-- [MultiMerge nodes]

function number_of_connected_layers(mmrg)
    local res = 0
    while(mmrg["Layer"..tostring(res+1)] ~= nil) do
        res = res+1
    end
    return res-1
end

function rename_multimerge_node(tool)
    if(tool:GetAttrs("TOOLS_RegID") == "MultiMerge") then
        for i=1,number_of_connected_layers(tool) do
            tool["LayerName"..tostring(i)][0] = tool["Layer"..tostring(i)].Foreground:GetConnectedOutput():GetTool():GetAttrs("TOOLS_Name")
        end
    end
end

-- [main loop]

function main()
    tools = comp:GetToolList()
    local renamed = 0

    for _,tool in ipairs(tools) do
        local _tool_id = tool:GetAttrs("TOOLS_RegID")
        local _tool_name_changed_by_user = tool:GetAttrs("TOOLB_NameSet")

        if((_tool_id == "MediaIn") and (not _tool_name_changed_by_user)) then
            if pcall(rename_mediain_node, tool) then renamed = renamed + 1 end

        elseif(_tool_id == "Background" and (not _tool_name_changed_by_user)) then
            if pcall(rename_background_node, tool) then renamed = renamed + 1 end

        elseif((_tool_id == "TextPlus") or (_tool_id == "Text3D")) then
            if(not _tool_name_changed_by_user) then
                if pcall(rename_textplus_node, tool) then renamed = renamed + 1 end
            end

        elseif(_tool_id == "Transform" and (not _tool_name_changed_by_user)) then
            if pcall(rename_transform_node, tool) then renamed = renamed + 1 end

        elseif(_tool_id == "MultiMerge") then
            if pcall(rename_multimerge_node, tool) then renamed = renamed + 1 end
        end
    end

    print(string.format("Renamed %d node(s)", renamed))
end

main()
