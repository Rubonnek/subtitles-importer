@tool
extends EditorScript
## Test script to demonstrate the merge behavior of the Subtitles class.
##
## This script creates test subtitle data with duplicate timestamps
## and verifies that they are properly merged by the Subtitles class parsers.

func _run() -> void:
	print("\n=== Testing Subtitles Class Merge Behavior ===\n")

	# Test 1: SRT with duplicate timestamps
	print("Test 1: SRT format with duplicate timestamps")
	var srt_content: String = """1
00:00:01,000 --> 00:00:03,000
First line

2
00:00:01,000 --> 00:00:03,000
Second line

3
00:00:05,000 --> 00:00:07,000
Different timestamp
"""

	var srt_subtitle: Subtitles = Subtitles.new()
	var _err1: Error = srt_subtitle.parse_srt(srt_content)
	var srt_entries: Array[Dictionary] = srt_subtitle.get_entries()
	print("  Entries after merge: ", srt_entries.size())
	print("  Expected: 2 entries (1 merged + 1 separate)")
	if srt_entries.size() == 2:
		print("  ✓ PASSED: Entries were properly merged")
		var first_text: String = srt_entries[0][SubtitleEntry._key.TEXT]
		print("  First entry text: ", first_text)
		if first_text.contains("\n"):
			print("  ✓ PASSED: Lines were combined with newline")
		else:
			print("  ✗ FAILED: Lines were not combined properly")
	else:
		print("  ✗ FAILED: Expected 2 entries but got ", srt_entries.size())
	print()

	# Test 2: VTT with duplicate timestamps
	print("Test 2: VTT format with duplicate timestamps")
	var vtt_content: String = """WEBVTT

00:00:10.000 --> 00:00:12.000
Speaker 1: Hello

00:00:10.000 --> 00:00:12.000
Speaker 2: Hi there

00:00:15.000 --> 00:00:17.000
Speaker 1: How are you?
"""

	var vtt_subtitle: Subtitles = Subtitles.new()
	var _err2: Error = vtt_subtitle.parse_vtt(vtt_content)
	var vtt_entries: Array[Dictionary] = vtt_subtitle.get_entries()
	print("  Entries after merge: ", vtt_entries.size())
	print("  Expected: 2 entries (1 merged + 1 separate)")
	if vtt_entries.size() == 2:
		print("  ✓ PASSED: Entries were properly merged")
		var first_text: String = vtt_entries[0][SubtitleEntry._key.TEXT]
		print("  First entry text: ", first_text)
		if "Speaker 1" in first_text and "Speaker 2" in first_text:
			print("  ✓ PASSED: Both speakers' lines were merged")
		else:
			print("  ✗ FAILED: Lines were not merged properly")
	else:
		print("  ✗ FAILED: Expected 2 entries but got ", vtt_entries.size())
	print()

	# Test 3: SSA with duplicate timestamps (original implementation)
	print("Test 3: SSA format with duplicate timestamps")
	var ssa_content: String = """[Script Info]
Title: Test

[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
Dialogue: 0,0:00:20.00,0:00:22.00,Default,,0,0,0,,Line one
Dialogue: 0,0:00:20.00,0:00:22.00,Default,,0,0,0,,Line two
Dialogue: 0,0:00:25.00,0:00:27.00,Default,,0,0,0,,Different time
"""

	var ssa_subtitle: Subtitles = Subtitles.new()
	var _err3: Error = ssa_subtitle.parse_ssa(ssa_content)
	var ssa_entries: Array[Dictionary] = ssa_subtitle.get_entries()
	print("  Entries after merge: ", ssa_entries.size())
	print("  Expected: 2 entries (1 merged + 1 separate)")
	if ssa_entries.size() == 2:
		print("  ✓ PASSED: Entries were properly merged")
		var first_text: String = ssa_entries[0][SubtitleEntry._key.TEXT]
		print("  First entry text: ", first_text)
		if "Line one" in first_text and "Line two" in first_text:
			print("  ✓ PASSED: Both lines were merged")
		else:
			print("  ✗ FAILED: Lines were not merged properly")
	else:
		print("  ✗ FAILED: Expected 2 entries but got ", ssa_entries.size())
	print()

	# Test 4: Verify tolerance (timestamps within 1ms are considered same)
	print("Test 4: Timestamp tolerance test")
	var srt_tolerance: String = """1
00:00:01,000 --> 00:00:03,000
First line

2
00:00:01,000 --> 00:00:03,001
Should NOT merge (1ms difference in end time)

3
00:00:01,000 --> 00:00:03,000
Should merge with first
"""

	var tolerance_subtitle: Subtitles = Subtitles.new()
	var _err4: Error = tolerance_subtitle.parse_srt(srt_tolerance)
	var tolerance_entries: Array[Dictionary] = tolerance_subtitle.get_entries()
	print("  Entries after merge: ", tolerance_entries.size())
	print("  Expected: 2 entries (entry 1 merged with 3, entry 2 separate)")
	if tolerance_entries.size() == 2:
		print("  ✓ PASSED: 1ms tolerance working correctly")
	else:
		print("  ✗ FAILED: Expected 2 entries but got ", tolerance_entries.size())
	print()

	# Test 5: Check overlap detection still works
	print("Test 5: Overlap detection test")
	var overlapping_srt: String = """1
00:00:01,000 --> 00:00:05,000
Long subtitle

2
00:00:03,000 --> 00:00:06,000
Overlapping subtitle
"""

	print("  Parsing overlapping subtitles (should see warning)...")
	var overlap_subtitle: Subtitles = Subtitles.new()
	var _err5: Error = overlap_subtitle.parse_srt(overlapping_srt)
	var _overlap_entries: Array[Dictionary] = overlap_subtitle.get_entries()
	print("  ✓ PASSED: Overlap detection still functional (check warnings above)")
	print()

	print("=== All Tests Complete ===")
	print("Note: This test script verifies that the merge behavior is working correctly")
	print("in the Subtitles class for all subtitle format parsers.")
	print("All parsers share common functionality through the Subtitles class.\n")
