extends Node
## Runtime parsing demo for the Subtitles Importer plugin.
##
## This demo shows how to parse subtitle content from strings at runtime
## and load subtitle files dynamically.

func _ready() -> void:
	_example_parse_from_string()
	_example_auto_detect_format()
	_example_load_from_file()


## Parse subtitle content from a string
func _example_parse_from_string() -> void:
	print("\n=== Example 1: Parse from String ===\n")

	var srt_content: String = """1
00:00:01,000 --> 00:00:03,500
Hello, world!

2
00:00:04,000 --> 00:00:06,000
This is a subtitle example.
"""

	var subtitles: Subtitles = Subtitles.new()
	var error: Error = subtitles.parse_srt(srt_content)

	if error == OK:
		print("Successfully parsed SRT content")
		print("  Entry count: ", subtitles.get_entry_count())
		print("  First subtitle: ", subtitles.get_entry_text(0))
	else:
		printerr("Failed to parse SRT content: ", error)


## Auto-detect format using parse_from_string
func _example_auto_detect_format() -> void:
	print("\n=== Example 2: Auto-detect Format ===\n")

	var srt_content: String = """1
00:00:01,000 --> 00:00:03,500
Hello, world!

2
00:00:04,000 --> 00:00:06,000
This is a subtitle example.
"""

	var subtitles: Subtitles = Subtitles.new()
	var error: Error = subtitles.parse_from_string(srt_content, "srt")

	if error == OK:
		print("Successfully parsed using auto-detect")
		print("  Entry count: ", subtitles.get_entry_count())


## Load from file at runtime
func _example_load_from_file() -> void:
	print("\n=== Example 3: Load from File ===\n")

	# This example shows how to load from a file
	# Uncomment the following lines if you have a subtitle file available:

	# var subtitles: Subtitles = Subtitles.new()
	# var error: Error = subtitles.load_from_file("user://subtitles/video.srt")
	#
	# if error == OK:
	#     print("Successfully loaded subtitle file")
	#     print("  Entry count: ", subtitles.get_entry_count())
	# else:
	#     printerr("Failed to load subtitle file: ", error)

	print("Note: Uncomment the code in this function to test file loading")
	print("  You can load from 'res://' or 'user://' paths")
