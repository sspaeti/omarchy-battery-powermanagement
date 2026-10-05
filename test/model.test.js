const assert = require("assert")
const M = require("../Model.js")

const all = M.chargeProfiles("high_capacity balanced stationary")
assert.strictEqual(all.length, 3)
assert.strictEqual(all[2].id, "stationary")
assert.strictEqual(all[2].label, "80%")
assert.strictEqual(M.chargeProfiles("").length, 0, "no sysfs -> no profiles")
assert.strictEqual(M.chargeProfiles("balanced").length, 1, "subset")
assert.strictEqual(M.chargeProfileLabel("stationary"), "80%")
assert.strictEqual(M.chargeProfileLabel(""), "")

const kv = M.parseKeyValue("profile\tstationary\ndisplay\t80\nhealth\t60%\n")
assert.deepStrictEqual(kv, { profile: "stationary", display: "80", health: "60%" })

console.log("ok")
