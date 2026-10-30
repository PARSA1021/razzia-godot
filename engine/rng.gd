extends RefCounted
## Deterministic RNG, bit-exact with the JS reference (mulberry32 on a 32-bit state).
## GDScript ints are 64-bit, so every 32-bit JS operation (|0, >>>, Math.imul) is emulated here.
## Never use randi()/randf() in the engine (docs/04 §18, docs/07 §16).


static func u32(x: int) -> int:
	return x & 0xFFFFFFFF


## JS `x | 0`: wrap to a signed 32-bit integer.
static func to_i32(x: int) -> int:
	var y := x & 0xFFFFFFFF
	return y - 0x100000000 if y >= 0x80000000 else y


## JS Math.imul without 64-bit overflow (16-bit limb multiplication).
static func imul(a: int, b: int) -> int:
	var al := a & 0xFFFF
	var ah := (a >> 16) & 0xFFFF
	var bl := b & 0xFFFF
	var bh := (b >> 16) & 0xFFFF
	return to_i32(al * bl + ((((ah * bl) + (al * bh)) & 0xFFFF) << 16))


## Advances s["rngState"] and returns a float in [0, 1). `s` is any Dictionary holding "rngState".
static func rng_float(s: Dictionary) -> float:
	var st := to_i32(int(s["rngState"]) + 0x6D2B79F5)
	s["rngState"] = st
	var t := st
	t = imul(to_i32(t ^ (u32(t) >> 15)), 1 | t)
	t = to_i32(t + imul(to_i32(t ^ (u32(t) >> 7)), 61 | t)) ^ t
	return float(u32(t ^ (u32(t) >> 14))) / 4294967296.0


static func rng_int(s: Dictionary, lo: int, hi: int) -> int:
	return lo + int(floor(rng_float(s) * float(hi - lo + 1)))


## In-place Fisher-Yates, same index order as the JS version. Returns the same array.
static func shuffle(s: Dictionary, arr: Array) -> Array:
	var i := arr.size() - 1
	while i > 0:
		var j := rng_int(s, 0, i)
		var t = arr[i]
		arr[i] = arr[j]
		arr[j] = t
		i -= 1
	return arr
