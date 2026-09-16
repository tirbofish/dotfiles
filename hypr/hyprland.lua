-- =========================================================================
-- @snes19xx Hyprland CONFIG
-- =========================================================================

local mod     = "SUPER"
local alt     = "ALT"
local home    = os.getenv("HOME") or "."
local scripts = home .. "/.config/hypr/scripts"
local palette = {
    active_border = "rgba(7aa1a6ee)", inactive_border = "rgba(141719aa)",
    accent = "rgb(7aa1a6)", secondary = "rgb(7aa1a6)",
    background = "rgb(141719)", foreground = "rgb(dde5df)",
    danger = "rgb(e67e80)", muted = "rgb(9da9a0)",
    shadow = "rgba(14171944)",
}
local palette_chunk = loadfile(home .. "/.cache/wal/tirbofish-hyprland.lua")
if palette_chunk then
    local ok, loaded = pcall(palette_chunk)
    if ok and type(loaded) == "table" then
        for k, v in pairs(loaded) do palette[k] = v end
    end
end

-- Import Shader Manager and Inject Core
local shader = require("shader")
local persist_ok, persist_or_err = pcall(require, "persist")
local persist
if persist_ok and type(persist_or_err) == "table" then
    persist = persist_or_err
else
    io.stderr:write("hypr persist.lua: " .. tostring(persist_or_err) .. "\n")
    persist = {
        input = function()
            return {
                sensitivity = 0.35, accel_profile = "adaptive",
                natural_scroll = false, left_handed = false,
                touchpad = {
                    natural_scroll = true, tap_to_click = true,
                    disable_while_typing = true,
                },
            }
        end,
        shader_path = function(dir) return dir .. "main.glsl" end,
        apply_monitors = function() end,
    }
end
local input = persist.input()

-- =========================================================================
-- Environment Variables
-- Must be set before the display server comes up (before hl.monitor).
-- =========================================================================
local function theme_mode()
    local f = io.open(home .. "/.cache/quickshell/theme_mode", "r")
    if not f then return "dark" end
    local m = f:read("l") or ""
    f:close()
    return m:gsub("%s+", "") == "light" and "light" or "dark"
end

local function cursor_installed(name)
    for _, dir in ipairs({ home .. "/.local/share/icons/", "/usr/share/icons/" }) do
        local f = io.open(dir .. name .. "/index.theme", "r")
        if f then f:close() return true end
    end
    return false
end

local function local_binary_or_command(name)
    local path = home .. "/.local/bin/" .. name
    local file = io.open(path, "r")
    if file then
        file:close()
        return path
    end
    return name
end

local wanted_cursor = theme_mode() == "light" and "Saturnian-Day" or "Saturnian-Night"
local cursor_theme  = cursor_installed(wanted_cursor) and wanted_cursor or "Adwaita"
local snappy_switcher = local_binary_or_command("snappy-switcher")
local hyprfloat = local_binary_or_command("hyprfloat")
local vicinae = local_binary_or_command("vicinae")

-- Work around rejected Intel/dock modesets; takes effect on the next login.
-- AQ_NO_MODIFIERS: LINEAR GBM buffers. AQ_NO_ATOMIC: skip atomic TEST_ONLY.
-- After MST renames DP-4 -> DP-3, every atomic modeset on the ultrawide is
-- EINVAL (even 640x480) and the output stays 0x0 until a compositor restart
-- with the legacy DRM path.
hl.env("AQ_NO_MODIFIERS", "1")
hl.env("AQ_NO_ATOMIC", "1")
hl.env("HYPRCURSOR_THEME", cursor_theme)
hl.env("HYPRCURSOR_SIZE",  "32")
hl.env("XCURSOR_THEME",    cursor_theme)
hl.env("XCURSOR_SIZE",     "32")
-- Do not set GDK_SCALE. The wiki laptop-only recipe (GDK_SCALE=2 plus
-- xwayland.force_zero_scaling) pins Electron and XWayland GTK to 2x, so
-- they stay twice as large on the 1x ultrawide. Native Wayland GTK/Qt
-- already follow each output via wp_fractional_scale_v1.
hl.env("GDK_BACKEND",     "wayland,x11,*")
hl.env("CLUTTER_BACKEND", "wayland")
hl.env("TERMINAL",        "kitty")
hl.env("QT_QPA_PLATFORMTHEME", "kde")
hl.env("QT_STYLE_OVERRIDE",    "kvantum")
hl.env("QT_QPA_PLATFORM",      "wayland;xcb")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "wayland")

-- =========================================================================
-- Monitors
-- =========================================================================
-- The installer rewrites the blocks below from what you enter on its monitor
-- screen. Editing them by hand afterwards is fine, keep them at the top level.
-- BEGIN installer-managed monitors
-- hl.monitor({
--     output   = "eDP-1",
--     mode     = "preferred",
--     position = "0x0",
--     scale    = 2,
--     bitdepth = 10
-- })
-- END installer-managed monitors
-- Saved layouts (desc: selectors) live in ~/.config/quickshell/lib/monitors.json.
-- Pyprland plus the apply script retry 0x0 MST hotplugs; do not name DP-*.
persist.apply_monitors()

local function set_wallpapers()
    hl.exec_cmd(scripts .. "/wallpaper.sh")
end

-- Plugging a monitor in gives it no wallpaper until awww is told about it, so
-- redraw shortly after the layout settles.
local function set_wallpapers_delayed()
    hl.timer(set_wallpapers, { timeout = 500, type = "oneshot" })
end

