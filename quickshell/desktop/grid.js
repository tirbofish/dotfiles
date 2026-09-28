.pragma library
// Desktop widget grid. The screen is divided edge to edge into whole cells
// (~pitch px each, stretched to fit exactly); `gap` px separate neighbours.
var pitch = 112   // nominal cell + gap; size classes are judged against this
var gap = 12

function layout(screenW, screenH) {
    var cols = Math.max(1, Math.round((screenW + gap) / pitch))
    var rows = Math.max(1, Math.round((screenH + gap) / pitch))
    return { cols: cols, rows: rows, px: (screenW + gap) / cols, py: (screenH + gap) / rows }
}

function cells(px) { return Math.max(1, Math.round((px + gap) / pitch)) }
function span(n) { return n * pitch - gap }

function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)) }

// Cell rect in pixels (flush with the screen edges on the outer cells).
function rect(col, row, cw, ch, g) {
    var x = Math.round(col * g.px), y = Math.round(row * g.py)
    return { x: x, y: y, w: Math.round((col + cw) * g.px - gap) - x, h: Math.round((row + ch) * g.py - gap) - y }
}

function snap(x, y, w, h, screenW, screenH) {
    var g = layout(screenW, screenH)
    var cw = clamp(Math.round((w + gap) / g.px), 1, g.cols)
    var ch = clamp(Math.round((h + gap) / g.py), 1, g.rows)
    var col = clamp(Math.round(x / g.px), 0, g.cols - cw)
    var row = clamp(Math.round(y / g.py), 0, g.rows - ch)
    var r = rect(col, row, cw, ch, g)
    r.cols = cw
    r.rows = ch
    return r
}
