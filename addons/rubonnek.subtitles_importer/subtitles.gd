#============================================================================
#  subtitles.gd                                                             |
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
extends Resource

class_name Subtitles
## A resource for storing and managing subtitle data from various subtitle file formats.[br]
## [br]
## Subtitles provides functionality for importing, parsing, and querying subtitle entries
## with timing and text information. It supports multiple subtitle formats including SRT, VTT,
## LRC, SSA/ASS, and many others. The class can parse subtitle files at runtime, query subtitles
## by time, and inject subtitle animations into [AnimationPlayer] nodes.
## [br]
## [b]Key Features:[/b][br]
## - Parse 15+ subtitle formats at runtime[br]
## - Query subtitles by timestamp or time range[br]
## - Create and inject animations for [AnimationPlayer][br]
## - Iterate through subtitle entries[br]
## - Support for HTML and ASS tag removal[br]
## [br]
## [b]Basic Usage:[/b]
## [codeblock]
## # Create and populate subtitles
## var subtitles = Subtitles.new()
## subtitles.add_entry(0.0, 2.0, "Hello, World!")
## subtitles.add_entry(2.5, 5.0, "Welcome to Godot!")
##
## # Query subtitle at specific time
## var text = subtitles.get_subtitle_at_time(1.0)
## print(text)  # Output: "Hello, World!"
##
## # Inject into AnimationPlayer
## var result = subtitles.inject_animation("subtitles", animation_player, label_node)
## if result == OK:
##     print("Animation injected successfully!")
## [/codeblock]
## [br]
## [b]Supported Formats:[/b][br]
## [br]SRT, VTT, LRC, SSA/ASS, SBV, TTML/DFXP, SCC, SUB (MicroDVD), SMI/SAMI,
## [br]EBU-STL, TTXT, MPL2, TMP (TMPlayer), Adobe Encore, Transtation

# Internal array of subtitle entries stored as dictionaries with start_time, end_time, and text keys
@export var _entries: Array[Dictionary] = []

## Array of supported subtitle file extensions.[br]
## [br]
## Contains all subtitle formats that can be imported and parsed by this plugin.
## Use this to check if a file extension is supported before attempting to load it.
static var supported_extensions: PackedStringArray = PackedStringArray(
	[
		"srt", # SubRip
		"vtt", # WebVTT
		"lrc", # LRC (Lyrics)
		"ssa", # SubStation Alpha
		"ass", # Advanced SubStation Alpha
		"sbv", # YouTube subtitles
		"ttml", # Timed Text Markup Language
		"dfxp", # Distribution Format Exchange Profile (same as TTML, older name)
		"scc", # Scenarist Closed Caption
		"sub", # MicroDVD
		"smi", # SAMI
		"sami", # SAMI (alternate extension)
		"stl", # EBU-STL (European Broadcasting Union Subtitling)
		"ttxt", # MPEG-4 TTXT (3GPP Timed Text)
		"mpl", # MPL2 (MPSub)
		"tmp", # TMPlayer
		"encore", # Adobe Encore
		"transtation", # Transtation
	],
)

# Cached regex for HTML tag removal (compiled once on first use for performance)
static var _html_tag_regex: RegEx = null

# Cached regex for SSA/ASS formatting tag removal
static var _ass_tags_regex: RegEx = null

# Cached regex for SUB (MicroDVD) formatting code removal
static var _sub_formatting_regex: RegEx = null

# Cached regex for LRC timestamp parsing ([mm:ss.xx] format)
static var _lrc_timestamp_regex: RegEx = null

# Iterator needle for tracking current position during for-in loops
var _iter_needle: int = 0

# Cached regex for SMI/SAMI <sync> tag matching
static var _smi_sync_regex: RegEx = null
# Cached regex for SMI/SAMI <p> tag matching
static var _smi_p_regex: RegEx = null
# Cached regex for SMI/SAMI </p> tag matching
static var _smi_p_close_regex: RegEx = null
# Cached regex for SMI/SAMI <br> tag matching
static var _smi_br_regex: RegEx = null
# Cached regex for SMI/SAMI HTML tag removal
static var _smi_tag_regex: RegEx = null
# Cached regex for SMI/SAMI HTML entity matching (&name;)
static var _smi_entity_regex: RegEx = null
# Cached regex for SMI/SAMI hexadecimal HTML entity matching (&#xHHHH;)
static var _smi_hex_entity_regex: RegEx = null

# Cached character map for SCC (Scenarist Closed Caption) byte-to-character decoding
static var _scc_char_map: Dictionary = { }

## Tolerance for timestamp comparison (1 millisecond)
const TIMESTAMP_TOLERANCE: float = 0.001

## Overlap detection threshold (50 milliseconds)
const OVERLAP_THRESHOLD: float = 0.05

## Maximum number of overlap warnings to display
const MAX_OVERLAP_WARNINGS: int = 5


## Returns the subtitle text that should be displayed at the given time.[br]
## [br]
## Searches through all subtitle entries and returns the text of the entry
## that is active at the specified time. If no subtitle is active at that time,
## returns an empty string.[br]
## [br]
## [b]Example:[/b]
## [codeblock]
## var subtitles = Subtitles.new()
## subtitles.add_entry(1.0, 3.0, "First subtitle")
## print(subtitles.get_subtitle_at_time(2.0))  # Output: "First subtitle"
## print(subtitles.get_subtitle_at_time(5.0))  # Output: ""
## [/codeblock]
func get_subtitle_at_time(p_time: float) -> String:
	for entry_dict: Dictionary in _entries:
		var start: float = entry_dict.get(SubtitleEntry._key.START_TIME, 0.0)
		var end: float = entry_dict.get(SubtitleEntry._key.END_TIME, 0.0)
		if p_time >= start and p_time <= end:
			return entry_dict.get(SubtitleEntry._key.TEXT, "")
	return ""


## Returns the entry index (ID) of the subtitle active at the given time.[br]
## [br]
## Searches through all subtitle entries and returns the index of the entry
## that is active at the specified time. Returns [code]-1[/code] if no subtitle
## is active at that time.[br]
## [br]
## [b]Returns:[/b] The zero-based index of the active subtitle, or [code]-1[/code] if none.
func get_entry_id_at_time(p_time: float) -> int:
	for i: int in _entries.size():
		var entry_dict: Dictionary = _entries[i]
		var start: float = entry_dict.get(SubtitleEntry._key.START_TIME, 0.0)
		var end: float = entry_dict.get(SubtitleEntry._key.END_TIME, 0.0)
		if p_time >= start and p_time <= end:
			return i
	return -1