local function apply_monitors_delayed()
    hl.exec_cmd(scripts .. "/pypr-apply-monitors.py")
    set_wallpapers_delayed()
end

-- Surface Laptop 4: keyboard keys press the panel when the lid is shut and
-- generate phantom touches on the remaining (usually docked) monitor.
local function lid_closed()
    for _, path in ipairs({
        "/proc/acpi/button/lid/LID0/state",
        "/proc/acpi/button/lid/LID/state",
    }) do
        local f = io.open(path, "r")
        if f then
            local s = f:read("*a") or ""
            f:close()
            return s:find("closed", 1, true) ~= nil
        end
    end
    return false
end

local function set_touchscreen_enabled(enabled)
    hl.config({ input = { touchdevice = { enabled = enabled } } })
    hl.exec_cmd(scripts .. "/lid-touchscreen.sh " .. (enabled and "on" or "off"))
end

hl.on("monitor.added",   apply_monitors_delayed)
hl.on("monitor.removed", set_wallpapers_delayed)

hl.permission("/usr/(bin|local/bin)/hyprpm", "plugin", "allow")
hl.exec_cmd("pgrep -x snappy-switcher >/dev/null || " .. snappy_switcher .. " --daemon")

-- =========================================================================
-- Autostart
-- =========================================================================
local function apply_input_devices()
    hl.exec_cmd(scripts .. "/apply-input.sh")
end

hl.on("hyprland.start", function()
    hl.exec_cmd("hyprpm reload")
    hl.exec_cmd("qs")
    hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE && systemctl --user stop kanshi.service; systemctl --user restart pyprland.service")
    hl.exec_cmd("awww-daemon")
    hl.exec_cmd("hypridle")
    hl.exec_cmd(vicinae .. " server --replace")
    -- logind's default HandlePowerKey=poweroff wins unless we inhibit it.
    hl.exec_cmd("systemctl --user start hypr-power-key-lock.service")
    hl.exec_cmd("systemctl --user start cpu-starvation-guard.service")
    hl.exec_cmd("dunst")
    hl.exec_cmd(scripts .. "/clipboard-history.sh boot")
    hl.exec_cmd("blueman-applet")
    hl.exec_cmd("pgrep -f bt-audio-agent.py >/dev/null || " .. scripts .. "/bt-audio-agent.py")
    -- hyprpolkitagent if you have it, polkit-gnome otherwise
    hl.exec_cmd("systemctl --user start hyprpolkitagent 2>/dev/null || /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1")
    -- needs the oauth done first, skip it if there's no config
    hl.exec_cmd("[ -f $HOME/.config/vdirsyncer/config ] && vdirsyncer sync || true")
    hl.exec_cmd("sleep 1 && mpv --no-video --volume=100 " .. home .. "/.config/hypr/sounds/startup.wav")
    hl.timer(set_wallpapers, { timeout = 1500, type = "oneshot" }) -- after awww-daemon is up
    -- Dock already plugged at login: MST rename lands a few seconds later.
    hl.timer(function()
        hl.exec_cmd(scripts .. "/pypr-apply-monitors.py")
    end, { timeout = 2500, type = "oneshot" })
    -- XWayland is up by then; xpet is an override-redirect X11 pet.
    hl.timer(function()
        hl.exec_cmd("pgrep -x xpet >/dev/null || " .. home .. "/xpet/xpet")
    end, { timeout = 3000, type = "oneshot" })
    -- Devices do not exist yet when this file is first parsed.
    hl.timer(apply_input_devices, { timeout = 400, type = "oneshot" })
end)
hl.on("config.reloaded", function()
    hl.timer(apply_input_devices, { timeout = 200, type = "oneshot" })
end)

-- Re-arm Biopass after a timeout window: first password keystroke while
-- locked writes a trigger file that lock.sh waits on.
local hyprlock_biopass_runtime = os.getenv("XDG_RUNTIME_DIR") or "/tmp"
local hyprlock_biopass_armed = hyprlock_biopass_runtime .. "/hyprlock-biopass.armed"
local hyprlock_biopass_trigger = hyprlock_biopass_runtime .. "/hyprlock-biopass.trigger"
local hyprlock_biopass_done = hyprlock_biopass_runtime .. "/hyprlock-biopass.done"
local hyprlock_biopass_skip = {
    [9] = true, [37] = true, [50] = true, [62] = true, [64] = true, [66] = true,
    [105] = true, [107] = true, [108] = true, [121] = true, [122] = true,
    [123] = true, [133] = true, [134] = true, [135] = true, [172] = true,
    [232] = true, [233] = true,
}
local function file_exists(path)
    local f = io.open(path, "r")
    if not f then return false end
    f:close()
    return true
end
local function request_hyprlock_biopass()
    if file_exists(hyprlock_biopass_done) or not file_exists(hyprlock_biopass_armed) then
        return
    end
    local trigger = io.open(hyprlock_biopass_trigger, "w")
    if trigger then trigger:close() end
