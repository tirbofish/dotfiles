.pragma library
// Pet physics in screen pixels (origin top-left of the pet's monitor, y down).
// A platform is a horizontal edge the pet can stand on: the floor, or the top
// of a window.
var G = 2400          // gravity, px/s²

// Hyprland clients → standable window tops on this monitor's active workspace.
// Tops too close to the reserved top edge (bar) leave no headroom and are skipped.
function platforms(clients, mon, floorY, headroom) {
    var out = [{ id: "floor", x: 0, y: floorY, w: mon.width }]
    for (var i = 0; i < clients.length; i++) {
        var c = clients[i]
        if (!c || !c.mapped || c.hidden || c.fullscreen) continue
        if (c.monitor !== mon.id || !c.workspace || c.workspace.id !== mon.workspace) continue
        var y = c.at[1] - mon.y
        if (y - headroom < mon.top || y >= floorY - 4) continue
        out.push({ id: c.address, x: c.at[0] - mon.x, y: y, w: c.size[0] })
    }
    return out
}

function over(p, x, halfW) { return x + halfW * 0.4 >= p.x && x - halfW * 0.4 <= p.x + p.w }

// Platform whose top the feet passed through this step (falling only).
function landing(prevY, y, x, plats, halfW) {
    var best = null
    for (var i = 0; i < plats.length; i++) {
        var p = plats[i]
        if (prevY <= p.y + 0.5 && y >= p.y && over(p, x, halfW) && (!best || p.y < best.y)) best = p
    }
    return best
}

// What the pet is standing on right now, if anything.
function support(x, y, plats, halfW) {
    for (var i = 0; i < plats.length; i++)
        if (Math.abs(plats[i].y - y) < 1.5 && over(plats[i], x, halfW)) return plats[i]
    return null
}

// Launch velocity for a hop from (x, y) that peaks `arc` px above the higher
// of the two points and comes down on (tx, ty).
function jumpTo(x, y, tx, ty, arc) {
    var apex = Math.min(y, ty) - (arc || 60)
    var up = Math.sqrt(2 * (y - apex) / G), down = Math.sqrt(2 * (ty - apex) / G)
    return { vx: (tx - x) / (up + down), vy: -G * up }
}

// Simulate one ballistic flight; used by the test (and handy to reason about).
function fly(x, y, vx, vy, plats, halfW, dt) {
    for (var t = 0; t < 5; t += dt) {
        var py = y
        vy += G * dt; x += vx * dt; y += vy * dt
        var p = landing(py, y, x, plats, halfW)
        if (p && vy > 0) return { x: x, y: p.y, on: p.id }
    }
    return null
}
