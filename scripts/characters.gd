class_name ShadowCharacters
## Unlockable assassin roster. Speed is the meta — the fastest costs most gems.
## Stats are multipliers / pools applied by ShadowGame at level start.

const CHARACTERS := [
	{"id": "shadow", "name": "Shadow", "desc": "The original assassin.", "speed": 1.0, "health": 3, "cost": 0},
	{"id": "ninja", "name": "Ninja", "desc": "Quick and quiet.", "speed": 1.15, "health": 3, "cost": 150},
	{"id": "ronin", "name": "Ronin", "desc": "A tough veteran.", "speed": 1.0, "health": 5, "cost": 300},
	{"id": "ghost", "name": "Ghost", "desc": "The fastest blade alive.", "speed": 1.45, "health": 3, "cost": 800},
]


static func get_character(char_id: String) -> Dictionary:
	for c in CHARACTERS:
		if String(c["id"]) == char_id:
			return c
	return CHARACTERS[0]


static func speed_mult(char_id: String) -> float:
	return float(get_character(char_id).get("speed", 1.0))


static func max_health(char_id: String) -> int:
	return int(get_character(char_id).get("health", 3))


static func cost(char_id: String) -> int:
	return int(get_character(char_id).get("cost", 0))


static func is_owned(save: Dictionary, char_id: String) -> bool:
	var owned: Array = save.get("characters_owned", ["shadow"])
	return owned.has(char_id)


static func buy(save: Dictionary, char_id: String) -> bool:
	var price := cost(char_id)
	if is_owned(save, char_id):
		return true
	if int(save.get("total_gems", 0)) < price:
		return false
	save["total_gems"] = int(save.get("total_gems", 0)) - price
	var owned: Array = save.get("characters_owned", ["shadow"])
	owned.append(char_id)
	save["characters_owned"] = owned
	save["selected_character"] = char_id
	ShadowSave.save_data(save)
	return true
