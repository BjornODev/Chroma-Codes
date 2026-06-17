extends Node

# =========================
# AUDIO MANAGER (autoload "AudioManager")
# Modeled on the original AudioLoader that worked in export: SFX are a hardcoded
# dictionary of preloaded streams (no folder scanning, no runtime buses). Music
# is added on top with simple crossfading AudioStreamPlayers.
#
# SFX:   AudioManager.play_sound("Shuffle", 0.0, 1.0, 0.15)
# MUSIC: AudioManager.play_screen_music("Synthwave_1")
# =========================

# --- SOUND EFFECTS ---
# Hardcoded preloads, exactly like the original AudioLoader. Add a line per file.
# Keys are what you pass to play_sound(). Update paths/extensions to match yours.
var sound_library := {
	"peg_snap": preload("res://assets/audio/sfx/PegSnap.wav"),
	"popup": preload("res://assets/audio/sfx/Popup.wav"),
	"damage": preload("res://assets/audio/sfx/Damage.wav"),
	"obscure": preload("res://assets/audio/sfx/Obscure.wav"),
	"select": preload("res://assets/audio/sfx/Select.wav"),
	"win": preload("res://assets/audio/sfx/Win.wav"),
	"lose": preload("res://assets/audio/sfx/Lose.wav"),
	"reveal": preload("res://assets/audio/sfx/Reveal.wav"),
	"goop": preload("res://assets/audio/sfx/Goop.wav"),
	"Shuffle": preload("res://assets/audio/sfx/Shuffle.wav"),
}

# --- MUSIC ---
# Hardcoded preloads of the songs. Add a line per track.
var music_library := {
	"Synthwave_1": preload("res://assets/audio/music/Synthwave_1.ogg"),
	"Synthwave_2": preload("res://assets/audio/music/Synthwave_2.ogg"),
	"Synthwave_3": preload("res://assets/audio/music/Synthwave_3.ogg"),
}

const MUSIC_CROSSFADE := 2.0
const SILENT_DB := -60.0

var _current_song := ""
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _active_music: AudioStreamPlayer        # which of a/b is currently audible
var _music_volume := 0.5                     # 0..1 global music scalar
var _music_fade_tween: Tween


func _ready():
	_music_a = AudioStreamPlayer.new()
	_music_b = AudioStreamPlayer.new()
	add_child(_music_a)
	add_child(_music_b)
	_active_music = _music_a


# =========================
# SOUND EFFECTS
# Same behavior as the old AudioLoader: spawn a one-shot player, free on finish.
# Extra optional pitch / pitch_rand args for variation (used by flying pegs).
# =========================

func play_sound(name: String, db: float = 0.0, pitch: float = 1.0, pitch_rand: float = 0.0):
	if not sound_library.has(name):
		# Try a case-insensitive fallback so "shuffle"/"Shuffle" both work
		var lower = name.to_lower()
		var found = ""
		for k in sound_library.keys():
			if k.to_lower() == lower:
				found = k
				break
		if found == "":
			push_warning("Sound not found: " + name)
			return
		name = found

	var player := AudioStreamPlayer.new()
	player.stream = sound_library[name]
	player.volume_db = db
	var p = pitch
	if pitch_rand > 0.0:
		p += randf_range(-pitch_rand, pitch_rand)
	player.pitch_scale = max(0.01, p)
	add_child(player)
	player.finished.connect(func(): player.queue_free())
	player.play()


# =========================
# MUSIC
# =========================

# Play a screen's music. Crossfades if a different song is playing; does nothing
# if the same song is already playing. volume_db is a per-play offset.
func play_screen_music(name: String, volume_db: float = 0.0, crossfade: float = MUSIC_CROSSFADE):
	if _current_song == name:
		return
	play_song(name, volume_db, crossfade)


func play_song(name: String, volume_db: float = 0.0, crossfade: float = MUSIC_CROSSFADE):
	if not music_library.has(name):
		push_warning("Song not found: " + name)
		return

	_current_song = name

	# Swap active/idle players so the new song fades in on the idle one
	var incoming = _music_b if _active_music == _music_a else _music_a
	var outgoing = _active_music

	var stream = music_library[name]
	_enable_loop(stream)
	incoming.stream = stream
	incoming.volume_db = SILENT_DB
	incoming.play()

	var target_db = _music_target_db() + volume_db

	if _music_fade_tween and _music_fade_tween.is_valid():
		_music_fade_tween.kill()
	_music_fade_tween = create_tween().set_parallel(true)
	_music_fade_tween.tween_property(incoming, "volume_db", target_db, crossfade)
	if outgoing.playing:
		_music_fade_tween.tween_property(outgoing, "volume_db", SILENT_DB, crossfade)
		# Stop the outgoing player after the fade
		var t = get_tree().create_timer(crossfade + 0.1)
		t.timeout.connect(func():
			if outgoing != _active_music:
				outgoing.stop()
		)

	_active_music = incoming


func stop_music(fade: float = MUSIC_CROSSFADE):
	_current_song = ""
	if _active_music == null:
		return
	var p = _active_music
	if _music_fade_tween and _music_fade_tween.is_valid():
		_music_fade_tween.kill()
	_music_fade_tween = create_tween()
	_music_fade_tween.tween_property(p, "volume_db", SILENT_DB, fade)
	var t = get_tree().create_timer(fade + 0.1)
	t.timeout.connect(func(): p.stop())


# Layered stems aren't supported in this simplified version, but the method
# exists so existing calls don't crash. It's a no-op.
func set_layer(_layer_index: int, _on: bool, _fade: float = 1.0):
	pass


func current_song() -> String:
	return _current_song


# =========================
# VOLUME (0..1 scalars)
# =========================

func set_music_volume(v: float):
	_music_volume = clamp(v, 0.0, 1.0)
	# Apply immediately to the currently playing song
	if _active_music and _active_music.playing:
		_active_music.volume_db = _music_target_db()


func set_master_volume(v: float):
	_set_bus_volume("Master", v)


func set_sfx_volume(v: float):
	# SFX play on the default bus in this simple version; if you make an "SFX"
	# bus this will control it, otherwise it's a no-op.
	_set_bus_volume("SFX", v)


func register_songs(_defs: Dictionary):
	# Kept for compatibility. Songs are defined in music_library above, so this
	# is a no-op. (Left in so existing calls don't error.)
	pass


# =========================
# INTERNALS
# =========================

func _music_target_db() -> float:
	if _music_volume <= 0.0:
		return SILENT_DB
	return linear_to_db(_music_volume)


func _set_bus_volume(bus_name: String, v: float):
	var idx = AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	var c = clamp(v, 0.0, 1.0)
	AudioServer.set_bus_volume_db(idx, -80.0 if c <= 0.0 else linear_to_db(c))


func _enable_loop(stream: AudioStream):
	if stream is AudioStreamOggVorbis:
		stream.loop = true
	elif stream is AudioStreamMP3:
		stream.loop = true
	elif stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD