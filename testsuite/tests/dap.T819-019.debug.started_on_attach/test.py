"""
This test checks that GS correctly consider the debugger as started
after attaching a process.
This means that "debug continue" should not try to start the debugger again.
"""
import GPS
import os
from gs_utils.internal.utils import *

ATTACH_DIALOG_NAME = "Enter the PID of the process to attach to"


@run_test_driver
def test_driver():
    # Build the project
    GPS.execute_action("Build All")
    yield wait_tasks()

    # Run the process
    proc = GPS.Process("./obj/main_t819_019")
    pid = proc.get_pid()

    # Initialize a debug session without any main
    GPS.execute_action("/Debug/Initialize/no main file")
    yield wait_idle()

    # Attach to the running 'main' process
    yield idle_modal_dialog(lambda: GPS.execute_action("debug attach"))
    dialog = get_window_by_title(ATTACH_DIALOG_NAME)
    entry = get_widgets_by_type(Gtk.Entry, dialog)[0]
    ok_button = get_button_from_label("OK", dialog)
    entry.set_text(str(pid))
    ok_button.clicked()
    yield wait_DAP_server("stackTrace")
    yield wait_idle()

    # Check that the debugger has been stopped when attaching to
    # the running process
    debugger = GPS.Debugger.get()
    frames = debugger.frames()
    gps_assert(
        len(frames) != 1,
        True,
        "The debugger should be stopped, and thus we should have frames",
    )

    # Check that 'debug continue' works fine
    GPS.execute_action("debug continue")
    yield timeout(1000)
    gps_assert(
        debugger.is_busy(),
        True,
        "The debugger should be running after 'debug continue'",
    )

    # Kill the process manually
    proc.kill()

