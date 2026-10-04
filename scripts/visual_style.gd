class_name VisualStyle
extends RefCounted
## Préférences communes de graphisme et confort.
const SAVE_PATH := "user://visual_style.cfg"
static var detailed := true
static var ui_scale := 1.0
static var distance_factor := 1.0
static var throw_gain := 1.0
static var cue_gain := 1.0
static var rod_gain := 1.0
static var master_volume := 1.0
static var music_volume := 1.0
static var effects_volume := 1.0

static func load_preferences() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		detailed = bool(cfg.get_value("graphics", "detailed", true))
		ui_scale = clampf(float(cfg.get_value("comfort", "scale", 1.0)), 1.0, 1.3)
		distance_factor = clampf(float(cfg.get_value("comfort", "distance", 1.0)), 0.85, 1.25)

		throw_gain = clampf(float(cfg.get_value("gestures", "throw", 1.0)), 0.8, 1.2)
		cue_gain = clampf(float(cfg.get_value("gestures", "cue", 1.0)), 0.75, 1.25)
		rod_gain = clampf(float(cfg.get_value("gestures", "rod", 1.0)), 0.75, 1.25)

		master_volume = clampf(float(cfg.get_value("audio", "master", 1.0)), 0.0, 1.0)
		music_volume = clampf(float(cfg.get_value("audio", "music", 1.0)), 0.0, 1.0)
		effects_volume = clampf(float(cfg.get_value("audio", "effects", 1.0)), 0.0, 1.0)

static func _save() -> Error:
	var cfg := ConfigFile.new()
	cfg.set_value("graphics", "detailed", detailed)
	cfg.set_value("comfort", "scale", ui_scale)
	cfg.set_value("comfort", "distance", distance_factor)
	cfg.set_value("gestures", "throw", throw_gain)
	cfg.set_value("gestures", "cue", cue_gain)
	cfg.set_value("gestures", "rod", rod_gain)
	cfg.set_value("audio", "master", master_volume)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "effects", effects_volume)
	return cfg.save(SAVE_PATH)

static func set_detailed(value: bool, persist: bool = true) -> Error:
	detailed = value
	return _save() if persist else OK

static func set_comfort(size: float, distance: float, persist: bool = true) -> Error:
	ui_scale = clampf(size, 1.0, 1.3)
	distance_factor = clampf(distance, 0.85, 1.25)
	return _save() if persist else OK

static func set_gestures(throw_value: float, cue_value: float, rod_value: float, persist: bool = true) -> Error:
	throw_gain = clampf(throw_value, 0.8, 1.2)
	cue_gain = clampf(cue_value, 0.75, 1.25)
	rod_gain = clampf(rod_value, 0.75, 1.25)
	return _save() if persist else OK

static func set_audio(master: float, music: float, effects: float, persist: bool = true) -> Error:
	master_volume = clampf(master, 0.0, 1.0)
	music_volume = clampf(music, 0.0, 1.0)
	effects_volume = clampf(effects, 0.0, 1.0)
	return _save() if persist else OK
