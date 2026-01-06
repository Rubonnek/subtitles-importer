extends Node
## Example demonstrating the SubtitleEntry iterator and helper methods.
##
## This example shows how to use the new iterator functionality
## to loop through subtitle entries using SubtitleEntry objects.

func _ready() -> void:
	_example_basic_iterator()
	_example_helper_methods()
	_example_subtitle_entry_methods()
	_example_finding_active_subtitles()


## Example 1: Basic iterator usage with SubtitleEntry
func _example_basic_iterator() -> void:
	print("\n=== Example 1: Basic Iterator Usage ===\n")

	var srt_content: String = """1
00:00:01,000 --> 00:00:03,000
First subtitle line

2
00:00:04,000 --> 00:00:06,000
Second subtitle line

3
00:00:07,000 --> 00:00:09,000
Third subtitle line
"""

	var subtitles: Subtitles = Subtitles.new()
	var error: Error = subtitles.parse_srt(srt_content)

	if error == OK:
		print("Using iterator to loop through entries:")
		# The subtitles object is now iterable!
		for entry: SubtitleEntry in subtitles:
			print("  ", entry) # Uses SubtitleEntry._to_string()

		print("\nAccessing individual fields:")
		for entry: SubtitleEntry in subtitles:
			print(
				"  Start: %.2fs, End: %.2fs, Duration: %.2fs" % [
					entry.get_start_time(),
					entry.get_end_time(),
					entry.get_duration(),
				],
			)
			print("    Text: ", entry.get_text())


## Example 2: Using helper methods to access entries by index
func _example_helper_methods() -> void:
	print("\n=== Example 2: Helper Methods ===\n")

	var subtitles: Subtitles = Subtitles.new()
	subtitles.add_entry(0.0, 2.5, "Entry 1")
	subtitles.add_entry(3.0, 5.0, "Entry 2")
	subtitles.add_entry(5.5, 8.0, "Entry 3")

	print("Total entries: ", subtitles.get_entry_count())
	print("\nAccessing by index using helper methods:")

	for i: int in range(subtitles.get_entry_count()):
		var start: float = subtitles.get_entry_start_time(i)
		var end: float = subtitles.get_entry_end_time(i)
		var text: String = subtitles.get_entry_text(i)
		print("  Entry %d: [%.2fs - %.2fs] %s" % [i, start, end, text])

	# Out of bounds handling
	print("\nOut of bounds test:")
	print("  Entry at index 99: ", subtitles.get_entry_text(99)) # Returns ""
	print("  Start time at index -1: ", subtitles.get_entry_start_time(-1)) # Returns 0.0


## Example 3: Using SubtitleEntry wrapper objects
func _example_subtitle_entry_methods() -> void:
	print("\n=== Example 3: SubtitleEntry Methods ===\n")

	var subtitles: Subtitles = Subtitles.new()
	subtitles.add_entry(1.0, 4.5, "This is a longer subtitle")
	subtitles.add_entry(5.0, 6.0, "Short")
	subtitles.add_entry(7.0, 12.0, "Another long one")

	print("Analyzing subtitle durations:")
	for entry: SubtitleEntry in subtitles:
		var duration: float = entry.get_duration()
		var classification: String = "short" if duration < 2.0 else "medium" if duration < 4.0 else "long"
		print("  %.2fs duration (%s): %s" % [duration, classification, entry.get_text()])

	# Using get_subtitle_entry to get a specific entry
	print("\nGetting specific entry by index:")
	var second_entry: SubtitleEntry = subtitles.get_subtitle_entry(1)
	if second_entry != null:
		print("  Second entry: ", second_entry)
		print("  Duration: %.2fs" % second_entry.get_duration())


## Example 4: Finding active subtitles at specific times
func _example_finding_active_subtitles() -> void:
	print("\n=== Example 4: Finding Active Subtitles ===\n")

	var vtt_content: String = """WEBVTT

00:00:01.000 --> 00:00:03.500
Subtitle A

00:00:03.000 --> 00:00:05.000
Subtitle B (overlapping!)

00:00:06.000 --> 00:00:08.000
Subtitle C
"""

	var subtitles: Subtitles = Subtitles.new()
	var error: Error = subtitles.parse_vtt(vtt_content)

	if error == OK:
		var test_times: Array[float] = [0.5, 2.0, 3.25, 4.0, 7.0, 9.0]

		print("Testing which subtitles are active at specific times:")
		for test_time: float in test_times:
			print("\nAt %.2fs:" % test_time)
			var found_active: bool = false

			# Using iterator to check each entry
			for entry: SubtitleEntry in subtitles:
				if entry.is_active_at(test_time):
					print("  ✓ Active: ", entry.get_text())
					found_active = true

			if not found_active:
				print("  (no active subtitles)")

		# Compare with built-in method
		print("\n\nUsing built-in get_subtitle_at_time():")
		for test_time: float in test_times:
			var text: String = subtitles.get_subtitle_at_time(test_time)
			if text.is_empty():
				print("  At %.2fs: (no subtitle)" % test_time)
			else:
				print("  At %.2fs: %s" % [test_time, text])


## Example 5: Filtering and processing entries
func _example_filtering() -> void:
	print("\n=== Example 5: Filtering Entries ===\n")

	var subtitles: Subtitles = Subtitles.new()
	subtitles.add_entry(0.0, 2.0, "Hello")
	subtitles.add_entry(2.5, 3.0, "This is a very long subtitle with lots of text")
	subtitles.add_entry(3.5, 5.0, "Short")
	subtitles.add_entry(6.0, 15.0, "Super long duration subtitle")

	print("Finding long text entries (> 30 characters):")
	for entry: SubtitleEntry in subtitles:
		if entry.get_text().length() > 30:
			print("  ", entry)

	print("\nFinding long duration entries (> 5 seconds):")
	for entry: SubtitleEntry in subtitles:
		if entry.get_duration() > 5.0:
			print("  ", entry)

	print("\nFinding entries in specific time range (0-4 seconds):")
	for entry: SubtitleEntry in subtitles:
		if entry.get_start_time() >= 0.0 and entry.get_end_time() <= 4.0:
			print("  ", entry)


## Example 6: Creating a subtitle timeline
func _example_timeline() -> void:
	print("\n=== Example 6: Creating a Timeline ===\n")

	var subtitles: Subtitles = Subtitles.new()
	subtitles.add_entry(0.0, 2.0, "Start")
	subtitles.add_entry(2.5, 4.0, "Middle")
	subtitles.add_entry(5.0, 7.0, "End")

	var total_duration: float = subtitles.get_total_duration()
	print("Total duration: %.2fs" % total_duration)
	print("\nTimeline visualization:")

	var timeline_width: int = 50
	for entry: SubtitleEntry in subtitles:
		var start_pos: int = int((entry.get_start_time() / total_duration) * timeline_width)
		var end_pos: int = int((entry.get_end_time() / total_duration) * timeline_width)
		var width: int = maxi(end_pos - start_pos, 1)

		var line: String = " ".repeat(start_pos) + "█".repeat(width)
		print("  %s [%.1fs-%.1fs] %s" % [line, entry.get_start_time(), entry.get_end_time(), entry.get_text()])
