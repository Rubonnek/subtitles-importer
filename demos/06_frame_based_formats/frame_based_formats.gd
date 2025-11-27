




























extends Node
## Frame-based formats demo for the Subtitles Importer plugin.
##
## This demo shows how to parse frame-based subtitle formats with custom
## framerates. Frame-based formats use frame numbers instead of timestamps.


func _ready() -> void:
	_demo_parse_microdvd()
	_demo_parse_mpl2()
	_demo_parse_scc()
	_demo_parse_tmp()
	_demo_load_from_file_with_framerate()


## Demo: Parse MicroDVD with custom framerate
func _demo_parse_microdvd() -> void:
	print("\n=== Parse MicroDVD (SUB) Format ===\n")

	var content: String = """{25}{75}First subtitle at frames 25-75
{100}{150}Second subtitle at frames 100-150
{200}{250}Third subtitle at frames 200-250
"""

	# Parse with 29.97 fps (common for NTSC video)
	var subtitles: Subtitles = Subtitles.new()
	var error: Error = subtitles.parse_sub(content, 29.97)

	if error == OK:
		print("MicroDVD parsed at 29.97 fps:")
		for entry: SubtitleEntry in subtitles:
			print("  [%.2fs - %.2fs] %s" % [
				entry.get_start_time(),
				entry.get_end_time(),
				entry.get_text()
			])
	else:
		printerr("Failed to parse MicroDVD content")


## Demo: Parse MPL2 with custom framerate
func _demo_parse_mpl2() -> void:
	print("\n=== Parse MPL2/MPSub Format ===\n")

	var content: String = """[25][75]First subtitle
[100][150]Second subtitle
[200][250]Third subtitle
"""

	# Parse with 25 fps (PAL standard)
	var subtitles: Subtitles = Subtitles.new()
	var error: Error = subtitles.parse_mpl2(content, 25.0)

	if error == OK:
		print("MPL2 parsed at 25 fps:")
		for entry: SubtitleEntry in subtitles:
			print("  [%.2fs - %.2fs] %s" % [
				entry.get_start_time(),
				entry.get_end_time(),
				entry.get_text()
			])
	else:
		printerr("Failed to parse MPL2 content")


## Demo: Parse SCC with custom framerate
func _demo_parse_scc() -> void:
	print("\n=== Parse Scenarist (SCC) Format ===\n")

	var content: String = """Scenarist_SCC V1.0

00:00:01:00	9420 9420 94ae 94ae 9452 9452 97a2 97a2 54e5 73f4 2043 61f0 f4e9 ef6e

00:00:03:00	942c 942c

00:00:04:00	9420 9420 94ae 94ae 9452 9452 97a2 97a2 53e5 e3ef 6e64 2054 e5f8 f4

00:00:06:00	942c 942c
"""

	# Parse with 23.976 fps (common for film)
	var subtitles: Subtitles = Subtitles.new()
	var error: Error = subtitles.parse_scc(content, 23.976)

	if error == OK:
		print("SCC parsed at 23.976 fps:")
		print("  Entry count: ", subtitles.get_entry_count())
		if subtitles.get_entry_count() > 0:
			print("  First entry: '", subtitles.get_entry_text(0), "'")
	else:
		printerr("Failed to parse SCC content")


## Demo: Parse TMPlayer (TMP) format
func _demo_parse_tmp() -> void:
	print("\n=== Parse TMPlayer (TMP) Format ===\n")

	var content: String = """00:00:01:First subtitle
00:00:04:Second subtitle
00:00:07:Third subtitle with|line break
"""

	# TMPlayer uses time-based format (not frames)
	var subtitles: Subtitles = Subtitles.new()
	var error: Error = subtitles.parse_tmp(content)

	if error == OK:
		print("TMPlayer parsed:")
		for entry: SubtitleEntry in subtitles:
			print("  [%.2fs - %.2fs] %s" % [
				entry.get_start_time(),
				entry.get_end_time(),
				entry.get_text()
			])
	else:
		printerr("Failed to parse TMPlayer content")


## Demo: Load from file with auto-detect or specified framerate
func _demo_load_from_file_with_framerate() -> void:
	print("\n=== Load from File with Framerate ===\n")

	# Example of how to load frame-based subtitle files
	# Uncomment the following lines if you have a subtitle file available:

	# var subtitles: Subtitles = Subtitles.new()
	# var error: Error = subtitles.load_from_file("res://subtitles/video.sub", 25.0)
	#
	# if error == OK:
	#     print("Successfully loaded subtitle file with framerate")
	#     print("  Entry count: ", subtitles.get_entry_count())
	# else:
	#     printerr("Failed to load subtitle file: ", error)

	print("Note: Uncomment the code in this function to test file loading")
	print("  You can specify framerate as the second parameter")
	print("  Common framerates: 23.976, 24, 25, 29.97, 30, 60 fps")