end
local hyprlock_biopass_binds = {}
local function add_hyprlock_biopass_key(key)
    local bind = hl.bind(key, request_hyprlock_biopass, {
        locked = true,
        non_consuming = true,
        ignore_mods = true,
        description = "Re-enable Biopass on lockscreen key",
    })
    if bind then
        bind:set_enabled(false)
        hyprlock_biopass_binds[#hyprlock_biopass_binds + 1] = bind
    end
end
for key in ("abcdefghijklmnopqrstuvwxyz0123456789"):gmatch(".") do
    add_hyprlock_biopass_key(key)
end
for _, key in ipairs({
    "return", "backspace", "space", "tab", "minus", "equal", "semicolon",
    "apostrophe", "grave", "comma", "period", "slash", "backslash",
    "bracketleft", "bracketright",
}) do
    add_hyprlock_biopass_key(key)
end
local hyprlock_biopass_binds_enabled = false
hl.timer(function()
    local armed = io.open(hyprlock_biopass_armed, "r")
    local enabled = armed ~= nil
    if armed then armed:close() end
    if enabled == hyprlock_biopass_binds_enabled then return end
    hyprlock_biopass_binds_enabled = enabled
    for _, bind in ipairs(hyprlock_biopass_binds) do
        bind:set_enabled(enabled)
    end
end, { timeout = 1000, type = "repeat" })
hl.on("input.keyboard.key", function(keycode, _, state)
    if state ~= 1 or hyprlock_biopass_skip[keycode] then return end
    if lid_closed() then return end
    request_hyprlock_biopass()
end)

-- =========================================================================
-- Workspace Rules
-- Each display gets four regular slots and an empty trailing slot. IDs are
-- globally unique in Hyprland; preserve existing windows and allocate locally.
-- =========================================================================
local ws_rules = {}
local workspace_slots = {}

local function sync_workspace_span()
    local monitors = hl.get_monitors()
    workspace_slots = {}
    table.sort(monitors, function(a, b) return a.id < b.id end)
    local used, desired, slots = {}, {}, {}
    for _, ws in ipairs(hl.get_workspaces()) do
        if not ws.special and ws.id > 0 and ws.monitor then
            used[ws.id] = true
            local name = ws.monitor.name
            slots[name] = slots[name] or {}
            table.insert(slots[name], ws)
        end
    end
    for _, mon in ipairs(monitors) do
        local list = slots[mon.name] or {}
        table.sort(list, function(a, b) return a.id < b.id end)
        local keep = 5
        for i, ws in ipairs(list) do
            if not ws.is_empty then keep = math.max(keep, i + 1) end
            if mon.active_workspace and ws.id == mon.active_workspace.id then
                keep = math.max(keep, i)
            end
        end
        workspace_slots[mon.name] = {}
        local last = 0
        for i = 1, keep do
            local id = list[i] and list[i].id
            if not id then
                id = last + 1
                while used[id] do id = id + 1 end
            end
            used[id], desired[id] = true, mon.name
            workspace_slots[mon.name][i] = id
            last = id
        end
    end
    for id, entry in pairs(ws_rules) do
        entry.rule:set_enabled(desired[id] == entry.monitor)
    end
    for id, monitor in pairs(desired) do
        if not ws_rules[id] or ws_rules[id].monitor ~= monitor then
            ws_rules[id] = { monitor = monitor, rule = hl.workspace_rule({
                workspace = tostring(id), monitor = monitor, persistent = true,
            }) }
        end
    end
end

local ws_sync_gen = 0
local function schedule_workspace_span()
    ws_sync_gen = ws_sync_gen + 1
    local gen = ws_sync_gen
    hl.timer(function()
        if gen == ws_sync_gen then sync_workspace_span() end
    end, { timeout = 80, type = "oneshot" })
end

sync_workspace_span()
hl.on("window.open", schedule_workspace_span)
hl.on("window.close", schedule_workspace_span)
hl.on("window.move_to_workspace", schedule_workspace_span)
hl.on("workspace.active", schedule_workspace_span)
hl.on("workspace.removed", schedule_workspace_span)
hl.on("workspace.created", schedule_workspace_span)
hl.on("workspace.move_to_monitor", schedule_workspace_span)
hl.on("monitor.added", schedule_workspace_span)
hl.on("monitor.removed", schedule_workspace_span)
hl.on("hyprland.start", schedule_workspace_span)
hl.on("config.reloaded", schedule_workspace_span)

-- =========================================================================
-- Core Config
-- =========================================================================
hl.config({
    general = {
        gaps_in               = 1,
        gaps_out              = 3,
        border_size           = 1,
        ["col.active_border"]   = palette.active_border,
        ["col.inactive_border"] = palette.inactive_border,
        resize_on_border      = true,
        extend_border_grab_area = 15,
        allow_tearing         = false,
        layout                = "dwindle",
        snap = {
            enabled        = true,
            window_gap     = 10,
            monitor_gap    = 10,
            border_overlap = true,
            respect_gaps   = true,
        },
    },
    decoration = {
        rounding         = 7,
        active_opacity   = 1.0,
        inactive_opacity = 0.9,
        dim_inactive     = false,
        dim_strength     = 0.19,
        dim_around       = 0.6,
        shadow = {
            enabled      = true,
            range        = 3,
            render_power = 17,
            color        = palette.shadow
        },
        blur = {
            enabled           = true,
            size              = 5,
            passes            = 2,
            new_optimizations = true,
        },
        screen_shader    = persist.shader_path(home .. "/.config/hypr/shaders/")
    },
    animations = {
        enabled = true
    },
    cursor = {
        -- AQ_NO_ATOMIC + Intel hw cursors flicker/vanish across mixed-scale
        -- monitors. 1 = software cursor.
        no_hardware_cursors = 1,
        no_warps = true,
    },
    dwindle = {
        preserve_split = true,
        smart_resizing = true
    },
    master = {
        new_status = "master"
    },
    group = {
        ["col.border_active"]   = "rgba(00000000)",
        ["col.border_inactive"] = "rgba(00000000)",
        groupbar = {
            enabled              = true,
            height               = 16,
            gradients            = true,
            ["col.active"]       = palette.accent,
            ["col.inactive"]     = palette.background,
            keep_upper_gap       = false,
            indicator_height     = 0,
            indicator_gap        = 0,
            gaps_in              = 0,
            gaps_out             = 9,
            gradient_rounding    = 8,
            font_family          = "Inter",
            font_size            = 11,
            font_weight_active   = "medium",
            font_weight_inactive = "medium",
            text_color           = palette.background,
            text_color_inactive  = palette.foreground,
            text_offset          = 1
        }
    },
    input = {
        kb_layout      = "us",
        follow_mouse   = 0,
        sensitivity    = input.sensitivity,
        accel_profile  = input.accel_profile,
        natural_scroll = input.natural_scroll,
        left_handed    = input.left_handed,
        repeat_rate    = 50,
        repeat_delay   = 300,
        touchpad = {
            natural_scroll       = input.touchpad.natural_scroll,
            tap_to_click         = input.touchpad.tap_to_click,
            disable_while_typing = input.touchpad.disable_while_typing
        },
        -- Closed lid presses the keyboard into the panel; keep the digitizer
        -- off then, and pin remaining events to eDP-1 so they cannot leak
        -- onto a docked display. Live lid binds update this after parse.
        touchdevice = {
            enabled = not lid_closed(),
            output  = "eDP-1"
        }
    },
    xwayland = {
        force_zero_scaling = true
    },
    misc = {
        vrr                      = 1,
        disable_hyprland_logo    = true,
        disable_splash_rendering = true,
        force_default_wallpaper  = 0,
        animate_manual_resizes   = true,
        enable_swallow           = true,
        swallow_regex            = "^(kitty)$"
    },
    gestures = {
        workspace_swipe_use_r   = false,
        workspace_swipe_forever = false,
    },
layerrule = {
    "animation slide, rofi",
    "animation slide, wifi-menu",
    "animation popin, power-menu",
    "dim_around, power-menu",
    "noanim, desktop-widget",
    "noanim, desktop-widget-edit",
}
})

-- =========================================================================
-- Animations
-- =========================================================================
hl.curve("md3_standard", { type = "bezier", points = { {0.2, 0.0}, {0, 1.0} } })
hl.curve("md3_decel", { type = "bezier", points = { {0.05, 0.7}, {0.1, 1.0} } })
hl.curve("md3_accel", { type = "bezier", points = { {0.3, 0.0}, {0.8, 0.15} } })

hl.curve("winIn", { type = "spring", mass = 1, stiffness = 350, dampening = 35 })
hl.curve("winOut", { type = "spring", mass = 1, stiffness = 320, dampening = 32 })
hl.curve("winMove", { type = "spring", mass = 1, stiffness = 300, dampening = 30 })

hl.animation({ leaf = "windowsIn", enabled = true, speed = 3, spring = "winIn", style = "popin 85%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 3, spring = "winOut", style = "popin 85%" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 3, spring = "winMove", style = "slide" })

hl.animation({ leaf = "fade", enabled = true, speed = 2, bezier = "md3_standard" })
hl.animation({ leaf = "fadeDim", enabled = true, speed = 2, bezier = "md3_standard" })

hl.animation({ leaf = "workspacesIn", enabled = true, speed = 3, bezier = "md3_decel", style = "slidefade 15%" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 3, bezier = "md3_accel", style = "slidefade 15%" })
hl.animation({ leaf = "specialWorkspaceIn", enabled = true, speed = 3, bezier = "md3_decel", style = "slide top" })
hl.animation({ leaf = "specialWorkspaceOut", enabled = true, speed = 3, bezier = "md3_accel", style = "slide top" })

hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = 2, bezier = "md3_decel" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 2, bezier = "md3_accel" })




-- =========================================================================
-- Gestures
-- =========================================================================
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
hl.gesture({
    fingers = 3,
    direction = "down",
    action = function()
        hl.exec_cmd(scripts .. "/desktop-mode.sh down")
    end,
})
hl.gesture({
    fingers = 3,
    direction = "up",
    action = function()
        hl.exec_cmd(scripts .. "/desktop-mode.sh up")
    end,
})

local hymission = hl.plugin and hl.plugin.hymission
if hymission then
    hl.config({ plugin = { hymission = {
        layout_engine = "mission-control",
        only_active_workspace = 1,
        workspace_strip_empty_mode = "existing",
    } } })
end

-- Additional plugin hooks: ~/.config/hypr/plugins/init.lua
do
    local chunk = loadfile(home .. "/.config/hypr/plugins/init.lua")
    if chunk then
        local ok, err = pcall(chunk)
        if not ok then
            io.stderr:write("hypr plugins/init.lua: " .. tostring(err) .. "\n")
        end
    end
end

local workspace_float = dofile(home .. "/.config/hypr/plugins/workspace-float.lua")
workspace_float.sync()
hl.on("window.open", workspace_float.schedule)
hl.on("window.close", workspace_float.schedule)
hl.on("window.move_to_workspace", workspace_float.schedule)
hl.on("hyprland.start", workspace_float.sync)
hl.on("config.reloaded", workspace_float.sync)

hl.layer_rule({ match = { namespace = "snappy-switcher" }, blur = true, ignore_alpha = 0.01 })
hl.layer_rule({ match = { namespace = "notifications" }, blur = true, ignore_alpha = 0.2 })

-- =========================================================================
-- Keybindings
-- =========================================================================

-- Hub & Modes
hl.bind(mod .. " + SPACE", hl.dsp.exec_cmd(vicinae .. " toggle"), { description = "Vicinae" })
hl.bind(mod .. " + R", hl.dsp.global("quickshell:drawerToggle"))  -- Workspace Drawer
hl.bind(mod .. " + SHIFT + W", hl.dsp.global("quickshell:widgetEdit")) -- Desktop widgets

-- Apps
hl.bind(mod .. " + Q", hl.dsp.exec_cmd("kitty"))
hl.bind(mod .. " + E", hl.dsp.exec_cmd("nautilus"))
-- hl.bind(mod .. " + R", hl.dsp.exec_cmd(home .. "/.config/rofi/rofi_wide.sh")) -- if you prefer rofi
hl.bind(mod .. " + B", hl.dsp.exec_cmd("firefox"))
hl.bind(mod .. " + S", hl.dsp.exec_cmd("lens --no-decorations --sniper"))
hl.bind(mod .. " + P", hl.dsp.exec_cmd("hyprpicker -a"))
hl.bind(mod .. " + SHIFT + P", hl.dsp.exec_cmd("pgrep -x xpet >/dev/null && pkill -x xpet || " .. home .. "/xpet/xpet"), { description = "Toggle desktop pet" })
hl.bind(mod .. " + SHIFT + CTRL + P", hl.dsp.exec_cmd("pkill -USR1 -x xpet"), { description = "xpet chase toggle" })
hl.bind(mod .. " + SHIFT + ALT + P", hl.dsp.exec_cmd("pkill -USR2 -x xpet"), { description = "xpet freeze toggle" })
hl.bind("SUPER + V", function()
    hl.exec_cmd(scripts .. "/clipboard-history.sh")
end, { description = "Clipboard history" })
hl.bind(mod .. " + period", hl.dsp.exec_cmd(scripts .. "/emoji.sh"), { description = "Emoji picker" })

-- Window Actions
hl.bind(mod .. " + X", hl.dsp.window.close())
hl.bind(mod .. " + N", hl.dsp.exec_cmd(scripts .. "/minimized-windows.sh hide"), { description = "Minimize window" })
hl.bind(mod .. " + SHIFT + N", hl.dsp.exec_cmd(scripts .. "/minimized-windows.sh menu"), { description = "Restore minimized window" })
hl.bind(mod .. " + F", function()
    hl.dispatch(hl.dsp.window.float({ action = "toggle" }))
    workspace_float.schedule()
end)
hl.bind(mod .. " + SHIFT + F", function()
    hl.dispatch(hl.dsp.exec_cmd(hyprfloat .. " togglefloat"))
    workspace_float.schedule(200)
end, { description = "Toggle workspace / tiled mode" })
hl.bind(mod .. " + " .. alt .. " + F", function()
    hl.dispatch(hl.dsp.window.float({ action = "set" }))
    hl.dispatch(hl.dsp.window.resize({ x = 900, y = 600 }))
    hl.dispatch(hl.dsp.window.center())
    workspace_float.schedule()
end)
local float_max_saved = {}
local function reserved_sides(r)
    r = r or {}
    return r.left or r[1] or 0, r.top or r[2] or 0, r.right or r[3] or 0, r.bottom or r[4] or 0
end
local function monitor_work_area(mon)
    mon = mon or hl.get_active_monitor()
    if not mon then return nil end
    local scale = (mon.scale and mon.scale > 0) and mon.scale or 1
    local gap = 3
    local border = 1
    local pad = gap + border
    local left, top, right, bottom = reserved_sides(mon.reserved)
    return {
        x = (mon.x or 0) + left + pad,
        y = (mon.y or 0) + top + pad,
        w = mon.width / scale - left - right - 2 * pad,
        h = mon.height / scale - top - bottom - 2 * pad,
    }
end
local function window_geom(win)
    local at, size = win.at or {}, win.size or {}
    return {
        x = at.x or at[1] or 0,
        y = at.y or at[2] or 0,
        w = size.x or size.width or size[1] or 0,
        h = size.y or size.height or size[2] or 0,
    }
end
local function place_floating(x, y, w, h)
    hl.dispatch(hl.dsp.window.resize({ x = math.floor(w), y = math.floor(h), relative = false }))
    hl.dispatch(hl.dsp.window.move({ x = math.floor(x), y = math.floor(y), relative = false }))
end
hl.bind(mod .. " + M", function()
    local win = hl.get_active_window()
    if not win then return end
    if win.floating then
        local area = monitor_work_area()
        if not area or area.w < 50 or area.h < 50 then return end
        local addr = tostring(win.address)
        local g = window_geom(win)
        local filled = math.abs(g.x - area.x) <= 10 and math.abs(g.y - area.y) <= 10
            and math.abs(g.w - area.w) <= 20 and math.abs(g.h - area.h) <= 20
        if filled and float_max_saved[addr] then
            local prev = float_max_saved[addr]
            place_floating(prev.x, prev.y, prev.w, prev.h)
            float_max_saved[addr] = nil
        else
            float_max_saved[addr] = g
            place_floating(area.x, area.y, area.w, area.h)
        end
        return
    end
    hl.dispatch(hl.dsp.window.fullscreen({
        mode = "maximized",
        action = "toggle",
        layout_aware = false,
    }))
end, { description = "Maximize" })
-- hl.bind(mod .. " + P", hl.dsp.window.pseudo())
hl.bind(mod .. " + SHIFT + DOWN", hl.dsp.layout("togglesplit"))
hl.bind(mod .. " + SHIFT + UP",   hl.dsp.layout("togglesplit"))
hl.bind(mod .. " + G",    hl.dsp.group.toggle())

hl.bind(mod .. " + L", function()
    if not hl.get_active_window() then return end
    local tw, th = 1440, 1080
    local area = monitor_work_area()
    hl.dispatch(hl.dsp.window.float({ action = "set" }))
    if area and area.w > 50 and area.h > 50 then
        local s = math.min(1, area.w / tw, area.h / th)
        local w = math.max(200, math.floor(tw * s))
        local h = math.max(200, math.floor(th * s))
        if w / h > tw / th then
            w = math.max(200, math.floor(h * tw / th))
        else
            h = math.max(200, math.floor(w * th / tw))
        end
        place_floating(area.x + (area.w - w) / 2, area.y + (area.h - h) / 2, w, h)
    else
        hl.dispatch(hl.dsp.window.resize({ x = tw, y = th, relative = false }))
        hl.dispatch(hl.dsp.window.center())
    end
    workspace_float.schedule()
end, { description = "Float 1440x1080, fitted to work area" })

hl.bind(mod .. " + CTRL + left",  hl.dsp.focus({ workspace = "m-1" }))
hl.bind(mod .. " + CTRL + right", hl.dsp.focus({ workspace = "m+1" }))
hl.bind(mod .. " + CTRL + down", hl.dsp.exec_cmd(scripts .. "/desktop-mode.sh down"), { description = "Show desktop" })
hl.bind(mod .. " + CTRL + up", hl.dsp.exec_cmd(scripts .. "/desktop-mode.sh up"), { description = "Restore desktop / Mission Control" })

local desktop_hidden_state = (os.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/tirbofish-desktop-mode/windows.json"
local function hidden_window_addresses()
    local f = io.open(desktop_hidden_state, "r")
    if not f then return nil end
    local raw = f:read("*a") or ""
    f:close()
    local addrs = {}
    for addr in raw:gmatch('"address"%s*:%s*"([^"]+)"') do
        addrs[addr] = true
    end
    return next(addrs) and addrs or nil
end
local function window_contains(win, px, py)
    if not win then return false end
    local at, size = win.at or {}, win.size or {}
    local x = at.x or at[1] or 0
    local y = at.y or at[2] or 0
    local w = size.x or size.width or size[1] or 0
    local h = size.y or size.height or size[2] or 0
    return px >= x and py >= y and px < x + w and py < y + h
end
hl.bind("mouse:272", function()
    local addrs = hidden_window_addresses()
    if not addrs then return end
    local pos = hl.get_cursor_pos()
    if not pos then return end
    local px, py = pos.x or pos[1], pos.y or pos[2]
    if not px or not py then return end
    for _, win in ipairs(hl.get_windows({ mapped = true }) or {}) do
        local addr = win.address and tostring(win.address)
        if addr and addrs[addr] and window_contains(win, px, py) then
            hl.exec_cmd(scripts .. "/desktop-mode.sh hide")
            return
        end
    end
end, { non_consuming = true, description = "Restore desktop from peeked window" })

hl.bind(mod .. " + " .. alt .. " + F4", hl.dsp.exec_cmd("hyprctl dispatch 'hl.dsp.exit()'"))
hl.bind(alt .. " + F4", hl.dsp.exec_cmd("hyprctl layers | grep -q power-menu || quickshell -p ~/.config/quickshell/utils/PowerMenu.qml"))

hl.bind(alt .. " + TAB",         hl.dsp.exec_cmd(snappy_switcher .. " next --workspace --mod alt"), { description = "Snappy Switcher" })
hl.bind(alt .. " + SHIFT + TAB", hl.dsp.exec_cmd(snappy_switcher .. " prev --workspace --mod alt"), { description = "Snappy Switcher (previous)" })
hl.bind(alt .. " + CTRL + TAB", hl.dsp.exec_cmd(snappy_switcher .. " next --mod alt"), { description = "Snappy Switcher (all displays)" })
hl.bind(alt .. " + CTRL + SHIFT + TAB", hl.dsp.exec_cmd(snappy_switcher .. " prev --mod alt"), { description = "Snappy Switcher (all displays, previous)" })

-- Focused floating windows must be explicitly raised; harmless for tiled ones.
hl.on("window.active", function()
    hl.dispatch(hl.dsp.window.bring_to_top())
end)

hl.bind(mod .. " + TAB", hl.dsp.exec_cmd(scripts .. "/desktop-mode.sh mission-toggle"), { description = "Mission Control" })

hl.bind(mod .. " + left",  hl.dsp.exec_cmd(hyprfloat .. " dynamicbind SUPER_LEFT"),  { description = "Snap left / focus left" })
hl.bind(mod .. " + right", hl.dsp.exec_cmd(hyprfloat .. " dynamicbind SUPER_RIGHT"), { description = "Snap right / focus right" })
hl.bind(mod .. " + up",    hl.dsp.exec_cmd(hyprfloat .. " dynamicbind SUPER_UP"),    { description = "Snap top / focus up" })
hl.bind(mod .. " + down",  hl.dsp.exec_cmd(hyprfloat .. " dynamicbind SUPER_DOWN"),  { description = "Snap bottom / focus down" })

hl.bind(mod .. " + CTRL + SHIFT + left",  hl.dsp.window.swap({ direction = "l" }), { description = "Swap window left" })
hl.bind(mod .. " + CTRL + SHIFT + right", hl.dsp.window.swap({ direction = "r" }), { description = "Swap window right" })
hl.bind(mod .. " + CTRL + SHIFT + up",    hl.dsp.window.swap({ direction = "u" }), { description = "Swap window up" })
hl.bind(mod .. " + CTRL + SHIFT + down",  hl.dsp.window.swap({ direction = "d" }), { description = "Swap window down" })

-- Nudge the focused window's size; hold the keys for continuous resizing.
hl.bind(mod .. " + " .. alt .. " + left",  hl.dsp.window.resize({ x = -40, y = 0, relative = true }), { repeating = true })
hl.bind(mod .. " + " .. alt .. " + right", hl.dsp.window.resize({ x = 40, y = 0, relative = true }),  { repeating = true })
hl.bind(mod .. " + " .. alt .. " + up",    hl.dsp.window.resize({ x = 0, y = 40, relative = true }),  { repeating = true })
hl.bind(mod .. " + " .. alt .. " + down",  hl.dsp.window.resize({ x = 0, y = -40, relative = true }), { repeating = true })

hl.bind(mod .. " + H",         hl.dsp.workspace.toggle_special("magic"))
hl.bind(mod .. " + SHIFT + S", hl.dsp.exec_cmd(scripts .. "/screenshot.sh s"))

hl.bind(mod .. " + mouse_down", hl.dsp.focus({ workspace = "m+1" }))
hl.bind(mod .. " + mouse_up",   hl.dsp.focus({ workspace = "m-1" }))

hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd(scripts .. "/brightnesscontrol.sh d"))
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd(scripts .. "/brightnesscontrol.sh i"))
hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd(scripts .. "/audiocontrol.sh i"))
hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd(scripts .. "/audiocontrol.sh d"))
hl.bind("XF86AudioMute",         hl.dsp.exec_cmd(scripts .. "/audiocontrol.sh m"))
hl.bind("XF86AudioPlay",         hl.dsp.exec_cmd(scripts .. "/mediacontrol.sh"))
hl.bind("XF86AudioPause",        hl.dsp.exec_cmd(scripts .. "/mediacontrol.sh"))
hl.bind("XF86AudioNext",         hl.dsp.exec_cmd(scripts .. "/mediacontrol.sh next"))
hl.bind("XF86AudioPrev",         hl.dsp.exec_cmd(scripts .. "/mediacontrol.sh prev"))
hl.bind("XF86PowerOff",          hl.dsp.exec_cmd(scripts .. "/lock.sh"), { locked = true, description = "Lock on power button" })

