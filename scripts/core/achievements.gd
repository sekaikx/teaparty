class_name Achievements
extends RefCounted
## Goals to chase, checked after every match from what you did (and your lifetime stats).
## Unlocked ones are saved in the profile and, when Steam is running, sent to Steam as well
## (Steamworks.unlock_achievement; the ids are the Steam API names).

const LIST := [
	{"id": "FIRST_SIP", "name": "First Sip", "desc": "Finish a tea party."},
	{"id": "WINNER", "name": "Last One Standing", "desc": "Win a match."},
	{"id": "POISONER_WIN", "name": "Perfectly Poisonous", "desc": "Win as the poisoner."},
	{"id": "DOUBLE_DOSE", "name": "Double Dose", "desc": "Poison two guests in one match."},
	{"id": "CAUGHT_YOU", "name": "Caught Red-Handed", "desc": "Vote out a poisoner."},
	{"id": "ROUND_ONE", "name": "Round One Sleuth", "desc": "The poisoner is thrown out in round 1, and you voted for them."},
	{"id": "CLOSE_CALL", "name": "Close Call", "desc": "Drink a poisoned cup and live (antidote or smelling salts)."},
	{"id": "ELEMENTARY", "name": "Elementary", "desc": "As the Inspector, find poison on someone's hands."},
	{"id": "SALTS", "name": "Smelling Salts", "desc": "As the Physician, bring a poisoned guest round."},
	{"id": "BUTLER_WIN", "name": "Unflappable", "desc": "Win as the Butler."},
	{"id": "POLTERGEIST", "name": "Poltergeist", "desc": "Rattle 3 cups as a ghost in one match."},
	{"id": "CAKE_BOSS", "name": "Cake Boss", "desc": "Hit 10 guests with cake (all time)."},
	{"id": "REGULAR", "name": "A Regular", "desc": "Play 10 matches."},
	{"id": "HIT_JOB", "name": "Nothing Personal", "desc": "Win Hit List as the poisoner."},
	{"id": "LONE_WOLF", "name": "Lone Wolf", "desc": "Win Rival Poisoners as the last poisoner standing."},
	{"id": "DAILY", "name": "Daily Brew", "desc": "Finish a daily challenge."},
	{"id": "SOCIALITE", "name": "Socialite", "desc": "Play 50 matches."},
]


static func info(id: String) -> Dictionary:
	for a: Dictionary in LIST:
		if a["id"] == id:
			return a
	return {}


## After a match (Profile.award already counted it): returns the names newly unlocked.
static func check(res: Dictionary, my_seat: int) -> Array:
	var seats: Array = res.get("seats", [])
	if my_seat < 0 or my_seat >= seats.size():
		return []
	var me: Dictionary = seats[my_seat]
	var role := StringName(me.get("role", &"guest"))
	var won := (res.get("winners", []) as Array).has(my_seat)
	var got: Array[String] = []
	got.append("FIRST_SIP")
	if won:
		got.append("WINNER")
		if role == &"poisoner":
			got.append("POISONER_WIN")
		if role == &"butler":
			got.append("BUTLER_WIN")
		if role == &"poisoner" and String(res.get("mode", "")) == "hitlist":
			got.append("HIT_JOB")
		if role == &"poisoner" and String(res.get("mode", "")) == "rivals" and (res.get("winners", []) as Array).size() == 1:
			got.append("LONE_WOLF")
	if String(res.get("daily", "")) != "":
		got.append("DAILY")
	if int(me.get("kills", 0)) >= 2:
		got.append("DOUBLE_DOSE")
	if int(me.get("good_votes", 0)) >= 1:
		got.append("CAUGHT_YOU")
	if int(me.get("inspect_hits", 0)) >= 1:
		got.append("ELEMENTARY")
	if int(me.get("revives", 0)) >= 1:
		got.append("SALTS")
	if int(me.get("rattles_used", 0)) >= 3:
		got.append("POLTERGEIST")
	for rd: Dictionary in res.get("history", []):
		for d: Dictionary in rd.get("drinks", []):
			if int(d["seat"]) == my_seat and not d["died"]:
				got.append("CLOSE_CALL")
		if int(rd["round"]) == 1 and String(rd.get("ejected_role", "")) == "poisoner" and int(me.get("good_votes", 0)) >= 1:
			got.append("ROUND_ONE")
	if int(Profile.stats.get(&"cake_hits", 0)) >= 10:
		got.append("CAKE_BOSS")
	if int(Profile.stats.get(&"matches", 0)) >= 10:
		got.append("REGULAR")
	if int(Profile.stats.get(&"matches", 0)) >= 50:
		got.append("SOCIALITE")
	var fresh: Array = []
	for id in got:
		if not Profile.achievements.has(id):
			Profile.achievements[id] = Time.get_date_string_from_system()
			fresh.append(String(info(id).get("name", id)))
			Steamworks.unlock_achievement(id)
	if not fresh.is_empty():
		Profile.save_profile()
	return fresh
