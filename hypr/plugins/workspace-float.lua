-- New windows follow the workspace majority: all-float stays float,
-- all-tile stays tiled. A 50/50 split keeps the last decided mode.

local mode = {}
local rules = {}
local gen = 0

local function vote(floating, tiled, prev)
    if floating > tiled then return true end
    if tiled > floating then return false end
    return prev
end

local function countable(win)
    if not win or win.hidden or win.pinned then return false end
    local ws = win.workspace
    if not ws or ws.special or (tonumber(ws.id) or 0) <= 0 then return false end
    local title = win.title or ""
    if title:find("^hyprfloat:") then return false end
    local class = win.class or win.initialClass or ""
    if class == "xpet" then return false end
    return true
end

local function apply(id, want)
    if want then
        if not rules[id] then
            rules[id] = hl.window_rule({
                name = "workspace-follow-float-" .. id,
                match = { workspace = tostring(id) },
                float = true,
            })
        else
            rules[id]:set_enabled(true)
        end
    elseif rules[id] then
        rules[id]:set_enabled(false)
    end
    mode[id] = want and true or false
end

local function sync()
    local counts = {}
    for _, win in ipairs(hl.get_windows() or {}) do
        if countable(win) then
            local id = win.workspace.id
            local c = counts[id]
            if not c then
                c = { f = 0, t = 0 }
                counts[id] = c
            end
            if win.floating then
                c.f = c.f + 1
            else
                c.t = c.t + 1
            end
        end
    end
    for id, c in pairs(counts) do
        local want = vote(c.f, c.t, mode[id])
        if want == nil then want = false end
        if mode[id] ~= want then apply(id, want) end
    end
end

local function schedule(delay)
    if type(delay) ~= "number" then delay = 50 end
    gen = gen + 1
    local g = gen
    hl.timer(function()
        if g == gen then sync() end
    end, { timeout = delay, type = "oneshot" })
end

return {
    vote = vote,
    sync = sync,
    schedule = schedule,
}
