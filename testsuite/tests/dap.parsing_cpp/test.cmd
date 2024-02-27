
### Description
## Parse variables in CPP code

if [ "$CPP_TESTING" = "false" ]; then
   # do not test cpp
   exit 99
fi

v="$(gdb -v | head -n 1 | cut -c 14-16)"
if [ $v -ge 15 ]
then
  gprbuild -q -Pgvd_cpp
  $GPS --load=python:test.py --debug=obj/parse_cpp --traceon=GPS.DEBUGGING.DAP_MODULE --traceon=MODULE.Debugger_DAP
fi
