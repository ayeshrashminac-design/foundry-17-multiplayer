extends Node

signal finished(allowed: bool)

const CONFIG := "res://mvp/update_config.cfg"
const DOWNLOAD := "user://updates/foundry17_update.zip"
var current_version := "1.0.0"
var manifest_url := ""
var manifest: Dictionary = {}
var request: HTTPRequest
var layer: CanvasLayer
var message: Label
var progress: ProgressBar
var update_button: Button
var retry_button: Button
var exit_button: Button
var downloading := false

func begin() -> void:
	if Engine.is_editor_hint():
		finished.emit(true)
		return
	_load_config()
	_build_ui()
	_check()

func _load_config() -> void:
	var config := ConfigFile.new()
	if config.load(CONFIG) != OK: return
	current_version = str(config.get_value("update","current_version",current_version))
	manifest_url = str(config.get_value("update","manifest_url","")).strip_edges()

func _build_ui() -> void:
	layer = CanvasLayer.new()
	layer.layer = 200
	add_child(layer)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.015,0.025,0.035,0.98)
	layer.add_child(shade)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-260,-145)
	panel.size = Vector2(520,290)
	shade.add_child(panel)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation",14)
	panel.add_child(rows)
	var title := Label.new()
	title.text = "FOUNDRY 17  •  UPDATE SERVICE"
	title.add_theme_font_size_override("font_size",24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rows.add_child(title)
	message = Label.new()
	message.text = "Checking for the latest version…"
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.custom_minimum_size = Vector2(480,78)
	rows.add_child(message)
	progress = ProgressBar.new()
	progress.show_percentage = true
	progress.hide()
	rows.add_child(progress)
	update_button = Button.new()
	update_button.text = "UPDATE NOW"
	update_button.pressed.connect(_download)
	update_button.hide()
	rows.add_child(update_button)
	retry_button = Button.new()
	retry_button.text = "RETRY"
	retry_button.pressed.connect(_check)
	retry_button.hide()
	rows.add_child(retry_button)
	exit_button = Button.new()
	exit_button.text = "CANCEL / EXIT GAME"
	exit_button.pressed.connect(func(): get_tree().quit())
	exit_button.hide()
	rows.add_child(exit_button)
	request = HTTPRequest.new()
	request.timeout = 30.0
	request.request_completed.connect(_request_completed)
	add_child(request)

func _check() -> void:
	_set_buttons(false,false,false)
	message.text = "Checking for the latest version…"
	if not manifest_url.begins_with("https://"):
		_fail("Update service is not configured. This build cannot start safely.")
		return
	request.download_file = ""
	var error := request.request(manifest_url,["Cache-Control: no-cache"])
	if error != OK: _fail("Could not contact the update service.")

func _request_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if downloading:
		_download_completed(result,code)
		return
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_fail("The update server is unavailable. Internet access is required to verify this version.")
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not parsed is Dictionary:
		_fail("The update server returned an invalid response.")
		return
	manifest = parsed
	var latest := str(manifest.get("version","0.0.0"))
	if _version_compare(current_version,latest) >= 0:
		layer.queue_free()
		finished.emit(true)
		return
	message.text = "Update %s is required.\n%s\n\nYou must update before playing online." % [latest,str(manifest.get("notes","Stability and multiplayer update."))]
	_set_buttons(true,false,true)

func _download() -> void:
	var url := str(manifest.get("url","")).strip_edges()
	var checksum := str(manifest.get("sha256","")).to_lower()
	if not url.begins_with("https://") or checksum.length() != 64:
		_fail("This release manifest is incomplete or unsafe.")
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://updates"))
	downloading = true
	progress.value = 0
	progress.show()
	_set_buttons(false,false,true)
	message.text = "Downloading update inside the game…"
	request.download_file = DOWNLOAD
	var error := request.request(url)
	if error != OK:
		downloading = false
		_fail("Could not start the update download.")

func _process(_delta: float) -> void:
	if not downloading or not request: return
	var total := request.get_body_size()
	if total > 0: progress.value = float(request.get_downloaded_bytes()) / float(total) * 100.0

func _download_completed(result: int, code: int) -> void:
	downloading = false
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_fail("Update download failed. Check the connection and retry.")
		return
	var expected_size := int(manifest.get("size",0))
	var downloaded := FileAccess.open(DOWNLOAD,FileAccess.READ)
	var actual_size := downloaded.get_length() if downloaded else 0
	if expected_size > 0 and actual_size != expected_size:
		_fail("Update file is incomplete. Please retry.")
		return
	message.text = "Verifying update…"
	if _sha256(DOWNLOAD) != str(manifest.get("sha256","")).to_lower():
		_fail("Update verification failed. The file was not installed.")
		return
	_apply_windows_update()

func _sha256(path: String) -> String:
	var file := FileAccess.open(path,FileAccess.READ)
	if not file: return ""
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	while file.get_position() < file.get_length(): hash.update(file.get_buffer(mini(1048576,file.get_length()-file.get_position())))
	return hash.finish().hex_encode()

func _apply_windows_update() -> void:
	if OS.get_name() != "Windows":
		_fail("Automatic installation is currently available for Windows builds.")
		return
	var executable := OS.get_executable_path()
	var install_dir := executable.get_base_dir()
	var script_path := ProjectSettings.globalize_path("user://updates/apply_update.ps1")
	var script := "param([string]$Zip,[string]$Target,[string]$Exe,[int]$PidToWait)\n$ErrorActionPreference='Stop'\nWait-Process -Id $PidToWait -ErrorAction SilentlyContinue\n$stage=Join-Path $env:TEMP ('Foundry17Update_'+[guid]::NewGuid())\nExpand-Archive -LiteralPath $Zip -DestinationPath $stage -Force\nCopy-Item -Path (Join-Path $stage '*') -Destination $Target -Recurse -Force\nStart-Process -FilePath $Exe -WorkingDirectory $Target\nRemove-Item -LiteralPath $stage -Recurse -Force\n"
	var file := FileAccess.open(script_path,FileAccess.WRITE)
	if not file:
		_fail("Could not prepare the update installer.")
		return
	file.store_string(script)
	file.close()
	message.text = "Update verified. Restarting…"
	var pid := OS.create_process("powershell.exe",["-NoProfile","-ExecutionPolicy","Bypass","-File",script_path,ProjectSettings.globalize_path(DOWNLOAD),install_dir,executable,str(OS.get_process_id())])
	if pid <= 0:
		_fail("Could not launch the update installer.")
		return
	get_tree().quit()

func _fail(text: String) -> void:
	message.text = text + "\nThe game remains locked until version verification succeeds."
	progress.hide()
	_set_buttons(false,true,true)

func _set_buttons(update: bool, retry: bool, exit_game: bool) -> void:
	update_button.visible = update
	retry_button.visible = retry
	exit_button.visible = exit_game

func _version_compare(a: String, b: String) -> int:
	var left := a.split(".")
	var right := b.split(".")
	for i in maxi(left.size(),right.size()):
		var av := int(left[i]) if i < left.size() else 0
		var bv := int(right[i]) if i < right.size() else 0
		if av != bv: return 1 if av > bv else -1
	return 0
