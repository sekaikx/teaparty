class_name LoadingScreen
extends CanvasLayer
## The loading screen: the key art (the same picture as the boot splash, so the hand-over is
## seamless), a bobbing teacup, a real progress bar and a tip. Shown while the game starts (the
## room models load on a background thread) and while a match's table is built.

const ART := "res://assets/splash/key_art.png"
const TIPS := [
	"Poison leaves a trace on the hands of whoever poured it. The Inspector can find it, but only that round.",
	"The Physician can save a poisoned guest with smelling salts. Just not the same guest two rounds running.",
	"Anyone can CLAIM to be the Inspector. If two guests do, one of them is lying.",
	"Sugar hides everything from a sniff. Handy if you have something to hide...",
	"Scared your cup is poisoned? Press F at the toast and cake it off the table. You get 4 cakes a match: don't waste them.",
	"Your glimpse in the dark is always true. What people SAY about it isn't.",
	"The WHO SAID WHAT board flags stories that don't add up. Read it before you vote.",
	"No mic? Press Enter to type in the chat. Ghosts can only chat with other ghosts.",
	"Mic not working? Settings > TEST MIC shows a live level bar.",
	"A poisoner who lies low for a round (and pours sugar) comes up clean.",
	"Swap two cups and everyone sees it. Be ready to explain yourself.",
]
const MODELS_DIR := "res://assets/models/"

## Resources loaded ahead of time, kept so they stay in the cache for the whole session.
static var _keep: Array[Resource] = []

var _bar: ProgressBar
var _tip: Label
var _cup: Control
var _shown := 0.0
var _target := 0.0
var _t := 0.0
var _root: Control


func _init(tip: String = "") -> void:
	layer = 40
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var bg := ColorRect.new()
	bg.color = Color("2a1640")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(bg)
	if ResourceLoader.exists(ART):
		var art := TextureRect.new()
		art.texture = load(ART)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_root.add_child(art)
	var band := Ui.panel(Color(Ui.PLUM_DARK, 0.9), 22, Vector4(22, 12, 22, 14))
	_root.add_child(band)
	Ui.pin(band, Vector2(0.5, 1), Vector2(0.5, 1), Vector2(0, -28))
	var h := Ui.hbox(16)
	band.add_child(h)
	_cup = Doodle.make("cup", 64)
	h.add_child(_cup)
	var v := Ui.vbox(6)
	v.custom_minimum_size.x = 620
	h.add_child(v)
	v.add_child(Ui.title("BREWING...", 30, Ui.YELLOW))
	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.max_value = 1.0
	_bar.custom_minimum_size = Vector2(620, 16)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Ui.MINT
	fill.set_corner_radius_all(8)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(Ui.INK, 0.8)
	back.set_corner_radius_all(8)
	_bar.add_theme_stylebox_override("fill", fill)
	_bar.add_theme_stylebox_override("background", back)
	v.add_child(_bar)
	_tip = Ui.wrap(Ui.label("TIP: " + (tip if tip != "" else TIPS[randi() % TIPS.size()]), 16, Ui.CREAM, 700), 620)
	v.add_child(_tip)


func _process(delta: float) -> void:
	_t += delta
	_shown = move_toward(_shown, _target, delta * 1.5)
	_bar.value = _shown
	if _cup:
		_cup.pivot_offset = _cup.size * 0.5
		_cup.rotation = sin(_t * 3.0) * 0.18
		_cup.position.y = -absf(sin(_t * 3.0)) * 6.0


func set_progress(p: float) -> void:
	_target = clampf(p, 0.0, 1.0)


## Loads every room model on a background thread, updating the bar. Await it.
func preload_models() -> void:
	var paths: Array[String] = []
	_scan(MODELS_DIR, paths)
	for p in paths:
		ResourceLoader.load_threaded_request(p, "", true)
	var done := {}
	var t0 := Time.get_ticks_msec()
	while done.size() < paths.size() and Time.get_ticks_msec() - t0 < 30000:
		var sum := 0.0
		for p in paths:
			if done.has(p):
				sum += 1.0
				continue
			var prog := []
			var st := ResourceLoader.load_threaded_get_status(p, prog)
			if st == ResourceLoader.THREAD_LOAD_LOADED:
				var r := ResourceLoader.load_threaded_get(p)
				if r:
					_keep.append(r)
				done[p] = true
				sum += 1.0
			elif st == ResourceLoader.THREAD_LOAD_FAILED or st == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				done[p] = true
				sum += 1.0
			else:
				sum += float(prog[0]) if not prog.is_empty() else 0.0
		set_progress(0.85 * sum / maxf(paths.size(), 1))
		await get_tree().process_frame


func _scan(dir: String, out: Array[String]) -> void:
	for f in ResourceLoader.list_directory(dir):
		if f.ends_with("/"):
			_scan(dir + f, out)
		elif f.ends_with(".gltf") or f.ends_with(".glb"):
			out.append(dir + f)


## Waits for a few quick frames in a row (the first frames of a new scene compile shaders and
## stall); the bar creeps up meanwhile. Gives up after 20 s.
func until_smooth() -> void:
	var good := 0
	var t0 := Time.get_ticks_msec()
	var last := t0
	while good < 4 and Time.get_ticks_msec() - t0 < 20000:
		await get_tree().process_frame
		var now := Time.get_ticks_msec()
		good = good + 1 if now - last < 80 else 0
		last = now
		_target = minf(0.98, _target + 0.02)


## Fill the bar, fade out and go.
func finish(hold: float = 0.0) -> void:
	set_progress(1.0)
	var tw := create_tween()
	tw.tween_interval(maxf(hold, 0.35))
	tw.tween_property(_root, "modulate:a", 0.0, 0.45)
	tw.tween_callback(queue_free)
