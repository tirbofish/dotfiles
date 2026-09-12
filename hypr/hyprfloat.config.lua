-- hyprfloat (https://github.com/yz778/hyprfloat)
-- Merged over the packaged default at ~/.local/share/hyprfloat/config/default.conf.lua

local scripts = (os.getenv("HOME") or ".") .. "/.config/hypr/scripts"
local function golden(direction)
    return string.format(
        'dispatch hl.dsp.exec_cmd("%s/golden-focus.sh %s")',
        scripts,
        direction
    )
end

return {
    dynamic_bind = {
        overview = {
            SUPER_LEFT  = "hyprfloat:movefocus l",
            SUPER_RIGHT = "hyprfloat:movefocus r",
            SUPER_UP    = "hyprfloat:movefocus u",
            SUPER_DOWN  = "hyprfloat:movefocus d",
        },
        tiling = {
            SUPER_LEFT  = golden("left"),
            SUPER_RIGHT = golden("right"),
            SUPER_UP    = golden("up"),
            SUPER_DOWN  = golden("down"),
        },
        floating = {
            SUPER_LEFT  = "hyprfloat:snap 0.0 0.5 0.0 1.0",
            SUPER_RIGHT = "hyprfloat:snap 0.5 1.0 0.0 1.0",
            SUPER_UP    = "hyprfloat:snap 0.0 1.0 0.0 0.5",
            SUPER_DOWN  = "hyprfloat:snap 0.0 1.0 0.5 1.0",
        },
    },
}
