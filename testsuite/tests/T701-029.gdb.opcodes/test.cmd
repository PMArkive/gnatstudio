$GPS -Pdefault --load=test.py --traceoff=GPS.DEBUGGING.Gdb_MI --traceon=MODULE.Debugger_Gdb
$GPS -Pdefault --load=test.py --traceoff=GPS.DEBUGGING.Gdb_MI --traceon=MODULE.Debugger_Gdb_MI

# Opcodes implemented in gdb 13.1.90
#if [ "`type qgenc 2>/dev/null`" = "" ]; then
  # Do not run test with qgen
#  v="$(gdb -v | head -n 1 | cut -c 14-16)"
#  if [ $v -gt 12 ]
#  then
#    $GPS -Pdefault --load=test.py --traceon=GPS.DEBUGGING.DAP_MODULE --traceon=MODULE.Debugger_DAP
#  fi
#fi

