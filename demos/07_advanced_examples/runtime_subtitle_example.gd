




























extends Node
## Example script demonstrating runtime subtitle parsing and usage.
##
## This example shows various ways to use the Subtitles resource at runtime.
@export var video_player: VideoStreamPlayer
@export var audio_player: AudioStreamPlayer
@export var subtitle_label: Label

var subtitle_data: Subtitles = Subtitles.new()
var current_time: float = 0.0


func _ready() -> void:
	# Example 1: Load subtitle file at runtime
	_example_load_from_file()

	# Example 2: Parse subtitle content from string
	_example_parse_from_string()

	# Example 3: Parse different subtitle formats
	_example_parse_different_formats()


## Example 1: Load and parse a subtitle file at runtime
func _example_load_from_file() -> void:
	var subtitle_path: String = "res://subtitles/video.srt"
	var error: Error = subtitle_data.load_from_file(subtitle_path)

	if error == OK:
		print("Successfully loaded subtitle file")
		print("  Entries: ", subtitle_data.get_entry_count())
		print("  Duration: ", subtitle_data.get_total_duration(), " seconds")
	else:
		printerr("Failed to load subtitle file: ", error)


## Example 2: Parse subtitle content from string
func _example_parse_from_string() -> void:
	var srt_content: String = """1
00:00:01,000 --> 00:00:03,500
Hello, world!

2
00:00:04,000 --> 00:00:06,000
This is a subtitle example.
"""

	var subtitle: Subtitles = Subtitles.new()
	var error: Error = subtitle.parse_srt(srt_content)

	if error == OK:
		print("Parsed SRT content successfully")
		# Get subtitle at specific time
		var text: String = subtitle.get_subtitle_at_time(2.0)
		print("  Subtitle at 2.0s: ", text)

	# You can also use parse_from_string with explicit format
	var _err1: Error = subtitle.parse_from_string(srt_content, "srt", false)

	# Or parse VTT format
	var vtt_content: String = """WEBVTT

00:00:01.000 --> 00:00:03.500
Hello from VTT!
"""
	var _err2: Error = subtitle.parse_vtt(vtt_content)


## Example 3: Parse different subtitle formats using Subtitles class
func _example_parse_different_formats() -> void:
	var lrc_content: String = """[ar:Artist Name]
[ti:Song Title]
[00:20.00]First lyric line
[00:24.60]Second lyric line
[00:28.50]Third lyric line
"""

	# Parse using Subtitles class
	var lrc_subtitle: Subtitles = Subtitles.new()
	var error: Error = lrc_subtitle.parse_lrc(lrc_content, false)

	if error == OK:
		print("Parsed LRC entries:")
		# Using SubtitleEntry iterator
		for entry: SubtitleEntry in lrc_subtitle:
			print("  ", entry)  # Uses _to_string()
			# Or access individual fields:
			# print("  [%.2f - %.2f] %s" % [entry.get_start_time(), entry.get_end_time(), entry.get_text()])


## Example 4: Sync subtitles with video playback (optimized with entry ID caching)
var _last_entry_id: int = -1

func _process(_p_delta: float) -> void:
	if video_player == null or subtitle_label == null:
		return

	# Get current playback position
	current_time = video_player.stream_position

	# Optimized approach: Use get_entry_id_at_time() to avoid string allocations
	# Only update the label text when the subtitle actually changes
	var current_entry_id: int = subtitle_data.get_entry_id_at_time(current_time)

	if current_entry_id != _last_entry_id:
		_last_entry_id = current_entry_id

		if current_entry_id == -1:
			# No subtitle active
			subtitle_label.text = ""
		else:
			# Get the subtitle text only when it changed
			subtitle_label.text = subtitle_data.get_entry_text(current_entry_id)

	# Alternative (less optimized): Get subtitle text directly
	# var subtitle_text: String = subtitle_data.get_subtitle_at_time(current_time)
	# subtitle_label.text = subtitle_text

	# You can also get all subtitles in a time range
	var range_start: float = current_time
	var range_end: float = current_time + 5.0
	var upcoming_subtitles: Array[Dictionary] = subtitle_data.get_subtitles_in_range(range_start, range_end)

	if not upcoming_subtitles.is_empty():
		# Do something with upcoming subtitles (e.g., preload, highlight, etc.)
		pass


## Example 5: Manually create subtitle data
func _example_manual_creation() -> void:
	var manual_subtitle: Subtitles = Subtitles.new()

	# Add entries manually
	manual_subtitle.add_entry(0.0, 2.5, "First subtitle")
	manual_subtitle.add_entry(3.0, 5.0, "Second subtitle")
	manual_subtitle.add_entry(5.5, 8.0, "Third subtitle")

	print("Manual subtitle data created with ", manual_subtitle.get_entry_count(), " entries")

	# Clear all entries if needed
	manual_subtitle.clear_entries()


## Example 6: Advanced subtitle querying
func _example_advanced_querying() -> void:
	# Find all subtitles in first 10 seconds
	var early_subtitles: Array[Dictionary] = subtitle_data.get_subtitles_in_range(0.0, 10.0)

	print("Found ", early_subtitles.size(), " subtitles in first 10 seconds")

	# Check if subtitle exists at specific time
	var text_at_five: String = subtitle_data.get_subtitle_at_time(5.0)
	if not text_at_five.is_empty():
		print("Subtitle active at 5s: ", text_at_five)
	else:
		print("No subtitle at 5 seconds")

	# Get total duration
	var duration: float = subtitle_data.get_total_duration()
	print("Total subtitle duration: ", duration, " seconds")

	# Use helper methods to access entry data by index
	if subtitle_data.get_entry_count() > 0:
		print("First entry start time: ", subtitle_data.get_entry_start_time(0))
		print("First entry end time: ", subtitle_data.get_entry_end_time(0))
		print("First entry text: ", subtitle_data.get_entry_text(0))

	# Use SubtitleEntry wrapper
	var first_entry: SubtitleEntry = subtitle_data.get_subtitle_entry(0)
	if first_entry != null:
		print("First entry (using SubtitleEntry): ", first_entry)
		print("  Duration: ", first_entry.get_duration(), " seconds")
		print("  Active at 1.0s? ", first_entry.is_active_at(1.0))


## Example 7: Load subtitles with HTML tag removal
func _example_with_html_removal() -> void:
	var html_content: String = """1
00:00:01,000 --> 00:00:03,000
<b>Bold text</b> and <i>italic text</i>

2
00:00:04,000 --> 00:00:06,000
<font color="red">Red text</font>
"""

	var subtitle_with_html: Subtitles = Subtitles.new()
	var subtitle_without_html: Subtitles = Subtitles.new()

	# Parse with HTML tags
	var _err3: Error = subtitle_with_html.parse_srt(html_content, false)

	# Parse with HTML tags removed
	var _err4: Error = subtitle_without_html.parse_srt(html_content, true)

	print("With HTML: ", subtitle_with_html.get_subtitle_at_time(2.0))
	print("Without HTML: ", subtitle_without_html.get_subtitle_at_time(2.0))
