import GPS

class Console_Process (GPS.Console, GPS.Process):
  """This class provides a way to spawn an interactive process and
     do its input/output in a dedicated console in GPS.
     You can of course derive from this class easily. Things are
     slightly more complicated if you want in fact to derive from
     a child of GPS.Console (for instance a class that would handle
     ANSI escape sequences). The code would then look like:
        class ANSI_Console (GPS.Console):
           def write (self, txt): ...

        class My_Process (ANSI_Console, Console_Process):
           def __init__ (self, process, args=""):
             Console_Process.__init__ (self, process, args)

     In the list of base classes for My_Process, you must put
     ANSI_Console before Console_Process. This is because python
     resolves overridden methods by looking depth-first search from
     left to right. This way, it will see ANSI_Console.write before
     Console_Process.write and therefore use the former.

     However, because of that the __init__ method that would be called
     when calling My_Process (...) is also that of ANSI_Console.
     Therefore you must define your own __init__ method locally.
  """

  def on_output (self, matched, unmatched):
    """This method is called when the process has emitted some output.
       The output is then printed to the console"""
    self.write (unmatched + matched)

  def on_exit (self, status, remaining_output):
    """This method is called when the process terminates.
       As a result, we close the console automatically, although we could
       decide to keep it open as well"""
    try:
       if self.close_on_exit:
          self.destroy ()  # Close console
       else:
          self.write (remaining_output)
          self.write ("exit status: " + `status`)
    except: pass  # Might have already been destroyed if that's what
                  # resulted in the call to on_exit

  def on_input (self, input):
    """This method is called when the user has pressed <enter> in the
       console. The corresponding command is then sent to the process"""
    self.send (input)

  def on_destroy (self):
    """This method is called when the console is being closed.
       As a result, we terminate the process (this also results in a
       call to on_exit"""
    self.kill ()

  def on_resize (self, rows, columns):
    """This method is called when the console is being resized. We then
       let the process know about the size of its terminal, so that it
       can adapt its output accordingly. This is especially useful with
       processes like gdb or unix shells"""
    self.set_size (rows, columns)

  def on_interrupt (self):
    """This method is called when the user presses control-c in the
       console. This interrupts the command we are currently processing"""
    GPS.Logger ("CONSOLE_PROCESS").log ("MANU on_interrupt")
    self.interrupt()

  def __init__ (self, process, args="", close_on_exit=True):
    """Spawn a new interactive process and show its input/output in a
       new GPS console. The process is created so that it does not
       appear in the task manager, and therefore the user can exit GPS
       without being asked whether or not to kill the process."""
    self.close_on_exit = close_on_exit
    GPS.Console.__init__ (
      self, process.split()[0],
      on_input = self.on_input,
      on_destroy = self.on_destroy,
      on_resize = self.on_resize,
      on_interrupt = self.on_interrupt,
      force = True)
    GPS.Process.__init__ (
      self, process + " " + args, ".+",
      single_line_regexp=True,  # For efficiency
      task_manager=False,
      on_exit = self.on_exit,
     on_match = self.on_output)

    GPS.MDI.get_by_child (self).raise_window ()
