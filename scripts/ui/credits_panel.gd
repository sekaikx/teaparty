class_name CreditsPanel
extends Control
## Who made what, and the licence notices the game ships with.

const LINES := [
	["MURDER AT TEATIME", "A Tea Party game. The guests, hats, cups, teapots, cakes, the UI and the tea sounds are made procedurally for this game."],
	["ENGINE", "Made with Godot Engine (godotengine.org), MIT licence. Copyright (c) 2014-present Godot Engine contributors, (c) 2007-2014 Juan Linietsky, Ariel Manzur."],
	["STEAM", "GodotSteam by Gramps (godotsteam.com), MIT licence. Steamworks SDK by Valve Corporation."],
	["ICONS", "Phosphor Icons by Helena Zhang and Tobias Fried (phosphoricons.com), MIT licence."],
	["3D MODELS", "KayKit Furniture Bits and Medieval Hexagon by Kay Lousberg (kaylousberg.com), CC0. Stylized Nature MegaKit by Quaternius (quaternius.com), CC0."],
	["FONTS", "Lilita One by Juan Montoreano and Fredoka by Milena Brandao, SIL Open Font Licence 1.1."],
	["MUSIC", "\"Sneaky Snitch\" and \"Carefree\" by Kevin MacLeod (incompetech.com), licensed under Creative Commons: By Attribution 4.0 License (creativecommons.org/licenses/by/4.0). Evening and tavern loops made for the Woods project."],
	["SOUNDS", "Recorded effects from Freesound contributors (CC0; the full list is in audio/CREDITS.md) and Kenney (kenney.nl, CC0). Other sounds made for this game."],
]

signal closed


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Ui.backdrop(self, 0.8)
	var p := Ui.panel()
	p.custom_minimum_size = Vector2(700, 0)
	add_child(Ui.center(p))
	var v := Ui.vbox(10)
	p.add_child(v)
	v.add_child(Ui.title("CREDITS", 46, Ui.YELLOW))
	# The notices scroll; the button stays put.
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(680, 440)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	var list := Ui.vbox(6)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(list)
	for l: Array in LINES:
		list.add_child(Ui.label(String(l[0]), 16, Ui.PINK, 800))
		list.add_child(Ui.wrap(Ui.label(String(l[1]), 16, Ui.CREAM, 600), 650))
	list.add_child(Ui.label("Version %s" % ProjectSettings.get_setting("application/config/version", "1.0"), 14, Ui.MUTED, 600))
	v.add_child(Ui.button("THANKS!", func() -> void: closed.emit(), Ui.MINT))


func _unhandled_key_input(e: InputEvent) -> void:
	if e.is_action_pressed(&"pause"):
		closed.emit()
		get_viewport().set_input_as_handled()
