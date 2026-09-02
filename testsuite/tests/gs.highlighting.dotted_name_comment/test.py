"""
This test checks the highlighting of a dotted name that is split over
several lines and has a comment between the dot and the selector, e.g:

   V
     .  --  Comment
       X := 10;

Ada_Analyzer.End_Of_Identifier used to skip the line breaks leading to the
dot without accounting for them in its line counter when it stopped on the
dot itself. The counter stayed behind for the rest of the parsing, so the
entities reported afterwards mixed a stale line number with a column
computed on a later line: the comment was highlighted one line too early,
and so was everything following it.
"""

from GPS import *
from gs_utils.internal.utils import *


expected_tags = [
    "keyword 1:1 1:7",
    "keyword 1:9 1:12",
    "block 1:14 1:14",
    "keyword 1:16 1:17",
    "keyword 3:4 3:12",
    "block 3:14 3:17",
    "keyword 3:24 3:25",
    "keyword 3:27 3:29",
    "type 3:31 3:31",
    "keyword 3:34 3:35",
    "keyword 4:4 4:8",
    "number 5:14 5:14",
    # The comment is on line 7, columns 12 .. 22. Before the fix it was
    # reported on line 6, which made GNAT Studio paint unrelated characters.
    "comment 7:12 7:22",
    "number 8:16 8:17",
    "number 9:14 9:15",
    "keyword 10:4 10:6",
    "block 10:8 10:11",
    "keyword 12:1 12:3",
    "block 12:5 12:5",
    "",
]


@run_test_driver
def run_test():
    buffer = EditorBuffer.get(File("p.adb"))
    yield wait_idle()

    tags = get_all_tags(buffer)
    gps_assert(tags.split("\n"), expected_tags, "The highlighting is not correct")
