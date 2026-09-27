class_name Defs
extends RefCounted
## Shared constants: ingredients, items, phases, modes, rooms, emotes and default lobby rules.

enum Ingredient { NOTHING, POISON, ANTIDOTE, SUGAR }
enum Item { SWAP, SNIFF, TOAST, PEEK }
## Round order: DEAL > POUR (serve in the dark) > ITEMS > DRINK (the toast) > REVEAL > TALK (the
## meeting) > VOTE > EJECT. New phases are appended so the numbers of the old ones never change.
enum Phase { LOBBY, INTRO, DEAL, POUR, ITEMS, TALK, DRINK, REVEAL, MATCH_END, VOTE, EJECT }

const INGREDIENTS := {
	Ingredient.NOTHING: {"name": "Plain", "short": "Plain", "color": Color("b8a88a"),
		"desc": "Just tea. Harmless, but it gives you an alibi."},
	Ingredient.POISON: {"name": "Poison", "short": "Poison", "color": Color("5f8a2c"),
		"desc": "One drop and the drinker collapses (unless an antidote is in the cup too)."},
	Ingredient.ANTIDOTE: {"name": "Antidote", "short": "Antidote", "color": Color("2e6a93"),
		"desc": "Cancels one poison in the same cup."},
	Ingredient.SUGAR: {"name": "Sugar", "short": "Sugar", "color": Color("e9e1d0"),
		"desc": "Harmless, but a sniff of a sugared cup tells nothing."},
}

const ITEMS := {
	Item.SWAP: {"name": "Swap", "targets": 2, "target": &"cup",
		"desc": "Swap two cups on the table. Everyone sees it (so you'll have to explain yourself)."},
	Item.SNIFF: {"name": "Sniff", "targets": 1, "target": &"cup",
		"desc": "Sniff a cup: you alone learn if it's poisoned right now (sugar hides it)."},
	Item.TOAST: {"name": "Force a Toast", "targets": 1, "target": &"guest",
		"desc": "Raise a toast to a guest: they must drink their cup right now (after the swaps)."},
	Item.PEEK: {"name": "Watch", "targets": 1, "target": &"guest",
		"desc": "Watch a guest: you alone learn whose cup they poured into. Catch a liar."},
}

const PHASE_NAMES := {
	Phase.LOBBY: "Lobby", Phase.INTRO: "The guests arrive", Phase.DEAL: "Dealing",
	Phase.POUR: "Serve", Phase.ITEMS: "Items", Phase.TALK: "Meeting",
	Phase.DRINK: "Toast", Phase.REVEAL: "The reveal", Phase.MATCH_END: "Party's over",
	Phase.VOTE: "Vote", Phase.EJECT: "Thrown out",
}

## Modes and rooms, with the player level that unlocks them.
const MODES := {
	&"classic": {"name": "Murder at Teatime", "level": 1, "desc": "A secret poisoner (two with 8 guests) is at the table. Find them and vote them out before they poison everyone."},
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
	"item_turn_time": 12.0,
	"talk_time": 60.0,
	"vote_time": 20.0,
	## How likely each guest is to glimpse one other guest's pour in the dark (-1 = by table size).
	"glimpse_chance": -1.0,
	"items_per_round": 1,
	"max_items": 2,
	"laced_round": 5,
	"max_rounds": 8,
	"poison_scale": 1.0,
	"ghost_rattles": 3,
	"ghosts_see_cups": false,
	"ghosts_talk_to_living": false,
	"helium": false,
	"items_enabled": [Item.SWAP, Item.SNIFF, Item.PEEK],
}

## Emote wheel: label, speech bubble line, gesture (Guest.gesture) and a voice blip.
const EMOTES := [
	{"name": "Cheers!", "line": "Cheers!", "clip": &"cheer", "sound": &"voice_01"},
	{"name": "Not me!", "line": "It wasn't me!", "clip": &"no", "sound": &"voice_02"},
	{"name": "Accuse", "line": "YOU!!", "clip": &"point", "sound": &"voice_03"},
	{"name": "Hmm...", "line": "Hmmmm...", "clip": &"think", "sound": &"voice_04"},
	{"name": "Trust me", "line": "Trust me :)", "clip": &"yes", "sound": &"voice_05"},
	{"name": "Please", "line": "PLEASE SPARE ME", "clip": &"plead", "sound": &"voice_02"},
	{"name": "Laugh", "line": "HA HA HA", "clip": &"laugh", "sound": &"voice_01"},
	{"name": "Sip", "line": "*sips loudly*", "clip": &"sip", "sound": &"voice_04"},
]

const BOT_NAMES := [
	"Lady Marmalade", "Sir Crumpet", "Duchess Earl", "Colonel Scone", "Miss Bergamot",
	"Lord Biscuit", "Auntie Oolong", "Vicar Treacle", "Countess Chai", "Baron Jam",
	"Madame Lapsang", "Captain Kettle",
]


## Things you can SAY at the meeting (a button bar, for players not on voice and for bots).
## Any claim can be a lie.
const CLAIMS := {
	&"poured": "I poured %s into %s's cup.",
	&"saw": "I saw %s pour into %s's cup!",
	&"sniff": "I sniffed %s's cup: %s.",
	&"watch": "I watched %s: they poured into %s's cup!",
	&"sus": "It's %s! Vote %s!",
	&"clear": "%s is innocent, I'd bet on it.",
}


## The words of a claim {kind, a, b, k, smell}, with `nm` turning a seat into a name.
static func claim_text(c: Dictionary, nm: Callable) -> String:
	match StringName(c.get("kind", "")):
		&"poured":
			var k := int(c.get("k", -1))
			return "I poured %s into %s's cup." % [ingredient_name(k).to_upper() if k >= 0 else "something", nm.call(int(c["a"]))]
		&"saw":
			return "I saw %s pour into %s's cup!" % [nm.call(int(c["a"])), nm.call(int(c["b"]))]
		&"sniff":
			var sm := String(c.get("smell", "clean"))
			return "I sniffed %s's cup: %s." % [nm.call(int(c["a"])), {"poison": "POISON", "clean": "it was clean", "sweet": "too sweet to tell"}.get(sm, sm)]
		&"watch":
			return "I watched %s: they poured into %s's cup!" % [nm.call(int(c["a"])), nm.call(int(c["b"]))]
		&"sus":
			return "It's %s! Vote %s!" % [nm.call(int(c["a"])), nm.call(int(c["a"]))]
		&"clear":
			return "%s is innocent, I'd bet on it." % nm.call(int(c["a"]))
	return "..."


static func ingredient_name(k: int) -> String:
	return INGREDIENTS[k]["name"] if INGREDIENTS.has(k) else "?"


static func item_name(k: int) -> String:
	return ITEMS[k]["name"] if ITEMS.has(k) else "?"


static func default_rules() -> Dictionary:
	return DEFAULT_RULES.duplicate(true)
