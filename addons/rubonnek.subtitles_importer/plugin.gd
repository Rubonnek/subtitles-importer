#============================================================================
#  plugin.gd                                                                |
#============================================================================
#                         This file is part of:                             |
#                           SUBTITLE IMPORTER                               |
#           https://github.com/Rubonnek/subtitle-importer                   |
#============================================================================
# Copyright (c) 2025 Wilson Enrique Alvarez Torres                          |
#                                                                           |
# Permission is hereby granted, free of charge, to any person obtaining     |
# a copy of this software and associated documentation files (the           |
# "Software"), to deal in the Software without restriction, including       |
# without limitation the rights to use, copy, modify, merge, publish,       |
# distribute, sublicense, and/or sell copies of the Software, and to        |
# permit persons to whom the Software is furnished to do so, subject to     |
# the following conditions:                                                 |
#                                                                           |
# The above copyright notice and this permission notice shall be            |
# included in all copies or substantial portions of the Software.           |
#                                                                           |
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,           |
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF        |
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.    |
# IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY      |
# CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,      |
# TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE         |
# SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.                    |
#============================================================================

@tool
extends EditorPlugin
## Editor plugin for importing subtitle files.
##
## Provides import functionality for SRT, VTT, and LRC subtitle formats,
## and includes a tool menu item for injecting Subtitles into AnimationPlayer nodes.

var _m_subtitles_importer_import_plugin: EditorImportPlugin
var _m_success_dialog: AcceptDialog
var _m_error_dialog: AcceptDialog
const TOOL_MENU_ITEM_STRING: String = "Inject Subtitles into AnimationPlayer"
const ANIMATION_NAME: String = "subtitles"


func _enter_tree() -> void:
	var script_resource: Resource = get_script()
	var editor_import_plugin_gdscript: GDScript = ResourceLoader.load(script_resource.get_path().get_base_dir().path_join("subtitles_importer_import_plugin.gd"))
	_m_subtitles_importer_import_plugin = editor_import_plugin_gdscript.new()
	add_import_plugin(_m_subtitles_importer_import_plugin)

	# Create dialogs
	_m_success_dialog = AcceptDialog.new()
	_m_success_dialog.title = "Subtitle Injection Success"
	_m_success_dialog.ok_button_text = "OK"
	EditorInterface.get_base_control().add_child(_m_success_dialog)

	_m_error_dialog = AcceptDialog.new()
	_m_error_dialog.title = "Subtitle Injection Error"
	_m_error_dialog.ok_button_text = "OK"
	EditorInterface.get_base_control().add_child(_m_error_dialog)

	# Add tool menu item
	add_tool_menu_item(TOOL_MENU_ITEM_STRING, _on_inject_subtitles)


func _exit_tree() -> void:
	remove_import_plugin(_m_subtitles_importer_import_plugin)
	_m_subtitles_importer_import_plugin = null

	# Clean up dialogs
	if _m_success_dialog:
		_m_success_dialog.queue_free()
		_m_success_dialog = null
	if _m_error_dialog:
		_m_error_dialog.queue_free()
		_m_error_dialog = null

	# Remove tool menu item
	remove_tool_menu_item(TOOL_MENU_ITEM_STRING)


func _on_inject_subtitles() -> void:
	print("Injecting subtitles into AnimationPlayer...")

	# Get selected resources from FileSystem
	var selected_paths: PackedStringArray = EditorInterface.get_selected_paths()
	var subtitles: Subtitles = null

	# Find Subtitles from selected files
	for path: String in selected_paths:
		var file_extension : String = path.get_extension().to_lower()
		if file_extension in Subtitles.supported_extensions:
			var resource: Resource = load(path)
			if resource is Subtitles:
				subtitles = resource
				print("Found Subtitles: ", path)
				break

	# Get selected nodes from Scene tree
	var selected_nodes: Array[Node] = EditorInterface.get_selection().get_selected_nodes()
	var label_node: Control = null
	var animation_player: AnimationPlayer = null

	for node: Node in selected_nodes:
		if node is Label or node is RichTextLabel:
			label_node = node
			print("Found Label/RichTextLabel: ", node.name)
		elif node is AnimationPlayer:
			animation_player = node
			print("Found AnimationPlayer: ", node.name)

	# Validate selection
	if subtitles == null:
		printerr("ERROR: No Subtitles resource selected in FileSystem!")
		_show_error("No Subtitles resource selected in FileSystem!\n\nPlease select a file with any of the following extensions: " + str(Subtitles.supported_extensions))
		return

	if label_node == null:
		printerr("ERROR: No Label or RichTextLabel node selected in Scene tree!")
		_show_error("No Label or RichTextLabel node selected in Scene tree!\n\nPlease select a Label or RichTextLabel node.")
		return

	if animation_player == null:
		printerr("ERROR: No AnimationPlayer node selected in Scene tree!")
		_show_error("No AnimationPlayer node selected in Scene tree!\n\nPlease select an AnimationPlayer node.")
		return

	# Create the animation
	var success: bool = _create_subtitle_animation(subtitles, label_node, animation_player)

	if success:
		print("✓ Successfully created subtitle animation!")
		print("  Animation name: ", ANIMATION_NAME)
		print("  Duration: ", subtitles.get_total_duration(), " seconds")
		print("  Subtitle count: ", subtitles.get_entry_count())
		print("")
		print("You can now play the animation in the AnimationPlayer!")
		print("Note: Make sure the label is visible in your scene to see subtitles.")

		_show_success(
			"Successfully created subtitle animation!\n\n" +
			"Animation name: " + ANIMATION_NAME + "\n" +
			"Duration: " + str(subtitles.get_total_duration()) + " seconds\n" +
			"Subtitle count: " + str(subtitles.get_entry_count()) + "\n\n" +
			"You can now play the animation in the AnimationPlayer!\n" +
			"Note: Make sure the label is visible in your scene to see subtitles."
		)
	else:
		printerr("✗ Failed to create subtitle animation.")
		_show_error("Failed to create subtitle animation.\n\nPlease check the Output console for details.")