## Returns all subtitle entries that overlap with the given time range.[br]
## [br]
## Collects and returns all subtitle entries whose time ranges overlap with the
## specified time range [code][p_start, p_end][/code]. An entry overlaps if its start
## time is before or at [param p_end] and its end time is after or at [param p_start].[br]
## [br]
## [b]Returns:[/b] An [Array] of [Dictionary] entries containing subtitle data.
func get_subtitles_in_range(p_start: float, p_end: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry_dict: Dictionary in _entries:
		var entry_start: float = entry_dict.get(SubtitleEntry._key.START_TIME, 0.0)
		var entry_end: float = entry_dict.get(SubtitleEntry._key.END_TIME, 0.0)
		if entry_start <= p_end and entry_end >= p_start:
			result.append(entry_dict)
	return result


## Returns the total duration of all subtitles.[br]
## [br]
## Returns the end time of the last subtitle entry, representing the total duration
## of the subtitle track. Returns [code]0.0[/code] if there are no entries.[br]
## [br]
## [b]Returns:[/b] The end time in seconds of the last subtitle entry.
func get_total_duration() -> float:
	if _entries.is_empty():
		return 0.0
	return _entries[-1].get(SubtitleEntry._key.END_TIME, 0.0)


## Returns the number of subtitle entries in this resource.
func get_entry_count() -> int:
	return _entries.size()


## Adds a new subtitle entry to this resource.[br]
## [br]
## Creates and appends a new subtitle entry with the specified timing and text.
## The entry will be added to the end of the internal entries array.
func add_entry(p_start_time: float, p_end_time: float, p_text: String) -> void:
	_entries.append(
		{
			SubtitleEntry._key.START_TIME: p_start_time,
			SubtitleEntry._key.END_TIME: p_end_time,
			SubtitleEntry._key.TEXT: p_text,
		},
	)


## Returns a reference to the internal entries array.[br]
## [br]
## [b]Warning:[/b] Modifying the returned array directly will affect the subtitle data.
func get_entries() -> Array[Dictionary]:
	return _entries


## Sets the subtitle entries array.[br]
## [br]
## Replaces the current subtitle entries with the provided array. Each entry should
## be a [Dictionary] containing subtitle timing and text data.
func set_entries(p_entries: Array[Dictionary]) -> void:
	_entries = p_entries


## Clears all subtitle entries from this resource.[br]
## [br]
## Removes all subtitle entries, resetting the resource to an empty state.[br]
func clear_entries() -> void:
	_entries.clear()


## Creates an [Animation] from the subtitle data for use with [AnimationPlayer].[br]
## [br]
## Generates an animation with keyframes for each subtitle entry. The animation uses
## a VALUE track with DISCRETE update mode and NEAREST interpolation to ensure subtitle
## text changes instantly at keyframes.[br]
## [br]
## [b]Note:[/b] The caller must set the track path using [method Animation.track_set_path]
## to target the correct label node's text property.[br]
## [br]
## [b]Returns:[/b] A new [Animation] object, or [code]null[/code] if there are no entries.[br]
## [br]
## [b]Example:[/b]
## [codeblock]
## var animation = subtitles.create_animation()
## if animation:
##     animation.track_set_path(0, "Label:text")
##     animation_player.get_animation_library("").add_animation("subtitles", animation)
## [/codeblock]
func create_animation() -> Animation:
	if get_entry_count() == 0:
		push_error("Subtitles: Subtitles has no entries!")
		return null

	# Create new animation
	var animation: Animation = Animation.new()

	# Set animation length to the total duration of subtitles
	var total_duration: float = get_total_duration()
	animation.set_length(total_duration)

	# Create text track (path will be set by caller)
	var track_idx: int = animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_interpolation_type(track_idx, Animation.INTERPOLATION_NEAREST)
	animation.value_track_set_update_mode(track_idx, Animation.UPDATE_DISCRETE)

	# Check if first subtitle starts at 0.0, if not add empty key at 0.0
	var first_start_time: float = get_entry_start_time(0) if get_entry_count() > 0 else 0.0
	if first_start_time > 0.0:
		var _key0: int = animation.track_insert_key(track_idx, 0.0, "")

	# Add keyframes for each subtitle entry using optimized accessors
	for i: int in get_entry_count():
		var start_time: float = get_entry_start_time(i)
		var end_time: float = get_entry_end_time(i)
		var text: String = get_entry_text(i)

		# Set text at start time
		var _key1: int = animation.track_insert_key(track_idx, start_time, text)

		# Clear text at end time
		var _key2: int = animation.track_insert_key(track_idx, end_time, "")

	return animation


## Injects a subtitle animation into an [AnimationPlayer].[br]
## [br]
## Creates a subtitle animation and adds it to the specified [AnimationPlayer]. The animation
## will control the text property of the provided label node ([Label] or [RichTextLabel]).
## If an animation with the same name already exists, only the track for the specified label
## will be removed and replaced, preserving other tracks in the animation.[br]
## [br]
## This method can be called at runtime to dynamically inject subtitle animations.[br]
## [br]
## [b]Returns:[/b] [constant OK] on success, or one of the following error codes:[br]
## - [constant ERR_INVALID_DATA]: The subtitle resource has no entries.[br]
## - [constant ERR_INVALID_PARAMETER]: Invalid [param p_animation_player] or [param p_label].[br]
## - [constant ERR_CANT_CREATE]: Failed to create the animation. [br]
## [br]
## [b]Example:[/b]
## [codeblock]
## var subtitles = load("res://subtitles/dialog.srt")
## var result = subtitles.inject_animation("subtitles", $AnimationPlayer, $Label)
## if result == OK:
##     $AnimationPlayer.play("subtitles")
## else:
##     push_error("Failed to inject animation: ", result)
## [/codeblock]
func inject_animation(p_animation_name: String, p_animation_player: AnimationPlayer, p_label: Control) -> Error:
	if get_entry_count() == 0:
		push_error("Subtitles: Subtitles has no entries!")
		return ERR_INVALID_DATA

	if p_animation_player == null:
		push_error("Subtitles: AnimationPlayer is null!")
		return ERR_INVALID_PARAMETER

	if p_label == null:
		push_error("Subtitles: Label node is null!")
		return ERR_INVALID_PARAMETER

	if not (p_label is Label or p_label is RichTextLabel):
		push_error("Subtitles: Label node must be Label or RichTextLabel!")
		return ERR_INVALID_PARAMETER

	# Get the node path from AnimationPlayer to Label
	var node_path: NodePath = p_animation_player.get_node(p_animation_player.get_root_node()).get_path_to(p_label)
	var text_property_path: String = str(node_path) + ":text"

	# Create the animation
	var new_animation: Animation = create_animation()

	if new_animation == null:
		push_error("Subtitles: Failed to create animation from subtitles!")
		return ERR_CANT_CREATE

	# Set the track path for the text property
	if new_animation.get_track_count() > 0:
		new_animation.track_set_path(0, text_property_path)

	# Handle existing animation
	var animation: Animation
	if p_animation_player.has_animation(p_animation_name):
		animation = p_animation_player.get_animation(p_animation_name)

		# Only remove the track for the specific label node
		for i: int in range(animation.get_track_count() - 1, -1, -1):
			if str(animation.track_get_path(i)) == text_property_path:
				animation.remove_track(i)

		# Copy the new animation data into the existing animation
		animation.set_length(new_animation.get_length())
		for i: int in new_animation.get_track_count():
			var track_idx: int = animation.add_track(new_animation.track_get_type(i))
			animation.track_set_path(track_idx, new_animation.track_get_path(i))
			animation.track_set_interpolation_type(track_idx, new_animation.track_get_interpolation_type(i))
			animation.value_track_set_update_mode(track_idx, new_animation.value_track_get_update_mode(i))

			# Copy all keys from the new track
			for key_idx: int in new_animation.track_get_key_count(i):
				var key_time: float = new_animation.track_get_key_time(i, key_idx)
				var key_value: Variant = new_animation.track_get_key_value(i, key_idx)
				animation.track_insert_key(track_idx, key_time, key_value)
	else:
		# Add the new animation to the AnimationPlayer
		animation = new_animation
		var library: AnimationLibrary = null
		if p_animation_player.has_animation_library(""):
			library = p_animation_player.get_animation_library("")
		var err: Error = OK
		if library == null:
			library = AnimationLibrary.new()
			err = p_animation_player.add_animation_library("", library)
			if err != OK:
				push_error("Subtitles: Failed to add animation library: ", err)
				return err
		err = library.add_animation(p_animation_name, animation)
		if err != OK:
			push_error("Subtitles: Failed to add animation '", p_animation_name, "': ", err)
			return err

	return OK


## Returns the start time of an entry at the given index.[br]
## [br]
## [b]Returns:[/b] The start time in seconds, or [code]0.0[/code] if the index is out of bounds.
func get_entry_start_time(p_entry_id: int) -> float:
	if p_entry_id < 0 or p_entry_id >= _entries.size():
		return 0.0
	return _entries[p_entry_id].get(SubtitleEntry._key.START_TIME, 0.0)


## Returns the end time of an entry at the given index.[br]
## [br]
## [b]Returns:[/b] The end time in seconds, or [code]0.0[/code] if the index is out of bounds.
func get_entry_end_time(p_entry_id: int) -> float:
	if p_entry_id < 0 or p_entry_id >= _entries.size():
		return 0.0
	return _entries[p_entry_id].get(SubtitleEntry._key.END_TIME, 0.0)


## Returns the text of an entry at the given index.[br]
## [br]
## [b]Returns:[/b] The subtitle text, or an empty string if the index is out of bounds.
func get_entry_text(p_entry_id: int) -> String:
	if p_entry_id < 0 or p_entry_id >= _entries.size():
		return ""
	return _entries[p_entry_id].get(SubtitleEntry._key.TEXT, "")


## Returns a [SubtitleEntry] wrapper for the entry at the given index.[br]
## [br]
## [b]Returns:[/b] A [SubtitleEntry] object, or [code]null[/code] if the index is out of bounds.
func get_subtitle_entry(p_entry_id: int) -> SubtitleEntry:
	if p_entry_id < 0 or p_entry_id >= _entries.size():
		return null
	return SubtitleEntry.new(_entries[p_entry_id])


# Initializes the iterator for for-in loops.
#
# Enables iteration through subtitle entries using [code]for entry in subtitles[/code] syntax.
# This is called automatically by Godot when using for-in loops.
#
# [b]Example:[/b]
# [codeblock]
# for entry in subtitles:
#     print(entry.get_text())
# [/codeblock]
#
# [b]Returns:[/b] [code]true[/code] if there are entries to iterate, [code]false[/code] otherwise.
func _iter_init(_p_args: Array) -> bool:
	_iter_needle = 0
	return _iter_needle < _entries.size()


# Advances to the next entry during iteration.
#
# Called automatically by Godot during for-in loops to move to the next entry.
#
# [b]Returns:[/b] [code]true[/code] if there are more entries, [code]false[/code] otherwise.
func _iter_next(_p_args: Array) -> bool:
	_iter_needle += 1
	return _iter_needle < _entries.size()


# Returns the current [SubtitleEntry] at the iterator position.
#
# Called automatically by Godot during for-in loops to retrieve the current entry.
#
# [b]Returns:[/b] A [SubtitleEntry] wrapper for the current subtitle entry.
func _iter_get(_p_args: Variant) -> SubtitleEntry:
	return SubtitleEntry.new(_entries[_iter_needle])


## Parses SubRip (SRT) subtitle content at runtime.[br]
## [br]
## Parses SRT format subtitle content and populates this resource with the parsed entries.
## Optionally removes HTML and ASS formatting tags from the subtitle text.[br]
## [br]
## [b]Returns:[/b] [constant OK] on success, or [constant ERR_PARSE_ERROR] on failure.
func parse_srt(p_content: String, p_remove_html_tags: bool = true, p_remove_ass_tags: bool = true) -> Error:
	var parsed_entries: Array[Dictionary] = __parse_srt(p_content, "", p_remove_html_tags, p_remove_ass_tags)

	if parsed_entries.is_empty():
		return ERR_PARSE_ERROR

	_entries = parsed_entries
	return OK


## Parses WebVTT (VTT) subtitle content at runtime.[br]
## [br]
## Parses WebVTT format subtitle content and populates this resource with the parsed entries.
## Optionally removes HTML and ASS formatting tags from the subtitle text.[br]
## [br]
## [b]Returns:[/b] [constant OK] on success, or [constant ERR_PARSE_ERROR] on failure.
func parse_vtt(p_content: String, p_remove_html_tags: bool = true, p_remove_ass_tags: bool = true) -> Error:
	var parsed_entries: Array[Dictionary] = __parse_vtt(p_content, "", p_remove_html_tags, p_remove_ass_tags)

	if parsed_entries.is_empty():
		return ERR_PARSE_ERROR

	_entries = parsed_entries
	return OK


## Parses LRC (lyrics) subtitle content at runtime.[br]
## [br]
## Parses LRC format subtitle content (commonly used for song lyrics) and populates
## [br]
## this resource with the parsed entries. Optionally removes HTML and ASS formatting tags.[br]
## [b]Returns:[/b] [constant OK] on success, or [constant ERR_PARSE_ERROR] on failure.
func parse_lrc(p_content: String, p_remove_html_tags: bool = true, p_remove_ass_tags: bool = true) -> Error:
	var parsed_entries: Array[Dictionary] = __parse_lrc(p_content, "", p_remove_html_tags, p_remove_ass_tags)

	if parsed_entries.is_empty():
		return ERR_PARSE_ERROR

	_entries = parsed_entries
	return OK


## Parses SubStation Alpha (SSA/ASS) subtitle content at runtime.[br]
## [br]
## Parses SSA or ASS format subtitle content and populates this resource with the parsed entries.
## Optionally removes HTML and ASS formatting tags from the subtitle text.[br]
## [br]
## [b]Returns:[/b] [constant OK] on success, or [constant ERR_PARSE_ERROR] on failure.
func parse_ssa(p_content: String, p_remove_html_tags: bool = true, p_remove_ass_tags: bool = true) -> Error:
	var parsed_entries: Array[Dictionary] = __parse_ssa(p_content, "", p_remove_html_tags, p_remove_ass_tags)

	if parsed_entries.is_empty():
		return ERR_PARSE_ERROR

	_entries = parsed_entries
	return OK


## Parses YouTube SBV subtitle content at runtime.[br]
## [br]
## Parses SBV format subtitle content (YouTube subtitle format) and populates this resource
## with the parsed entries. Optionally removes HTML and ASS formatting tags.[br]
## [br]
## [b]Returns:[/b] [constant OK] on success, or [constant ERR_PARSE_ERROR] on failure.
func parse_sbv(p_content: String, p_remove_html_tags: bool = true, p_remove_ass_tags: bool = true) -> Error:
	var parsed_entries: Array[Dictionary] = __parse_sbv(p_content, "", p_remove_html_tags, p_remove_ass_tags)

	if parsed_entries.is_empty():
		return ERR_PARSE_ERROR

	_entries = parsed_entries
	return OK


## Parses TTML/DFXP subtitle content at runtime.[br]
## [br]
## Parses TTML (Timed Text Markup Language) or DFXP format subtitle content and populates
## this resource with the parsed entries. DFXP (Distribution Format Exchange Profile) is
## the same format as TTML, just an older name. Optionally removes HTML and ASS formatting tags.[br]
## [br]
## [b]Returns:[/b] [constant OK] on success, or [constant ERR_PARSE_ERROR] on failure.
func parse_ttml(p_content: String, p_remove_html_tags: bool = true, p_remove_ass_tags: bool = true) -> Error:
	var parsed_entries: Array[Dictionary] = __parse_ttml(p_content, "", p_remove_html_tags, p_remove_ass_tags)

	if parsed_entries.is_empty():
		return ERR_PARSE_ERROR

	_entries = parsed_entries
	return OK


## Parses Scenarist Closed Caption (SCC) subtitle content at runtime.[br]
## [br]
## Parses SCC format subtitle content and populates this resource with the parsed entries.
## Optionally removes HTML and ASS formatting tags.[br]
## [br]
## [b]Returns:[/b] [constant OK] on success, or [constant ERR_PARSE_ERROR] on failure.
func parse_scc(p_content: String, p_framerate: float = 29.97, p_remove_html_tags: bool = true, p_remove_ass_tags: bool = true) -> Error:
	var parsed_entries: Array[Dictionary] = __parse_scc(p_content, p_framerate, "", p_remove_html_tags, p_remove_ass_tags)

	if parsed_entries.is_empty():
		return ERR_PARSE_ERROR

	_entries = parsed_entries
	return OK


## Parses MicroDVD (SUB) subtitle content at runtime.[br]
## [br]
## Parses SUB (MicroDVD) format subtitle content and populates this resource with the parsed
## entries. This is a frame-based format that requires a framerate for conversion to seconds.
## Optionally removes HTML and ASS formatting tags.[br]
## [br]
## [b]Returns:[/b] [constant OK] on success, or [constant ERR_PARSE_ERROR] on failure.
func parse_sub(p_content: String, p_framerate: float = 25.0, p_remove_html_tags: bool = true, p_remove_ass_tags: bool = true) -> Error:
	var parsed_entries: Array[Dictionary] = __parse_sub(p_content, p_framerate, "", p_remove_html_tags, p_remove_ass_tags)

	if parsed_entries.is_empty():
		return ERR_PARSE_ERROR

	_entries = parsed_entries
	return OK


## Parses SAMI (Synchronized Accessible Media Interchange) subtitle content at runtime.[br]
## [br]
## SAMI is an XML-based subtitle format developed by Microsoft. It supports both .smi and .sami file extensions.[br]
## The format uses [code]<sync start="timestamp">[/code] tags to define subtitle timing and [code]<p>[/code] tags for content.[br]
## [br]
## [b]Format features:[/b][br]
## - Case-insensitive XML tags (SYNC/sync, P/p, etc.)[br]
## - Timestamps in milliseconds without quotes, or with single/double quotes[br]
## - HTML entities (&amp;, &lt;, &#169;, &#x2122;, etc.) are automatically decoded[br]
## - [code]<br>[/code] or [code]<br/>[/code] tags are converted to newlines[br]
## - Empty entries (containing only &nbsp; or whitespace) are automatically skipped[br]
## - Excessive whitespace is normalized while preserving intentional line breaks[br]
## [br]
## [b]Example SAMI format:[/b]
## [codeblock]
## <sami>
##  <body>
##   <sync start="0">
##    <p>First subtitle</p>
##   </sync>
##   <sync start="2500">
##    <p>Second subtitle<br/>with line break</p>
##   </sync>
##  </body>
## </sami>
## [/codeblock]
## [br]
## [b]Returns:[/b] [constant OK] on success, or [constant ERR_PARSE_ERROR] on failure.
func parse_smi(p_content: String, p_remove_html_tags: bool = true, p_remove_ass_tags: bool = true) -> Error:
	var parsed_entries: Array[Dictionary] = __parse_smi(p_content, "", p_remove_html_tags, p_remove_ass_tags)

	if parsed_entries.is_empty():
		return ERR_PARSE_ERROR

	_entries = parsed_entries
	return OK


## Parses EBU-STL (European Broadcasting Union Subtitling) binary data at runtime.[br]
## [br]
## Parses EBU-STL binary subtitle data and populates this resource with the parsed entries.
## Unlike other formats, EBU-STL is a binary format that requires [PackedByteArray] input.
## Optionally removes HTML and ASS formatting tags.[br]
## [br]
## [b]Note:[/b] This method requires binary data as [PackedByteArray], not a string.[br]
## [br]
## [b]Returns:[/b] [constant OK] on success, or [constant ERR_PARSE_ERROR] on failure.
func parse_ebu_stl(p_bytes: PackedByteArray, p_remove_html_tags: bool = true, p_remove_ass_tags: bool = true) -> Error:
	var entries: Array[Dictionary] = __parse_ebu_stl(p_bytes, "", p_remove_html_tags, p_remove_ass_tags)

	if entries.is_empty():
		return ERR_PARSE_ERROR

	set_entries(entries)
	return OK


## Parses MPEG-4 Timed Text (TTXT) subtitle content at runtime.[br]
## [br]
## Parses 3GPP TTXT format subtitle content and populates this resource with the parsed entries.
## Optionally removes HTML and ASS formatting tags.[br]
## [br]
## [b]Returns:[/b] [constant OK] on success, or [constant ERR_PARSE_ERROR] on failure.[br]
func parse_ttxt(p_content: String, p_remove_html_tags: bool = true, p_remove_ass_tags: bool = true) -> Error:
	var parsed_entries: Array[Dictionary] = __parse_ttxt(p_content, "", p_remove_html_tags, p_remove_ass_tags)

	if parsed_entries.is_empty():
		return ERR_PARSE_ERROR

	_entries = parsed_entries
	return OK


## Parses MPL2 (MPSub) subtitle content at runtime.[br]
## [br]
## Parses MPL2 format subtitle content and populates this resource with the parsed entries.
## Optionally removes HTML and ASS formatting tags.[br]
## [br]
## [b]Returns:[/b] [constant OK] on success, or [constant ERR_PARSE_ERROR] on failure.
func parse_mpl2(p_content: String, p_framerate: float = 25.0, p_remove_html_tags: bool = true, p_remove_ass_tags: bool = true) -> Error:
	var parsed_entries: Array[Dictionary] = __parse_mpl2(p_content, "", p_remove_html_tags, p_remove_ass_tags)

	if parsed_entries.is_empty():
		return ERR_PARSE_ERROR

	_entries = parsed_entries
	return OK


## Parses TMPlayer (TMP) subtitle content at runtime.[br]
## [br]
## Parses TMPlayer format subtitle content and populates this resource with the parsed entries.
## Optionally removes HTML and ASS formatting tags.[br]
## [br]
## [b]Returns:[/b] [constant OK] on success, or [constant ERR_PARSE_ERROR] on failure.[br]
func parse_tmp(p_content: String, p_remove_html_tags: bool = true, p_remove_ass_tags: bool = true) -> Error:
	var parsed_entries: Array[Dictionary] = __parse_tmp(p_content, "", p_remove_html_tags, p_remove_ass_tags)

	if parsed_entries.is_empty():
		return ERR_PARSE_ERROR

	_entries = parsed_entries
	return OK


## Parses Adobe Encore subtitle content at runtime.[br]
## [br]
## Parses Adobe Encore format subtitle content and populates this resource with the parsed entries.
## This is a frame-based format that requires a framerate for conversion to seconds.
## Optionally removes HTML and ASS formatting tags.[br]
## [br]
## [b]Returns:[/b] [constant OK] on success, or [constant ERR_PARSE_ERROR] on failure.[br]
func parse_encore(p_content: String, p_framerate: float = 25.0, p_remove_html_tags: bool = true, p_remove_ass_tags: bool = true) -> Error:
	var parsed_entries: Array[Dictionary] = __parse_encore(p_content, p_framerate, "", p_remove_html_tags, p_remove_ass_tags)

	if parsed_entries.is_empty():
		return ERR_PARSE_ERROR

	_entries = parsed_entries
	return OK


## Parses Transtation subtitle content at runtime.[br]
## [br]
## Parses Transtation format subtitle content and populates this resource with the parsed entries.
## This is a frame-based format that requires a framerate for conversion to seconds.
## Optionally removes HTML and ASS formatting tags.[br]
## [br]
## [b]Returns:[/b] [constant OK] on success, or [constant ERR_PARSE_ERROR] on failure.[br]
func parse_transtation(p_content: String, p_framerate: float = 30.0, p_remove_html_tags: bool = true, p_remove_ass_tags: bool = true) -> Error:
	var parsed_entries: Array[Dictionary] = __parse_transtation(p_content, p_framerate, "", p_remove_html_tags, p_remove_ass_tags)

	if parsed_entries.is_empty():
		return ERR_PARSE_ERROR

	_entries = parsed_entries
	return OK


## Parses subtitle content from a string with automatic format detection.[br]
## [br]
## Parses subtitle content based on the specified format extension and populates this resource
## with the parsed entries. Automatically selects the appropriate parser for the given format.
## For frame-based formats (SUB, SCC, Encore, Transtation), provide the appropriate framerate.[br]
## [br]
## [b]Supported formats:[/b][br]
## srt, vtt, lrc, ssa, ass, sbv, ttml, dfxp, scc, sub, smi, sami, stl, ttxt, mpl, tmp, encore, transtation[br]
## [br]
## [b]Returns:[/b] [constant OK] on success, [constant ERR_FILE_UNRECOGNIZED] for unsupported formats,
## [constant ERR_INVALID_DATA] for EBU-STL (which requires binary data), or [constant ERR_PARSE_ERROR]
## on parsing failure.
func parse_from_string(p_content: String, p_extension: String, p_framerate: float = 25.0, p_file_path: String = "", p_remove_html_tags: bool = true, p_remove_ass_tags: bool = true) -> Error:
	var entries: Array[Dictionary] = []
	match p_extension.to_lower():
		"srt":
			entries = __parse_srt(p_content, p_file_path, p_remove_html_tags, p_remove_ass_tags)
		"vtt":
			entries = __parse_vtt(p_content, p_file_path, p_remove_html_tags, p_remove_ass_tags)
		"lrc":
			entries = __parse_lrc(p_content, p_file_path, p_remove_html_tags, p_remove_ass_tags)
		"ssa", "ass":
			entries = __parse_ssa(p_content, p_file_path, p_remove_html_tags, p_remove_ass_tags)
		"sbv":
			entries = __parse_sbv(p_content, p_file_path, p_remove_html_tags, p_remove_ass_tags)
		"ttml", "dfxp":
			entries = __parse_ttml(p_content, p_file_path, p_remove_html_tags, p_remove_ass_tags)
		"scc":
			entries = __parse_scc(p_content, p_framerate, p_file_path, p_remove_html_tags, p_remove_ass_tags)
		"sub":
			entries = __parse_sub(p_content, p_framerate, p_file_path, p_remove_html_tags, p_remove_ass_tags)
		"smi", "sami":
			entries = __parse_smi(p_content, p_file_path, p_remove_html_tags, p_remove_ass_tags)
		"stl":
			printerr("parse_from_string: EBU-STL requires binary data, use parse_ebu_stl() directly with PackedByteArray")
			return ERR_INVALID_DATA
		"ttxt":
			entries = __parse_ttxt(p_content, p_file_path, p_remove_html_tags, p_remove_ass_tags)
		"mpl":
			entries = __parse_mpl2(p_content, p_file_path, p_remove_html_tags, p_remove_ass_tags)
		"tmp":
			entries = __parse_tmp(p_content, p_file_path, p_remove_html_tags, p_remove_ass_tags)
		"encore":
			entries = __parse_encore(p_content, p_framerate, p_file_path, p_remove_html_tags, p_remove_ass_tags)
		"transtation":
			entries = __parse_transtation(p_content, p_framerate, p_file_path, p_remove_html_tags, p_remove_ass_tags)
		_:
			printerr("Unsupported subtitle format: ", p_extension)
			return ERR_FILE_UNRECOGNIZED

	if entries.is_empty():
		return ERR_PARSE_ERROR

	set_entries(entries)
	return OK


## Loads and parses a subtitle file at runtime.[br]
## [br]
## Loads a subtitle file from disk and parses it based on the file extension. Automatically
## detects the format and selects the appropriate parser. For frame-based formats (SUB, SCC,
## Encore, Transtation), provide the appropriate framerate.[br]
## [br]
## [b]Returns:[/b] [constant OK] on success, or an appropriate error code on failure.
func load_from_file(p_file_path: String, p_framerate: float = 25.0, p_remove_html_tags: bool = true, p_remove_ass_tags: bool = true) -> Error:
	var file: FileAccess = FileAccess.open(p_file_path, FileAccess.READ)
	if file == null:
		return FileAccess.get_open_error()

	var extension: String = p_file_path.get_extension().to_lower()

	var result: Error
	if extension == "stl":
		var content_bytes: PackedByteArray = file.get_buffer(file.get_length())
		file.close()
		result = parse_ebu_stl(content_bytes, p_remove_html_tags, p_remove_ass_tags)
	else:
		var content: String = file.get_as_text()
		file.close()
		result = parse_from_string(content, extension, p_framerate, p_file_path, p_remove_html_tags, p_remove_ass_tags)

	return result

# ============================================================================
# PRIVATE PARSER IMPLEMENTATIONS
# ============================================================================


# Parses SubRip (SRT) subtitle content and returns an array of subtitle entry dictionaries.
# Each block is separated by blank lines and contains: index, timestamps, and text lines.
func __parse_srt(p_content: String, p_file_path: String = "", p_remove_html_tags: bool = true, p_remove_ass_tags: bool = true) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var blocks: PackedStringArray = __normalize_line_endings(p_content).split("\n\n")

	var block_count: int = blocks.size()
	for block_idx: int in block_count:
		var block: String = blocks[block_idx].strip_edges()
		var block_len: int = block.length()
		if block_len == 0:
			continue

		var lines: PackedStringArray = block.split("\n")
		var line_count: int = lines.size()
		if line_count < 3:
			continue

		var timing_line: String = lines[1].strip_edges()

		# SRT format: HH:MM:SS,mmm --> HH:MM:SS,mmm
		# Optimized: find arrow position directly
		var arrow_pos: int = timing_line.find("-->")
		if arrow_pos < 0:
			continue

		var start_time: float = __parse_srt_timestamp(timing_line.substr(0, arrow_pos).strip_edges())
		var end_time: float = __parse_srt_timestamp(timing_line.substr(arrow_pos + 3).strip_edges())

		if start_time < 0 or end_time < 0:
			continue

		# Optimized: use PackedStringArray for better performance
		var text_lines: PackedStringArray = PackedStringArray()
		var _resize_error: int = text_lines.resize(line_count - 2)
		for i: int in range(2, line_count):
			text_lines[i - 2] = lines[i]

		var text: String = "\n".join(text_lines)

		# Apply formatting removal if requested
		if p_remove_html_tags:
			text = __remove_html_tags(text)
		if p_remove_ass_tags:
			text = __remove_ass_tags(text)

		entries.append(
			{
				SubtitleEntry._key.START_TIME: start_time,
				SubtitleEntry._key.END_TIME: end_time,
				SubtitleEntry._key.TEXT: text,
			},
		)

	# Post-process: merge consecutive entries with same timestamps
	entries = __merge_same_timestamp_entries(entries)

	# Sanity check: warn about overlapping time intervals
	__check_overlapping_intervals(entries, "SRTParser", p_file_path)

	return entries


# Parses SRT timestamp string (HH:MM:SS,mmm or HH:MM:SS.mmm) and returns time in seconds.
# Returns -1.0 on parse error.
func __parse_srt_timestamp(p_timestamp: String) -> float:
	var ts: String = p_timestamp.strip_edges()

	# Find colon positions for optimized parsing
	var first_colon: int = ts.find(":")
	if first_colon < 0:
		return -1.0

	var second_colon: int = ts.find(":", first_colon + 1)
	if second_colon < 0:
		return -1.0

	# Parse hours and minutes
	var hours: float = ts.substr(0, first_colon).to_float()
	var minutes: float = ts.substr(first_colon + 1, second_colon - first_colon - 1).to_float()

	# Parse seconds and milliseconds (SRT uses comma or dot)
	var seconds_part: String = ts.substr(second_colon + 1)
	var dot_pos: int = seconds_part.find(".")
	if dot_pos < 0:
		dot_pos = seconds_part.find(",")

	var seconds: float = 0.0
	var milliseconds: float = 0.0

	if dot_pos >= 0:
		seconds = seconds_part.substr(0, dot_pos).to_float()
		milliseconds = seconds_part.substr(dot_pos + 1).to_float() * 0.001
	else:
		seconds = seconds_part.to_float()

	return hours * 3600.0 + minutes * 60.0 + seconds + milliseconds


# Parses WebVTT subtitle content and returns an array of subtitle entry dictionaries.
# Handles WEBVTT header, cue identifiers, timestamps with --> separator, and cue settings.
func __parse_vtt(p_content: String, p_file_path: String = "", p_remove_html_tags: bool = true, p_remove_ass_tags: bool = true) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var lines: PackedStringArray = __normalize_line_endings(p_content).split("\n")

	var line_count: int = lines.size()
	if line_count == 0 or not lines[0].begins_with("WEBVTT"):
		printerr("Invalid VTT file: missing WEBVTT header")
		return entries

	var i: int = 1

	while i < line_count:
		var line: String = lines[i].strip_edges()
		var line_len: int = line.length()

		# Skip empty lines and NOTE blocks (optimized with length check)
		if line_len == 0:
			i += 1
			continue

		if line_len >= 4 and line.substr(0, 4) == "NOTE":
			i += 1
			continue

		# Skip STYLE and REGION blocks (optimized with direct string comparison)
		if line_len >= 5:
			var prefix: String = line.substr(0, 5)
			if prefix == "STYLE" or (line_len >= 6 and line.substr(0, 6) == "REGION"):
				i += 1
				while i < line_count and not lines[i].strip_edges().is_empty():
					i += 1
				continue

		# Check for timing line (optimized with find)
		var arrow_pos: int = line.find("-->")
		if arrow_pos >= 0:
			# Split on arrow position for better performance
			var start_part: String = line.substr(0, arrow_pos).strip_edges()
			var end_part: String = line.substr(arrow_pos + 3).strip_edges()

			# Remove cue settings from end part (e.g., "position:50% align:middle")
			var end_space_pos: int = end_part.find(" ")
			if end_space_pos > 0:
				end_part = end_part.substr(0, end_space_pos)

			var start_time: float = __parse_vtt_timestamp(start_part)
			var end_time: float = __parse_vtt_timestamp(end_part)

			if start_time < 0 or end_time < 0:
				i += 1
				continue

			# Collect text lines until we hit an empty line
			i += 1
			var text_lines: PackedStringArray = PackedStringArray()
			while i < line_count:
				var text_line: String = lines[i]
				if text_line.strip_edges().is_empty():
					break
				var _append_idx: int = text_lines.append(text_line)
				i += 1

			var text: String = "\n".join(text_lines)

			# Decode HTML entities first (VTT uses entities like &lt;, &gt;, &amp;)
			text = __decode_html_entities(text)

			if p_remove_html_tags:
				text = __remove_html_tags(text)

			if p_remove_ass_tags:
				text = __remove_ass_tags(text)

			entries.append(
				{
					SubtitleEntry._key.START_TIME: start_time,
					SubtitleEntry._key.END_TIME: end_time,
					SubtitleEntry._key.TEXT: text,
				},
			)
		else:
			i += 1

	# Post-process: merge consecutive entries with same timestamps
	entries = __merge_same_timestamp_entries(entries)

	# Sanity check: warn about overlapping time intervals
	__check_overlapping_intervals(entries, "VTTParser", p_file_path)

	return entries


# Parses VTT timestamp string (HH:MM:SS.mmm or MM:SS.mmm) and returns time in seconds.
# Returns -1.0 on parse error.
func __parse_vtt_timestamp(p_timestamp: String) -> float:
	var ts: String = p_timestamp.strip_edges()

	# Find colon positions for optimized parsing
	var first_colon: int = ts.find(":")
	if first_colon < 0:
		return -1.0

	var second_colon: int = ts.find(":", first_colon + 1)

	var hours: float = 0.0
	var minutes: float = 0.0
	var seconds_part: String = ""

	if second_colon >= 0:
		# HH:MM:SS.mmm format
		hours = ts.substr(0, first_colon).to_float()
		minutes = ts.substr(first_colon + 1, second_colon - first_colon - 1).to_float()
		seconds_part = ts.substr(second_colon + 1)
	else:
		# MM:SS.mmm format
		minutes = ts.substr(0, first_colon).to_float()
		seconds_part = ts.substr(first_colon + 1)

	# Parse seconds and milliseconds
	var dot_pos: int = seconds_part.find(".")
	var seconds: float = 0.0
	var milliseconds: float = 0.0

	if dot_pos >= 0:
		seconds = seconds_part.substr(0, dot_pos).to_float()
		milliseconds = seconds_part.substr(dot_pos + 1).to_float() * 0.001 # Multiply by 0.001 instead of dividing by 1000
	else:
		seconds = seconds_part.to_float()

	return hours * 3600.0 + minutes * 60.0 + seconds + milliseconds


# Parses LRC (Lyrics) subtitle content and returns an array of subtitle entry dictionaries.
# Handles multiple timestamps per line ([mm:ss.xx][mm:ss.xx]text) and metadata tags.
func __parse_lrc(p_content: String, p_file_path: String = "", p_remove_html_tags: bool = true, p_remove_ass_tags: bool = true) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var lines: PackedStringArray = __normalize_line_endings(p_content).split("\n")
	var temp_entries: Array[Dictionary] = []

	# Initialize cached regex on first use
	if _lrc_timestamp_regex == null:
		_lrc_timestamp_regex = RegEx.new()
		var _compile_error: Error = _lrc_timestamp_regex.compile("\\[(\\d+):(\\d+(?:\\.\\d+)?)\\]")

	var line_count: int = lines.size()
	for line_idx: int in line_count:
		var line: String = lines[line_idx].strip_edges()
		var line_len: int = line.length()

		if line_len == 0:
			continue

		# Skip metadata tags like [ar:], [ti:], [al:], etc.
		# Optimized: check first character before processing
		if line_len > 2 and line[0] == '[':
			var colon_pos: int = line.find(":")
			if colon_pos > 0 and colon_pos < 10: # Metadata tags have colon early
				var close_bracket: int = line.find("]")
				if close_bracket > 0:
					var before_colon: String = line.substr(1, colon_pos - 1)
					# If it's not a number, it's metadata
					if not before_colon.is_valid_float() and not before_colon.is_valid_int():
						continue

		# Parse timestamp tags [MM:SS.mmm] using cached regex
		var matches: Array[RegExMatch] = _lrc_timestamp_regex.search_all(line)

		var match_count: int = matches.size()
		if match_count == 0:
			continue

		# Extract text after the last timestamp bracket (optimized: single rfind)
		var last_bracket: int = line.rfind("]")
		var text: String = ""
		if last_bracket >= 0 and last_bracket + 1 < line_len:
			text = line.substr(last_bracket + 1).strip_edges()

		if p_remove_html_tags:
			text = __remove_html_tags(text)

		if p_remove_ass_tags:
			text = __remove_ass_tags(text)

		# Process each timestamp in the line (LRC supports multiple timestamps per line)
		for match_idx: int in match_count:
			var match: RegExMatch = matches[match_idx]
			var minutes: int = match.get_string(1).to_int()
			var seconds_str: String = match.get_string(2)
			var dot_pos: int = seconds_str.find(".")
			var seconds: float = 0.0
			if dot_pos >= 0:
				var whole_seconds: float = seconds_str.substr(0, dot_pos).to_float()
				var fractional: float = seconds_str.substr(dot_pos + 1).to_float() * 0.001
				seconds = whole_seconds + fractional
			else:
				seconds = seconds_str.to_float()
			var timestamp: float = float(minutes) * 60.0 + seconds

			temp_entries.append(
				{
					SubtitleEntry._key.START_TIME: timestamp,
					SubtitleEntry._key.END_TIME: -1.0,
					SubtitleEntry._key.TEXT: text,
				},
			)

	# Sort entries by start time
	temp_entries.sort_custom(
		func(p_a: Dictionary, p_b: Dictionary) -> bool:
			return p_a[SubtitleEntry._key.START_TIME] < p_b[SubtitleEntry._key.START_TIME]
	)

	# Calculate end times based on next entry's start time
	var temp_count: int = temp_entries.size()
	for i: int in temp_count:
		var entry: Dictionary = temp_entries[i]

		if i < temp_count - 1:
			# Set end time to the start of the next entry
			entry[SubtitleEntry._key.END_TIME] = temp_entries[i + 1][SubtitleEntry._key.START_TIME]
		else:
			# For the last entry, add a default duration of 3 seconds
			entry[SubtitleEntry._key.END_TIME] = entry[SubtitleEntry._key.START_TIME] + 3.0

		entries.append(entry)

	# Post-process: merge consecutive entries with same timestamps
	entries = __merge_same_timestamp_entries(entries)

	# Sanity check: warn about overlapping time intervals
	__check_overlapping_intervals(entries, "LRCParser", p_file_path)

	return entries


# Parses SSA/ASS (SubStation Alpha) subtitle content and returns an array of subtitle entry dictionaries.
# Handles [Events] section with Format and Dialogue lines.
func __parse_ssa(p_content: String, p_file_path: String = "", p_remove_html_tags: bool = true, p_remove_ass_tags: bool = true) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var lines: PackedStringArray = __normalize_line_endings(p_content).split("\n")

	var in_events_section: bool = false
	var dialogue_format: Array[String] = []

	var line_count: int = lines.size()
	for i: int in line_count:
		var line: String = lines[i].strip_edges()

		if line.is_empty() or line[0] == ';':
			continue

		# Check for section headers (optimized with direct character access)
		if line[0] == '[':
			in_events_section = (line.length() == 8 and line.to_lower() == "[events]")
			continue

		if not in_events_section:
			continue

		# Parse Format line to understand field order
		if line.length() > 7 and line.substr(0, 7) == "Format:":
			var format_part: String = line.substr(7).strip_edges()
			var fields: PackedStringArray = format_part.split(",")
			dialogue_format.clear()
			var _resize_error: int = dialogue_format.resize(fields.size())
			for idx: int in fields.size():
				dialogue_format[idx] = fields[idx].strip_edges().to_lower()
			continue

		# Parse Dialogue lines
		if line.length() > 9 and line.substr(0, 9) == "Dialogue:":
			if dialogue_format.size() == 0:
				# Default ASS format if Format line is missing
				dialogue_format = ["layer", "start", "end", "style", "name", "marginl", "marginr", "marginv", "effect", "text"]

			var dialogue_part: String = line.substr(9).strip_edges()
			var entry: Dictionary = __parse_ssa_dialogue_line(dialogue_part, dialogue_format, p_remove_html_tags, p_remove_ass_tags)

			if not entry.is_empty():
				entries.append(entry)

	# Post-process: merge consecutive entries with same timestamps
	entries = __merge_same_timestamp_entries(entries)

	# Sanity check: warn about overlapping time intervals
	__check_overlapping_intervals(entries, "SSAParser", p_file_path)

	return entries


# Parses a single SSA/ASS Dialogue line based on the Format specification.
# Handles comma-separated fields with the Text field potentially containing commas.
func __parse_ssa_dialogue_line(p_line: String, p_format: Array[String], p_remove_html_tags: bool = true, p_remove_ass_tags: bool = true) -> Dictionary:
	# Find the text field index
	var text_index: int = p_format.find("text")
	if text_index < 0:
		return { }

	# Split the line manually to handle commas in text field
	# Pre-allocate array for better performance
	var parts: PackedStringArray = PackedStringArray()
	var _resize_error: int = parts.resize(text_index + 2) # Pre-allocate expected size
	var part_count: int = 0
	var start_pos: int = 0
	var line_len: int = p_line.length()

	# Find comma positions up to text_index
	for i: int in line_len:
		if p_line[i] == ',' and part_count < text_index:
			parts[part_count] = p_line.substr(start_pos, i - start_pos)
			part_count += 1
			start_pos = i + 1

	# Add the remaining text (everything after the last comma)
	if start_pos < line_len:
		parts[part_count] = p_line.substr(start_pos)
		part_count += 1

	# Resize to actual count
	var _resize_error2: int = parts.resize(part_count)

	# We should have at least text_index + 1 parts
	if part_count < text_index + 1:
		return { }

	# Map parts to field names (optimized with direct access)
	var field_values: Dictionary = { }
	var format_size: int = p_format.size()
	var min_size: int = mini(part_count, format_size)
	for i: int in min_size:
		field_values[p_format[i]] = parts[i].strip_edges()

	# Extract required fields (optimized with direct access)
	if not ("start" in field_values and "end" in field_values and "text" in field_values):
		return { }

	var start_str: String = field_values["start"]
	var end_str: String = field_values["end"]
	var text: String = field_values["text"]

	var start_time: float = __parse_ssa_timestamp(start_str)
	var end_time: float = __parse_ssa_timestamp(end_str)

	if start_time < 0 or end_time < 0:
		return { }

	# Remove SSA/ASS tags
	if p_remove_ass_tags:
		text = __remove_ass_tags(text)

	if p_remove_html_tags:
		text = __remove_html_tags(text)

	return {
		SubtitleEntry._key.START_TIME: start_time,
		SubtitleEntry._key.END_TIME: end_time,
		SubtitleEntry._key.TEXT: text,
	}


# Parses SSA/ASS timestamp (H:MM:SS.cc where cc is centiseconds) and returns time in seconds.
# Returns -1.0 on parse error.
func __parse_ssa_timestamp(p_timestamp: String) -> float:
	var ts: String = p_timestamp.strip_edges()

	# Find colon positions for faster parsing
	var first_colon: int = ts.find(":")
	if first_colon < 0:
		return -1.0

	var second_colon: int = ts.find(":", first_colon + 1)
	if second_colon < 0:
		return -1.0

	# Parse hours, minutes, and seconds.centiseconds
	var hours: float = ts.substr(0, first_colon).to_float()
	var minutes: float = ts.substr(first_colon + 1, second_colon - first_colon - 1).to_float()

	var seconds_part: String = ts.substr(second_colon + 1)
	var dot_pos: int = seconds_part.find(".")

	var seconds: float = 0.0
	var centiseconds: float = 0.0

	if dot_pos >= 0:
		seconds = seconds_part.substr(0, dot_pos).to_float()
		centiseconds = seconds_part.substr(dot_pos + 1).to_float() * 0.01 # Divide by 100
	else:
		seconds = seconds_part.to_float()

	return hours * 3600.0 + minutes * 60.0 + seconds + centiseconds


# Removes SSA/ASS formatting tags like {\i1}, {\b1}, {\pos(x,y)}, etc.
# Also converts \N and \n to newlines and \h to spaces.
func __remove_ass_tags(p_text: String) -> String:
	# Initialize cached regex on first use
	if _ass_tags_regex == null:
		_ass_tags_regex = RegEx.new()
		var _compile_error: Error = _ass_tags_regex.compile("\\{[^}]*\\}")

	var result: String = _ass_tags_regex.sub(p_text, "", true)

	# Also remove \N and \n line breaks (convert to actual newlines)
	# Optimized: chain replacements efficiently
	result = result.replace("\\N", "\n").replace("\\n", "\n").replace("\\h", " ")

	return result


# Parses SBV (YouTube SubViewer) subtitle content and returns an array of subtitle entry dictionaries.
# Format: timestamp range on one line, followed by text lines, separated by blank lines.
func __parse_sbv(p_content: String, p_file_path: String = "", p_remove_html_tags: bool = true, p_remove_ass_tags: bool = true) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var blocks: PackedStringArray = __normalize_line_endings(p_content).split("\n\n")

	var block_count: int = blocks.size()
	for block_idx: int in block_count:
		var block: String = blocks[block_idx].strip_edges()
		var block_len: int = block.length()
		if block_len == 0:
			continue

		var lines: PackedStringArray = block.split("\n")
		var line_count: int = lines.size()
		if line_count < 2:
			continue

		var timing_line: String = lines[0].strip_edges()

		# SBV format: H:MM:SS.mmm,H:MM:SS.mmm
		# Optimized: find comma position instead of contains check
		var comma_pos: int = timing_line.find(",")
		if comma_pos < 0:
			continue

		var start_time: float = __parse_sbv_timestamp(timing_line.substr(0, comma_pos).strip_edges())
		var end_time: float = __parse_sbv_timestamp(timing_line.substr(comma_pos + 1).strip_edges())

		if start_time < 0 or end_time < 0:
			continue

		# Collect text lines (everything after the timing line)
		# Optimized: use PackedStringArray for better performance
		var text_lines: PackedStringArray = PackedStringArray()
		var _resize_error: int = text_lines.resize(line_count - 1)
		for i: int in range(1, line_count):
			text_lines[i - 1] = lines[i]

		var text: String = "\n".join(text_lines)

		# Apply formatting removal if requested
		if p_remove_html_tags:
			text = __remove_html_tags(text)

		if p_remove_ass_tags:
			text = __remove_ass_tags(text)

		entries.append(
			{
				SubtitleEntry._key.START_TIME: start_time,
				SubtitleEntry._key.END_TIME: end_time,
				SubtitleEntry._key.TEXT: text,
			},
		)

	# Post-process: merge consecutive entries with same timestamps
	entries = __merge_same_timestamp_entries(entries)

	# Sanity check: warn about overlapping time intervals
	__check_overlapping_intervals(entries, "SBVParser", p_file_path)

	return entries


# Parses SBV timestamp (H:MM:SS.mmm or HH:MM:SS.mmm) and returns time in seconds.
# Returns -1.0 on parse error.
func __parse_sbv_timestamp(p_timestamp: String) -> float:
	var ts: String = p_timestamp.strip_edges()

	# Find colon positions for optimized parsing
	var first_colon: int = ts.find(":")
	if first_colon < 0:
		return -1.0

	var second_colon: int = ts.find(":", first_colon + 1)
	if second_colon < 0:
		return -1.0

	# Parse hours and minutes
	var hours: float = ts.substr(0, first_colon).to_float()
	var minutes: float = ts.substr(first_colon + 1, second_colon - first_colon - 1).to_float()

	# Parse seconds and milliseconds
	var seconds_part: String = ts.substr(second_colon + 1)
	var dot_pos: int = seconds_part.find(".")
	var seconds: float = 0.0
	var milliseconds: float = 0.0

	if dot_pos >= 0:
		seconds = seconds_part.substr(0, dot_pos).to_float()
		milliseconds = seconds_part.substr(dot_pos + 1).to_float() * 0.001
	else:
		seconds = seconds_part.to_float()

	return hours * 3600.0 + minutes * 60.0 + seconds + milliseconds


# Parses TTML/DFXP (Timed Text Markup Language) XML content and returns an array of subtitle entry dictionaries.
# DFXP is the older name for TTML - same format. Handles <p> and <span> elements with begin/end/dur timing.
func __parse_ttml(p_content: String, p_file_path: String = "", p_remove_html_tags: bool = true, p_remove_ass_tags: bool = true) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var normalized_content: String = __normalize_line_endings(p_content)

	# Parse XML to find <p> or <span> elements with timing
	var parser: XMLParser = XMLParser.new()
	var error: Error = parser.open_buffer(normalized_content.to_utf8_buffer())

	if error != OK:
		printerr("Failed to parse TTML XML content")
		return entries

	var default_framerate: float = 25.0
	var tick_rate: float = 1.0

	# Parse document to extract entries
	while parser.read() == OK:
		if parser.get_node_type() == XMLParser.NODE_ELEMENT:
			var node_name: String = parser.get_node_name().to_lower()

			# Check for framerate in tt element
			if node_name == "tt":
				if parser.has_attribute("ttp:frameRate"):
					default_framerate = parser.get_named_attribute_value("ttp:frameRate").to_float()
				elif parser.has_attribute("frameRate"):
					default_framerate = parser.get_named_attribute_value("frameRate").to_float()

				if parser.has_attribute("ttp:tickRate"):
					tick_rate = parser.get_named_attribute_value("ttp:tickRate").to_float()
				elif parser.has_attribute("tickRate"):
					tick_rate = parser.get_named_attribute_value("tickRate").to_float()

			# Parse p (paragraph) elements
			if node_name == "p":
				var entry: Dictionary = __parse_ttml_element(parser, default_framerate, tick_rate, p_remove_html_tags, p_remove_ass_tags)
				if not entry.is_empty():
					entries.append(entry)

	# Sort entries by start time
	entries.sort_custom(
		func(p_a: Dictionary, p_b: Dictionary) -> bool:
			return p_a[SubtitleEntry._key.START_TIME] < p_b[SubtitleEntry._key.START_TIME]
	)

	# Post-process: merge consecutive entries with same timestamps
	entries = __merge_same_timestamp_entries(entries)

	# Sanity check: warn about overlapping time intervals
	__check_overlapping_intervals(entries, "TtmlParser", p_file_path)

	return entries


# Parses a single TTML/DFXP element (<p> or <span>) with timing attributes.
# Extracts begin, end, and dur attributes and recursively extracts text content.
func __parse_ttml_element(p_parser: XMLParser, p_framerate: float, p_tick_rate: float, p_remove_html_tags: bool = true, p_remove_ass_tags: bool = true) -> Dictionary:
	var begin_attr: String = ""
	var end_attr: String = ""
	var dur_attr: String = ""

	# Check for timing attributes (with and without namespace)
	if p_parser.has_attribute("begin"):
		begin_attr = p_parser.get_named_attribute_value("begin")

	if p_parser.has_attribute("end"):
		end_attr = p_parser.get_named_attribute_value("end")

	if p_parser.has_attribute("dur"):
		dur_attr = p_parser.get_named_attribute_value("dur")

	# If no begin attribute, skip this element
	if begin_attr.is_empty():
		return { }

	var start_time: float = __parse_ttml_time(begin_attr, p_framerate, p_tick_rate)
	if start_time < 0:
		return { }

	var end_time: float = -1.0

	# Calculate end time from end or dur attribute
	if not end_attr.is_empty():
		end_time = __parse_ttml_time(end_attr, p_framerate, p_tick_rate)
	elif not dur_attr.is_empty():
		var duration: float = __parse_ttml_time(dur_attr, p_framerate, p_tick_rate)
		if duration > 0:
			end_time = start_time + duration

	# If no valid end time, use default duration
	if end_time < 0:
		end_time = start_time + 3.0

	# Extract text content recursively
	var text: String = __extract_ttml_text_content_recursive(p_parser)

	if p_remove_html_tags:
		text = __remove_html_tags(text)

	if p_remove_ass_tags:
		text = __remove_ass_tags(text)

	return {
		SubtitleEntry._key.START_TIME: start_time,
		SubtitleEntry._key.END_TIME: end_time,
		SubtitleEntry._key.TEXT: text.strip_edges(),
	}


# Recursively extracts text content from TTML/DFXP elements, handling nested tags.
# Converts <br/> to newlines and preserves text from nested elements.
func __extract_ttml_text_content_recursive(p_parser: XMLParser) -> String:
	var text_parts: Array[String] = []
	var depth: int = 0
	var initial_node_name: String = p_parser.get_node_name().to_lower()
	var last_was_text: bool = false

	while p_parser.read() == OK:
		var node_type: int = p_parser.get_node_type()

		if node_type == XMLParser.NODE_ELEMENT:
			var node_name: String = p_parser.get_node_name().to_lower()

			# Handle <br> tags by adding newline
			if node_name == "br":
				text_parts.append("\n")
				last_was_text = false
			else:
				# For other elements (like span), we go deeper
				depth += 1

		elif node_type == XMLParser.NODE_ELEMENT_END:
			var node_name: String = p_parser.get_node_name().to_lower()

			# Check if we're closing the initial element we started with
			if depth == 0 and node_name == initial_node_name:
				break

			if depth > 0:
				depth -= 1

		elif node_type == XMLParser.NODE_TEXT:
			# Add text content, strip leading/trailing whitespace from each text node
			var text_data: String = p_parser.get_node_data().strip_edges()
			# Only add non-empty text
			if not text_data.is_empty():
				# Add space between consecutive text nodes (but not after newline)
				if last_was_text and not text_parts.is_empty() and text_parts[-1] != "\n":
					text_parts.append(" ")
				text_parts.append(text_data)
				last_was_text = true

	return "".join(text_parts)


# Parses TTML time expressions (supports multiple formats: HH:MM:SS.mmm, offset-time with units, frames, ticks).
# Returns time in seconds, or -1.0 on parse error.
func __parse_ttml_time(p_time: String, p_framerate: float, p_tick_rate: float) -> float:
	var time_str: String = p_time.strip_edges()
	var time_len: int = time_str.length()

	if time_len == 0:
		return -1.0

	# Check for offset time with units (optimized: check last character first)
	var last_char: String = time_str[time_len - 1]

	if last_char == "s":
		# Could be "ms" or "s"
		if time_len > 2 and time_str[time_len - 2] == 'm':
			return time_str.substr(0, time_len - 2).to_float() * 0.001
		else:
			return time_str.substr(0, time_len - 1).to_float()
	elif last_char == "m":
		return time_str.substr(0, time_len - 1).to_float() * 60.0
	elif last_char == "h":
		return time_str.substr(0, time_len - 1).to_float() * 3600.0
	elif last_char == "t":
		# Ticks
		return time_str.substr(0, time_len - 1).to_float() / p_tick_rate
	elif last_char == "f":
		# Frames
		return time_str.substr(0, time_len - 1).to_float() / p_framerate

	# Clock time format: HH:MM:SS.mmm or HH:MM:SS:FF
	# Optimized: find colons instead of split
	var first_colon: int = time_str.find(":")

	if first_colon < 0:
		# Try as raw seconds
		return time_str.to_float()

	var second_colon: int = time_str.find(":", first_colon + 1)
	var hours: float = 0.0
	var minutes: float = 0.0
	var seconds: float = 0.0
	var fraction: float = 0.0

	if second_colon >= 0:
		# HH:MM:SS.mmm or HH:MM:SS:FF format
		hours = time_str.substr(0, first_colon).to_float()
		minutes = time_str.substr(first_colon + 1, second_colon - first_colon - 1).to_float()

		var third_colon: int = time_str.find(":", second_colon + 1)
		if third_colon >= 0:
			# HH:MM:SS:FF format (with frames)
			seconds = time_str.substr(second_colon + 1, third_colon - second_colon - 1).to_float()
			fraction = time_str.substr(third_colon + 1).to_float() / p_framerate
		else:
			# HH:MM:SS.mmm format
			var last_part: String = time_str.substr(second_colon + 1)
			var dot_pos: int = last_part.find(".")
			if dot_pos >= 0:
				seconds = last_part.substr(0, dot_pos).to_float()
				# Convert milliseconds to seconds (optimized)
				var ms_str: String = last_part.substr(dot_pos + 1)
				var ms_len: int = ms_str.length()
				if ms_len == 1:
					fraction = ms_str.to_float() * 0.1
				elif ms_len == 2:
					fraction = ms_str.to_float() * 0.01
				elif ms_len >= 3:
					fraction = ms_str.substr(0, 3).to_float() * 0.001
			else:
				seconds = last_part.to_float()
	else:
		# MM:SS.mmm format
		minutes = time_str.substr(0, first_colon).to_float()
		var seconds_part: String = time_str.substr(first_colon + 1)
		var dot_pos: int = seconds_part.find(".")
		if dot_pos >= 0:
			seconds = seconds_part.substr(0, dot_pos).to_float()
			var ms_str: String = seconds_part.substr(dot_pos + 1)
			var ms_len: int = ms_str.length()
			if ms_len == 1:
				fraction = ms_str.to_float() * 0.1
			elif ms_len == 2:
				fraction = ms_str.to_float() * 0.01
			elif ms_len >= 3:
				fraction = ms_str.substr(0, 3).to_float() * 0.001
		else:
			seconds = seconds_part.to_float()

	return hours * 3600.0 + minutes * 60.0 + seconds + fraction


# Parses SCC (Scenarist Closed Caption) content and returns an array of subtitle entry dictionaries.
# Each line with decoded text becomes a separate subtitle. Lines with only clear-screen commands (942c 942c) are skipped.
func __parse_scc(p_content: String, p_framerate: float = 29.97, p_file_path: String = "", p_remove_html_tags: bool = true, p_remove_ass_tags: bool = true) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var lines: PackedStringArray = __normalize_line_endings(p_content).split("\n")

	var framerate: float = p_framerate if p_framerate > 0.0 else 29.97 # Default NTSC framerate

	var line_count: int = lines.size()
	for line_idx: int in line_count:
		var line: String = lines[line_idx].strip_edges()
		var line_len: int = line.length()

		if line_len == 0:
			continue

		# Check for header (optimized with length check)
		if line_len > 15 and line.substr(0, 15) == "Scenarist_SCC V":
			continue

		# Parse timecode line format: HH:MM:SS:FF<tab>caption_data
		# Optimized: check for colon first (most lines won't have it)
		var first_colon: int = line.find(":")
		if first_colon >= 0 and first_colon < 10: # Timecode should have colon early
			var tab_pos: int = line.find("\t")
			if tab_pos < 0:
				tab_pos = line.find(" ")

			if tab_pos > 0 and tab_pos < line_len:
				var timecode: String = line.substr(0, tab_pos).strip_edges()
				var caption_data: String = line.substr(tab_pos).strip_edges()

				var timestamp: float = __parse_scc_timecode(timecode, framerate)
				if timestamp < 0:
					continue

				# Skip clear-screen only commands (942c 942c with no text)
				if caption_data.strip_edges() == "942c 942c":
					continue

				# Decode the caption data
				var decoded_text: String = __decode_scc_data(caption_data)

				# If we have decoded text, create a new entry
				if not decoded_text.is_empty():
					var entry_text: String = decoded_text

					if p_remove_html_tags:
						entry_text = __remove_html_tags(entry_text)
					if p_remove_ass_tags:
						entry_text = __remove_ass_tags(entry_text)

					entries.append(
						{
							SubtitleEntry._key.START_TIME: timestamp,
							SubtitleEntry._key.END_TIME: timestamp + 3.0, # Default duration
							SubtitleEntry._key.TEXT: entry_text.strip_edges(),
						},
					)

	# Post-process: set end times based on next entry's start time
	var entry_count: int = entries.size()
	for i: int in entry_count - 1:
		var next_start: float = entries[i + 1][SubtitleEntry._key.START_TIME]
		# Only update if next entry starts after current
		if next_start > entries[i][SubtitleEntry._key.START_TIME]:
			entries[i][SubtitleEntry._key.END_TIME] = next_start

	# Post-process: merge consecutive entries with same timestamps
	entries = __merge_same_timestamp_entries(entries)

	# Sanity check: warn about overlapping time intervals
	__check_overlapping_intervals(entries, "SCCParser", p_file_path)

	return entries


# Parses SCC timecode (HH:MM:SS:FF where FF is frame number) and returns time in seconds.
# Returns -1.0 on parse error.
func __parse_scc_timecode(p_timecode: String, p_framerate: float) -> float:
	var ts: String = p_timecode.strip_edges()

	# Optimized parsing without split
	var first_colon: int = ts.find(":")
	if first_colon < 0:
		return -1.0

	var second_colon: int = ts.find(":", first_colon + 1)
	if second_colon < 0:
		return -1.0

	var third_colon: int = ts.find(":", second_colon + 1)
	if third_colon < 0:
		return -1.0

	var hours: float = ts.substr(0, first_colon).to_float()
	var minutes: float = ts.substr(first_colon + 1, second_colon - first_colon - 1).to_float()
	var seconds: float = ts.substr(second_colon + 1, third_colon - second_colon - 1).to_float()
	var frames: float = ts.substr(third_colon + 1).to_float()

	# Optimized: multiply by reciprocal instead of divide
	return hours * 3600.0 + minutes * 60.0 + seconds + (frames / p_framerate)


# Decodes SCC hex data codes into text characters.
# Control codes (0x10-0x1F, 0x90-0x9F) are positioning/formatting commands that are skipped.
# Uses parity bits - characters 0x80-0xFF are the same as 0x00-0x7F with high bit set.
func __decode_scc_data(p_data: String) -> String:
	var hex_codes: PackedStringArray = p_data.strip_edges().split(" ")
	var text_parts: PackedStringArray = PackedStringArray()

	# Initialize character map on first use (cache for performance)
	if _scc_char_map.is_empty():
		_scc_char_map = {
			0x20: " ",
			0x21: "!",
			0x22: "\"",
			0x23: "#",
			0x24: "$",
			0x25: "%",
			0x26: "&",
			0x27: "'",
			0x28: "(",
			0x29: ")",
			0x2A: "á",
			0x2B: "+",
			0x2C: ",",
			0x2D: "-",
			0x2E: ".",
			0x2F: "/",
			0x30: "0",
			0x31: "1",
			0x32: "2",
			0x33: "3",
			0x34: "4",
			0x35: "5",
			0x36: "6",
			0x37: "7",
			0x38: "8",
			0x39: "9",
			0x3A: ":",
			0x3B: ";",
			0x3C: "<",
			0x3D: "=",
			0x3E: ">",
			0x3F: "?",
			0x40: "@",
			0x41: "A",
			0x42: "B",
			0x43: "C",
			0x44: "D",
			0x45: "E",
			0x46: "F",
			0x47: "G",
			0x48: "H",
			0x49: "I",
			0x4A: "J",
			0x4B: "K",
			0x4C: "L",
			0x4D: "M",
			0x4E: "N",
			0x4F: "O",
			0x50: "P",
			0x51: "Q",
			0x52: "R",
			0x53: "S",
			0x54: "T",
			0x55: "U",
			0x56: "V",
			0x57: "W",
			0x58: "X",
			0x59: "Y",
			0x5A: "Z",
			0x5B: "[",
			0x5C: "é",
			0x5D: "]",
			0x5E: "í",
			0x5F: "ó",
			0x60: "ú",
			0x61: "a",
			0x62: "b",
			0x63: "c",
			0x64: "d",
			0x65: "e",
			0x66: "f",
			0x67: "g",
			0x68: "h",
			0x69: "i",
			0x6A: "j",
			0x6B: "k",
			0x6C: "l",
			0x6D: "m",
			0x6E: "n",
			0x6F: "o",
			0x70: "p",
			0x71: "q",
			0x72: "r",
			0x73: "s",
			0x74: "t",
			0x75: "u",
			0x76: "v",
			0x77: "w",
			0x78: "x",
			0x79: "y",
			0x7A: "z",
			0x7B: "ç",
			0x7C: "÷",
			0x7D: "Ñ",
			0x7E: "ñ",
			0x7F: "█",
		}

	var hex_count: int = hex_codes.size()
	var last_was_control: bool = false

	for hex_idx: int in hex_count:
		var hex_str: String = hex_codes[hex_idx]
		if hex_str.length() != 4:
			continue

		# Each SCC code is 4 hex digits (2 bytes)
		var byte1_str: String = hex_str.substr(0, 2)
		var byte2_str: String = hex_str.substr(2, 2)

		if not byte1_str.is_valid_hex_number() or not byte2_str.is_valid_hex_number():
			continue

		var byte1: int = ("0x" + byte1_str).hex_to_int()
		var byte2: int = ("0x" + byte2_str).hex_to_int()

		# Check for control codes - skip them but check for line breaks
		# Control codes: 0x10-0x1F (positioning), 0x90-0x9F (control commands)
		if (byte1 >= 0x10 and byte1 <= 0x1F) or (byte1 >= 0x90 and byte1 <= 0x9F):
			# Check for specific line break control codes
			# 0x94d0 and 0x9470 are line break indicators in SCC
			if (byte1 == 0x94 and byte2 == 0xd0) or (byte1 == 0x94 and byte2 == 0x70):
				# Add newline for line break control codes, but only if last wasn't already a newline
				# (SCC often repeats control codes for redundancy)
				if text_parts.size() == 0 or text_parts[text_parts.size() - 1] != "\n":
					var _append_newline: int = text_parts.append("\n")
			else:
				# Other control codes - add space after control sequence if we had text before
				if text_parts.size() > 0 and not last_was_control:
					# Check if last char isn't already a space or newline
					var last_part: String = text_parts[text_parts.size() - 1]
					if last_part != " " and last_part != "\n":
						var _append_space: int = text_parts.append(" ")
			last_was_control = true
			continue

		last_was_control = false

		# SCC uses parity bits - strip the high bit (0x80) for characters 0x80-0xFF
		# This converts them to standard ASCII 0x00-0x7F
		var char1: int = byte1 & 0x7F
		var char2: int = byte2 & 0x7F

		# Decode character from both bytes if they indicate text
		if _scc_char_map.has(char1):
			var char1_str: String = _scc_char_map[char1]
			var _append_idx1: int = text_parts.append(char1_str)

		# Check second byte (also skip if it's a control code)
		if not ((byte2 >= 0x10 and byte2 <= 0x1F) or (byte2 >= 0x90 and byte2 <= 0x9F)):
			if _scc_char_map.has(char2):
				var char2_str: String = _scc_char_map[char2]
				var _append_idx2: int = text_parts.append(char2_str)

	# Join text parts efficiently
	return "".join(text_parts)


# Parses SUB (MicroDVD) subtitle content and returns an array of subtitle entry dictionaries.
# Format: {start_frame}{end_frame}text with optional framerate declaration on first line.
func __parse_sub(p_content: String, p_framerate: float = 25.0, p_file_path: String = "", p_remove_html_tags: bool = true, p_remove_ass_tags: bool = true) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var lines: PackedStringArray = __normalize_line_endings(p_content).split("\n")

	var detected_framerate: float = p_framerate

	var line_count: int = lines.size()
	for line_idx: int in line_count:
		var line: String = lines[line_idx].strip_edges()
		var line_len: int = line.length()

		if line_len == 0:
			continue

		# MicroDVD format: {start_frame}{end_frame}Text
		# Optimized: check first character directly
		if line_len < 5 or line[0] != '{':
			continue

		var first_close: int = line.find("}")
		if first_close < 2: # Need at least one digit
			continue

		var start_frame_str: String = line.substr(1, first_close - 1)

		# Look for second frame marker
		# Optimized: check character directly instead of substr + begins_with
		var second_open: int = first_close + 1
		if second_open >= line_len or line[second_open] != '{':
			continue

		var second_close: int = line.find("}", second_open)
		if second_close < 0:
			continue

		var end_frame_str: String = line.substr(second_open + 1, second_close - second_open - 1)
		var text: String = line.substr(second_close + 1)

		# Check if this is a framerate declaration line
		# Format: {1}{1}framerate or {0}{0}framerate
		# Optimized: early check before string comparison
		if start_frame_str.length() == 1 and start_frame_str == end_frame_str:
			if start_frame_str == "0" or start_frame_str == "1":
				var potential_fps: float = text.to_float()
				if potential_fps > 10.0 and potential_fps < 120.0:
					detected_framerate = potential_fps
					continue

		# Parse frame numbers
		if not start_frame_str.is_valid_int() or not end_frame_str.is_valid_int():
			continue

		var start_frame: int = start_frame_str.to_int()
		var end_frame: int = end_frame_str.to_int()

		# Convert frames to time (optimized: multiply by reciprocal)
		var frame_to_time: float = 1.0 / detected_framerate
		var start_time: float = float(start_frame) * frame_to_time
		var end_time: float = float(end_frame) * frame_to_time

		# Process text formatting
		# MicroDVD uses | for line breaks
		text = text.replace("|", "\n")

		# Remove MicroDVD formatting tags like {y:i}, {y:b}, etc.
		text = __remove_sub_formatting(text)

		if p_remove_html_tags:
			text = __remove_html_tags(text)

		if p_remove_ass_tags:
			text = __remove_ass_tags(text)

		entries.append(
			{
				SubtitleEntry._key.START_TIME: start_time,
				SubtitleEntry._key.END_TIME: end_time,
				SubtitleEntry._key.TEXT: text.strip_edges(),
			},
		)

	# Post-process: merge consecutive entries with same timestamps
	entries = __merge_same_timestamp_entries(entries)

	# Sanity check: warn about overlapping time intervals
	__check_overlapping_intervals(entries, "SUBParser", p_file_path)

	return entries


# Removes MicroDVD formatting codes like {y:i}, {y:b}, {c:$color}, etc.
func __remove_sub_formatting(p_text: String) -> String:
	# Initialize cached regex on first use
	if _sub_formatting_regex == null:
		_sub_formatting_regex = RegEx.new()
		var _compile_error: Error = _sub_formatting_regex.compile("\\{[^}]*\\}")

	return _sub_formatting_regex.sub(p_text, "", true)


# Parses SMI/SAMI (Synchronized Accessible Media Interchange) HTML-like content and returns an array of subtitle entry dictionaries.
# Extracts <sync start="X"> tags, captures content between sync tags, extracts text from <p> tags, and decodes HTML entities.
func __parse_smi(p_content: String, p_file_path: String = "", p_remove_html_tags: bool = true, p_remove_ass_tags: bool = true) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var normalized_content: String = __normalize_line_endings(p_content)

	# Initialize cached regex on first use
	# Pattern explanation:
	# (?is) - case insensitive and DOTALL mode (. matches newlines)
	# <sync\s+ - match <sync with whitespace
	# start\s*=\s* - match start= with optional whitespace
	# ["\']?([0-9]+)["\']? - capture timestamp with optional quotes (group 1)
	# [^>]*> - match rest of tag until closing >
	# (.*?) - capture content non-greedily including newlines (group 2)
	# (?=<sync|</body>|</sami>|$) - lookahead for next sync tag, body end, sami end, or end of string
	if _smi_sync_regex == null:
		_smi_sync_regex = RegEx.new()
		var _compile_error: Error = _smi_sync_regex.compile("(?is)<sync\\s+start\\s*=\\s*[\"']?([0-9]+)[\"']?[^>]*>(.*?)(?=<sync|</body>|</sami>|$)")

	var matches: Array[RegExMatch] = _smi_sync_regex.search_all(normalized_content)

	var match_count: int = matches.size()
	if match_count == 0:
		return entries

	# Process each SYNC tag
	for i: int in match_count:
		var match: RegExMatch = matches[i]
		var start_ms: String = match.get_string(1)
		var content_block: String = match.get_string(2)

		var start_time: float = start_ms.to_float() * 0.001 # Multiply by 0.001 instead of dividing by 1000
		var end_time: float = start_time + 3.0 # Default duration

		# End time is the start of the next subtitle
		if i < match_count - 1:
			var next_match: RegExMatch = matches[i + 1]
			var next_start_ms: String = next_match.get_string(1)
			end_time = next_start_ms.to_float() * 0.001

		# Extract text from content block
		var text: String = __extract_smi_text(content_block)

		# Skip empty entries or entries with only whitespace/&nbsp
		var stripped_text: String = text.strip_edges()
		if stripped_text.is_empty() or stripped_text == " ":
			continue

		if p_remove_html_tags:
			text = __remove_html_tags(text)

		if p_remove_ass_tags:
			text = __remove_ass_tags(text)

		entries.append(
			{
				SubtitleEntry._key.START_TIME: start_time,
				SubtitleEntry._key.END_TIME: end_time,
				SubtitleEntry._key.TEXT: text.strip_edges(),
			},
		)

	# Post-process: merge consecutive entries with same timestamps
	entries = __merge_same_timestamp_entries(entries)

	# Sanity check: warn about overlapping time intervals
	__check_overlapping_intervals(entries, "SMIParser", p_file_path)

	return entries


# Extracts text content from SMI HTML-like content.
# Handles <p> tags, <br> tags converted to newlines, and decodes HTML entities.
func __extract_smi_text(p_content: String) -> String:
	var content: String = p_content.strip_edges()

	# Initialize cached regex patterns on first use
	if _smi_p_regex == null:
		_smi_p_regex = RegEx.new()
		var _err1: Error = _smi_p_regex.compile("(?i)<P[^>]*>")

		_smi_p_close_regex = RegEx.new()
		var _err2: Error = _smi_p_close_regex.compile("(?i)</P>")

		_smi_br_regex = RegEx.new()
		var _err3: Error = _smi_br_regex.compile("(?i)<BR[^>]*/?>")

		_smi_tag_regex = RegEx.new()
		var _err4: Error = _smi_tag_regex.compile("<[^>]+>")

	# Remove P tags but keep their content
	content = _smi_p_regex.sub(content, "", true)
	content = _smi_p_close_regex.sub(content, "", true)

	# Convert BR tags to newlines
	content = _smi_br_regex.sub(content, "\n", true)

	# Remove any remaining HTML tags (like </sync>)
	content = _smi_tag_regex.sub(content, "", true)

	# Decode HTML entities
	content = __decode_html_entities(content)

	# Clean up excessive whitespace while preserving intentional line breaks
	# Split by newlines, trim each line, remove empty lines, then rejoin
	var lines: PackedStringArray = content.split("\n")
	var cleaned_lines: Array[String] = []
	for line: String in lines:
		var trimmed: String = line.strip_edges()
		if not trimmed.is_empty():
			cleaned_lines.append(trimmed)
	content = "\n".join(cleaned_lines)

	return content


# Decodes common HTML entities in text (&amp;, &lt;, &gt;, &quot;, &nbsp;, &#DDD;, &#xHHHH;).
func __decode_html_entities(p_text: String) -> String:
	var result: String = p_text

	# Common HTML entities - chain for efficiency
	result = result.replace("&nbsp;", " ") \
	.replace("&amp;", "&") \
	.replace("&lt;", "<") \
	.replace("&gt;", ">") \
	.replace("&quot;", "\"") \
	.replace("&apos;", "'") \
	.replace("&#39;", "'") \
	.replace("&copy;", "©") \
	.replace("&reg;", "®") \
	.replace("&trade;", "™")

	# Numeric entities (basic support) - use cached regex
	if _smi_entity_regex == null:
		_smi_entity_regex = RegEx.new()
		var _err: Error = _smi_entity_regex.compile("&#([0-9]+);")

	var matches: Array[RegExMatch] = _smi_entity_regex.search_all(result)

	for match: RegExMatch in matches:
		var code: int = match.get_string(1).to_int()
		if code > 0 and code < 0x110000:
			result = result.replace(match.get_string(0), char(code))

	# Hexadecimal entities (&#xNN;) - use cached regex
	if _smi_hex_entity_regex == null:
		_smi_hex_entity_regex = RegEx.new()
		var _err2: Error = _smi_hex_entity_regex.compile("&#[xX]([0-9A-Fa-f]+);")

	var hex_matches: Array[RegExMatch] = _smi_hex_entity_regex.search_all(result)

	for match: RegExMatch in hex_matches:
		var hex_str: String = match.get_string(1)
		var code: int = hex_str.hex_to_int()
		if code > 0 and code < 0x110000:
			result = result.replace(match.get_string(0), char(code))

	return result


# Parses EBU-STL (European Broadcasting Union Subtitling Data Exchange Format) binary content.
# Reads GSI block for metadata (framerate, CCT character code table) and TTI blocks for subtitle entries.
func __parse_ebu_stl(p_bytes: PackedByteArray, p_file_path: String = "", p_remove_html_tags: bool = true, p_remove_ass_tags: bool = true) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []

	# Check if this looks like an EBU-STL file (minimum size for GSI block)
	var byte_size: int = p_bytes.size()
	if byte_size < 1024:
		push_warning("EBUSTLParser: File too small to be a valid EBU-STL file")
		return entries

	# GSI (General Subtitle Information) block is first 1024 bytes
	# TTI (Text and Timing Information) blocks follow

	# Extract framerate from GSI block (byte 5 - DFC: Disk Format Code)
	var framerate: float = 25.0
	if byte_size >= 6:
		var dfr_byte: int = p_bytes[5]
		match dfr_byte:
			0x31:
				framerate = 23.976 # STL23.01
			0x32:
				framerate = 24.0 # STL24.01
			0x33:
				framerate = 25.0 # STL25.01
			0x34:
				framerate = 29.97 # STL30.01
			0x35:
				framerate = 30.0 # STL30.01
			_:
				framerate = 25.0

	# CCT (Character Code Table) is at byte 3 of GSI
	var cct: int = 0x00 # Default to Latin
	if byte_size >= 4:
		cct = p_bytes[3]

	# Skip GSI block and parse TTI blocks
	# Each TTI block is 128 bytes
	var offset: int = 1024
	var max_offset: int = byte_size - 128

	while offset <= max_offset:
		var tti_block: PackedByteArray = p_bytes.slice(offset, offset + 128)

		# Parse TTI block
		var entry: Dictionary = __parse_ebu_stl_tti_block(tti_block, framerate, cct, p_remove_html_tags, p_remove_ass_tags)
		if not entry.is_empty():
			entries.append(entry)

		offset += 128

	# Sort entries by start time
	entries.sort_custom(
		func(p_a: Dictionary, p_b: Dictionary) -> bool:
			return p_a[SubtitleEntry._key.START_TIME] < p_b[SubtitleEntry._key.START_TIME]
	)

	# Post-process: merge consecutive entries with same timestamps
	entries = __merge_same_timestamp_entries(entries)

	# Sanity check: warn about overlapping time intervals
	__check_overlapping_intervals(entries, "EBUSTLParser", p_file_path)

	return entries


# Parses a single EBU-STL TTI (Text and Timing Information) block (128 bytes).
# Extracts timecodes, cumulative status, and text field data.
func __parse_ebu_stl_tti_block(p_block: PackedByteArray, p_framerate: float, p_cct: int, p_remove_html_tags: bool = true, p_remove_ass_tags: bool = true) -> Dictionary:
	if p_block.size() < 128:
		return { }

	# SGN (Subtitle Group Number) - byte 0
	var _sgn: int = p_block[0]

	# SN (Subtitle Number) - bytes 1-2 (BIG ENDIAN)
	var _sn: int = (p_block[1] << 8) | p_block[2]

	# EBN (Extension Block Number) - byte 3
	var ebn: int = p_block[3]

	# CS (Cumulative Status) - byte 4
	var _cs: int = p_block[4]

	# Skip if this is an extension block (EBN != 0xFF means it's a continuation)
	# We only process the first block (EBN == 0xFF)
	if ebn != 0xFF:
		return { }

	# TCI (Time Code In) - bytes 5-8 (HH:MM:SS:FF)
	# TCI (Time Code In) - bytes 5-8
	var tci_hours: int = p_block[5]
	var tci_minutes: int = p_block[6]
	var tci_seconds: int = p_block[7]
	var tci_frames: int = p_block[8]

	# TCO (Time Code Out) - bytes 9-12
	var tco_hours: int = p_block[9]
	var tco_minutes: int = p_block[10]
	var tco_seconds: int = p_block[11]
	var tco_frames: int = p_block[12]

	# Convert timecode to seconds
	var start_time: float = __parse_ebu_stl_timecode_to_seconds(tci_hours, tci_minutes, tci_seconds, tci_frames, p_framerate)
	var end_time: float = __parse_ebu_stl_timecode_to_seconds(tco_hours, tco_minutes, tco_seconds, tco_frames, p_framerate)

	# Check for invalid timecodes
	if start_time < 0 or end_time < 0 or end_time <= start_time:
		return { }

	# VP (Vertical Position) - byte 13
	# JC (Justification Code) - byte 14
	# CF (Comment Flag) - byte 15
	var cf: int = p_block[15]

	# Skip comment blocks
	if cf != 0:
		return { }

	# TF (Text Field) - bytes 16-127 (112 bytes)
	var text_field: PackedByteArray = p_block.slice(16, 128)
	var text: String = __decode_ebu_stl_text_field(text_field, p_cct)

	if text.is_empty():
		return { }

	if p_remove_html_tags:
		text = __remove_html_tags(text)

	if p_remove_ass_tags:
		text = __remove_ass_tags(text)

	return {
		SubtitleEntry._key.START_TIME: start_time,
		SubtitleEntry._key.END_TIME: end_time,
		SubtitleEntry._key.TEXT: text.strip_edges(),
	}


# Converts EBU-STL timecode (HH:MM:SS:FF) to seconds using the specified framerate.
# Returns -1.0 on invalid timecode.
func __parse_ebu_stl_timecode_to_seconds(p_hours: int, p_minutes: int, p_seconds: int, p_frames: int, p_framerate: float) -> float:
	# Validate timecode
	if p_hours > 23 or p_minutes > 59 or p_seconds > 59:
		return -1.0

	# Optimized: convert once and use multiplication
	var total_seconds: float = float(p_hours * 3600 + p_minutes * 60 + p_seconds)
	var frame_time: float = float(p_frames) / p_framerate

	return total_seconds + frame_time


# Decodes EBU-STL text field from byte array using the specified CCT (Character Code Table).
# Handles control codes (0x8A for newline, 0x8F for end) and filters out other control codes while preserving UTF-8 sequences.
func __decode_ebu_stl_text_field(p_bytes: PackedByteArray, _p_cct: int) -> String:
	# Aegisub uses UTF-8 encoding mixed with EBU STL control codes.
	# Strategy: Process byte-by-byte, detecting UTF-8 sequences and EBU control codes.
	# UTF-8 multi-byte sequences: first byte determines length
	#   - 0xxxxxxx: 1-byte (ASCII)
	#   - 110xxxxx: 2-byte sequence
	#   - 1110xxxx: 3-byte sequence
	#   - 11110xxx: 4-byte sequence
	#   - 10xxxxxx: continuation byte

	var cleaned_bytes: PackedByteArray = PackedByteArray()
	var byte_count: int = p_bytes.size()
	var i: int = 0

	while i < byte_count:
		var byte: int = p_bytes[i]

		# Check if this is the start of a UTF-8 multi-byte sequence
		if byte >= 0xC0:
			# This is a UTF-8 multi-byte sequence start
			# Determine sequence length and copy all bytes
			var seq_len: int = 0
			if byte >= 0xF0 and byte <= 0xF7:
				seq_len = 4 # 4-byte sequence
			elif byte >= 0xE0 and byte <= 0xEF:
				seq_len = 3 # 3-byte sequence
			elif byte >= 0xC0 and byte <= 0xDF:
				seq_len = 2 # 2-byte sequence

			# Copy the entire UTF-8 sequence
			for j: int in seq_len:
				if i + j < byte_count:
					var _ignore: bool = cleaned_bytes.append(p_bytes[i + j])
			i += seq_len
			continue

		# Handle single-byte cases (ASCII and control codes)
		if byte == 0x00:
			# Null, skip
			i += 1
			continue
		elif byte == 0x0A:
			# Line feed (LF) - treat as line break
			var _ignore: bool = cleaned_bytes.append(0x0A)
			i += 1
		elif byte == 0x0B:
			# Vertical tab - skip
			i += 1
			continue
		elif byte == 0x0D:
			# Carriage return (CR) - skip (we handle LF)
			i += 1
			continue
		elif byte == 0x8A:
			# EBU-STL line break - convert to newline
			var _ignore: bool = cleaned_bytes.append(0x0A)
			i += 1
		elif byte == 0x8F:
			# End of text field
			break
		elif byte >= 0x80 and byte <= 0x9F:
			# Other EBU control codes (0x80=italic start, 0x81=italic end, etc.)
			# Skip formatting codes
			i += 1
			continue
		elif byte >= 0x20 and byte <= 0x7F:
			# Standard ASCII characters
			var _ignore: bool = cleaned_bytes.append(byte)
			i += 1
		elif byte >= 0xA0:
			# Extended single-byte character (Latin-1 supplement)
			var _ignore: bool = cleaned_bytes.append(byte)
			i += 1
		else:
			# Other characters < 0x20 (control characters), skip
			i += 1

	# Decode as UTF-8 (handles Aegisub's non-standard encoding)
	var text: String = cleaned_bytes.get_string_from_utf8()

	return text


# Parses TTXT (MPEG-4 Timed Text / 3GPP Timed Text) XML content and returns an array of subtitle entry dictionaries.
# Extracts timescale from <TextStream> and <TextSample> elements with sampleTime attributes.
func __parse_ttxt(p_content: String, p_file_path: String = "", p_remove_html_tags: bool = true, p_remove_ass_tags: bool = true) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var normalized_content: String = __normalize_line_endings(p_content)

	# Parse XML
	var parser: XMLParser = XMLParser.new()
	var error: Error = parser.open_buffer(normalized_content.to_utf8_buffer())

	if error != OK:
		printerr("Failed to parse TTXT XML content")
		return entries

	var _default_framerate: float = 30.0
	var timescale: float = 1000.0 # Default timescale (milliseconds)

	# Track pending entry (TTXT uses consecutive samples for start/end)
	var pending_entry: Dictionary = { }

	# Parse document to extract entries
	while parser.read() == OK:
		if parser.get_node_type() == XMLParser.NODE_ELEMENT:
			var node_name: String = parser.get_node_name().to_lower()

			# Check for TextStream element (root) - optimized with length check
			if node_name.length() == 10 and node_name == "textstream":
				# Extract timescale if present
				if parser.has_attribute("timeScale"):
					timescale = parser.get_named_attribute_value("timeScale").to_float()
				elif parser.has_attribute("timescale"):
					timescale = parser.get_named_attribute_value("timescale").to_float()

			# Parse TextSample elements (subtitle entries) - optimized with length check
			if node_name.length() == 10 and node_name == "textsample":
				var sample_data: Dictionary = __parse_ttxt_textsample_element(parser, timescale, p_remove_html_tags, p_remove_ass_tags)

				if not sample_data.is_empty():
					# Check if this sample has text
					var text_value: String = sample_data.get("text", "")
					if sample_data.has("text") and not text_value.is_empty():
						# If we have a pending entry, finalize it with this sample's time as end
						if not pending_entry.is_empty():
							pending_entry[SubtitleEntry._key.END_TIME] = sample_data["time"]
							entries.append(pending_entry)

						# Start a new pending entry
						pending_entry = {
							SubtitleEntry._key.START_TIME: sample_data["time"],
							SubtitleEntry._key.END_TIME: sample_data["time"] + 3.0, # Default duration
							SubtitleEntry._key.TEXT: text_value,
						}
					else:
						# Empty sample - use as end time for pending entry
						if not pending_entry.is_empty():
							pending_entry[SubtitleEntry._key.END_TIME] = sample_data["time"]
							entries.append(pending_entry)
							pending_entry = { }

	# Add any remaining pending entry
	if not pending_entry.is_empty():
		entries.append(pending_entry)

	# Sort entries by start time
	entries.sort_custom(
		func(p_a: Dictionary, p_b: Dictionary) -> bool:
			return p_a[SubtitleEntry._key.START_TIME] < p_b[SubtitleEntry._key.START_TIME]
	)

	# Post-process: merge consecutive entries with same timestamps
	entries = __merge_same_timestamp_entries(entries)

	# Sanity check: warn about overlapping time intervals
	__check_overlapping_intervals(entries, "TTXTParser", p_file_path)

	return entries


# Parses a single TTXT <TextSample> element with sampleTime and text attributes or content.
# Returns a subtitle entry dictionary.
func __parse_ttxt_textsample_element(p_parser: XMLParser, p_timescale: float, p_remove_html_tags: bool = true, p_remove_ass_tags: bool = true) -> Dictionary:
	var sampleTime_attr: String = ""
	var text_attr: String = ""

	# Check for timing attributes
	if p_parser.has_attribute("sampleTime"):
		sampleTime_attr = p_parser.get_named_attribute_value("sampleTime")
	elif p_parser.has_attribute("sampletime"):
		sampleTime_attr = p_parser.get_named_attribute_value("sampletime")

	# Check for text attribute (sometimes the text is in an attribute)
	if p_parser.has_attribute("text"):
		text_attr = p_parser.get_named_attribute_value("text")

	# If no sampleTime, skip this element
	if sampleTime_attr.is_empty():
		return { }

	# Parse time value - TTXT uses HH:MM:SS.mmm format or numeric timescale units
	var sample_time: float = 0.0
	if sampleTime_attr.contains(":"):
		# HH:MM:SS.mmm format
		sample_time = __parse_ttxt_timestamp(sampleTime_attr)
		if sample_time < 0.0:
			return { }
	else:
		# Numeric timescale units
		var timescale_reciprocal: float = 1.0 / p_timescale
		var sample_time_units: float = sampleTime_attr.to_float()
		sample_time = sample_time_units * timescale_reciprocal

	# Extract text content (either from attribute or element content)
	var text: String = text_attr
	if text.is_empty():
		text = __extract_ttxt_text_content(p_parser)

	# Decode HTML entities like &#xD; (carriage return)
	text = __decode_html_entities(text)

	# Normalize line endings (convert \r to \n)
	text = text.replace("\r\n", "\n").replace("\r", "\n")

	# Clean up text
	if p_remove_html_tags:
		text = __remove_html_tags(text)

	if p_remove_ass_tags:
		text = __remove_ass_tags(text)

	# Return parsed data (let the caller handle start/end logic)
	return {
		"time": sample_time,
		"text": text.strip_edges(),
	}


# Parses TTXT timestamp in HH:MM:SS.mmm or raw milliseconds format and returns time in seconds.
# Returns -1.0 on parse error.
func __parse_ttxt_timestamp(p_timestamp: String) -> float:
	var ts: String = p_timestamp.strip_edges()

	# Find colon positions for optimized parsing
	var first_colon: int = ts.find(":")
	if first_colon < 0:
		return -1.0

	var second_colon: int = ts.find(":", first_colon + 1)
	if second_colon < 0:
		return -1.0

	# Parse hours and minutes
	var hours: float = ts.substr(0, first_colon).to_float()
	var minutes: float = ts.substr(first_colon + 1, second_colon - first_colon - 1).to_float()

	# Parse seconds and milliseconds (TTXT uses dot)
	var seconds_part: String = ts.substr(second_colon + 1)
	var dot_pos: int = seconds_part.find(".")

	var seconds: float = 0.0
	var milliseconds: float = 0.0

	if dot_pos >= 0:
		seconds = seconds_part.substr(0, dot_pos).to_float()
		milliseconds = seconds_part.substr(dot_pos + 1).to_float() * 0.001
	else:
		seconds = seconds_part.to_float()

	return hours * 3600.0 + minutes * 60.0 + seconds + milliseconds


# Extracts text content from TTXT XML element, including nested elements.
# Converts <br/> to newlines.
func __extract_ttxt_text_content(p_parser: XMLParser) -> String:
	var text_parts: Array[String] = []
	var depth: int = 0
	var initial_node_name: String = p_parser.get_node_name().to_lower()

	while p_parser.read() == OK:
		var node_type: int = p_parser.get_node_type()

		if node_type == XMLParser.NODE_ELEMENT:
			var node_name: String = p_parser.get_node_name().to_lower()

			# Handle <br> or <br/> tags by adding newline - optimized with length check
			if node_name.length() == 2 and node_name == "br":
				text_parts.append("\n")
			else:
				depth += 1

		elif node_type == XMLParser.NODE_ELEMENT_END:
			var node_name: String = p_parser.get_node_name().to_lower()

			# Check if we're closing the initial element we started with
			if depth == 0 and node_name == initial_node_name:
				break

			if depth > 0:
				depth -= 1

		elif node_type == XMLParser.NODE_TEXT:
			# Add text content (only if non-empty for efficiency)
			var text_data: String = p_parser.get_node_data()
			if not text_data.is_empty():
				text_parts.append(text_data)

	# Join efficiently with PackedStringArray
	return "".join(text_parts)


# Parses MPL2 (MPSub) subtitle format and returns an array of subtitle entry dictionaries.
# Format: [start_deciseconds][end_deciseconds]text with | as line separator.
func __parse_mpl2(p_content: String, p_file_path: String = "", p_remove_html_tags: bool = true, p_remove_ass_tags: bool = true) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var normalized_content: String = __normalize_line_endings(p_content)
	var lines: PackedStringArray = normalized_content.split("\n")

	var time_unit: float = 0.1 # MPL2 timestamps are in deciseconds

	# Parse each line of MPL2 subtitle format
	var line_count: int = lines.size()
	for line_idx: int in line_count:
		var line: String = lines[line_idx]
		var trimmed: String = line.strip_edges()
		if trimmed.is_empty():
			continue

		# MPL2 format: [start_frame][end_frame] Text with | as line breaks
		# Find the pattern [number][number] at the start
		var first_bracket: int = trimmed.find("[")
		if first_bracket != 0:
			continue

		var first_close: int = trimmed.find("]", 1)
		if first_close < 0:
			continue

		var second_bracket: int = trimmed.find("[", first_close)
		if second_bracket != first_close + 1:
			continue

		var second_close: int = trimmed.find("]", second_bracket + 1)
		if second_close < 0:
			continue

		# Extract frame numbers
		var start_frame_str: String = trimmed.substr(1, first_close - 1)
		var end_frame_str: String = trimmed.substr(second_bracket + 1, second_close - second_bracket - 1)

		if not start_frame_str.is_valid_int() or not end_frame_str.is_valid_int():
			continue

		var start_frame: int = start_frame_str.to_int()
		var end_frame: int = end_frame_str.to_int()

		# Extract text (everything after second ])
		var text: String = trimmed.substr(second_close + 1).strip_edges()

		if text.is_empty():
			continue

		# Convert frames to seconds
		var start_time: float = start_frame * time_unit
		var end_time: float = end_frame * time_unit

		# Replace pipe characters with newlines
		text = text.replace("|", "\n")

		# Clean up text
		if p_remove_html_tags:
			text = __remove_html_tags(text)

		if p_remove_ass_tags:
			text = __remove_ass_tags(text)

		entries.append(
			{
				SubtitleEntry._key.START_TIME: start_time,
				SubtitleEntry._key.END_TIME: end_time,
				SubtitleEntry._key.TEXT: text.strip_edges(),
			},
		)

	# Sort by start time
	entries.sort_custom(
		func(p_a: Dictionary, p_b: Dictionary) -> bool:
			return p_a[SubtitleEntry._key.START_TIME] < p_b[SubtitleEntry._key.START_TIME]
	)

	# Post-process: merge consecutive entries with same timestamps
	entries = __merge_same_timestamp_entries(entries)

	# Sanity check: warn about overlapping time intervals
	__check_overlapping_intervals(entries, "MPL2Parser", p_file_path)

	return entries


# Parses TMP (TMPlayer) subtitle format and returns an array of subtitle entry dictionaries.
# Multiple formats supported: HH:MM:SS:text, HH:MM:SS=text, HH:MM:SS.mmm:text
func __parse_tmp(p_content: String, p_file_path: String = "", p_remove_html_tags: bool = true, p_remove_ass_tags: bool = true) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var normalized_content: String = __normalize_line_endings(p_content)
	var lines: PackedStringArray = normalized_content.split("\n")

	var temp_entries: Array[Dictionary] = []
	var current_entry: Dictionary = { }

	# Parse each line of TMP subtitle format
	var line_count: int = lines.size()
	for line_idx: int in line_count:
		var line: String = lines[line_idx]
		var trimmed: String = line.strip_edges()
		if trimmed.is_empty():
			continue

		# TMP format: HH:MM:SS:Text
		# Check if line starts with timestamp pattern
		var colon_count: int = 0
		var first_colon: int = -1
		var second_colon: int = -1
		var third_colon: int = -1

		# Check for colons in the first part of the line
		var check_length: int = min(10, trimmed.length())
		for i: int in check_length:
			if trimmed[i] == ":":
				colon_count += 1
				if first_colon < 0:
					first_colon = i
				elif second_colon < 0:
					second_colon = i
				elif third_colon < 0:
					third_colon = i
					break

		# Need at least 3 colons for HH:MM:SS:Text
		if colon_count >= 3 and first_colon > 0 and second_colon > 0 and third_colon > 0:
			# Save previous entry if exists
			if not current_entry.is_empty():
				temp_entries.append(current_entry)

			# Parse timestamp
			var hours_str: String = trimmed.substr(0, first_colon)
			var minutes_str: String = trimmed.substr(first_colon + 1, second_colon - first_colon - 1)
			var seconds_str: String = trimmed.substr(second_colon + 1, third_colon - second_colon - 1)

			if hours_str.is_valid_int() and minutes_str.is_valid_int() and seconds_str.is_valid_int():
				var hours: int = hours_str.to_int()
				var minutes: int = minutes_str.to_int()
				var seconds: int = seconds_str.to_int()

				# Calculate start time in seconds
				var start_time: float = hours * 3600.0 + minutes * 60.0 + seconds

				# Extract text (everything after third colon)
				var text: String = trimmed.substr(third_colon + 1).strip_edges()

				# Replace pipe characters with newlines
				text = text.replace("|", "\n")

				# Start new entry
				current_entry = {
					"start": start_time,
					"text": text,
				}
		else:
			# Continuation line - append to current entry
			if not current_entry.is_empty():
				var existing_text: String = current_entry.get("text", "")
				if not existing_text.is_empty():
					current_entry["text"] = existing_text + "\n" + trimmed
				else:
					current_entry["text"] = trimmed

	# Save last entry
	if not current_entry.is_empty():
		temp_entries.append(current_entry)

	# Sort by start time
	temp_entries.sort_custom(
		func(p_a: Dictionary, p_b: Dictionary) -> bool:
			return p_a["start"] < p_b["start"]
	)

	# Calculate end times based on next subtitle or default duration
	var temp_count: int = temp_entries.size()
	# Process each temporary entry to set end times
	for i: int in temp_count:
		var entry: Dictionary = temp_entries[i]
		var start_time: float = entry["start"]
		var end_time: float

		if i < temp_count - 1:
			# End time is start of next subtitle
			end_time = temp_entries[i + 1]["start"]
		else:
			# Last entry gets default 3 second duration
			end_time = start_time + 3.0

		var text: String = entry["text"]

		# Clean up text
		if p_remove_html_tags:
			text = __remove_html_tags(text)

		if p_remove_ass_tags:
			text = __remove_ass_tags(text)

		entries.append(
			{
				SubtitleEntry._key.START_TIME: start_time,
				SubtitleEntry._key.END_TIME: end_time,
				SubtitleEntry._key.TEXT: text.strip_edges(),
			},
		)

	# Post-process: merge consecutive entries with same timestamps
	entries = __merge_same_timestamp_entries(entries)

	# Sanity check: warn about overlapping time intervals
	__check_overlapping_intervals(entries, "TMPParser", p_file_path)

	return entries


# Parses Adobe Encore subtitle format and returns an array of subtitle entry dictionaries.
# Format: <number> <start_timecode> <end_timecode> <text>
# Timecode format: HH:MM:SS:FF (hours:minutes:seconds:frames)
func __parse_encore(p_content: String, p_framerate: float = 25.0, p_file_path: String = "", p_remove_html_tags: bool = true, p_remove_ass_tags: bool = true) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var lines: PackedStringArray = __normalize_line_endings(p_content).split("\n")

	var line_count: int = lines.size()
	var i: int = 0

	while i < line_count:
		var line: String = lines[i].strip_edges()
		i += 1

		if line.is_empty():
			continue

		# Parse line format: <number> <start> <end> <text>
		var parts: PackedStringArray = line.split(" ", false, 3)
		if parts.size() < 4:
			continue

		# Verify the first part is a number and second/third parts look like timecodes
		if not parts[0].is_valid_int():
			continue

		# Check if parts[1] and parts[2] look like Adobe Encore timecodes (contain semicolons)
		if not (";" in parts[1] and ";" in parts[2]):
			continue

		# parts[0] is the subtitle number (ignored)
		var start_timecode: String = parts[1]
		var end_timecode: String = parts[2]
		var text: String = parts[3]

		# Parse timecodes (HH;MM;SS;FF format with semicolons)
		var start_time: float = __parse_encore_timecode(start_timecode, p_framerate)
		var end_time: float = __parse_encore_timecode(end_timecode, p_framerate)

		if start_time < 0.0 or end_time < 0.0:
			continue

		# Collect multi-line text
		while i < line_count:
			var next_line: String = lines[i].strip_edges()
			# Check if next line is empty
			if next_line.is_empty():
				i += 1
				break

			# Check if this looks like a new subtitle entry (number followed by timecode)
			var next_parts: PackedStringArray = next_line.split(" ", false, 3)
			if next_parts.size() >= 3 and next_parts[0].is_valid_int() and ";" in next_parts[1]:
				break

			text += "\n" + next_line
			i += 1

		# Apply formatting removal if requested
		if p_remove_html_tags:
			text = __remove_html_tags(text)
		if p_remove_ass_tags:
			text = __remove_ass_tags(text)

		entries.append(
			{
				SubtitleEntry._key.START_TIME: start_time,
				SubtitleEntry._key.END_TIME: end_time,
				SubtitleEntry._key.TEXT: text.strip_edges(),
			},
		)

	# Post-process: merge consecutive entries with same timestamps
	entries = __merge_same_timestamp_entries(entries)

	# Sanity check: warn about overlapping time intervals
	__check_overlapping_intervals(entries, "EncoreParser", p_file_path)

	return entries


# Parses Adobe Encore timecode format (HH;MM;SS;FF with semicolons) and returns time in seconds.
# Returns -1.0 on parse error.
func __parse_encore_timecode(p_timecode: String, p_framerate: float) -> float:
	var parts: PackedStringArray = p_timecode.split(";")
	if parts.size() != 4:
		return -1.0

	var hours: float = parts[0].to_float()
	var minutes: float = parts[1].to_float()
	var seconds: float = parts[2].to_float()
	var frames: float = parts[3].to_float()

	return hours * 3600.0 + minutes * 60.0 + seconds + (frames / p_framerate)


# Parses Transtation subtitle format and returns an array of subtitle entry dictionaries.
# Format: SUB[<track> <type> <start>><end>] followed by text lines
# Timecode format: HH:MM:SS:FF (hours:minutes:seconds:frames)
func __parse_transtation(p_content: String, p_framerate: float = 30.0, p_file_path: String = "", p_remove_html_tags: bool = true, p_remove_ass_tags: bool = true) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var lines: PackedStringArray = __normalize_line_endings(p_content).split("\n")

	var line_count: int = lines.size()
	var i: int = 0

	while i < line_count:
		var line: String = lines[i].strip_edges()
		i += 1

		if not line.begins_with("SUB["):
			continue

		# Find the closing bracket
		var close_bracket: int = line.find("]")
		if close_bracket < 0:
			continue

		# Extract header: SUB[0 N 00:00:21:00>00:00:27:00]
		var header: String = line.substr(4, close_bracket - 4)

		# Parse header parts
		var header_parts: PackedStringArray = header.split(" ", false)
		if header_parts.size() < 3:
			continue

		# header_parts[0] is track number (ignored)
		# header_parts[1] is type: I (italic), N (normal) (ignored for now)
		var timecode_part: String = header_parts[2]

		# Parse timecodes separated by >
		var timecode_parts: PackedStringArray = timecode_part.split(">")
		if timecode_parts.size() != 2:
			continue

		var start_time: float = __parse_transtation_timecode(timecode_parts[0], p_framerate)
		var end_time: float = __parse_transtation_timecode(timecode_parts[1], p_framerate)

		if start_time < 0.0 or end_time < 0.0:
			continue

		# Collect text lines until next SUB[ or empty line or end
		var text_lines: PackedStringArray = PackedStringArray()
		while i < line_count:
			var text_line: String = lines[i]

			# Stop at next subtitle entry
			if text_line.strip_edges().begins_with("SUB["):
				break

			# Skip completely empty lines between entries
			if text_line.strip_edges().is_empty() and text_lines.is_empty():
				i += 1
				continue

			# Stop at empty line after we have text
			if text_line.strip_edges().is_empty() and not text_lines.is_empty():
				i += 1
				break

			var _ignore: bool = text_lines.append(text_line)
			i += 1

		var text: String = "\n".join(text_lines).strip_edges()

		if text.is_empty():
			continue

		# Apply formatting removal if requested
		if p_remove_html_tags:
			text = __remove_html_tags(text)
		if p_remove_ass_tags:
			text = __remove_ass_tags(text)

		entries.append(
			{
				SubtitleEntry._key.START_TIME: start_time,
				SubtitleEntry._key.END_TIME: end_time,
				SubtitleEntry._key.TEXT: text,
			},
		)

	# Post-process: merge consecutive entries with same timestamps
	entries = __merge_same_timestamp_entries(entries)

	# Sanity check: warn about overlapping time intervals
	__check_overlapping_intervals(entries, "TranstationParser", p_file_path)

	return entries


# Parses Transtation timecode format (HH:MM:SS:FF) and returns time in seconds.
# Returns -1.0 on parse error.
func __parse_transtation_timecode(p_timecode: String, p_framerate: float) -> float:
	var parts: PackedStringArray = p_timecode.split(":")
	if parts.size() != 4:
		return -1.0

	var hours: float = parts[0].to_float()
	var minutes: float = parts[1].to_float()
	var seconds: float = parts[2].to_float()
	var frames: float = parts[3].to_float()

	return hours * 3600.0 + minutes * 60.0 + seconds + (frames / p_framerate)

# ============================================================================
# BASE HELPER FUNCTIONS (from SubtitleParser)
# ============================================================================


# Merges subtitle entries that have identical start and end timestamps by concatenating their text with newlines.
# This helps consolidate multi-line subtitles that were split into separate entries.
func __merge_same_timestamp_entries(p_entries: Array[Dictionary]) -> Array[Dictionary]:
	var entry_count: int = p_entries.size()
	if entry_count == 0:
		return p_entries

	# Pre-allocate merged array with reasonable capacity
	var merged: Array[Dictionary] = []
	var _resize_error: int = merged.resize(entry_count)
	var merged_count: int = 0

	var i: int = 0
	while i < entry_count:
		var current: Dictionary = p_entries[i]
		var start_time: float = current[SubtitleEntry._key.START_TIME]
		var end_time: float = current[SubtitleEntry._key.END_TIME]
		var text_parts: PackedStringArray = PackedStringArray()
		var current_text: String = current[SubtitleEntry._key.TEXT]
		var _append_idx: int = text_parts.append(current_text)

		# Look ahead for consecutive entries with same timestamps
		var j: int = i + 1
		while j < entry_count:
			var next: Dictionary = p_entries[j]
			var start_diff: float = next[SubtitleEntry._key.START_TIME] - start_time
			var end_diff: float = next[SubtitleEntry._key.END_TIME] - end_time

			# Use single comparison with tolerance
			if start_diff < TIMESTAMP_TOLERANCE and start_diff > -TIMESTAMP_TOLERANCE and \
			end_diff < TIMESTAMP_TOLERANCE and end_diff > -TIMESTAMP_TOLERANCE:
				var next_text: String = next[SubtitleEntry._key.TEXT]
				if not next_text.is_empty():
					var _append_idx2: int = text_parts.append(next_text)
				j += 1
			else:
				break

		# Combine text efficiently using PackedStringArray
		var combined_text: String = "\n".join(text_parts).strip_edges()

		# Add the merged entry
		merged[merged_count] = {
			SubtitleEntry._key.START_TIME: start_time,
			SubtitleEntry._key.END_TIME: end_time,
			SubtitleEntry._key.TEXT: combined_text,
		}
		merged_count += 1

		# Skip the entries we've merged
		i = j

	# Resize to actual count
	var _resize_error2: int = merged.resize(merged_count)
	return merged


func __check_overlapping_intervals(p_entries: Array[Dictionary], p_parser_name: String = "SubtitleParser", p_file_path: String = "") -> void:
	var entry_count: int = p_entries.size()
	if entry_count < 2:
		return

	var overlap_count: int = 0
	var warning_count: int = 0

	# Optimized O(n) algorithm - only check consecutive and nearby entries
	for i: int in entry_count - 1:
		var current: Dictionary = p_entries[i]
		var current_end: float = current[SubtitleEntry._key.END_TIME]

		# Only check entries that could potentially overlap
		var check_limit: int = mini(i + 10, entry_count) # Check at most 10 entries ahead
		for j: int in range(i + 1, check_limit):
			var next: Dictionary = p_entries[j]
			var next_start: float = next[SubtitleEntry._key.START_TIME]

			# If next subtitle starts after current ends, no more overlaps possible
			if next_start >= current_end:
				break

			# Check if intervals overlap
			var next_end: float = next[SubtitleEntry._key.END_TIME]
			var current_start: float = current[SubtitleEntry._key.START_TIME]

			if current_start < next_end and next_start < current_end:
				# Calculate overlap amount efficiently
				var overlap_amount: float = minf(current_end, next_end) - maxf(current_start, next_start)

				# Allow tiny overlaps (< 50ms) as they're common in subtitles
				if overlap_amount > OVERLAP_THRESHOLD:
					overlap_count += 1
					if warning_count < MAX_OVERLAP_WARNINGS:
						if p_file_path:
							push_warning(
								"%s (%s): Overlapping subtitles detected at %.2fs-%.2fs and %.2fs-%.2fs (%.2fs overlap)" % [
									p_parser_name,
									p_file_path,
									current_start,
									current_end,
									next_start,
									next_end,
									overlap_amount,
								],
							)
						else:
							push_warning(
								"%s: Overlapping subtitles detected at %.2fs-%.2fs and %.2fs-%.2fs (%.2fs overlap)" % [
									p_parser_name,
									current_start,
									current_end,
									next_start,
									next_end,
									overlap_amount,
								],
							)
						warning_count += 1

	if overlap_count > 0:
		if p_file_path:
			push_warning("%s (%s): Total overlapping subtitle pairs: %d. Linear dialogue format may not support this properly." % [p_parser_name, p_file_path, overlap_count])
		else:
			push_warning("%s: Total overlapping subtitle pairs: %d. Linear dialogue format may not support this properly." % [p_parser_name, overlap_count])


# Removes HTML/formatting tags from text using regex (<tag>content</tag> becomes content).
func __remove_html_tags(p_text: String) -> String:
	# Initialize cached regex on first use (lazy initialization)
	if _html_tag_regex == null:
		_html_tag_regex = RegEx.new()
		var _compile_error: Error = _html_tag_regex.compile("<[^>]+>")

	return _html_tag_regex.sub(p_text, "", true)


# Helper function to normalize line endings by converting \r\n and \r to \n for consistent parsing.
func __normalize_line_endings(p_content: String) -> String:
	# Optimized: replace \r\n first, then \r (fewer operations than chaining)
	return p_content.replace("\r\n", "\n").replace("\r", "\n")


# Helper function to compare timestamps with tolerance (TIMESTAMP_TOLERANCE = 1ms) to handle floating-point precision issues.
func __timestamps_equal(p_time1: float, p_time2: float) -> bool:
	var diff: float = p_time1 - p_time2
	return diff < TIMESTAMP_TOLERANCE and diff > -TIMESTAMP_TOLERANCE
