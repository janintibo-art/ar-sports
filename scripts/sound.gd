extends Node
## Gestion des sons (autoload « Sound ») : bruitages spatialisés, musique, ambiance.

const SFX := {
	"pin_hit_1": preload("res://sounds/pin_hit_1.ogg"),
	"pin_hit_2": preload("res://sounds/pin_hit_2.ogg"),
	"pin_hit_3": preload("res://sounds/pin_hit_3.ogg"),
	"strike_crash": preload("res://sounds/strike_crash.ogg"),
	"ball_thud": preload("res://sounds/ball_thud.ogg"),
	"whoosh": preload("res://sounds/whoosh.ogg"),
	"ui_click": preload("res://sounds/ui_click.ogg"),
	"grab": preload("res://sounds/grab.ogg"),
	"next_player": preload("res://sounds/next_player.ogg"),
	"cheer_big": preload("res://sounds/cheer_big.ogg"),
	"cheer_small": preload("res://sounds/cheer_small.ogg"),
	"gutter": preload("res://sounds/gutter.ogg"),
	"burp": preload("res://sounds/burp.ogg"),
	"clink": preload("res://sounds/clink.ogg"),
	"pour": preload("res://sounds/pour.ogg"),
	"pinsetter": preload("res://sounds/pinsetter.ogg"),
	"dart_thud": preload("res://sounds/dart_thud.ogg"),
	"bull_ding": preload("res://sounds/bull_ding.ogg"),
	"pp_paddle": preload("res://sounds/pp_paddle.ogg"),
	"pp_table": preload("res://sounds/pp_table.ogg"),
	"pp_net": preload("res://sounds/pp_net.ogg"),
	"pet_clack": preload("res://sounds/pet_clack.ogg"),
	"pet_land": preload("res://sounds/pet_land.ogg"),
}

const LOOPS := {
	"roll_loop": preload("res://sounds/roll_loop.ogg"),
	"glug_loop": preload("res://sounds/glug_loop.ogg"),
	"ambience_loop": preload("res://sounds/ambience_loop.ogg"),
	"music_lounge": preload("res://sounds/music_lounge.ogg"),
}

const POOL_SIZE := 14

var music_enabled := true:
	set(value):
		music_enabled = value
		_apply_music()

var _pool: Array[AudioStreamPlayer3D] = []
var _music: AudioStreamPlayer
var _ambience: AudioStreamPlayer
var _music_wanted := false
var _next := 0


func _ready() -> void:
	for stream in LOOPS.values():
		(stream as AudioStreamOggVorbis).loop = true
	for i in POOL_SIZE:
		var p := AudioStreamPlayer3D.new()
		p.unit_size = 3.0
		p.max_db = 3.0
		p.attenuation_filter_cutoff_hz = 12000.0
		p.panning_strength = 1.0
		add_child(p)
		_pool.append(p)
	_music = AudioStreamPlayer.new()
	_music.stream = LOOPS["music_lounge"]
	_music.volume_db = -13.0
	add_child(_music)
	_ambience = AudioStreamPlayer.new()
	_ambience.stream = LOOPS["ambience_loop"]
	_ambience.volume_db = -20.0
	add_child(_ambience)


## Joue un bruitage à une position dans l'espace (le son vient de là).
func play_at(sound: String, pos: Vector3, volume_db: float = 0.0, pitch_jitter: float = 0.05) -> void:
	if not SFX.has(sound):
		push_warning("Son inconnu : " + sound)
		return
	var p := _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stop()
	p.stream = SFX[sound]
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.global_position = pos
	p.play()


## Joue un bruitage sans position (interface, annonces).
func play(sound: String, volume_db: float = 0.0) -> void:
	if not SFX.has(sound):
		return
	var p := AudioStreamPlayer.new()
	p.stream = SFX[sound]
	p.volume_db = volume_db
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


## Crée un lecteur en boucle attaché à un noeud (roulement de boule, glouglou…).
func make_loop_player(sound: String, parent: Node3D, volume_db: float = 0.0) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = LOOPS[sound]
	p.volume_db = volume_db
	p.unit_size = 3.0
	parent.add_child(p)
	return p


func start_music() -> void:
	_music_wanted = true
	_apply_music()


func stop_music() -> void:
	_music_wanted = false
	_apply_music()


func _apply_music() -> void:
	if not is_inside_tree():
		return
	var on := _music_wanted and music_enabled
	if on and not _music.playing:
		_music.play()
	elif not on and _music.playing:
		_music.stop()
	if _music_wanted and not _ambience.playing:
		_ambience.play()
	elif not _music_wanted and _ambience.playing:
		_ambience.stop()