hl.bind("Print",                    hl.dsp.exec_cmd(scripts .. "/screenshot.sh s"))
hl.bind(mod .. " + Print",         hl.dsp.exec_cmd(scripts .. "/screenshot.sh p"))
hl.bind(mod .. " + SHIFT + Print", hl.dsp.exec_cmd(scripts .. "/screenshot.sh sf"))
hl.bind(mod .. " + O",             hl.dsp.exec_cmd(scripts .. "/screenshot.sh m"))

-- =========================================================================
-- Workspace Binds
-- =========================================================================
for i = 1, 10 do
    hl.bind(mod .. " + " .. tostring(i % 10), function()
        local mon = hl.get_active_monitor()
        local slots = mon and workspace_slots[mon.name]
        if slots and slots[i] then hl.dispatch(hl.dsp.focus({ workspace = slots[i] })) end
    end)
    hl.bind(mod .. " + SHIFT + " .. tostring(i % 10), function()
        local mon = hl.get_active_monitor()
        local slots = mon and workspace_slots[mon.name]
        if slots and slots[i] then hl.dispatch(hl.dsp.window.move({ workspace = slots[i] })) end
    end)
end

-- =========================================================================
-- Mouse Binds
-- =========================================================================
hl.bind("ALT + mouse:272",   hl.dsp.window.drag(),   { mouse = true })
hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- =========================================================================
-- Lid Switch
-- =========================================================================
-- switch:off = lid OPEN, switch:on = lid CLOSED
-- No monitor block here. The installer regenerates every
-- monitor block in this file and would take these two with it.
-- "preferred,auto" re-reads the panel instead of repeating the mode above, so
-- this keeps working whatever the monitor section ends up saying.
hl.bind("switch:off:Lid Switch", function()
    set_touchscreen_enabled(true)
    hl.exec_cmd(scripts .. "/pypr-apply-monitors.py")
    set_wallpapers_delayed()
    hl.exec_cmd(scripts .. "/lock.sh --lid-open")
end, { locked = true })

