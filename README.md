# Subtitles Importer

<img src="icon.svg" width="128" height="128">

A comprehensive subtitles importer plugin for the Godot Game Engine.

## :star: Features

- :page_facing_up: **16 subtitle formats supported** including SRT, VTT, LRC, SSA/ASS, TTML/DFXP, SCC, MPL2, TMP, and more
- :rocket: **Runtime parsing** - load and parse subtitle files at runtime or during import
- :art: **Easy to use** - simple API for querying subtitles by time
- :wrench: **Editor integration** - import plugin included along with an AnimationPlayer subtitles injection tool
- :hammer_and_wrench: **HTML/ASS tag removal** - optional tag stripping for clean text output
- :mag: **Overlap detection** - automatic warnings for close-overlapping subtitle intervals

## :bookmark_tabs: Supported Formats

| Format | Extension(s) | Description |
|--------|--------------|-------------|
| **SubRip** | `.srt` | Most common subtitle format |
| **WebVTT** | `.vtt` | Web Video Text Tracks format |
| **LRC** | `.lrc` | Lyrics format with timestamps |
| **SubStation Alpha** | `.ssa`, `.ass` | Advanced subtitle format with styling |
| **YouTube Subtitles** | `.sbv` | YouTube's subtitle format |
| **TTML/DFXP** | `.ttml`, `.dfxp`| XML-based W3C standard (DFXP is the older name for TTML) |
| **Scenarist** | `.scc` | Closed caption format for broadcast |
| **MicroDVD** | `.sub` | Frame-based subtitle format |
| **SAMI** | `.smi`, `.sami` | Microsoft's Synchronized Accessible Media Interchange |
| **EBU-STL** | `.stl` | European Broadcasting Union binary format |
| **MPEG-4 Timed Text** | `.ttxt` | 3GPP Timed Text format |
| **MPL2/MPSub** | `.mpl` | Frame-based subtitle format with pipe separator |
| **TMPlayer** | `.tmp` | Simple time-based format with multi-line support |
| **Adobe Encore** | `.encore` | Adobe Encore subtitle format with frame-based timing |
| **Transtation** | `.transtation` | Transtation subtitle format with frame-based timing |

## :zap: Requirements

- Godot 4.2+

## :rocket: Getting Started

Inject the subtitles into an animation player in three easy steps:

1. In the scene tree, hold `Control` on your keyboard to select both an AnimationPlayer and Label (or RichTextLabel).
2. In the FileSystem stab, select one subtitle file in any of the supported formats.
3. Finally click `Project -> Tools -> Inject Subtitles into AnimationPlayer`, select the `subtitles` animation in the selected AnimationPlayer and click the auto-play button and done!

## :package: Installation

1. Download or clone this repository
2. Copy the `addons/rubonnek.subtitles_importer` folder to your project's `addons` folder
3. Enable the **Subtitle Importer** plugin in Project Settings → Plugins

## :page_with_curl: License

This plugin is released under the MIT License.

## :link: Links

- [Subtitle Format Specifications](https://en.wikipedia.org/wiki/Subtitle_(captioning)#Subtitle_formats)
