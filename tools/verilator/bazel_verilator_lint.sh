#!/bin/bash

# We're going to run verilator --lint-only and then all the args after it,
# such as:
# verilator --lint-only -f some/generated.f.file other/top.sv

Cmd="verilator --lint-only"

echo "verilator lint: $Cmd $@"
$Cmd $@ && echo "Good -- Expected test to pass and it did ($Cmd $@)" && exit 0

echo "Bad -- Expected test to pass, but it failed ($Cmd $@)"
exit 1
