




























extends Node
## Querying subtitles demo for the Subtitles Importer plugin.
##
## This demo shows various ways to query subtitle data using the Subtitles API.


func _ready() -> void:
	# Create sample subtitle data
	var subtitles: Subtitles = Subtitles.new()
	subtitles.add_entry(1.0, 3.0, "First subtitle")
	subtitles.add_entry(4.0, 6.0, "Second subtitle")
	subtitles.add_entry(7.0, 9.0, "Third subtitle")
	subtitles.add_entry(10.0, 12.0, "Fourth subtitle")

	_demo_get_subtitle_at_time(subtitles)
	_demo_get_entry_id_at_time(subtitles)
	_demo_get_subtitles_in_range(subtitles)
	_demo_get_duration_and_count(subtitles)
	_demo_access_entry_by_index(subtitles)


## Demo: Get subtitle text at specific time
func _demo_get_subtitle_at_time(subtitles: Subtitles) -> void:
	print("\n=== Get Subtitle at Specific Time ===\n")

	var text: String = subtitles.get_subtitle_at_time(5.0)
	print("Subtitle at 5.0s: '", text, "'")

	text = subtitles.get_subtitle_at_time(0.5)
	print("Subtitle at 0.5s: '", text, "' (empty - no subtitle active)")


## Demo: Get entry ID at specific time
func _demo_get_entry_id_at_time(subtitles: Subtitles) -> void:
	print("\n=== Get Entry ID at Specific Time ===\n")

	# Returns -1 if no subtitle is active
	# Useful for avoiding string allocations when checking if subtitle changed
	var entry_id: int = subtitles.get_entry_id_at_time(5.0)
	print("Entry ID at 5.0s: ", entry_id)

	entry_id = subtitles.get_entry_id_at_time(0.5)
	print("Entry ID at 0.5s: ", entry_id, " (no subtitle active)")


## Demo: Get all subtitles in time range
func _demo_get_subtitles_in_range(subtitles: Subtitles) -> void:
	print("\n=== Get Subtitles in Time Range ===\n")

	var entries: Array[Dictionary] = subtitles.get_subtitles_in_range(3.0, 8.0)
	print("Subtitles between 3.0s and 8.0s:")
	for entry: Dictionary in entries:
		print("  [%.1f - %.1f] %s" % [
			entry.get("start_time", 0.0),
			entry.get("end_time", 0.0),
			entry.get("text", "")
		])


## Demo: Get total duration and entry count
func _demo_get_duration_and_count(subtitles: Subtitles) -> void:
	print("\n=== Get Duration and Count ===\n")

	var duration: float = subtitles.get_total_duration()
	print("Total duration: ", duration, "s")

	var count: int = subtitles.get_entry_count()
	print("Entry count: ", count)


## Demo: Access entry by index
func _demo_access_entry_by_index(subtitles: Subtitles) -> void:
	print("\n=== Access Entry by Index ===\n")

	if subtitles.get_entry_count() > 0:
		var start_time: float = subtitles.get_entry_start_time(0)
		var end_time: float = subtitles.get_entry_end_time(0)
		var entry_text: String = subtitles.get_entry_text(0)

		print("First entry:")
		print("  Start time: ", start_time, "s")
		print("  End time: ", end_time, "s")
		print("  Text: '", entry_text, "'")
