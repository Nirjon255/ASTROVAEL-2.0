extends Node
# Procedural sound for ASTROVAEL. Nothing is loaded from audio files: the engine hum, the boost roar, lasers, explosions,
# hits, the alarm, the radio tone, the mission chime and an ambient drone are synthesized here and mixed into one stream.

const MIX_RATE: float = 22050.0
const MASTER: float = 0.5
const DRONE_LEVEL: float = 0.05

var player: AudioStreamPlayer
var generator: AudioStreamGenerator
var playback: AudioStreamGeneratorPlayback
var voices: Array = []
var engine_level: float = 0.0
var engine_target: float = 0.0
var boost_level: float = 0.0
var alarm_on: bool = false
var alarm_clock: float = 0.0
var engine_phase: float = 0.0
var drone_phase: float = 0.0
var noise_state: float = 0.0
var time_s: float = 0.0


func _ready() -> void:
	generator = AudioStreamGenerator.new()
	generator.mix_rate = MIX_RATE
	generator.buffer_length = 0.1
	player = AudioStreamPlayer.new()
	player.stream = generator
	add_child(player)
	player.play()
	playback = player.get_stream_playback() as AudioStreamGeneratorPlayback


func _process(delta: float) -> void:
	time_s += delta
	if playback == null:
		return
	var frames: int = playback.get_frames_available()
	for i in range(frames):
		var s: float = _sample()
		playback.push_frame(Vector2(s, s))


# Plays a one-shot sound: "laser", "enemy_laser", "explosion", "hit", "click", "mission" or "radio".
func play(kind: String) -> void:
	var length: float = 0.25
	match kind:
		"explosion":
			length = 1.2
		"hit":
			length = 0.35
		"mission":
			length = 1.2
		"radio":
			length = 1.0
		"click":
			length = 0.08
	voices.append({"kind": kind, "t": 0.0, "dur": length, "phase": 0.0})
	if voices.size() > 24:
		voices.pop_front()


# The engine follows the ship's speed; boosting adds a roar.
func set_engine(level: float, boosting: bool) -> void:
	engine_target = clampf(level, 0.0, 1.0)
	boost_level = 1.0 if boosting else 0.0


func set_alarm(on: bool) -> void:
	alarm_on = on


func _sample() -> float:
	var dt: float = 1.0 / MIX_RATE
	var out: float = 0.0
	# Engine: a low fundamental with harmonics, plus filtered noise that grows with speed and boost.
	engine_level = lerpf(engine_level, engine_target, 0.0005)
	engine_phase += (48.0 + 28.0 * engine_level + 40.0 * boost_level) * dt
	var hum: float = sin(TAU * engine_phase) * 0.6 + sin(TAU * engine_phase * 2.0) * 0.25 + sin(TAU * engine_phase * 3.0) * 0.1
	noise_state = noise_state * 0.96 + randf_range(-1.0, 1.0) * 0.04
	out += (hum * 0.35 + noise_state * 0.5) * engine_level * (1.0 + boost_level * 0.6) * 0.5
	# Ambient drone: a quiet, slowly breathing chord.
	drone_phase += 55.0 * dt
	var pad: float = sin(TAU * drone_phase) * 0.5 + sin(TAU * drone_phase * 1.5) * 0.3 + sin(TAU * drone_phase * 2.0) * 0.2
	out += pad * DRONE_LEVEL * (0.6 + 0.4 * sin(time_s * 0.2))
	# Alarm: a rising and falling two-tone siren while the alarm is on.
	if alarm_on:
		alarm_clock += dt
		var tone: float = 880.0 if fposmod(alarm_clock, 0.5) < 0.25 else 660.0
		out += signf(sin(TAU * tone * alarm_clock)) * 0.12
	# One-shot voices.
	var finished: Array = []
	for i in range(voices.size()):
		var v: Dictionary = voices[i]
		v["t"] = float(v["t"]) + dt
		out += _voice(v)
		if float(v["t"]) >= float(v["dur"]):
			finished.append(i)
	for i in range(finished.size() - 1, -1, -1):
		voices.remove_at(finished[i])
	return clampf(out * MASTER, -0.95, 0.95)


func _voice(v: Dictionary) -> float:
	var t: float = float(v["t"])
	var dur: float = float(v["dur"])
	var fade: float = 1.0 - clampf(t / dur, 0.0, 1.0)
	match String(v["kind"]):
		"laser":
			var f: float = lerpf(1600.0, 260.0, t / dur)
			v["phase"] = float(v["phase"]) + f / MIX_RATE
			return sin(TAU * float(v["phase"])) * 0.35 * fade
		"enemy_laser":
			var g: float = lerpf(700.0, 160.0, t / dur)
			v["phase"] = float(v["phase"]) + g / MIX_RATE
			return sin(TAU * float(v["phase"])) * 0.3 * fade
		"explosion":
			return randf_range(-1.0, 1.0) * exp(-t * 4.0) * 0.6 + sin(TAU * lerpf(120.0, 40.0, t / dur) * t) * exp(-t * 3.0) * 0.5
		"hit":
			return randf_range(-1.0, 1.0) * exp(-t * 18.0) * 0.5
		"click":
			return randf_range(-1.0, 1.0) * exp(-t * 60.0) * 0.3
		"mission":
			# Four rising notes: C5, E5, G5, C6.
			var notes: Array = [523.25, 659.25, 783.99, 1046.5]
			var index: int = mini(int(t / 0.3), 3)
			var local: float = fposmod(t, 0.3)
			return sin(TAU * float(notes[index]) * t) * exp(-local * 6.0) * 0.35
		"radio":
			# Two short tones with a little crackle.
			var on: bool = fposmod(t, 0.4) < 0.25
			var tone: float = 1200.0 if fposmod(t, 0.4) < 0.12 else 1500.0
			if not on:
				return 0.0
			return sin(TAU * tone * t) * 0.25 + randf_range(-1.0, 1.0) * 0.05
	return 0.0
