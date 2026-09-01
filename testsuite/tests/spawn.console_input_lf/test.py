"""Regression test for the "spawn"-based process launcher
(GPS.Kernel.Spawns): text typed by the user in a "Run" console must reach
the child process's standard input terminated with a newline.

Before the fix, GPS.Kernel.Spawns.Input_Handler forwarded the text typed by
the user to the child's stdin verbatim, without adding back the newline
that the console strips out when it captures a typed line. A program
reading a line at a time (e.g. via Ada.Text_IO.Get_Line, as t.adb does)
would then block forever waiting for the missing line terminator, and the
expected echo would never appear.
"""

from gs_utils.internal.utils import (
    run_test_driver,
    wait_until_true,
    dot_exe,
    timeout,
    gps_assert,
    send_key_event,
    GDK_RETURN,
)
import pygps


@run_test_driver
def driver():
    GPS.execute_action("Build & Run Number 1")

    window_name = "Run: t" + dot_exe

    # Wait until the run window has appeared
    yield wait_until_true(
        lambda: GPS.MDI.get(window_name) is not None,
        timeout=10000,
        error_msg="The 'Run' console never appeared",
    )
    window = GPS.MDI.get(window_name)
    view = pygps.get_widgets_by_type(Gtk.TextView, window.pywidget())[0]

    console = GPS.Console(window_name)

    # Wait for the initial prompt
    yield wait_until_true(
        lambda: "Enter your name:" in console.get_text(),
        timeout=10000,
        error_msg="The child process never printed its prompt",
    )

    # Type "Peter" and press Enter, as a user would
    console.add_input("Peter")
    view.grab_focus()
    yield timeout(100)
    send_key_event(GDK_RETURN)

    # Without the fix, the child's Get_Line never returns (it never sees a
    # line terminator), so this text never appears and the test times out
    # here instead of passing.
    yield wait_until_true(
        lambda: "Hi Peter!" in console.get_text(),
        timeout=10000,
        error_msg=(
            "'Hi Peter!' was never echoed back: the console input sent to "
            "the child process's standard input is missing its terminating "
            "newline"
        ),
    )

    gps_assert(
        "Hi Peter!" in console.get_text(),
        True,
        "The child process should have echoed back the typed name",
    )
