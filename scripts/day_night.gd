## Day/night cycle driven by the machine's real local clock (a BagIdea
## Office idea): sun energy/color/angle, ambient light and sky color all
## follow the hour. Override with AGENT_TOWN_HOUR=17.5 for screenshots.
class_name DayNight
extends Node

var sun: DirectionalLight3D
var env: Environment

var _override_hour := -1.0

# hour, sun_energy, sun_color, ambient_energy, ambient_color, bg_color, sun_pitch_deg
const KEYS := [
	[0.0, 0.05, Color(0.50, 0.60, 0.90), 0.45, Color(0.16, 0.18, 0.30), Color(0.05, 0.06, 0.12), -35.0],
	[5.5, 0.05, Color(0.50, 0.60, 0.90), 0.45, Color(0.16, 0.18, 0.30), Color(0.05, 0.06, 0.12), -12.0],
	[7.0, 0.90, Color(1.00, 0.80, 0.62), 0.80, Color(0.55, 0.52, 0.55), Color(0.95, 0.78, 0.62), -18.0],
	[9.0, 1.25, Color(1.00, 0.96, 0.88), 1.00, Color(0.62, 0.63, 0.70), Color(0.72, 0.83, 0.90), -45.0],
	[15.5, 1.25, Color(1.00, 0.96, 0.88), 1.00, Color(0.62, 0.63, 0.70), Color(0.72, 0.83, 0.90), -45.0],
	[17.5, 0.95, Color(1.00, 0.72, 0.45), 0.75, Color(0.60, 0.48, 0.42), Color(0.94, 0.62, 0.42), -15.0],
	[19.0, 0.10, Color(0.65, 0.55, 0.75), 0.50, Color(0.22, 0.22, 0.38), Color(0.10, 0.09, 0.20), -10.0],
	[21.0, 0.05, Color(0.50, 0.60, 0.90), 0.45, Color(0.16, 0.18, 0.30), Color(0.05, 0.06, 0.12), -30.0],
	[24.0, 0.05, Color(0.50, 0.60, 0.90), 0.45, Color(0.16, 0.18, 0.30), Color(0.05, 0.06, 0.12), -35.0],
]


func _ready() -> void:
	var ov := OS.get_environment("AGENT_TOWN_HOUR")
	if not ov.is_empty():
		_override_hour = ov.to_float()
	var t := Timer.new()
	t.wait_time = 10.0
	t.timeout.connect(_apply)
	add_child(t)
	t.start()
	_apply()


func current_hour() -> float:
	if _override_hour >= 0.0:
		return _override_hour
	var t := Time.get_time_dict_from_system()
	return float(t.hour) + float(t.minute) / 60.0


func _apply() -> void:
	if sun == null or env == null:
		return
	var h := clampf(current_hour(), 0.0, 24.0)
	var a: Array = KEYS[0]
	var b: Array = KEYS[KEYS.size() - 1]
	for i in range(KEYS.size() - 1):
		if h >= float(KEYS[i][0]) and h <= float(KEYS[i + 1][0]):
			a = KEYS[i]
			b = KEYS[i + 1]
			break
	var span := float(b[0]) - float(a[0])
	var f := 0.0 if span <= 0.0 else (h - float(a[0])) / span
	sun.light_energy = lerpf(float(a[1]), float(b[1]), f)
	sun.light_color = (a[2] as Color).lerp(b[2] as Color, f)
	env.ambient_light_energy = lerpf(float(a[3]), float(b[3]), f)
	env.ambient_light_color = (a[4] as Color).lerp(b[4] as Color, f)
	env.background_color = (a[5] as Color).lerp(b[5] as Color, f)
	sun.rotation_degrees = Vector3(lerpf(float(a[6]), float(b[6]), f), 200.0, 0.0)