hl.bind("switch:on:Lid Switch", function()
    set_touchscreen_enabled(false)
    hl.monitor({ output = "eDP-1", disabled = true })
end, { locked = true })

-- =========================================================================
-- Window Rules
-- =========================================================================
hl.window_rule({ match = { class = "^kitty$" }, size = "950 550", center = true, rounding = 8, opacity = "0.9 0.9" })
hl.window_rule({
    match = { title = "^(HyprEmoji)$" },
    float = true, center = true, size = "440 560", rounding = 12,
    animation = "popin", dim_around = true, opacity = "0.96 0.96",
    border_size = 1, border_color = palette.accent .. " " .. palette.background,
})
hl.window_rule({
    match = { class = "^(hypremoji|HyprEmoji)$" },
    float = true, center = true, size = "440 560", rounding = 12,
    animation = "popin", dim_around = true, opacity = "0.96 0.96",
    border_size = 1, border_color = palette.accent .. " " .. palette.background,
})
hl.window_rule({ match = { class = "^org.pwmt.zathura$" }, float = true, size = "750 1000" })
hl.window_rule({ match = { class = "^blueman-manager$" }, float = true, size = "500 300", move = "1165 777", rounding = 10, opacity = "0.90 0.90", border_size = 1, border_color = palette.accent .. " " .. palette.background, animation = "popin", dim_around = true })
hl.window_rule({ match = { class = "^nm-connection-editor$" }, float = true, size = "500 600", center = true, rounding = 10, opacity = "0.95 0.95", border_color = palette.accent })
hl.window_rule({ match = { class = "^com.snes.evercal$" }, float = true, size = "1000 650", center = true, border_size = 1, rounding = 8 })
hl.window_rule({ match = { class = "^org.gnome.Lollypop$" }, float = true, size = "900 600" })
hl.window_rule({ match = { class = "^org.kde.plasma-systemmonitor$" }, float = true, size = "1000 700", rounding = 14 })
hl.window_rule({ match = { class = "^lens$" }, float = true, center = true, size = "1000 700", rounding = 10, border_color = palette.secondary }) --hl.window_rule({ match = { class = "^thunar$" }, float = true, size = "900 600", center = true })
hl.window_rule({ match = { class = "^xdm-app$" }, float = true, size = "700 400", rounding = 10, opacity = "0.8 0.8", center = true })
hl.window_rule({ match = { class = "^org.gnome.FileRoller$" }, float = true, size = "500 350", center = true, rounding = 10, border_color = palette.accent })
hl.window_rule({ match = { class = "^com.snes.nowplaying$" }, float = true, pin = true, border_size = 1, border_color = palette.background, animation = "slide", move = "1425 16", opacity = "0.9 0.9" })
hl.window_rule({
    match = { title = "^Settings$" },
    float = true, center = true, size = "960 680", rounding = 12,
    animation = "popin", dim_around = true, opacity = "0.96 0.96",
    border_size = 1, border_color = palette.accent .. " " .. palette.background,
})
hl.window_rule({ match = { class = "^xdg-desktop-portal-gtk$" }, float = true, center = true, size = "700 400" })

