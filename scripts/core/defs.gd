class_name Defs
extends RefCounted
## Shared constants: ingredients, items, phases, modes, rooms, emotes and default lobby rules.

enum Ingredient { NOTHING, POISON, ANTIDOTE, SUGAR }
enum Item { SWAP, SNIFF, TOAST, PEEK }
enum Phase { LOBBY, INTRO, DEAL, POUR, ITEMS, TALK, DRINK, REVEAL, MATCH_END }

const INGREDIENTS := {
	Ingredient.NOTHING: {"name": "Nothing", "short": "Plain", "color": Color("b8a88a"),
		"desc": "Just tea. Pour it with a straight face."},
	Ingredient.POISON: {"name": "Poison", "short": "Poison", "color": Color("5f8a2c"),
		"desc": "One drop and the drinker collapses (unless an antidote is in the cup too)."},
	Ingredient.ANTIDOTE: {"name": "Antidote", "short": "Antidote", "color": Color("2e6a93"),
		"desc": "Cancels one poison in the same cup."},
	Ingredient.SUGAR: {"name": "Sugar", "short": "Sugar", "color": Color("e9e1d0"),
		"desc": "Masks the taste: a sniff of this cup tells nothing."},
}

const ITEMS := {
	Item.SWAP: {"name": "Swap", "targets": 2, "target": &"cup",
		"desc": "Swap two cups on the table. Everyone sees the cups move."},
	Item.SNIFF: {"name": "Sniff", "targets": 1, "target": &"cup",
		"desc": "Sniff a cup: you alone learn if it smells of poison (sugar hides it)."},
	Item.TOAST: {"name": "Force a Toast", "targets": 1, "target": &"guest",
		"desc": "Raise a toast to a guest: they must drink their cup right now."},
	Item.PEEK: {"name": "Peek", "targets": 1, "target": &"guest",
		"desc": "Peek at a guest's tray: the ingredients they did not pour, and their items."},
}

const PHASE_NAMES := {
	Phase.LOBBY: "Lobby", Phase.INTRO: "The guests arrive", Phase.DEAL: "Dealing",
	Phase.POUR: "Pour", Phase.ITEMS: "Items", Phase.TALK: "Talk it out",
	Phase.DRINK: "Drink!", Phase.REVEAL: "The reveal", Phase.MATCH_END: "Party's over",
}

## Modes and rooms, with the player level that unlocks them.
const MODES := {
	&"classic": {"name": "Classic", "level": 1, "desc": "Every guest for themselves. Last one standing wins."},
	&"teams": {"name": "Teams", "level": 2, "desc": "Earl Grey vs Darjeeling. Teammates know each other; a team wins when the other is gone."},
	&"butler": {"name": "The Butler", "level": 4, "desc": "One hidden butler spikes a cup every round. Guests win by poisoning the butler; the butler wins if they reach the final two."},
}

const ROOMS := {
	&"parlor": {"name": "The Parlour", "level": 1, "seats": 6, "desc": "Firelight, wallpaper and a round table."},
	&"garden": {"name": "Garden Party", "level": 3, "seats": 6, "desc": "Hedges, bunting and birdsong on the lawn."},
	&"banquet": {"name": "Royal Banquet", "level": 5, "seats": 8, "desc": "A candlelit hall and a long table for eight."},
}

## Custom lobby rules (beyond players / bots / room / mode) unlock at this level.
const CUSTOM_RULES_LEVEL := 6

const TEAM_NAMES := ["Earl Grey", "Darjeeling"]
const TEAM_COLORS := [Color("7c4596"), Color("c2702a")]

const DEFAULT_RULES := {
	"room": &"parlor",
	"mode": &"classic",
	"max_players": 6,
	"hand_size": 3,
	"pour_time": 25.0,
	"item_turn_time": 15.0,
	"talk_time": 60.0,
	"items_per_round": 1,
	"max_items": 2,
	"laced_round": 5,
	"max_rounds": 10,
	"poison_scale": 1.0,
	"ghost_rattles": 3,
	"ghosts_see_cups": true,
	"ghosts_talk_to_living": false,
	"items_enabled": [Item.SWAP, Item.SNIFF, Item.TOAST, Item.PEEK],
}

## Emote wheel: id -> label, speech bubble line, upper-body clip (seated) and a voice blip.
const EMOTES := [
	{"name": "Cheers!", "line": "Cheers!", "clip": &"Cheer", "sound": &"voice_01"},
	{"name": "Not me!", "line": "It wasn't me!", "clip": &"ual/No", "sound": &"voice_02"},
	{"name": "Accuse", "line": "YOU!", "clip": &"Spellcast_Shoot", "sound": &"voice_03"},
	{"name": "Hmm...", "line": "Hmm...", "clip": &"ual/Idle_FoldArms", "sound": &"voice_04"},
	{"name": "Yes", "line": "Quite so.", "clip": &"ual/Yes", "sound": &"voice_05"},
	{"name": "Please", "line": "Please, spare me!", "clip": &"Block", "sound": &"voice_02"},
	{"name": "Laugh", "line": "Ha ha ha!", "clip": &"Cheer", "sound": &"voice_01"},
	{"name": "Sip", "line": "*sips*", "clip": &"ual/Consume", "sound": &"voice_04"},
]

const BOT_NAMES := [
	"Lady Marmalade", "Sir Crumpet", "Duchess Earl", "Colonel Scone", "Miss Bergamot",
	"Lord Biscuit", "Auntie Oolong", "Vicar Treacle", "Countess Chai", "Baron Jam",
	"Madame Lapsang", "Captain Kettle",
]


static func ingredient_name(k: int) -> String:
	return INGREDIENTS[k]["name"] if INGREDIENTS.has(k) else "?"


static func item_name(k: int) -> String:
	return ITEMS[k]["name"] if ITEMS.has(k) else "?"


static func default_rules() -> Dictionary:
	return DEFAULT_RULES.duplicate(true)
