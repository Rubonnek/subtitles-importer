#============================================================================
#  subtitles_importer_import_plugin.gd                                      |
#============================================================================
#                         This file is part of:                             |
#                           SUBTITLE IMPORTER                               |
#           https://github.com/Rubonnek/subtitle-importer                   |
#============================================================================
# Copyright (c) 2025 Wilson Enrique Alvarez Torres                          |
#                                                                           |
# Permission is hereby granted, free of charge, to any person obtaining     |
# a copy of this software and associated documentation files (the           |
# "Software"), to deal in the Software without restriction, including       |
# without limitation the rights to use, copy, modify, merge, publish,       |
# distribute, sublicense, and/or sell copies of the Software, and to        |
# permit persons to whom the Software is furnished to do so, subject to     |
# the following conditions:                                                 |
#                                                                           |
# The above copyright notice and this permission notice shall be            |
# included in all copies or substantial portions of the Software.           |
#                                                                           |
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,           |
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF        |
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.    |
# IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY      |
# CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,      |
# TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE         |
# SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.                    |
#============================================================================

@tool
extends EditorImportPlugin
## Import plugin for subtitle files.
##
## Imports subtitle files and converts them to Subtitles resources.
## Parsing is handled internally by the Subtitles class.
## Supported formats: SRT, VTT, LRC, SSA, ASS, SBV, TTML, DFXP, SCC, SUB, SMI, SAMI, EBU-STL, TTXT, Adobe Encore, Transtation

func _get_importer_name() -> String:
	return "rubonnek.subtitle_importer"


func _get_visible_name() -> String:
	return "Subtitles"


func _get_recognized_extensions() -> PackedStringArray:
	return Subtitles.supported_extensions


func _get_save_extension() -> String:
	return "res"


func _get_resource_type() -> String:
	return "Resource"


func _get_preset_count() -> int:
	return 1


func _get_preset_name(_p_preset_index: int) -> String:
	return "Default"


func _get_import_options(_p_path: String, _p_preset_index: int) -> Array[Dictionary]:
	return [
		{
			"name": "remove_html_tags",
			"default_value": true,
			"hint_string": "Remove HTML tags from subtitle text",
		},
		{
			"name": "remove_ass_tags",
			"default_value": true,
			"hint_string": "Remove ASS/SSA tags like {\\an8}, {\\i1}, etc.",
		},
		{
			"name": "framerate",
			"default_value": 25.0,
			"property_hint": PROPERTY_HINT_RANGE,
			"hint_string": "10.0,120.0,0.001",
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint_string_extra": "Framerate for frame-based formats (SUB, SCC, Encore, Transtation)",
		},
	]


func _get_option_visibility(p_path: String, p_option_name: StringName, _p_options: Dictionary) -> bool:
	# Show framerate option only for frame-based formats
	if p_option_name == "framerate":
		var extension: String = p_path.get_extension().to_lower()
		return extension == "sub" or extension == "scc" or extension == "encore" or extension == "transtation"
	return true


func _get_priority() -> float:
	return 1.0


func _get_import_order() -> int:
	return 0


func _import(p_source_file: String, p_save_path: String, p_options: Dictionary, _p_platform_variants: Array[String], _p_gen_files: Array[String]) -> Error:
	var remove_html_tags: bool = p_options.get("remove_html_tags", true)
	var remove_ass_tags: bool = p_options.get("remove_ass_tags", true)
	var framerate: float = p_options.get("framerate", 25.0)

	# Create Subtitles resource
	var subtitles: Subtitles = Subtitles.new()

	var result: Error = subtitles.load_from_file(p_source_file, framerate, remove_html_tags, remove_ass_tags)

	if result != OK:
		printerr("Failed to parse subtitle file: ", p_source_file)
		return result

	if subtitles.get_entry_count() == 0:
		printerr("No subtitle entries found in file: ", p_source_file)
		return ERR_PARSE_ERROR

	# Save the resource
	var filename: String = p_save_path + "." + _get_save_extension()
	return ResourceSaver.save(subtitles, filename)
