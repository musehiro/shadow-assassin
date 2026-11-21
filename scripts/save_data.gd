class_name ShadowSave
## Tiny save system for Shadow Assassin (unlocked levels, stars, coins, mute).

const PATH := "user://save.cfg"
const LEVEL_COUNT := 10


static func load_data() -> Dictionary:
	var data := {"unlocked": 0, "stars": {}, "total_coins": 0, "muted": false}
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return data
	data["unlocked"] = int(cfg.get_value("progress", "unlocked", 0))
	data["total_coins"] = int(cfg.get_value("progress", "total_coins", 0))
	data["muted"] = bool(cfg.get_value("settings", "muted", false))
	var stars := {}
	for i in range(LEVEL_COUNT):
		stars[i] = int(cfg.get_value("stars", "level_%d" % i, 0))
	data["stars"] = stars
	return data


static func save_data(data: Dictionary) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "unlocked", int(data.get("unlocked", 0)))
	cfg.set_value("progress", "total_coins", int(data.get("total_coins", 0)))
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
