




























@tool
extends EditorScript
## Test script to verify the get_entry_id_at_time() function.
##
## This script tests that get_entry_id_at_time() returns the correct entry index
## for various time values and validates edge cases.


func _run() -> void:
	print("\n=== Testing get_entry_id_at_time() Function ===\n")

	_test_basic_functionality()
	_test_edge_cases()
	_test_performance_comparison()
	_test_with_real_subtitle_file()

	print("\n=== All Tests Complete ===\n")


## Test 1: Basic functionality with simple SRT content
func _test_basic_functionality() -> void:
	print("Test 1: Basic functionality")

	var srt_content: String = """1
00:00:01,000 --> 00:00:03,000
First subtitle

2
00:00:04,000 --> 00:00:06,000
Second subtitle

3
00:00:07,000 --> 00:00:09,000
Third subtitle
"""

	var subtitles: Subtitles = Subtitles.new()
	var error: Error = subtitles.parse_srt(srt_content)

	if error != OK:
		printerr("  ✗ Failed to parse SRT content")
		return

	# Test times within subtitle ranges
	var test_cases: Array = [
		{"time": 0.5, "expected": -1, "desc": "Before first subtitle"},
		{"time": 1.0, "expected": 0, "desc": "Start of first subtitle"},
		{"time": 2.0, "expected": 0, "desc": "Middle of first subtitle"},
		{"time": 3.0, "expected": 0, "desc": "End of first subtitle"},
		{"time": 3.5, "expected": -1, "desc": "Between first and second"},
		{"time": 4.0, "expected": 1, "desc": "Start of second subtitle"},
		{"time": 5.0, "expected": 1, "desc": "Middle of second subtitle"},
		{"time": 6.0, "expected": 1, "desc": "End of second subtitle"},
		{"time": 6.5, "expected": -1, "desc": "Between second and third"},
		{"time": 7.0, "expected": 2, "desc": "Start of third subtitle"},
		{"time": 8.0, "expected": 2, "desc": "Middle of third subtitle"},
		{"time": 9.0, "expected": 2, "desc": "End of third subtitle"},
		{"time": 10.0, "expected": -1, "desc": "After last subtitle"}
	]

	var passed: int = 0
	var failed: int = 0

	for test: Dictionary in test_cases:
		var time: float = test["time"]
		var expected: int = test["expected"]
		var desc: String = test["desc"]
		var result: int = subtitles.get_entry_id_at_time(time)

		if result == expected:
			print("  ✓ %s: time=%.1fs, entry_id=%d" % [desc, time, result])
			passed += 1
		else:
			printerr("  ✗ %s: time=%.1fs, expected=%d, got=%d" % [desc, time, expected, result])
			failed += 1

	print("  Result: %d passed, %d failed\n" % [passed, failed])


## Test 2: Edge cases
func _test_edge_cases() -> void:
	print("Test 2: Edge cases")

	# Empty subtitles
	var empty_subtitles: Subtitles = Subtitles.new()
	var result: int = empty_subtitles.get_entry_id_at_time(5.0)

	if result == -1:
		print("  ✓ Empty subtitles returns -1")
	else:
		printerr("  ✗ Empty subtitles should return -1, got %d" % result)

	# Negative time
	var subtitles: Subtitles = Subtitles.new()
	subtitles.add_entry(1.0, 3.0, "Test")
	result = subtitles.get_entry_id_at_time(-1.0)

	if result == -1:
		print("  ✓ Negative time returns -1")
	else:
		printerr("  ✗ Negative time should return -1, got %d" % result)

	# Very large time
	result = subtitles.get_entry_id_at_time(99999.0)

	if result == -1:
		print("  ✓ Very large time returns -1")
	else:
		printerr("  ✗ Very large time should return -1, got %d" % result)

	print("")


