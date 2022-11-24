"""
Check that block names are properly highlighted.
"""

import GPS
from gs_utils.internal.utils import *
import gs_utils.internal.dialogs as dialogs


EXPECTED_SYNTAX_HIGHLIGHTING = """..........###...
.....
...###...........
........
...........
.......###.

...###.........
........
...........
.......###.

...###........
........
...........
.......###.

...###........
...........
.......###.

...###..........
........
...........
.......###.

...###..
..........
........
...........
.......###.
....###."""


@run_test_driver
def test_driver():
    buf = GPS.EditorBuffer.get(GPS.File("foo.adb"))
    editor_view = buf.current_view()

    gps_assert(
        buf.debug_dump_syntax_highlighting("Block_Text").strip(),
        EXPECTED_SYNTAX_HIGHLIGHTING.strip(),
        "Block_Text are not properly highlighted")
