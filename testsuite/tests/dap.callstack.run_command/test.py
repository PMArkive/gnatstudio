"""
Simple test on the callstack: verify that the view is correctly updated
when running and stopping on a breakpoint.
"""
import GPS
from gs_utils.internal.utils import *


@run_test_driver
def test_driver():
    NAME_COLUMN = 1
    LOCATION_COLUMN = 2

    yield wait_tasks()
    buf = GPS.EditorBuffer.get(GPS.File("main.adb"))
    buf.current_view().goto(buf.at(5, 1))
    yield wait_idle()
    yield wait_until_true(
        lambda: GPS.Action("debug set line breakpoint").can_execute() == False
    )
    GPS.execute_action("debug set line breakpoint")
    yield wait_idle()

    GPS.execute_action("Build & Debug Number 1")
    yield hook("debugger_started")
    yield wait_idle()

    debug = GPS.Debugger.get()
    yield wait_until_not_busy(debug)

    GPS.execute_action("open debugger call stack")
    yield wait_for_mdi_child("Call Stack")
    view = GPS.MDI.get("Call Stack")
    tree = get_widgets_by_type(Gtk.TreeView, view.pywidget())[0]
    model = tree.get_model()
    # The view should contains "No data" by default or when the call
    # stack is not accessible
    gps_assert(
        dump_tree_model(model, NAME_COLUMN),
        ["No data"],
        "Wrong content when opening the callstack",
    )

    debug.send("run")
    yield wait_DAP_server("stackTrace")
    yield wait_until_not_busy(debug)

    # Verify the view was correctly updated by the run/break command
    gps_assert(
        dump_tree_model(model, NAME_COLUMN), ["main"], "Wrong content after breaking"
    )
    # Verify we didn't loose the last character
    gps_assert(
        dump_tree_model(model, LOCATION_COLUMN)[0][-1],
        "5",
        "The last character in the Call Stack is wrong",
    )
