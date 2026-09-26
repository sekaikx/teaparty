extends Node
## mu-law round trip for the voice codec:  godot --headless --path . -- --qa --tool=res://tools/test_voice_codec.gd
func _ready() -> void:
	var worst := 0.0
	for i in 201:
		var x := -1.0 + i * 0.01
		var b: int = Voice._encode[clampi(int(x * 32767.0) + 32768, 0, 65535) >> 4]
		var y: float = Voice._decode[b]
		var err := absf(y - x) / maxf(absf(x), 0.02)
		worst = maxf(worst, err)
	print("VOICE CODEC worst relative error %.3f  %s" % [worst, "OK" if worst < 0.08 else "FAIL"])
	get_tree().quit(0 if worst < 0.08 else 1)