local portals = { "^(xdg-desktop-portal-gtk|xdg-desktop-portal-kde|xdg-desktop-portal-hyprland|org.freedesktop.impl.portal.desktop.gtk|org.freedesktop.impl.portal.desktop.kde)$", "^(org.kde.polkit-kde-authentication-agent-1|polkit-gnome-authentication-agent-1|lxqt-policykit-agent|mate-polkit)$", "^(pinentry|pinentry-gtk-2|pinentry-gnome3|gcr-prompter)$", "^(ssh-askpass|sshaskpass)$" }
for _, p in ipairs(portals) do hl.window_rule({ match = { class = p }, tag = "portal-ui" }) end
hl.window_rule({ match = { tag = "portal-ui" }, float = true, center = true, rounding = 10, size = "1100 750", dim_around = true, opacity = "0.95 0.95" })

local dialog_titles = { "^(Open File)(.*)$", "^(Select a File)(.*)$", "^(Choose wallpaper)(.*)$", "^(Open Folder)(.*)$", "^(Save As)(.*)$", "^(Library)(.*)$", "^(File Upload)(.*)$", "^(Extract archive)$", "^(Extract)(.*)$", "^(Extract to)$", "^(Confirm to replace files)$", "^(Rename)(.*)$", "^(Create New Folder)$", "^(Properties)$", "^(File Operation Progress)(.*)$" }
for _, t in ipairs(dialog_titles) do hl.window_rule({ match = { title = t }, float = true, center = true }) end

