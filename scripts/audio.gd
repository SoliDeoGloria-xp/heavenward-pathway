class_name AudioHub
extends Node
## Audio hooks with silent fallbacks. Drop files into assets/audio/music/<map music id>.ogg and
## assets/audio/sfx/<id>.ogg (or .wav) and they play; missing files are skipped without errors.

const MUSIC_DIR := "res://assets/audio/music/%s.ogg"
const SFX_DIRS := ["res://assets/audio/sfx/%s.ogg", "res://assets/audio/sfx/%s.wav"]
const FADE_S := 0.8
const SILENT_DB := -60.0
const SFX_VOICES := 6

var _music: AudioStreamPlayer
var _voices: Array[AudioStreamPlayer] = []
var _next_voice := 0
var _cache := {}        # id -> AudioStream or null (so a missing file is looked up only once)
var _music_id := ""

func _ready() -> void:
	for bus in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus(); AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
	_music = AudioStreamPlayer.new(); _music.bus = "Music"; add_child(_music)
	for i in SFX_VOICES:
		var p := AudioStreamPlayer.new(); p.bus = "SFX"; add_child(p); _voices.append(p)

func set_volumes(music: float, sfx_vol: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(maxf(music, 0.001)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(maxf(sfx_vol, 0.001)))

## Cross-fade to a map's music; an unknown or missing id fades to silence.
func music(id: String) -> void:
	if id == _music_id:
		return
	_music_id = id
	var stream := _load(id, [MUSIC_DIR])
	var tw := create_tween()
	tw.tween_property(_music, "volume_db", SILENT_DB, FADE_S)
	tw.tween_callback(func() -> void:
		_music.stop(); _music.stream = stream
		if stream:
			_music.play())
	if stream:
		tw.tween_property(_music, "volume_db", 0.0, FADE_S)

func sfx(id: String) -> void:
	var stream := _load(id, SFX_DIRS)
	if stream == null:
		return
	var p := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % SFX_VOICES
	p.stream = stream; p.play()

func _load(id: String, patterns: Array) -> AudioStream:
	if not _cache.has(id):
		_cache[id] = null
		for pat in patterns:
			var path: String = pat % id
			if id != "" and ResourceLoader.exists(path):
				_cache[id] = load(path)
				break
	return _cache[id]
