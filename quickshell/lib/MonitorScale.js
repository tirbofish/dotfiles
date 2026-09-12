function nearest(mode, requested) {
    var size = /^(\d+)x(\d+)/.exec(mode)
    if (!size || !isFinite(requested) || requested <= 0) return 1
    var best = 1, distance = Infinity
    for (var tick = 30; tick <= 960; tick++) {
        var scale = tick / 120
        var w = Number(size[1]) / scale, h = Number(size[2]) / scale
        if (Math.abs(w - Math.round(w)) > 0.0001 || Math.abs(h - Math.round(h)) > 0.0001) continue
        if (Math.abs(scale - requested) < distance) {
            best = scale
            distance = Math.abs(scale - requested)
        }
    }
    return best
}

function choices(mode) {
    return [1, 1.25, 1.33, 1.5, 2].map(function(s) { return nearest(mode, s) })
        .filter(function(s, i, values) { return values.indexOf(s) === i })
}
