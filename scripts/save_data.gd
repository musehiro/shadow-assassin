class_name ShadowSave
## Save system for Shadow Assassin (unlocked levels, stars kept for
## compatibility only — the UI no longer shows or awards them — coins, gems,
## mute, owned/selected assassins).

const PATH := "user://save.cfg"
const LEVEL_COUNT := 10


static func load_data() -> Dictionary:
	var data := {
		"unlocked": 0, "stars": {}, "total_coins": 0, "total_gems": 0,
		"muted": false, "characters_owned": ["shadow"], "selected_character": "shadow",
		# v3 weapons: knife owned from the start, gun locked until bought
		# (500 coins) or unlocked with a rewarded ad. Old saves get these
		# defaults, so nothing already saved is ever lost.
		"weapons_owned": ["knife"], "active_weapon": "knife",
		"levels_completed": 0,
		# v4 tutorial: coach-mark ids already shown or skipped — never
		# shown again. Old saves get the empty default.
		"hints_seen": [],
	}
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return data
	data["unlocked"] = int(cfg.get_value("progress", "unlocked", 0))
	data["total_coins"] = int(cfg.get_value("progress", "total_coins", 0))
	data["total_gems"] = int(cfg.get_value("progress", "total_gems", 0))
	data["muted"] = bool(cfg.get_value("settings", "muted", false))
	data["selected_character"] = String(cfg.get_value("progress", "selected_character", "shadow"))
	var owned: Array = cfg.get_value("progress", "characters_owned", ["shadow"])
	if owned.is_empty():
		owned = ["shadow"]
	data["characters_owned"] = owned
	var weapons_owned: Array = cfg.get_value("progress", "weapons_owned", ["knife"])
	if weapons_owned.is_empty():
		weapons_owned = ["knife"]
	data["weapons_owned"] = weapons_owned
	data["active_weapon"] = String(cfg.get_value("progress", "active_weapon", "knife"))
	data["levels_completed"] = int(cfg.get_value("progress", "levels_completed", 0))
	data["hints_seen"] = Array(cfg.get_value("progress", "hints_seen", []))
	var stars := {}
	for i in range(LEVEL_COUNT):
		stars[i] = int(cfg.get_value("stars", "level_%d" % i, 0))
	data["stars"] = stars
	return data


static func save_data(data: Dictionary) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "unlocked", int(data.get("unlocked", 0)))
	cfg.set_value("progress", "total_coins", int(data.get("total_coins", 0)))
	cfg.set_value("progress", "total_gems", int(data.get("total_gems", 0)))
	cfg.set_value("progress", "selected_character", String(data.get("selected_character", "shadow")))
	cfg.set_value("progress", "characters_owned", Array(data.get("characters_owned", ["shadow"])))
	cfg.set_value("progress", "weapons_owned", Array(data.get("weapons_owned", ["knife"])))
	cfg.set_value("progress", "active_weapon", String(data.get("active_weapon", "knife")))
	cfg.set_value("progress", "levels_completed", int(data.get("levels_completed", 0)))
	cfg.set_value("progress", "hints_seen", Array(data.get("hints_seen", [])))
	cfg.set_value("settings", "muted", bool(data.get("muted", false)))
	var stars: Dictionary = data.get("stars", {})
	for k in stars.keys():
		cfg.set_value("stars", "level_%d" % int(k), int(stars[k]))
	cfg.save(PATH)


static func stars_string(stars: Dictionary, level_index: int) -> String:
	var n: int = int(stars.get(level_index, 0))
	var s := ""
	for i in range(3):
		s += "★" if i < n else "☆"
	return s
