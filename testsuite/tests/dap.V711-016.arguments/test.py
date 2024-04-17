""" Test how local variables/arguments is displayed """
from GPS import *
from gs_utils.internal.utils import *

expected_values = ([['0', 'false']])
expected_names = (['<b>Arguments</b>', ['<b>i</b>', '<b>b</b>']])

expected_values_1 = ([['0', 'false'],'5'])
expected_names_1 = (['<b>Arguments</b>', ['<b>i</b>', '<b>b</b>'], '<b>arguments</b>'])

@run_test_driver
def run_test():
    yield wait_tasks()
    buf = GPS.EditorBuffer.get(GPS.File("main.adb"))
    GPS.execute_action("Build & Debug Number 1")
    yield hook('debugger_started')
    debug = GPS.Debugger.get()
    yield wait_until_not_busy(debug)

    GPS.MDI.get("main.adb").raise_window()
    yield wait_tasks(other_than=known_tasks)
    buf.current_view().goto(buf.at(6, 1))
    GPS.execute_action("debug set line breakpoint")
    yield wait_DAP_server("setBreakpoints")
    yield wait_tasks(other_than=known_tasks)

    debug.send("run")
    yield wait_until_not_busy(debug)

    GPS.execute_action("debug tree display arguments")
    yield wait_DAP_server("variables")
    yield wait_until_not_busy(debug)
    yield wait_idle()

    tree = get_widget_by_name("Variables Tree")
    dump = dump_tree_model(tree.get_model(), 1)
    gps_assert(dump, expected_values)
    dump = dump_tree_model(tree.get_model(), 0)
    gps_assert(dump, expected_names)

    yield idle_modal_dialog(
        lambda: GPS.execute_action("debug tree display expression"))
    dialog = get_window_by_title("Display the value of an expression")
    box = get_widgets_by_type(Gtk.ComboBoxText, dialog)[0]
    box.prepend_text("arguments")
    box.set_active(0)
    get_stock_button(dialog, Gtk.STOCK_OK).clicked()
    yield wait_idle()

    dump = dump_tree_model(tree.get_model(), 1)
    gps_assert(dump, expected_values_1)
    dump = dump_tree_model(tree.get_model(), 0)
    gps_assert(dump, expected_names_1)

