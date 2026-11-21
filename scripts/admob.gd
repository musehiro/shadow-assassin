# AdMob autoload (AdMob) — the ONLY script that talks to the AdMob plugin.
#
# PLUGIN: Poing Studios GodotAdMob v4.1.0 (Android AAR built for Godot 4.3.0).
# The plugin is NOT installed yet — see "INSTALL (still to do)" below. This
# script is written so the game runs fine WITHOUT the plugin: every plugin
# class is reached dynamically (Engine singleton + ClassDB), never by a
# static reference, so this file parses and runs in the editor, in headless
# CI, and on desktop. When the plugin is missing, every method degrades
# gracefully instead of crashing (see the "no ad right now" behaviour).
#
# INSTALL (still to do — needs an explicit go-ahead, see report):
#   1. Download the Godot wrapper from the godot-admob-plugin releases and
#      extract it into res://addons/admob/ (plugin.cfg, GDScript API).
#   2. Download the Android AARs for Godot 4.3.0 from the v4.1.0 release of
#      godot-admob-android and place them at:
#        res://addons/admob/android/bin/ads/libs/
#      (poing-godot-admob-ads-debug.aar, poing-godot-admob-ads-release.aar,
#       poing-godot-admob-core-debug.aar, poing-godot-admob-core-release.aar)
#   3. Enable the plugin: Project -> Project Settings -> Plugins -> AdMob.
#   4. Project -> Project Settings -> General -> Admob -> Android: Enabled
#      ON, App Id = AdMobConfig.APP_ID (test ID for now, real ID later).
#   5. Install the Android build template (Project -> Install Android Build
#      Template) and set gradle_build/use_gradle_build=true in
#      export_presets.cfg — the plugin adds the play-services-ads Gradle
#      dependency (24.9.0) and the AARs, which only a Gradle build includes.
#      Do NOT flip that flag before the template + plugin are in place or
#      the CI export will break.
#
# INTERFACE (the weapons/UI agent codes against exactly this):
#   signal rewarded_earned(placement: String)
#   signal rewarded_failed(placement: String)
#   signal interstitial_closed()
#   func show_rewarded(placement: String) -> void
#   func is_rewarded_ready() -> bool
#   func show_interstitial() -> void
#
# BEHAVIOUR NOTES:
# - init is deferred and never blocks game start; ads preload in background.
# - show_rewarded() with no ad ready emits rewarded_failed(placement) at
#   once, so the UI can show "no ad right now" and fall back to the coin price.
# - show_interstitial() with no ad ready emits interstitial_closed() at once,
#   so level flow never stalls waiting for an ad that will not come.
# - One rewarded ad is preloaded per placement ("unlock_gun", "double_coins")
#   so each placement can later have its own real ad unit ID.
extends Node

## Emitted when the user watched a rewarded ad to the end for a placement.
## The UI grants the reward for this placement (gun unlock / 2x coins).
signal rewarded_earned(placement: String)
## Emitted when a rewarded ad could not be shown for a placement (no ad
## loaded, no fill, no network, plugin missing, or show failed). The UI
## should show a short "no ad right now" note and fall back to the coin price.
signal rewarded_failed(placement: String)
## Emitted when an interstitial finishes: dismissed by the user, failed to
## show, or when no interstitial was ready (so game flow never stalls).
signal interstitial_closed()

const AdMobConfigScript := preload("res://scripts/admob_config.gd")

## Seconds before retrying a failed background ad load.
const _LOAD_RETRY_DELAY_SEC: float = 30.0

var _available: bool = false
var _initialised: bool = false

## placement String -> loaded RewardedAd Object (single-use; reloaded after show).
var _rewarded_ads: Dictionary = {}
## placement String -> true while a load is in flight for that placement.
var _rewarded_loading: Dictionary = {}
## Loaded InterstitialAd Object (single-use; reloaded after show/close).
var _interstitial_ad: Object = null
var _interstitial_loading: bool = false


func _ready() -> void:
	# Never block startup: initialise on the next idle frame.
	call_deferred("_initialise_ads")


func _initialise_ads() -> void:
	if OS.get_name() != "Android":
		print("[AdMob] Not Android (", OS.get_name(), ") — ads disabled, degrading gracefully.")
		return
	if not Engine.has_singleton("MobileAds"):
		print("[AdMob] MobileAds singleton not found — plugin not installed? Ads disabled, degrading gracefully.")
		return
	if not _plugin_classes_present():
		print("[AdMob] Plugin API classes missing — ads disabled, degrading gracefully.")
		return
	_available = true
	Engine.get_singleton("MobileAds").call("initialize")
	_initialised = true
	print("[AdMob] MobileAds initialised (app id: ", AdMobConfigScript.APP_ID, ", test ids: ", AdMobConfigScript.using_test_ids(), "). Preloading ads in background.")
	_load_rewarded(AdMobConfigScript.PLACEMENT_UNLOCK_GUN)
	_load_rewarded(AdMobConfigScript.PLACEMENT_DOUBLE_COINS)
	_load_interstitial()


func _plugin_classes_present() -> bool:
	for plugin_class in [
		"RewardedAdLoader", "RewardedAdLoadCallback", "OnUserEarnedRewardListener",
		"InterstitialAdLoader", "InterstitialAdLoadCallback",
		"FullScreenContentCallback", "AdRequest",
	]:
		if not ClassDB.class_exists(plugin_class):
			print("[AdMob] Missing plugin class: ", plugin_class)
			return false
	return true


# ---------------------------------------------------------------- rewarded

func is_rewarded_ready() -> bool:
	return not _rewarded_ads.is_empty()


