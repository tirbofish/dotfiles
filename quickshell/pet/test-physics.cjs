// Run: node ~/.config/quickshell/pet/test-physics.cjs
const assert = require('node:assert/strict');
const fs = require('node:fs'), vm = require('node:vm');
const P = {}; vm.runInNewContext(fs.readFileSync(__dirname + '/physics.js', 'utf8').replace('.pragma library', ''), P);

const mon = { id: 0, x: 1724, y: 723, width: 1440, workspace: 4, top: 40 };
const win = (address, x, y, w, extra = {}) => ({ address, at: [1724 + x, 723 + y], size: [w, 300], mapped: true, hidden: false, fullscreen: 0, monitor: 0, workspace: { id: 4 }, ...extra });
const plats = P.platforms([
    win('a', 100, 500, 400), win('maxed', 4, 44, 1432), win('other-ws', 0, 300, 200, { workspace: { id: 2 } }),
    win('full', 0, 300, 200, { fullscreen: 2 }), win('b', 700, 300, 300)], { ...mon, top: 0 }, 960, 40);
assert.equal(plats.map(p => p.id).join(), 'floor,a,maxed,b', 'window tops on the active workspace, tiled ones under the bar included');

// Falling onto a window top, not through it.
assert.equal(P.landing(495, 505, 300, plats, 20).id, 'a');
assert.equal(P.landing(505, 515, 300, plats, 20), null, 'already below it');
assert.equal(P.landing(900, 970, 50, plats, 20).id, 'floor');
assert.equal(P.support(300, 500, plats, 20).id, 'a');
assert.equal(P.support(560, 500, plats, 20), null, 'walked off the edge');

// A computed hop lands where it aimed, both up and down.
for (const [x, y, tx, ty, on] of [[50, 960, 850, 300, 'b'], [850, 300, 300, 500, 'a'], [300, 500, 1200, 960, 'floor']]) {
    const v = P.jumpTo(x, y, tx, ty, 60), r = P.fly(x, y, v.vx, v.vy, plats, 20, 1 / 240);
    assert.ok(r && r.on === on && Math.abs(r.x - tx) < 12, `hop ${x},${y} → ${tx},${ty} landed ${JSON.stringify(r)}`);
}
console.log('pet physics: ok');
