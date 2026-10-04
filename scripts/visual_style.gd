class_name VisualStyle
extends RefCounted
## Préférence graphique globale, appliquée aux scènes ouvertes ensuite.
const SAVE_PATH := "user://visual_style.cfg"
static var detailed := true

static func load_preferences() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		detailed = bool(cfg.get_value("graphics", "detailed", true))

static func set_detailed(value: bool, persist: bool = true) -> Error:
	detailed = value
	if not persist:
		return OK
	var cfg := ConfigFile.new()
	cfg.set_value("graphics", "detailed", detailed)
	return cfg.save(SAVE_PATH)
