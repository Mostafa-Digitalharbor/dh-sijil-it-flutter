"""Fail if any shared library in an APK is below 16 KB page alignment.

Android 15 moved devices to 16 KB memory pages, and from 1 November 2025
Google Play refuses an update targeting Android 15+ that contains a shared
library whose `PT_LOAD` segments are aligned to less than that. A build that
breaks this rule is not caught by anything else in the gate: it compiles, it
installs, it runs, and it is rejected at upload — or, on a 16 KB device,
falls back to a compatibility mode the platform warns about on first launch.

This is deliberately *not* `zipalign -P 16`. That checks where a `.so` sits
inside the archive, which AGP has handled correctly for years. The requirement
is about alignment recorded in the ELF program headers, which comes from
however the dependency was built and which no amount of repackaging fixes.

Usage:

    flutter build apk --debug
    python tool/check_elf_alignment.py build/app/outputs/flutter-apk/app-debug.apk

Exits non-zero and names every offender, so it can be dropped into CI as-is.
"""

from __future__ import annotations

import struct
import sys
import zipfile

# Program-header type for a loadable segment. The only one the loader has to
# map, and therefore the only one page size applies to.
PT_LOAD = 1

REQUIRED_ALIGNMENT = 16 * 1024


def load_segment_alignments(data: bytes) -> list[int] | None:
    """The `p_align` of every PT_LOAD segment, or None if this is not an ELF."""
    if data[:4] != b"\x7fELF":
        return None

    is_64bit = data[4] == 2
    endian = "<" if data[5] == 1 else ">"

    if is_64bit:
        (e_phoff,) = struct.unpack_from(endian + "Q", data, 0x20)
        (e_phentsize,) = struct.unpack_from(endian + "H", data, 0x36)
        (e_phnum,) = struct.unpack_from(endian + "H", data, 0x38)
        type_offset, align_offset = 0x00, 0x30
        align_format = "Q"
    else:
        (e_phoff,) = struct.unpack_from(endian + "I", data, 0x1C)
        (e_phentsize,) = struct.unpack_from(endian + "H", data, 0x2A)
        (e_phnum,) = struct.unpack_from(endian + "H", data, 0x2C)
        type_offset, align_offset = 0x00, 0x1C
        align_format = "I"

    alignments = []
    for index in range(e_phnum):
        header = e_phoff + index * e_phentsize
        (p_type,) = struct.unpack_from(endian + "I", data, header + type_offset)
        if p_type != PT_LOAD:
            continue
        (p_align,) = struct.unpack_from(
            endian + align_format, data, header + align_offset
        )
        alignments.append(p_align)

    return alignments


def main(apk_path: str) -> int:
    offenders: list[tuple[str, int]] = []
    checked = 0

    with zipfile.ZipFile(apk_path) as apk:
        for name in sorted(n for n in apk.namelist() if n.endswith(".so")):
            alignments = load_segment_alignments(apk.read(name))
            if not alignments:
                continue

            checked += 1
            worst = min(alignments)
            if worst < REQUIRED_ALIGNMENT:
                offenders.append((name, worst))

    if offenders:
        print(f"{len(offenders)} of {checked} shared libraries are below 16 KB:")
        for name, worst in offenders:
            print(f"  {name}  p_align={worst}")
        print()
        print(
            "Raise the dependency that ships it. Rebuilding or repackaging the "
            "APK cannot fix an alignment recorded in the ELF itself."
        )
        return 1

    print(f"All {checked} shared libraries are 16 KB aligned.")
    return 0


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print(__doc__)
        sys.exit(2)
    sys.exit(main(sys.argv[1]))
