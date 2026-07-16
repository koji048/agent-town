## Headless test: CaptionStudio.ass_font_ratio — libass sizes fonts by the GDI
## cell height (OS/2 winAscent+winDescent), Godot by em, so the preview must
## scale label fonts by upem/(winAsc+winDesc) to match the burn (measured:
## Anuphan Fontsize 72 burns 40px tall vs Godot's 60px at the same number).
##   godot --headless --path . --quit-after 600 -s res://tools/test_font_scale.gd
extends SceneTree

var _passes := 0
var _fails := 0


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var CS = load("res://scripts/caption_studio.gd")

	# ground truth parsed independently (python struct): upem / (winAsc+winDesc)
	var r_anuphan: float = CS.ass_font_ratio("res://assets/fonts/Anuphan.ttf")
	_check("Anuphan ratio = 1000/1443", absf(r_anuphan - 1000.0 / 1443.0) < 0.002)
	var r_chakra: float = CS.ass_font_ratio("res://assets/fonts/ChakraPetch-Medium.ttf")
	_check("ChakraPetch ratio = 1000/1814", absf(r_chakra - 1000.0 / 1814.0) < 0.002)
	_check("ratios differ per font", absf(r_anuphan - r_chakra) > 0.1)
	_check("missing file falls back to 1.0",
		is_equal_approx(CS.ass_font_ratio("res://assets/fonts/_nope.ttf"), 1.0))

	print("\n=== font scale tests: %d passed, %d failed ===" % [_passes, _fails])
	quit(1 if _fails > 0 else 0)


func _check(name: String, cond: bool) -> void:
	if cond:
		_passes += 1
		print("  PASS  ", name)
	else:
		_fails += 1
		print("  FAIL  ", name)