## Test 3: Performance comparison with get_subtitle_at_time()
func _test_performance_comparison() -> void:
	print("Test 3: Performance comparison")

	# Create a subtitle file with many entries
	var srt_content: String = ""
	for i: int in range(100):
		var start_sec: int = i * 2
		var end_sec: int = start_sec + 1
		srt_content += "%d\n00:00:%02d,000 --> 00:00:%02d,000\nSubtitle %d\n\n" % [i + 1, start_sec, end_sec, i + 1]

	var subtitles: Subtitles = Subtitles.new()
	var error: Error = subtitles.parse_srt(srt_content)

	if error != OK:
		printerr("  ✗ Failed to parse SRT content")
		return

	var iterations: int = 1000
	var test_time: float = 50.0

	# Test get_entry_id_at_time() performance
	var start_ticks: int = Time.get_ticks_usec()
	for i: int in range(iterations):
		var _entry_id: int = subtitles.get_entry_id_at_time(test_time)
	var entry_id_time: int = Time.get_ticks_usec() - start_ticks

	# Test get_subtitle_at_time() performance
	start_ticks = Time.get_ticks_usec()
	for i: int in range(iterations):
		var _text: String = subtitles.get_subtitle_at_time(test_time)
	var subtitle_time: int = Time.get_ticks_usec() - start_ticks

	print("  get_entry_id_at_time() x%d: %d μs (%.2f μs/call)" % [iterations, entry_id_time, float(entry_id_time) / iterations])
	print("  get_subtitle_at_time() x%d: %d μs (%.2f μs/call)" % [iterations, subtitle_time, float(subtitle_time) / iterations])

	if entry_id_time < subtitle_time:
		var speedup: float = float(subtitle_time) / float(entry_id_time)
		print("  ✓ get_entry_id_at_time() is %.2fx faster" % speedup)
	else:
		print("  Note: Performance may vary based on subtitle content")

	print("")


## Test 4: Integration test with real subtitle formats
func _test_with_real_subtitle_file() -> void:
	print("Test 4: Integration with different formats")

	# Test VTT format
	var vtt_content: String = """WEBVTT

00:00:01.000 --> 00:00:03.000
VTT subtitle one

00:00:04.500 --> 00:00:06.500
VTT subtitle two
"""

	var vtt_subtitles: Subtitles = Subtitles.new()
	var error: Error = vtt_subtitles.parse_vtt(vtt_content)

	if error == OK:
		var entry_id: int = vtt_subtitles.get_entry_id_at_time(2.0)
		if entry_id == 0:
			print("  ✓ VTT format: correct entry_id at 2.0s")
		else:
			printerr("  ✗ VTT format: expected entry_id=0, got %d" % entry_id)
	else:
		printerr("  ✗ Failed to parse VTT content")

	# Test LRC format
	var lrc_content: String = """[00:01.00]LRC lyric one
[00:03.50]LRC lyric two
[00:06.00]LRC lyric three
"""

	var lrc_subtitles: Subtitles = Subtitles.new()
	error = lrc_subtitles.parse_lrc(lrc_content)

	if error == OK:
		var entry_id: int = lrc_subtitles.get_entry_id_at_time(4.0)
		if entry_id == 1:
			print("  ✓ LRC format: correct entry_id at 4.0s")
		else:
			printerr("  ✗ LRC format: expected entry_id=1, got %d" % entry_id)
	else:
		printerr("  ✗ Failed to parse LRC content")

	# Verify consistency between get_entry_id_at_time() and get_subtitle_at_time()
	print("\n  Verifying consistency between functions:")
	var test_times: Array[float] = [0.5, 1.5, 2.5, 4.0, 5.0, 7.0]
	var consistent: bool = true

	for time: float in test_times:
		var entry_id: int = vtt_subtitles.get_entry_id_at_time(time)
		var text_via_id: String = vtt_subtitles.get_entry_text(entry_id) if entry_id != -1 else ""
		var text_direct: String = vtt_subtitles.get_subtitle_at_time(time)

		if text_via_id == text_direct:
			print("    ✓ Time %.1fs: consistent (entry_id=%d)" % [time, entry_id])
		else:
			printerr("    ✗ Time %.1fs: inconsistent (via_id='%s', direct='%s')" % [time, text_via_id, text_direct])
			consistent = false

	if consistent:
		print("  ✓ All functions return consistent results")

	print("")
