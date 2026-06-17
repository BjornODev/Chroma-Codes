extends Node
class_name SFXPool

# =========================
# SFX POOL
# A pool of AudioStreamPlayers for overlapping one-shot sound effects. Grabbing a
# free player means many sounds can play at once without cutting each other off.
# Streams are auto-loaded from a folder and referenced by file name (no extension).
# =========================

const SFX_FOLDER := "res://assets/audio/sfx"
const POOL_SIZE := 16
const SFX_BUS := "SFX"

var _streams: Dictionary = {}        # name -> AudioStream
var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready():
	_build_pool()
	_load_streams()


func _build_pool():
	for i in range(POOL_SIZE):
		var p = AudioStreamPlayer.new()
		p.bus = SFX_BUS
		add_child(p)
		_players.append(p)


func _load_streams():
	_streams.clear()

	var files := ResourceLoader.list_directory(SFX_FOLDER)
	files.sort()
	if files.is_empty():
		push_error("SFX folder missing or empty: " + SFX_FOLDER)
		return

	for file_name in files:
		if _is_audio_file(file_name):
			var path = SFX_FOLDER + "/" + file_name
			var stream = ResourceLoader.load(path)
			if stream:
				_streams[file_name.get_basename()] = stream
			else:
				push_warning("Failed to load sound: " + path)

	print("Loaded sound effects: ", _streams.size())


func _is_audio_file(fname: String) -> bool:
	var lower = fname.to_lower()
	return lower.ends_with(".ogg") or lower.ends_with(".wav") or lower.ends_with(".mp3")


# Play a sound by name. Returns the player used (or null if the sound is unknown).
# volume_db: gain offset. pitch: 1.0 = normal. pitch_rand: random +/- range added
# to pitch so repeated sounds don't feel robotic.
func play(sound_name: String, volume_db := 0.0, pitch := 1.0, pitch_rand := 0.0) -> AudioStreamPlayer:
	if not _streams.has(sound_name):
		push_warning("[SFXPool] unknown sound: " + sound_name)
		return null

	var player = _get_free_player()
	player.stream = _streams[sound_name]
	player.volume_db = volume_db
	var p = pitch
	if pitch_rand > 0.0:
		p += randf_range(-pitch_rand, pitch_rand)
	player.pitch_scale = max(0.01, p)
	player.play()
	return player


# Find a player that isn't currently playing; if all are busy, reuse the oldest
# (round-robin), which transparently steals the longest-running voice.
func _get_free_player() -> AudioStreamPlayer:
	for p in _players:
		if not p.playing:
			return p
	var player = _players[_next]
	_next = (_next + 1) % _players.size()
	return player


func has_sound(sound_name: String) -> bool:
	return _streams.has(sound_name)


func stop_all():
	for p in _players:
		p.stop()
