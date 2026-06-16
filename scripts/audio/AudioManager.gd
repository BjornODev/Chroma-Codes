extends Node

# =========================
# AUDIO MANAGER (autoload)
# Top-level audio API. Replaces AudioLoader. Owns:
#   - an SFX pool (overlapping one-shot sound effects, auto-loaded from a folder)
#   - a music player (layered stems + crossfade between songs)
#   - bus volume control for settings menus
#
# Add as an autoload named "AudioManager".
#
# SFX:
#   AudioManager.play_sound("reveal")
#   AudioManager.play_sound("peg_land", -3.0, 1.0, 0.08)   # volume, pitch, pitch randomness
#
# MUSIC:
#   AudioManager.register_songs({
#       "map_theme": ["res://assets/audio/music/map_drums.ogg",
#                     "res://assets/audio/music/map_bass.ogg",
#                     "res://assets/audio/music/map_melody.ogg"],
#   })
#   AudioManager.play_song("map_theme", [0, 1])     # start with drums + bass
#   AudioManager.set_layer(2, true)                  # fade the melody in
#   AudioManager.play_song("boss_theme")             # crossfade to a new song
#
# VOLUME (0..1):
#   AudioManager.set_master_volume(0.8)
#   AudioManager.set_music_volume(0.5)
#   AudioManager.set_sfx_volume(0.7)
# =========================

const MASTER_BUS := "Master"
const MUSIC_BUS := "Music"
const SFX_BUS := "SFX"

var sfx: SFXPool
var music: MusicPlayer


func _ready():
	_ensure_buses()

	sfx = SFXPool.new()
	sfx.name = "SFXPool"
	add_child(sfx)

	music = MusicPlayer.new()
	music.name = "MusicPlayer"
	add_child(music)


# Create the Music and SFX buses at runtime if the project doesn't define them,
# so the system works without manual bus setup. (Defining them in the Audio tab
# is still recommended for effects/mixing.)
func _ensure_buses():
	if AudioServer.get_bus_index(MUSIC_BUS) == -1:
		var idx = AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, MUSIC_BUS)
		AudioServer.set_bus_send(idx, MASTER_BUS)
	if AudioServer.get_bus_index(SFX_BUS) == -1:
		var idx = AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, SFX_BUS)
		AudioServer.set_bus_send(idx, MASTER_BUS)


# =========================
# SFX
# =========================

func play_sound(sound_name: String, volume_db := 0.0, pitch := 1.0, pitch_rand := 0.0) -> AudioStreamPlayer:
	if sfx == null:
		return null
	return sfx.play(sound_name, volume_db, pitch, pitch_rand)


func has_sound(sound_name: String) -> bool:
	return sfx != null and sfx.has_sound(sound_name)


func stop_all_sfx():
	if sfx != null:
		sfx.stop_all()


# =========================
# MUSIC
# =========================

func register_song(song_name: String, stem_paths: Array):
	music.register_song(song_name, stem_paths)


func register_songs(defs: Dictionary):
	music.register_songs(defs)


func play_song(song_name: String, enabled_layers: Array = [0], crossfade := MusicPlayer.DEFAULT_CROSSFADE):
	music.play_song(song_name, enabled_layers, crossfade)


func set_layer(layer_index: int, on: bool, fade := MusicPlayer.DEFAULT_LAYER_FADE):
	music.set_layer(layer_index, on, fade)


func set_layer_volume(layer_index: int, db: float, fade := MusicPlayer.DEFAULT_LAYER_FADE):
	music.set_layer_volume(layer_index, db, fade)


func stop_music(fade := MusicPlayer.DEFAULT_CROSSFADE):
	music.stop(fade)


func current_song() -> String:
	return music.current_song()


# =========================
# VOLUME (0..1 scalars, for settings sliders)
# =========================

func set_master_volume(v: float):
	_set_bus_volume(MASTER_BUS, v)


func set_sfx_volume(v: float):
	_set_bus_volume(SFX_BUS, v)


func set_music_volume(v: float):
	# Route through the music player so it respects per-layer fades cleanly,
	# and also set the bus for anything else routed there.
	music.set_music_volume(v)


func get_bus_volume(bus_name: String) -> float:
	var idx = AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return 1.0
	return db_to_linear(AudioServer.get_bus_volume_db(idx))


func set_bus_muted(bus_name: String, muted: bool):
	var idx = AudioServer.get_bus_index(bus_name)
	if idx != -1:
		AudioServer.set_bus_mute(idx, muted)


func _set_bus_volume(bus_name: String, v: float):
	var idx = AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	var clamped = clamp(v, 0.0, 1.0)
	if clamped <= 0.0:
		AudioServer.set_bus_volume_db(idx, -80.0)
	else:
		AudioServer.set_bus_volume_db(idx, linear_to_db(clamped))