local dim_dialogs = { "^(Open File)(.*)$", "^(Save As)(.*)$", "^(Confirm to replace files)$" }
for _, t in ipairs(dim_dialogs) do hl.window_rule({ match = { title = t }, dim_around = true }) end

hl.window_rule({ match = { title = "^(Open File)(.*)$" }, size = "900 600" })
hl.window_rule({ match = { title = "^(Save As)(.*)$" }, size = "900 600" })
hl.window_rule({ match = { title = "^(File Upload)(.*)$" }, size = "900 600" })
hl.window_rule({ match = { title = "^(Confirm to replace files)$" }, size = "500 300" })
hl.window_rule({ match = { title = "^(File Operation Progress)(.*)$" }, size = "500 300" })
hl.window_rule({ match = { title = "^(Rename)(.*)$" }, size = "450 200" })
hl.window_rule({ match = { title = "^(Create New Folder)$" }, size = "450 200" })
hl.window_rule({ match = { title = "^(Properties)$" }, size = "500 600" })
hl.window_rule({ match = { modal = true }, float = true, center = true, rounding = 10 })
hl.window_rule({ match = { title = "^hyprfloat:.*$" }, float = true, no_anim = true })
hl.window_rule({ match = { title = "^hyprfloat:alttab$" }, pin = true, size = "0 0" })
hl.window_rule({
    name = "xpet",
    match = { class = "^xpet$" },
    float = true,
    pin = true,
    rounding = 0,
    border_size = 0,
    no_anim = true,
    no_blur = true,
    no_shadow = true,
    no_dim = true,
    no_initial_focus = true,
    no_follow_mouse = true,
    opacity = "1.0 1.0",
})

-- HyprMod rewrites hyprland-gui.lua with monitor pins from the current
-- plug. Swallow every hl.monitor from it so a catch-all preferred or a
-- named DP-* cannot 0x0 the next hotplug.
do
    local apply = hl.monitor
    hl.monitor = function() end
    local ok, err = pcall(require, "hyprland-gui")
    hl.monitor = apply
    if not ok then
        io.stderr:write("hyprland-gui.lua: " .. tostring(err) .. "\n")
    end
end