func show_rewarded(placement: String) -> void:
	if not _available or not _initialised:
		print("[AdMob] show_rewarded(", placement, "): ads unavailable — emitting rewarded_failed.")
		rewarded_failed.emit(placement)
		return
	var ad: Object = _rewarded_ads.get(placement, null)
	if ad == null:
		print("[AdMob] show_rewarded(", placement, "): no ad loaded — emitting rewarded_failed.")
		rewarded_failed.emit(placement)
		_load_rewarded(placement)
		return
	_rewarded_ads.erase(placement)
	_show_rewarded_ad(ad, placement)


func _show_rewarded_ad(ad: Object, placement: String) -> void:
	var reward_listener: Object = ClassDB.instantiate("OnUserEarnedRewardListener")
	reward_listener.set("on_user_earned_reward", func(_rewarded_item) -> void:
		print("[AdMob] User earned reward for placement: ", placement)
		rewarded_earned.emit(placement)
	)
	var full_screen_callback: Object = ClassDB.instantiate("FullScreenContentCallback")
	full_screen_callback.set("on_ad_dismissed_full_screen_content", func() -> void:
		_destroy_ad(ad)
		_load_rewarded(placement)
	)
	full_screen_callback.set("on_ad_failed_to_show_full_screen_content", func(_ad_error) -> void:
		print("[AdMob] Rewarded ad failed to show for placement: ", placement)
		_destroy_ad(ad)
		rewarded_failed.emit(placement)
		_load_rewarded(placement)
	)
	ad.set("full_screen_content_callback", full_screen_callback)
	ad.call("show", reward_listener)


func _load_rewarded(placement: String) -> void:
	if not _available or not _initialised:
		return
	if _rewarded_ads.has(placement) or _rewarded_loading.get(placement, false):
		return
	_rewarded_loading[placement] = true
	var unit_id: String = AdMobConfigScript.rewarded_ad_unit_id(placement)
	var load_callback: Object = ClassDB.instantiate("RewardedAdLoadCallback")
	load_callback.set("on_ad_failed_to_load", func(ad_error) -> void:
		_rewarded_loading[placement] = false
		print("[AdMob] Rewarded ad failed to load for ", placement, ": ", ad_error)
		_schedule_retry(_load_rewarded.bind(placement))
	)
	load_callback.set("on_ad_loaded", func(rewarded_ad) -> void:
		_rewarded_loading[placement] = false
		_rewarded_ads[placement] = rewarded_ad
		print("[AdMob] Rewarded ad loaded for placement: ", placement)
	)
	var loader: Object = ClassDB.instantiate("RewardedAdLoader")
	loader.call("load", unit_id, ClassDB.instantiate("AdRequest"), load_callback)


# ------------------------------------------------------------ interstitial

func show_interstitial() -> void:
	if not _available or not _initialised:
		print("[AdMob] show_interstitial: ads unavailable — emitting interstitial_closed so flow continues.")
		interstitial_closed.emit()
		return
	if _interstitial_ad == null:
		print("[AdMob] show_interstitial: no ad loaded — emitting interstitial_closed so flow continues.")
		interstitial_closed.emit()
		_load_interstitial()
		return
	var ad: Object = _interstitial_ad
	_interstitial_ad = null
	var full_screen_callback: Object = ClassDB.instantiate("FullScreenContentCallback")
	full_screen_callback.set("on_ad_dismissed_full_screen_content", func() -> void:
		_destroy_ad(ad)
		interstitial_closed.emit()
		_load_interstitial()
	)
	full_screen_callback.set("on_ad_failed_to_show_full_screen_content", func(_ad_error) -> void:
		print("[AdMob] Interstitial failed to show.")
		_destroy_ad(ad)
		interstitial_closed.emit()
		_load_interstitial()
	)
	ad.set("full_screen_content_callback", full_screen_callback)
	ad.call("show")


func _load_interstitial() -> void:
	if not _available or not _initialised:
		return
	if _interstitial_ad != null or _interstitial_loading:
		return
	_interstitial_loading = true
	var load_callback: Object = ClassDB.instantiate("InterstitialAdLoadCallback")
	load_callback.set("on_ad_failed_to_load", func(ad_error) -> void:
		_interstitial_loading = false
		print("[AdMob] Interstitial failed to load: ", ad_error)
		_schedule_retry(_load_interstitial)
	)
	load_callback.set("on_ad_loaded", func(interstitial_ad) -> void:
		_interstitial_loading = false
		_interstitial_ad = interstitial_ad
		print("[AdMob] Interstitial loaded.")
	)
	var loader: Object = ClassDB.instantiate("InterstitialAdLoader")
	loader.call("load", AdMobConfigScript.INTERSTITIAL_AD_UNIT_ID, ClassDB.instantiate("AdRequest"), load_callback)


# ---------------------------------------------------------------- helpers

func _destroy_ad(ad: Object) -> void:
	if ad != null and is_instance_valid(ad):
		ad.call("destroy")


func _schedule_retry(retry_callable: Callable) -> void:
	if not is_inside_tree():
		return
	get_tree().create_timer(_LOAD_RETRY_DELAY_SEC).timeout.connect(
		func() -> void:
			if _available and _initialised:
				retry_callable.call()
	)


## One-line status for debugging (not part of the UI interface).
## e.g. "AdMob available=false initialised=false rewarded_ready=false interstitial_loaded=false"
func debug_status() -> String:
	return "AdMob available=%s initialised=%s rewarded_ready=%s rewarded_loaded=%s interstitial_loaded=%s" % [
		_available, _initialised, is_rewarded_ready(), _rewarded_ads.keys(), _interstitial_ad != null,
	]
