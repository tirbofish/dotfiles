-- Load Quickshell-persisted Hyprland settings at config parse time.
-- hyprctl eval is temporary and is wiped by `hyprctl reload` (pywal does
-- that on wallpaper apply ~1.5s after start).

local home = os.getenv("HOME") or "."

local M = {}

local function read_all(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local s = f:read("*a")
    f:close()
    return s
end

local function json_bool(raw, key, default)
    local v = raw:match('"' .. key .. '"%s*:%s*(%a+)')
    if v == "true" then return true end
    if v == "false" then return false end
    return default
end

local function json_num(raw, key, default)
    local v = raw:match('"' .. key .. '"%s*:%s*(-?[%d.]+)')
    return v and tonumber(v) or default
end

function M.input()
    local raw = read_all(home .. "/.config/quickshell/lib/inputsettings.json") or ""
    local accel = json_bool(raw, "mouseAcceleration", true)
    return {
        sensitivity = json_num(raw, "mouseSpeed", 0.35),
        accel_profile = accel and "adaptive" or "flat",
        natural_scroll = json_bool(raw, "mouseNaturalScroll", false),
        left_handed = json_bool(raw, "mouseLeftHanded", false),
        touchpad = {
            natural_scroll = json_bool(raw, "touchpadNaturalScroll", true),
            tap_to_click = json_bool(raw, "touchpadTapToClick", true),
            disable_while_typing = json_bool(raw, "touchpadDisableWhileTyping", true),
        },
        touchpad_sensitivity = json_num(raw, "touchpadSpeed", 0.35),
    }
end

-- Missing file => Main shader (same as the old hyprland.start default).
-- "none" / "OFF" / empty => no shader.
function M.shader_path(shader_dir)
    local raw = read_all(home .. "/.cache/quickshell/current_shader")
    if raw == nil then return shader_dir .. "main.glsl" end
    local name = (raw:match("^%s*(.-)%s*$")) or ""
    if name == "" or name:lower() == "none" or name == "OFF" then return "" end
    if name:sub(1, 1) == "/" then return name end
    return shader_dir .. name
end

local function mode_is_real(mode)
    if not mode or mode == "preferred" or mode == "highres" or mode == "highrr" then
        return false
    end
    local w, h = mode:match("^(%d+)x(%d+)")
    w, h = tonumber(w), tonumber(h)
    return w and h and w >= 200 and h >= 200
end

function M.apply_monitors()
    local raw = read_all(home .. "/.config/quickshell/lib/monitors.json")
    if not raw then return end
    -- Match by description, not connector name. A leftover DP-3 rule applies
    -- before EDID on the next plug and sticks at 0x0 until relogin.
    for description, block in raw:gmatch('"([^"]+)"%s*:%s*({[^{}]*"output"%s*:%s*"[^"]+"[^{}]*})') do
        if description ~= "" and description ~= "knownPatterns" then
            local spec = { output = "desc:" .. description }
            local mode = block:match('"mode"%s*:%s*"([^"]+)"')
            local position = block:match('"position"%s*:%s*"([^"]+)"')
            local scale = block:match('"scale"%s*:%s*([%d.]+)')
            if mode_is_real(mode) then
                if mode then spec.mode = mode end
                if position then spec.position = position end
                if scale then spec.scale = tonumber(scale) end
                if description:find("LQ135P1JX51", 1, true) then spec.bitdepth = 10 end
                hl.monitor(spec)
            end
        end
    end
end

return M
