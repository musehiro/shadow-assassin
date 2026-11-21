# Binary Decoder + Android Build Template Installer — editor plugin
# (runs on every editor start, including headless `godot --import` in CI).
#
# WHY THIS EXISTS (two jobs, one plugin):
#
# 1. BASE64 -> BINARY for the AdMob AARs. The GitHub connector cannot push
#    raw binary files, so the AdMob AARs are stored in the repo as BASE64
#    TEXT (in the very same .aar file paths). The Android exporter needs
#    real binaries, so this plugin decodes them back into real ZIP archives
#    before the export reads them. It is idempotent: files that already
#    start with the ZIP magic (PK\x03\x04) are left alone, and a file that
#    does not decode to a valid ZIP is left alone with an error printed.
#    If a file is missing entirely, it is skipped (the export will then
#    fail with the usual "file not found" error, which is the correct
#    signal).
#
# 2. ANDROID BUILD TEMPLATE INSTALL. A Gradle build (required for AdMob —
#    play-services-ads is a Maven dependency) needs res://android/build/,
#    whose libs/ holds the godot-lib AARs (95 MB + 91 MB = 178 MB). Those
#    can NEVER be pushed through the GitHub connector (16 MiB limit) or the
#    web UI (25 MB/file limit). But the CI workflow already downloads the
#    Godot export templates every run, and android_source.zip inside them
#    IS the build template. So when res://android/build/ is missing, this
#    plugin extracts it from the local export-templates dir
#    (OS.get_data_dir() + "/export_templates/<version>/android_source.zip")
#    using Godot's built-in ZIPReader. It is idempotent: it skips when
#    res://android/build/build.gradle already exists. gradlew is made
#    executable after extraction (ZIPReader does not preserve Unix perms).
#    If android_source.zip is not present (no export templates installed),
#    it prints a warning and skips — the export then fails with Godot's
#    standard "Android build template not installed" error, as before.
#    The installer ALSO writes res://android/.build_version and an empty
#    res://android/build/.gdignore, exactly like the editor's own
#    "Install Android Build Template" (ExportTemplateManager::
#    install_android_template_from_file in the Godot 4.3 source).
#    android_source.zip contains NEITHER file, and without .build_version
#    the Android exporter refuses the gradle-built template with
#    "Trying to build from a gradle built template, but no version info
#    for it exists." The version written is
#    ExportTemplateManager::get_android_template_identifier(): the Godot
#    version string (e.g. "4.3.stable") for the default template, or
#    "<path> [<md5>]" for a custom android_source_template preset option.
#    The version step runs even when the template is already installed,
#    so a template extracted by an older version of this plugin (no
#    .build_version) gets fixed on the next editor start.
@tool
extends EditorPlugin

## Repo paths of binaries stored as base64 text. Keep in sync with the files
## the connector push encodes (see the push manifest / report).
const BINARY_FILES: Array[String] = [
	"res://addons/admob/android/bin/ads/libs/poing-godot-admob-ads-debug.aar",
	"res://addons/admob/android/bin/ads/libs/poing-godot-admob-ads-release.aar",
	"res://addons/admob/android/bin/ads/libs/poing-godot-admob-core-debug.aar",
	"res://addons/admob/android/bin/ads/libs/poing-godot-admob-core-release.aar",
]

## Marker file whose presence means the Android build template is installed.
const TEMPLATE_MARKER := "res://android/build/build.gradle"
## Where the template is installed to (zip root maps here).
const TEMPLATE_DIR := "res://android/build"
## Version file the Android exporter requires (see _ensure_build_version).
const BUILD_VERSION_PATH := "res://android/.build_version"
## Empty file the editor's own template install adds to skip scanning.
const GDIGNORE_PATH := "res://android/build/.gdignore"


func _enter_tree() -> void:
	for path in BINARY_FILES:
		_decode_if_needed(path)
	_install_android_build_template()
	_ensure_build_version()


func _decode_if_needed(path: String) -> void:
	if not FileAccess.file_exists(path):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("[BinDecode] Cannot open " + path)
		return
	var data: PackedByteArray = file.get_buffer(file.get_length())
	file.close()
	# Real binaries (AAR = ZIP, jar = ZIP) start with the PK magic.
	if _is_zip(data):
		return
	var text: String = data.get_string_from_utf8().strip_edges()
	var decoded: PackedByteArray = Marshalls.base64_to_raw(text)
	if decoded.is_empty():
		push_error("[BinDecode] Failed to base64-decode " + path + " — leaving it alone.")
		return
	if not _is_zip(decoded):
		push_error("[BinDecode] Decoded " + path + " is not a valid ZIP archive — leaving it alone.")
		return
	var out := FileAccess.open(path, FileAccess.WRITE)
	if out == null:
		push_error("[BinDecode] Cannot write " + path)
		return
	out.store_buffer(decoded)
	out.close()
	print("[BinDecode] Decoded base64 -> binary: " + path + " (" + str(decoded.size()) + " bytes)")


func _is_zip(data: PackedByteArray) -> bool:
	return data.size() >= 4 and data[0] == 0x50 and data[1] == 0x4B and data[2] == 0x03 and data[3] == 0x04


