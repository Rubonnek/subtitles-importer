




























extends Node
## HTML and ASS tag removal demo for the Subtitles Importer plugin.
##
## This demo shows how to remove HTML and ASS/SSA formatting tags during
## subtitle parsing for clean text output.


func _ready() -> void:
	_demo_remove_html_tags()
	_demo_remove_ass_tags()
	_demo_remove_both_tags()


## Demo: Remove HTML tags during parsing
func _demo_remove_html_tags() -> void:
	print("\n=== Remove HTML Tags ===\n")

	var content: String = """1
00:00:01,000 --> 00:00:03,000
<b>Bold text</b> and <i>italic text</i>

2
00:00:04,000 --> 00:00:06,000
<font color="red">Red text</font> with <u>underline</u>
"""

	# Parse WITH HTML tags (default behavior when not specified)
	var subtitles_with_tags: Subtitles = Subtitles.new()
	var error: Error = subtitles_with_tags.parse_srt(content, false, false)

	if error == OK:
		print("With HTML tags:")
		for entry: SubtitleEntry in subtitles_with_tags:
			print("  ", entry.get_text())

	# Parse WITHOUT HTML tags (remove_html_tags=true)
	var subtitles_without_tags: Subtitles = Subtitles.new()
	error = subtitles_without_tags.parse_srt(content, true, false)

	if error == OK:
		print("\nWithout HTML tags:")
		for entry: SubtitleEntry in subtitles_without_tags:
			print("  ", entry.get_text())


## Demo: Remove ASS/SSA formatting tags
func _demo_remove_ass_tags() -> void:
	print("\n=== Remove ASS/SSA Tags ===\n")

	var content: String = """[Script Info]
Title: Test

[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
Dialogue: 0,0:00:01.00,0:00:03.00,Default,,0,0,0,,{\\b1}Bold text{\\b0} and {\\i1}italic{\\i0}
Dialogue: 0,0:00:04.00,0:00:06.00,Default,,0,0,0,,{\\c&HFF0000&}Colored text
"""

	# Parse WITHOUT ASS tags (remove_ass_tags=true)
	var subtitles: Subtitles = Subtitles.new()
	var error: Error = subtitles.parse_ssa(content, false, true)

	if error == OK:
		print("Without ASS tags:")
		for entry: SubtitleEntry in subtitles:
			print("  ", entry.get_text())


## Demo: Remove both HTML and ASS tags
func _demo_remove_both_tags() -> void:
	print("\n=== Remove Both HTML and ASS Tags ===\n")

	var vtt_content: String = """WEBVTT

00:00:01.000 --> 00:00:03.000
<b>Bold</b> with {\\i1}italic{\\i0} mixed

00:00:04.000 --> 00:00:06.000
<font color="red">Red</font> and {\\b1}bold{\\b0}
"""

	# Remove both types of tags
	var subtitles: Subtitles = Subtitles.new()
	var error: Error = subtitles.parse_vtt(vtt_content, true, true)

	if error == OK:
		print("Without any tags:")
		for entry: SubtitleEntry in subtitles:
			print("  ", entry.get_text())
