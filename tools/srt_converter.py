#!/usr/bin/env python3
import argparse
import os
import sys

import pysubs2
from pycaption import DFXPWriter, SAMIWriter, SCCWriter, SRTReader, WebVTTWriter


def read_srt_to_captionset(srt_text):
    """Read SRT text and return a pycaption CaptionSet."""
    return SRTReader().read(srt_text)


def write_pycaption_outputs(caption_set, outpaths):
    """Write formats supported by pycaption."""
    # WebVTT (VTT)
    with open(outpaths["vtt"], "w", encoding="utf-8") as f:
        f.write(WebVTTWriter().write(caption_set))

    # DFXP and TTML (TTML is an alias for DFXP)
    dfxp_content = DFXPWriter().write(caption_set)
    with open(outpaths["dfxp"], "w", encoding="utf-8") as f:
        f.write(dfxp_content)
    with open(outpaths["ttml"], "w", encoding="utf-8") as f:
        f.write(dfxp_content)

    # SCC
    with open(outpaths["scc"], "w", encoding="utf-8") as f:
        f.write(SCCWriter().write(caption_set))

    # SAMI and SMI (SMI is an alias for SAMI)
    sami_content = SAMIWriter().write(caption_set)
    with open(outpaths["sami"], "w", encoding="utf-8") as f:
        f.write(sami_content)
    with open(outpaths["smi"], "w", encoding="utf-8") as f:
        f.write(sami_content)


def write_sbv_format(srt_path, sbv_path):
    """Write SBV format using pysubs2."""
    subs = pysubs2.load(srt_path, encoding="utf-8")
    with open(sbv_path, "w", encoding="utf-8") as f:
        for ev in subs:
            start = format_sbv_time(ev.start)
            end = format_sbv_time(ev.end)
            # Clean text - remove formatting
            text = ev.text.replace("\\N", "\n")
            f.write(f"{start},{end}\n{text}\n\n")


def format_sbv_time(ms):
    """Format time in SBV format: H:MM:SS.mmm"""
    h = ms // 3600000
    m = (ms % 3600000) // 60000
    s = (ms % 60000) // 1000
    ms_rem = ms % 1000
    return f"{h}:{m:02d}:{s:02d}.{ms_rem:03d}"


def write_mpl_format(srt_path, mpl_path):
    """Write MPL format (MPL2) manually."""
    subs = pysubs2.load(srt_path, encoding="utf-8")
    with open(mpl_path, "w", encoding="utf-8") as f:
        for ev in subs:
            # MPL2 uses deciseconds (1/10 second)
            start_ds = ev.start // 100
            end_ds = ev.end // 100
            # MPL2 format: [start][end]Text|with|pipes|for|newlines
            text = ev.text.replace("\\N", "|").replace("\n", "|")
            f.write(f"[{start_ds}][{end_ds}]{text}\n")


def write_tmp_format(srt_path, tmp_path):
    """Write TMP format (TMPlayer) manually."""
    subs = pysubs2.load(srt_path, encoding="utf-8")
    with open(tmp_path, "w", encoding="utf-8") as f:
        for ev in subs:
            # TMP uses format: HH:MM:SS:Text
            h = ev.start // 3600000
            m = (ev.start % 3600000) // 60000
            s = (ev.start % 60000) // 1000
            # TMP format uses pipe for line breaks
            text = ev.text.replace("\\N", "|").replace("\n", "|")
            f.write(f"{h:02d}:{m:02d}:{s:02d}:{text}\n")


def write_lrc_format(srt_path, lrc_path):
    """Write LRC format manually."""
    subs = pysubs2.load(srt_path, encoding="utf-8")

    with open(lrc_path, "w", encoding="utf-8") as f:
        for ev in subs:
            total_ms = ev.start
            minutes = total_ms // 60000
            seconds = (total_ms % 60000) / 1000.0
            # LRC format: [mm:ss.xx]Text
            # LRC doesn't support multi-line, so join with spaces
            text = ev.text.replace("\\N", " ").replace("\n", " ").strip()
            if text:
                f.write(f"[{int(minutes):02d}:{seconds:05.2f}]{text}\n")


def main():
    parser = argparse.ArgumentParser(
        description="Convert SRT subtitle files to multiple formats"
    )
    parser.add_argument("input_srt", help="Input SRT file path")
    parser.add_argument(
        "-o",
        "--outdir",
        default=".",
        help="Output directory (default: current directory)",
    )
    args = parser.parse_args()

    in_path = args.input_srt

    if not os.path.exists(in_path):
        print(f"Error: Input file '{in_path}' not found", file=sys.stderr)
        sys.exit(1)

    base = os.path.splitext(os.path.basename(in_path))[0]
    outdir = args.outdir
    os.makedirs(outdir, exist_ok=True)

    outpaths = {
        "vtt": os.path.join(outdir, f"{base}.vtt"),
        "sbv": os.path.join(outdir, f"{base}.sbv"),
        "ttml": os.path.join(outdir, f"{base}.ttml"),
        "dfxp": os.path.join(outdir, f"{base}.dfxp"),
        "scc": os.path.join(outdir, f"{base}.scc"),
        "smi": os.path.join(outdir, f"{base}.smi"),
        "sami": os.path.join(outdir, f"{base}.sami"),
        "mpl": os.path.join(outdir, f"{base}.mpl"),
        "tmp": os.path.join(outdir, f"{base}.tmp"),
        "lrc": os.path.join(outdir, f"{base}.lrc"),
    }

    # Read SRT file (handle BOM if present)
    with open(in_path, "r", encoding="utf-8-sig") as f:
        srt_text = f.read()

    try:
        caption_set = read_srt_to_captionset(srt_text)
    except Exception as e:
        print(f"Error reading SRT file: {e}", file=sys.stderr)
        sys.exit(1)

    # Write formats using pycaption
    try:
        write_pycaption_outputs(caption_set, outpaths)
    except Exception as e:
        print(f"Error writing pycaption formats: {e}", file=sys.stderr)
        sys.exit(1)

    # Write formats using pysubs2 and custom writers
    try:
        write_sbv_format(in_path, outpaths["sbv"])
        write_mpl_format(in_path, outpaths["mpl"])
        write_tmp_format(in_path, outpaths["tmp"])
        write_lrc_format(in_path, outpaths["lrc"])
    except Exception as e:
        print(f"Error writing custom formats: {e}", file=sys.stderr)
        sys.exit(1)

    print("Successfully converted to the following formats:")
    for fmt, path in sorted(outpaths.items()):
        print(f"  {fmt.upper():5s} -> {path}")


if __name__ == "__main__":
    main()
