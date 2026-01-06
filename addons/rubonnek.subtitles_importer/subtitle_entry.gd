#============================================================================
#  subtitle_entry.gd                                                        |
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
class_name SubtitleEntry
extends RefCounted
## Wrapper class for subtitle entry dictionaries.
##
## Provides a clean interface for accessing subtitle entry data
## without exposing the internal dictionary structure.

# Enum for dictionary keys to avoid string-based lookups (private convention: lowercase)
enum _key {
	START_TIME,
	END_TIME,
	TEXT,
}

var _entry_dict: Dictionary


## Constructor that takes an entry dictionary.
func _init(p_entry_dict: Dictionary) -> void:
	_entry_dict = p_entry_dict


## Returns the start time of this subtitle entry in seconds.
func get_start_time() -> float:
	return _entry_dict.get(_key.START_TIME, 0.0)


## Returns the end time of this subtitle entry in seconds.
func get_end_time() -> float:
	return _entry_dict.get(_key.END_TIME, 0.0)


## Returns the text content of this subtitle entry.
func get_text() -> String:
	return _entry_dict.get(_key.TEXT, "")


## Returns the duration of this subtitle entry in seconds.
func get_duration() -> float:
	return get_end_time() - get_start_time()


## Checks if the subtitle is active at the given time.
func is_active_at(p_time: float) -> bool:
	return p_time >= get_start_time() and p_time <= get_end_time()


## Returns a string representation of this entry for debugging.
func _to_string() -> String:
	return "[%.2fs - %.2fs] %s" % [get_start_time(), get_end_time(), get_text()]


## Returns the internal dictionary (for advanced use cases).
## Use with caution - prefer the getter methods for normal usage.
func get_entry_dict() -> Dictionary:
	return _entry_dict
