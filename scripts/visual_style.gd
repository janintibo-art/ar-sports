class_name VisualStyle
extends RefCounted
## Préférences communes de graphisme et confort.
const SAVE_PATH := "user://visual_style.cfg"
static var detailed := true
static var ui_scale := 1.0
static var distance_factor := 1.0

static func load_preferences() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		detailed = bool(cfg.get_value("graphics", "detailed", true))
		ui_scale = clampf(float(cfg.get_value("comfort", "scale", 1.0)), 1.0, 1.3)
		distance_factor = clampf(float(cfg.get_value("comfort", "distance", 1.0)), 0.85, 1.25)

static func _save() -> Error:
	var cfg := ConfigFile.new()
	cfg.set_value("graphics", "detailed", detailed)
	cfg.set_value("comfort", "scale", ui_scale)
	cfg.set_value("comfort", "distance", distance_factor)
	return cfg.save(SAVE_PATH)

static func set_detailed(value: bool, persist: bool = true) -> Error:
	detailed = value
	return _save() if persist else OK

static func set_comfort(size: float, distance: float, persist: bool = true) -> Error:
	ui_scale = clampf(size, 1.0, 1.3)
	distance_factor = clampf(distance, 0.85, 1.25)
	return _save() if persist else OK
