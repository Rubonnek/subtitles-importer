




























extends Node
## Iterator usage demo for the Subtitles Importer plugin.
##
## This demo shows how to iterate through subtitle entries using the
## SubtitleEntry iterator and check if entries are active at specific times.


func _ready() -> void:
	# Create sample subtitle data
	var subtitles: Subtitles = Subtitles.new()
	subtitles.add_entry(1.0, 3.0, "First subtitle")
	subtitles.add_entry(4.0, 6.0, "Second subtitle")
	subtitles.add_entry(7.0, 9.0, "Third subtitle")
	subtitles.add_entry(10.0, 12.0, "Fourth subtitle")

	_demo_iterate_through_entries(subtitles)
	_demo_check_active_at_time(subtitles)


## Demo: Iterate through all subtitle entries
func _demo_iterate_through_entries(subtitles: Subtitles) -> void:
	print("\n=== Iterate Through All Subtitle Entries ===\n")

	for entry: SubtitleEntry in subtitles:
		print("[%.2f - %.2f] %s" % [
			entry.get_start_time(),
			entry.get_end_time(),
			entry.get_text()
		])


## Demo: Check if entry is active at specific time
func _demo_check_active_at_time(subtitles: Subtitles) -> void:
	print("\n=== Check if Entry is Active at Specific Time ===\n")

	var test_time: float = 5.0
	print("Checking which subtitles are active at ", test_time, "s:")

	for entry: SubtitleEntry in subtitles:
		if entry.is_active_at(test_time):
			print("  ✓ This subtitle is active: '", entry.get_text(), "'")
