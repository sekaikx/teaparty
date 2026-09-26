class_name Cosmetics
extends RefCounted
## Everything a guest can unlock: hats, teacups, death animations, skins and titles.
## `price` in coins (0 = free), `level` = player level needed before it can be bought.

const HATS := {
	&"none": {"name": "Bare head", "price": 0, "level": 1},
	&"top_hat": {"name": "Top Hat", "price": 0, "level": 1},
	&"bowler": {"name": "Bowler", "price": 80, "level": 1},
	&"party": {"name": "Party Cone", "price": 60, "level": 1},
	&"bonnet": {"name": "Sunday Bonnet", "price": 120, "level": 2},
	&"fez": {"name": "Fez", "price": 150, "level": 2},
	&"flower_crown": {"name": "Flower Crown", "price": 200, "level": 3},
	&"witch": {"name": "Witch's Hat", "price": 260, "level": 4},
	&"teacup": {"name": "Teacup Hat", "price": 320, "level": 5},
	&"crown": {"name": "Royal Crown", "price": 500, "level": 7},
}

## body / rim / tea colours.
const CUPS := {
	&"porcelain": {"name": "Blue Willow", "price": 0, "level": 1, "body": Color("f4f1ea"), "rim": Color("2e5f9a")},
	&"rose": {"name": "Rose Garden", "price": 70, "level": 1, "body": Color("f6d9dc"), "rim": Color("c0506a")},
	&"mint": {"name": "Mint Julep", "price": 70, "level": 1, "body": Color("d4efe1"), "rim": Color("3f8f6a")},
	&"midnight": {"name": "Midnight", "price": 140, "level": 2, "body": Color("252a44"), "rim": Color("c9b26b")},
	&"frog": {"name": "Toad Hall", "price": 160, "level": 3, "body": Color("7fae4a"), "rim": Color("3a5c1d")},
	&"gold": {"name": "Gilded", "price": 300, "level": 4, "body": Color("fbf4dd"), "rim": Color("d9a531")},
	&"skull": {"name": "Memento Mori", "price": 380, "level": 5, "body": Color("1b1b1b"), "rim": Color("e8e2d2")},
	&"royal": {"name": "Royal Doulton", "price": 520, "level": 7, "body": Color("4b2a6b"), "rim": Color("f0c75a")},
}

const DEATHS := {
	&"swoon": {"name": "The Swoon", "price": 0, "level": 1, "desc": "A classic faint."},
	&"keel": {"name": "Keel Over", "price": 0, "level": 1, "desc": "Straight back, like a plank."},
	&"stagger": {"name": "The Stagger", "price": 120, "level": 2, "desc": "Clutch, wobble, down."},
	&"monologue": {"name": "Last Words", "price": 200, "level": 3, "desc": "One raised hand, one final speech."},
	&"spin": {"name": "Pirouette", "price": 260, "level": 4, "desc": "A twirl on the way down."},
	&"confetti": {"name": "Confetti Pop", "price": 400, "level": 6, "desc": "Goes out with a bang."},
	&"ascend": {"name": "Ascension", "price": 600, "level": 8, "desc": "Straight up to the great tea room in the sky."},
}

## model + tint (multiplied over the KayKit texture).
const SKINS := {
	&"knight": {"name": "Sir Knight", "price": 0, "level": 1, "model": &"knight", "tint": Color(1, 1, 1)},
	&"rogue": {"name": "The Stranger", "price": 0, "level": 1, "model": &"rogue", "tint": Color(1, 1, 1)},
	&"knight_rose": {"name": "Rosy Knight", "price": 90, "level": 1, "model": &"knight", "tint": Color(1.0, 0.78, 0.8)},
	&"rogue_moss": {"name": "Moss Stranger", "price": 90, "level": 2, "model": &"rogue", "tint": Color(0.78, 1.0, 0.78)},
	&"knight_sky": {"name": "Sky Knight", "price": 150, "level": 3, "model": &"knight", "tint": Color(0.75, 0.88, 1.0)},
	&"rogue_plum": {"name": "Plum Stranger", "price": 150, "level": 3, "model": &"rogue", "tint": Color(0.88, 0.72, 1.0)},
	&"knight_gold": {"name": "Golden Knight", "price": 450, "level": 6, "model": &"knight", "tint": Color(1.0, 0.9, 0.55)},
	&"rogue_ash": {"name": "Ash Stranger", "price": 450, "level": 6, "model": &"rogue", "tint": Color(0.62, 0.62, 0.66)},
}

## Titles unlock by lifetime stats (or level) and are free to wear.
const TITLES := {
	&"newcomer": {"name": "Newcomer", "stat": &"", "need": 0},
	&"taster": {"name": "Tea Taster", "stat": &"matches", "need": 3},
	&"survivor": {"name": "Survivor", "stat": &"rounds_survived", "need": 10},
	&"poisoner": {"name": "Poisoner", "stat": &"kills", "need": 5},
	&"nose": {"name": "Nose of the Year", "stat": &"sniffs", "need": 10},
	&"toastmaster": {"name": "Toastmaster", "stat": &"toasts", "need": 10},
	&"sleight": {"name": "Sleight of Hand", "stat": &"swaps", "need": 15},
	&"poltergeist": {"name": "Poltergeist", "stat": &"rattles", "need": 25},
	&"untouchable": {"name": "The Untouchable", "stat": &"wins", "need": 5},
	&"butler": {"name": "The Butler Did It", "stat": &"butler_wins", "need": 1},
	&"host": {"name": "Hostess with the Mostest", "stat": &"level", "need": 5},
	&"dowager": {"name": "Dowager", "stat": &"level", "need": 10},
}

const CATEGORIES := {&"hat": HATS, &"cup": CUPS, &"death": DEATHS, &"skin": SKINS}

const DEFAULT_EQUIP := {&"hat": &"top_hat", &"cup": &"porcelain", &"death": &"swoon", &"skin": &"knight", &"title": &"newcomer"}


static func entry(category: StringName, id: StringName) -> Dictionary:
	if category == &"title":
		return TITLES.get(id, TITLES[&"newcomer"])
	var cat: Dictionary = CATEGORIES.get(category, {})
	return cat.get(id, cat.get(DEFAULT_EQUIP.get(category, &""), {}))


static func title_name(id: Variant) -> String:
	return String(TITLES.get(StringName(str(id)), TITLES[&"newcomer"])["name"])


## Random cosmetics for a bot (anything, so the table looks lively).
static func random_look(rng: RandomNumberGenerator) -> Dictionary:
	var pick := func(d: Dictionary) -> StringName:
		var keys := d.keys()
		return keys[rng.randi_range(0, keys.size() - 1)]
	var t: Array = TITLES.keys()
	return {
		"hat": pick.call(HATS), "cup": pick.call(CUPS), "death": pick.call(DEATHS),
		"skin": pick.call(SKINS), "title": t[rng.randi_range(0, t.size() - 1)],
	}