func _find_android_source_zip() -> String:
	var base: String = OS.get_data_dir() + "/godot/export_templates/"
	# Templates dir is named "<major>.<minor>.<status>", e.g. "4.3.stable"
	# (Engine.get_version_info()["string"] is "4.3-stable (official)" —
	# NOT the dir name, so build it from the parts).
	var info: Dictionary = Engine.get_version_info()
	var version_dir: String = "%s.%s.%s" % [str(info.get("major", "")), str(info.get("minor", "")), str(info.get("status", ""))]
	var preferred: String = base + version_dir + "/android_source.zip"
	if FileAccess.file_exists(preferred):
		return preferred
	# Fallback: any version dir that has the zip (handles dev/renamed dirs).
	var dir := DirAccess.open(base)
	if dir == null:
		return ""
	for sub in dir.get_directories():
		var candidate: String = base + sub + "/android_source.zip"
		if FileAccess.file_exists(candidate):
			return candidate
	return ""


func _install_android_build_template() -> void:
	if FileAccess.file_exists(TEMPLATE_MARKER):
		return
	var zip_path: String = _find_android_source_zip()
	if zip_path.is_empty():
		print("[BinDecode] No android_source.zip in the export templates dir — Android build template not installed (install export templates first).")
		return
	var reader := ZIPReader.new()
	var err: Error = reader.open(zip_path)
	if err != OK:
		push_error("[BinDecode] Cannot open " + zip_path + " (error " + str(err) + ").")
		return
	var files: PackedStringArray = reader.get_files()
	var count := 0
	for entry in files:
		if entry.ends_with("/"):
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEMPLATE_DIR + "/" + entry))
			continue
		var dest: String = TEMPLATE_DIR + "/" + entry
		var parent: String = dest.get_base_dir()
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(parent))
		var data: PackedByteArray = reader.read_file(entry)
		if data.is_empty() and not entry.ends_with(".xml") and not entry.ends_with(".gradle") and not entry.ends_with(".properties"):
			# Empty read on a non-trivial file is suspicious, but zero-byte
			# files do exist in the template (e.g. empty dirs are not
			# entries); only warn, do not abort.
			print("[BinDecode] Warning: empty read for " + entry)
		var out := FileAccess.open(dest, FileAccess.WRITE)
		if out == null:
			push_error("[BinDecode] Cannot write " + dest + " — template install aborted.")
			reader.close()
			return
		out.store_buffer(data)
		out.close()
		count += 1
	reader.close()
	# ZIPReader does not preserve Unix permissions; gradlew must be executable.
	if OS.get_name() == "Linux" or OS.get_name() == "macOS":
		var gradlew_abs: String = ProjectSettings.globalize_path(TEMPLATE_DIR + "/gradlew")
		OS.execute("chmod", ["+x", gradlew_abs])
	print("[BinDecode] Installed Android build template from " + zip_path + " (" + str(count) + " files -> " + TEMPLATE_DIR + ")")


## Mirror ExportTemplateManager::get_android_template_identifier() from
## the Godot 4.3 source (editor/export/export_template_manager.cpp):
## a custom android_source_template preset option -> "<path> [<md5>]",
## otherwise the Godot version string (VERSION_FULL_CONFIG, e.g. "4.3.stable").
func _android_template_identifier() -> String:
	var custom := ""
	var cfg := ConfigFile.new()
	if cfg.load("res://export_presets.cfg") == OK:
		for section in cfg.get_sections():
			var value := str(cfg.get_value(section, "gradle_build/android_source_template", ""))
			if not value.is_empty():
				custom = value
				break
	if not custom.is_empty():
		return custom + " [" + FileAccess.get_md5(custom) + "]"
	var info: Dictionary = Engine.get_version_info()
	return "%s.%s.%s" % [str(info.get("major", "")), str(info.get("minor", "")), str(info.get("status", ""))]


## Write res://android/.build_version (and the empty .gdignore) if missing
## or wrong. Runs on every editor start, so templates installed by an
## older version of this plugin get fixed too.
func _ensure_build_version() -> void:
	if not FileAccess.file_exists(TEMPLATE_MARKER):
		return
	var want: String = _android_template_identifier()
	var have := ""
	if FileAccess.file_exists(BUILD_VERSION_PATH):
		var f := FileAccess.open(BUILD_VERSION_PATH, FileAccess.READ)
		if f != null:
			have = f.get_line().strip_edges()
			f.close()
	if have != want:
		var out := FileAccess.open(BUILD_VERSION_PATH, FileAccess.WRITE)
		if out == null:
			push_error("[BinDecode] Cannot write " + BUILD_VERSION_PATH)
		else:
			out.store_line(want)
			out.close()
			print("[BinDecode] Wrote " + BUILD_VERSION_PATH + " = \"" + want + "\"")
	if not FileAccess.file_exists(GDIGNORE_PATH):
		var g := FileAccess.open(GDIGNORE_PATH, FileAccess.WRITE)
		if g == null:
			push_error("[BinDecode] Cannot write " + GDIGNORE_PATH)
		else:
			g.store_line("")
			g.close()
