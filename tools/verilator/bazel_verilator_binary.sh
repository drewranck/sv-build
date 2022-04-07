#!/bin/bash

# We're going to run verilator with a Top arg, and then all the args after it,
# such as:
# verilator_run.sh Vtop leftover_args_for_verilator
#
# This will expand to a verilator call like:
# verilator -o Vtop (args)

Cmd="verilator "
OutputBinName=$1
shift;

CmdArgs=$@

StdOutLog="tmp.verilator.log"

echo "$Cmd -o $OutputBinName"
echo "  CmdArgs: $CmdArgs"
set -o pipefail;
$Cmd -o $OutputBinName $CmdArgs 1> ./$StdOutLog && \
    echo "Good -- Expected build to be good ($Cmd $OutputBinName)" && \
    exit 0

# dump the StdOutLog b/c verilator failed.
cat $StdOutLog
echo "Bad -- Expected build to be good, but it failed ($Cmd $OutputBinName)"
exit 1
