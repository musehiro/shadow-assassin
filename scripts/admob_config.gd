# AdMob IDs for Shadow Assassin — ALL ad IDs live in this ONE file.
#
# *** TEST IDS — DO NOT SHIP REAL MONEY ADS WITH THESE ***
# These are Google's OFFICIAL test IDs. They always return a test ad, so
# they are safe to develop and test with. They earn NO revenue.
#
# WHEN BUDDHIKA'S REAL ADMOB ACCOUNT IS READY:
#   1. Create the app in AdMob, copy its App ID, and replace APP_ID below.
#   2. Create one rewarded ad unit and one interstitial ad unit (or one
#      rewarded unit per placement if he wants separate reporting) and
#      replace the *_AD_UNIT_ID values below.
#   3. ALSO set the same App ID in the editor:
#      Project -> Project Settings -> General -> Admob -> Android -> App Id
#      (that is what the Google Mobile Ads SDK reads at runtime on Android).
#   4. Rebuild the APK. Never ship test IDs in a public release — AdMob can
#      suspend the account for that.
#
# PLUGIN: Poing Studios GodotAdMob v4.1.0, Android AAR built for Godot 4.3.0
# (poing-godot-admob-android-v4.3.0.zip from the v4.1.0 release).
# See scripts/admob.gd for the install steps that still need doing.
class_name AdMobConfig
extends RefCounted

## AdMob App ID (contains "~"). Google test app ID.
const APP_ID: String = "ca-app-pub-3940256099942544~3347511713"

## Google test rewarded ad unit ID (Android). Both rewarded placements
## share this test unit; give each placement its own real unit later if
## Buddhika wants per-placement reporting.
const REWARDED_AD_UNIT_ID: String = "ca-app-pub-3940256099942544/5224354917"

## Google test interstitial ad unit ID (Android).
const INTERSTITIAL_AD_UNIT_ID: String = "ca-app-pub-3940256099942544/1033173712"

## Rewarded placement names. These exact strings are what the UI code
## passes to AdMob.show_rewarded() and gets back in the signals.
const PLACEMENT_UNLOCK_GUN: String = "unlock_gun"
const PLACEMENT_DOUBLE_COINS: String = "double_coins"

## Per-placement rewarded ad unit IDs. Today both placements use the same
## Google test unit; replace the values (not the keys) with real unit IDs.
const REWARDED_AD_UNIT_IDS: Dictionary = {
	PLACEMENT_UNLOCK_GUN: REWARDED_AD_UNIT_ID,
	PLACEMENT_DOUBLE_COINS: REWARDED_AD_UNIT_ID,
}


## Ad unit ID for a rewarded placement. Unknown placements fall back to the
## shared rewarded test unit so a typo never crashes the game.
static func rewarded_ad_unit_id(placement: String) -> String:
	return str(REWARDED_AD_UNIT_IDS.get(placement, REWARDED_AD_UNIT_ID))


## True when the configured IDs are still Google's test IDs.
static func using_test_ids() -> bool:
	return APP_ID == "ca-app-pub-3940256099942544~3347511713"
