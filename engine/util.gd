extends RefCounted
## Small helpers shared by engine, tests and save/load.


static func clone(x):
	if x is Dictionary or x is Array:
		return x.duplicate(true)
	return x


## JSON.parse_string returns every number as float. Turn whole floats back into ints (money, seeds, ids...).
static func normalize(v):
	if v is Dictionary:
		var out := {}
		for k in v:
			out[k] = normalize(v[k])
		return out
	if v is Array:
		var out_a := []
		for x in v:
			out_a.append(normalize(x))
		return out_a
	if v is float and v == floor(v) and absf(v) < 9007199254740992.0:
		return int(v)
	return v


## Order-independent text form (sorted keys, ints as ints). Used to compare events with the golden logs.
static func canonical(v) -> String:
	return JSON.stringify(normalize(v), "", true)
