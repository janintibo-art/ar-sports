class_name DartRules
extends RefCounted
## Règles pures (testables sans 3D) : conseil de sortie pour le 301/501.

const IMPOSSIBLE := [159, 162, 163, 165, 166, 168, 169]

static var _all: Array = []
static var _cache := {}


## Tous les tirs possibles, du plus fort au plus faible : {label, value, double}.
static func all_shots() -> Array:
	if not _all.is_empty():
		return _all
	var shots: Array = [{"label": "BULL", "value": 50, "double": true}, {"label": "25", "value": 25, "double": false}]
	for n in range(1, 21):
		shots.append({"label": "T%d" % n, "value": n * 3, "double": false})
		shots.append({"label": "D%d" % n, "value": n * 2, "double": true})
		shots.append({"label": str(n), "value": n, "double": false})
	shots.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["value"] > b["value"])
	_all = shots
	return _all


## Meilleure façon de finir `remaining` points avec au plus `darts` fléchettes.
## Renvoie un tableau d'étiquettes (vide si impossible).
static func checkout(remaining: int, darts: int, double_out: bool) -> Array:
	if remaining < 2 or darts < 1 or remaining > 170 or (double_out and remaining in IMPOSSIBLE):
		return []
	var key := "%d_%d_%s" % [remaining, darts, double_out]
	if _cache.has(key):
		return _cache[key]
	var result := _search(remaining, darts, double_out)
	_cache[key] = result
	return result


static func _search(remaining: int, darts: int, double_out: bool) -> Array:
	var shots := all_shots()
	# 1 fléchette
	for s in shots:
		if s["value"] == remaining and (s["double"] or not double_out):
			return [s["label"]]
	if darts < 2:
		return []
	for a in shots:
		var left: int = remaining - int(a["value"])
		if left < 2:
			continue
		for b in shots:
			if b["value"] == left and (b["double"] or not double_out):
				return [a["label"], b["label"]]
	if darts < 3:
		return []
	for a in shots:
		var left1: int = remaining - int(a["value"])
		if left1 < 2:
			continue
		for b in shots:
			var left2: int = left1 - int(b["value"])
			if left2 < 2:
				continue
			for c in shots:
				if c["value"] == left2 and (c["double"] or not double_out):
					return [a["label"], b["label"], c["label"]]
	return []
