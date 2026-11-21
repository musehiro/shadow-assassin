class_name ShadowWeapons
## Weapon data + unlock state for Shadow Assassin v3.
##
## KNIFE (starting weapon, free): the v2 contact kill, now named.
##   Short range (48 px — you must walk into the guard), SILENT (no noise),
##   instant kill, no cooldown. The stealth weapon.
## GUN (unlockable): ranged tracer shots, LOUD (every shot alerts nearby
##   guards, like a kill noise), 0.9 s cooldown between shots, no contact
##   kill while it is active. The loud weapon — different, not just better.
##
## Balance lever: COOLDOWN, not ammo. Ammo would need a second economy and
## an ammo HUD; a 0.9 s cooldown keeps the gun from being spammed, matches
## the guards' own fire-interval rhythm, and leaves the knife as the fast,
## silent option for close work. The gun also cannot kill shielded guards
## from the front (their shield blocks bullets, same as contact kills) —
## the knife from behind is still the answer there.
##
## Unlock: 500 coins, or a rewarded ad ("unlock_gun"). Persisted in save
## data ("weapons_owned", "active_weapon") with backward-compatible
## defaults — old saves get the knife owned + active, gun locked.

const KNIFE_ID := "knife"
const GUN_ID := "gun"

const GUN_PRICE := 500 # coins
const GUN_RANGE := 320.0 # px (~5 tiles)
const GUN_COOLDOWN := 0.9 # seconds between shots
const GUN_BULLET_SPEED := 700.0
const KNIFE_RANGE := 48.0 # == ShadowGame.ELIM_DIST (contact kill)

const WEAPONS := [
	{"id": KNIFE_ID, "name": "Knife", "icon": "🔪",
		"desc": "Silent • close range • instant kill", "price": 0},
	{"id": GUN_ID, "name": "Gun", "icon": "🔫",
		"desc": "Loud • 5 tiles • 0.9s between shots", "price": GUN_PRICE},
]


static func weapon_def(weapon_id: String) -> Dictionary:
	for w in WEAPONS:
		if String(w["id"]) == weapon_id:
			return w
	return WEAPONS[0]


static func price_of(weapon_id: String) -> int:
	return int(weapon_def(weapon_id).get("price", 0))


static func owned_weapons(save: Dictionary) -> Array:
	var owned: Array = save.get("weapons_owned", [KNIFE_ID])
	if owned.is_empty():
		owned = [KNIFE_ID]
	return owned


static func is_owned(save: Dictionary, weapon_id: String) -> bool:
	return owned_weapons(save).has(weapon_id)


## Buy with coins. Returns false (and spends nothing) if already owned
## or the player cannot afford it. Persists on success.
static func unlock_with_coins(save: Dictionary, weapon_id: String) -> bool:
	if is_owned(save, weapon_id):
		return true
	var price := price_of(weapon_id)
	if int(save.get("total_coins", 0)) < price:
		return false
	save["total_coins"] = int(save.get("total_coins", 0)) - price
	var owned: Array = owned_weapons(save)
	owned.append(weapon_id)
	save["weapons_owned"] = owned
	ShadowSave.save_data(save)
	return true


## Rewarded-ad path: no coins spent. Persists. The caller is responsible
## for only calling this after AdMob's rewarded_earned signal fires.
static func unlock_free(save: Dictionary, weapon_id: String) -> void:
	if is_owned(save, weapon_id):
		return
	var owned: Array = owned_weapons(save)
	owned.append(weapon_id)
	save["weapons_owned"] = owned
	ShadowSave.save_data(save)


static func active_weapon(save: Dictionary) -> String:
	var active := String(save.get("active_weapon", KNIFE_ID))
	if not is_owned(save, active):
		return KNIFE_ID
	return active


## Switch the active weapon. Only owned weapons can be equipped.
## Persists on success so the choice survives a restart.
static func set_active(save: Dictionary, weapon_id: String) -> bool:
	if not is_owned(save, weapon_id):
		return false
	save["active_weapon"] = weapon_id
	ShadowSave.save_data(save)
	return true