func _create_subtitle_animation(p_subtitles: Subtitles, p_label_node: Control, p_animation_player: AnimationPlayer) -> bool:
	if p_subtitles.get_entry_count() == 0:
		printerr("ERROR: Subtitles has no entries!")
		_show_error("Subtitles has no entries!\n\nThe selected subtitle file is empty.")
		return false

	# Create or get animation
	var animation: Animation
	if p_animation_player.has_animation(ANIMATION_NAME):
		print("Animation '", ANIMATION_NAME, "' already exists. Overwriting...")
		animation = p_animation_player.get_animation(ANIMATION_NAME)
		# Clear all tracks
		while animation.get_track_count() > 0:
			animation.remove_track(0)
	else:
		animation = Animation.new()
		var library: AnimationLibrary = null
		if p_animation_player.has_animation_library(""):
			library = p_animation_player.get_animation_library("")
		if library == null:
			library = AnimationLibrary.new()
			var _err1: Error = p_animation_player.add_animation_library("", library)
		var _err2: Error = library.add_animation(ANIMATION_NAME, animation)

	# Set animation length to the total duration of subtitles
	var total_duration: float = p_subtitles.get_total_duration()
	animation.length = total_duration

	# Get the node path from AnimationPlayer to Label
	var node_path: NodePath = p_animation_player.get_node(p_animation_player.get_root_node()).get_path_to(p_label_node)

	# Create text track
	var text_track_idx: int = _create_text_track(animation, node_path, p_subtitles)

	if text_track_idx < 0:
		printerr("ERROR: Failed to create text track!")
		return false

	print("Created track:")
	print("  - Text track (", text_track_idx, ") with ", p_subtitles.get_entry_count(), " keyframes")

	return true


func _create_text_track(p_animation: Animation, p_node_path: NodePath, p_subtitles: Subtitles) -> int:
	var track_idx: int = p_animation.add_track(Animation.TYPE_VALUE)
	p_animation.track_set_path(track_idx, String(p_node_path) + ":text")
	p_animation.track_set_interpolation_type(track_idx, Animation.INTERPOLATION_NEAREST)

	# Check if first subtitle starts at 0.0, if not add empty key at 0.0
	var first_start_time: float = p_subtitles.get_entry_start_time(0) if p_subtitles.get_entry_count() > 0 else 0.0
	if first_start_time > 0.0:
		var _key0: int = p_animation.track_insert_key(track_idx, 0.0, "")

	# Add keyframes for each subtitle entry using optimized accessors
	for i: int in range(p_subtitles.get_entry_count()):
		var start_time: float = p_subtitles.get_entry_start_time(i)
		var end_time: float = p_subtitles.get_entry_end_time(i)
		var text: String = p_subtitles.get_entry_text(i)

		# Set text at start time
		var _key1: int = p_animation.track_insert_key(track_idx, start_time, text)

		# Clear text at end time
		var _key2: int = p_animation.track_insert_key(track_idx, end_time, "")

	return track_idx


func _show_success(p_message: String) -> void:
	_m_success_dialog.dialog_text = p_message
	_m_success_dialog.popup_centered()


func _show_error(p_message: String) -> void:
	_m_error_dialog.dialog_text = p_message
	_m_error_dialog.popup_centered()
