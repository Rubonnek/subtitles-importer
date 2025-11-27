




























extends Node
## Basic usage demo for the Subtitles Importer plugin.
##
## This demo shows how to load subtitle files and display them with optimized
## performance using get_entry_id_at_time() to avoid string allocations.

@export var subtitle_label: Label
var subtitles: Subtitles = Subtitles.new()
var current_time: float = 0.0
var last_entry_id: int = -1


func _ready() -> void:
	# Create sample subtitle data
	subtitles.add_entry(1.0, 3.0, "Hello, world!")
	subtitles.add_entry(4.0, 6.0, "This is a subtitle example.")
	subtitles.add_entry(7.0, 9.0, "Subtitles are easy with this plugin!")
	subtitles.add_entry(10.0, 12.0, "Thanks for trying it out!")

	print("Loaded ", subtitles.get_entry_count(), " subtitle entries")

	# If you want to load from an imported file instead, use:
	# subtitles = load("res://subtitles/video.srt")


func _process(delta: float) -> void:
	if subtitle_label == null:
		return

	current_time += delta

	# Loop back to beginning after all subtitles have played
	if current_time > 13.0:
		current_time = 0.0

	# Optimized: Use get_entry_id_at_time() to avoid string allocations
	# Only update the label when the subtitle changes
	var entry_id: int = subtitles.get_entry_id_at_time(current_time)

	if entry_id != last_entry_id:
		last_entry_id = entry_id

		if entry_id == -1:
			subtitle_label.text = ""
		else:
			subtitle_label.text = subtitles.get_entry_text(entry_id)

	# Alternative (simpler but creates strings every frame):
	# subtitle_label.text = subtitles.get_subtitle_at_time(current_time)
