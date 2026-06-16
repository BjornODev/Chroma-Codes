extends Node
class_name MusicPlayer

# =========================
# MUSIC PLAYER
# Handles music with two blending concepts:
#
#  1. LAYERED STEMS within a song: a song is several stems (drums, bass, melody,
#     ...) that all play simultaneously and stay sample-synced. You fade
#     individual stems in/out to change intensity without ever desyncing them.
#
#  2. CROSSFADE between songs: switching songs fades the current song's stems out
#     while the new song's stems fade in over a set duration.
#
# A "song" is data: a name mapped to a list of stem stream paths. Stems are
# enabled/disabled by index. All stems of a song share the same playback position.
# =========================

const MUSIC_BUS := "Music"
const DEFAULT_CROSSFADE := 2.0
const DEFAULT_LAYER_FADE := 1.0
const SILENT_DB := -60.0           # effectively silent
const FULL_DB := 0.0

# A group of synced stem players for one song instance.
class SongInstance:
	var name: String
	var players: Array[AudioStreamPlayer] = []   # one per stem
	var target_db: Array[float] = []             # per-stem target volume
	var enabled: Array[bool] = []                # per-stem on/off
	var fade_tweens: Array = []                  # per-stem active tween

var _current: SongInstance = null
var _song_defs: Dictionary = {}    # name -> Array[String] of stem paths

var _music_volume := 1.0           # 0..1 master music scalar (for settings)


func _ready():
	pass


# Register a song: name -> array of stem resource paths (in layer order).
func register_song(song_name: String, stem_paths: Array) -> void:
	_song_defs[song_name] = stem_paths.duplicate()


func register_songs(defs: Dictionary) -> void:
	for k in defs.keys():
		register_song(k, defs[k])


# Start a song. enabled_layers: which stem indices begin audible (others start
# silent but still play, so they can be faded in later in sync). If a song is
# already playing, it crossfades out.
func play_song(song_name: String, enabled_layers: Array = [0], crossfade := DEFAULT_CROSSFADE) -> void:
	if not _song_defs.has(song_name):
		push_warning("[MusicPlayer] unknown song: " + song_name)
		return

	var old = _current
	var inst = _build_song_instance(song_name, enabled_layers)
	_current = inst

	# Start all stems together (sample-synced)
	for i in range(inst.players.size()):
		var p = inst.players[i]
		var start_db = SILENT_DB
		if inst.enabled[i]:
			start_db = (FULL_DB + _vol_offset()) if old == null else SILENT_DB
		p.volume_db = start_db
		p.play()

	# Fade the new song's enabled layers in
	for i in range(inst.players.size()):
		if inst.enabled[i]:
			_fade_stem(inst, i, _layer_target_db(inst, i), crossfade)

	# Crossfade the old song out, then free it
	if old != null:
		_fade_out_and_free(old, crossfade)


func _build_song_instance(song_name: String, enabled_layers: Array) -> SongInstance:
	var inst = SongInstance.new()
	inst.name = song_name
	var paths = _song_defs[song_name]
	for i in range(paths.size()):
		var p = AudioStreamPlayer.new()
		p.bus = MUSIC_BUS
		# Loop the stems if the stream supports it
		var stream = load(paths[i]) if ResourceLoader.exists(paths[i]) else null
		if stream != null and stream is AudioStream:
			_enable_loop(stream)
			p.stream = stream
		add_child(p)
		inst.players.append(p)
		inst.enabled.append(enabled_layers.has(i))
		inst.target_db.append(FULL_DB)
		inst.fade_tweens.append(null)
	return inst


# Enable/disable (fade in/out) a single stem layer of the current song.
func set_layer(layer_index: int, on: bool, fade := DEFAULT_LAYER_FADE) -> void:
	if _current == null:
		return
	if layer_index < 0 or layer_index >= _current.players.size():
		return
	_current.enabled[layer_index] = on
	var target = _layer_target_db(_current, layer_index) if on else SILENT_DB
	_fade_stem(_current, layer_index, target, fade)


# Set how loud a specific layer should be when enabled (its mix level).
func set_layer_volume(layer_index: int, db: float, fade := DEFAULT_LAYER_FADE) -> void:
	if _current == null or layer_index < 0 or layer_index >= _current.target_db.size():
		return
	_current.target_db[layer_index] = db
	if _current.enabled[layer_index]:
		_fade_stem(_current, layer_index, _layer_target_db(_current, layer_index), fade)


# Stop all music, optionally fading out first.
func stop(fade := DEFAULT_CROSSFADE) -> void:
	if _current == null:
		return
	_fade_out_and_free(_current, fade)
	_current = null


# Master music volume scalar (0..1), e.g. from a settings slider.
func set_music_volume(v: float) -> void:
	_music_volume = clamp(v, 0.0, 1.0)
	if _current != null:
		for i in range(_current.players.size()):
			if _current.enabled[i]:
				_fade_stem(_current, i, _layer_target_db(_current, i), 0.1)


func current_song() -> String:
	return _current.name if _current != null else ""


# =========================
# INTERNALS
# =========================

func _layer_target_db(inst: SongInstance, i: int) -> float:
	return inst.target_db[i] + _vol_offset()


func _vol_offset() -> float:
	# Convert the 0..1 scalar to a dB offset (1.0 -> 0 dB, lower -> attenuation)
	if _music_volume <= 0.0:
		return SILENT_DB
	return linear_to_db(_music_volume)


func _fade_stem(inst: SongInstance, i: int, to_db: float, dur: float) -> void:
	var p = inst.players[i]
	if inst.fade_tweens[i] != null and inst.fade_tweens[i].is_valid():
		inst.fade_tweens[i].kill()
	if dur <= 0.0:
		p.volume_db = to_db
		return
	var tw = create_tween()
	tw.tween_property(p, "volume_db", to_db, dur)
	inst.fade_tweens[i] = tw


func _fade_out_and_free(inst: SongInstance, dur: float) -> void:
	for i in range(inst.players.size()):
		_fade_stem(inst, i, SILENT_DB, dur)
	# Free after the fade completes
	var t = get_tree().create_timer(dur + 0.1)
	t.timeout.connect(func():
		for p in inst.players:
			if is_instance_valid(p):
				p.stop()
				p.queue_free()
	)


func _enable_loop(stream: AudioStream) -> void:
	# Best-effort loop enabling across common stream types
	if stream is AudioStreamOggVorbis:
		stream.loop = true
	elif stream is AudioStreamMP3:
		stream.loop = true
	elif stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD