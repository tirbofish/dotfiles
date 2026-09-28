.pragma library
// Turn one session length into Pomodoro blocks: 25 min focus, 5 min break,
// a 15 min break after every 4th focus block. Leftover minutes too short for
// another focus block are folded into the last one, so the plan sums to total.
var focus = 25
var shortBreak = 5
var longBreak = 15
var every = 4

function plan(totalMin) {
    var left = Math.max(5, Math.round(totalMin)), out = [], n = 0
    while (left > 0) {
        var work = Math.min(focus, left)
        out.push({ phase: "work", min: work })
        left -= work
        n++
        if (left <= 0) break
        var isLong = n % every === 0
        var brk = isLong ? longBreak : shortBreak
        if (left < brk + 10) { out[out.length - 1].min += left; break }
        out.push({ phase: isLong ? "long" : "short", min: brk })
        left -= brk
    }
    return out
}
