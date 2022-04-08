#!/bin/bash

# verilator_run_binary.sh <bin_exe> <expect_fail> <seed> [leftover_args]
# Args:
#  bin_exe -- the verilator executable binary
#  expect_fail -- False: expect pass, True: expect fail
#  seed -- simulation seed. If the seed arg is set to "0" or "random"
#          then this bash script will randomize it using `od ..`
#  leftover_args -- any additional run arguments
#                   These have special handing for:
#                   --rand_sim_seed
#                   +verilator+seed+{Int}
#
# This will run the bin_exe as follows:
# ./bin_exe (seed) (trace) (args $4 to end)
#
# Followed by some checking to make sure the test passed correctly.

function log_expect_pass()
{
    # Can't have:
    # - errors
    # - TEST_PASSED=0
    # - Test: FAIL
    # Must have:
    # - finish (exactly 1)
    # - TEST_PASSED=1 (exactly 1) or Test: PASS (exactly 1)
    [[ `grep -o "\%Error" $1` == "" ]] && \
    [[ `grep -o "TEST_PASSED=0" $1` == "" ]] && \
    [[ `grep -o "Test: FAIL" $1` == "" ]] && \
    [[ `egrep -co "Verilog .finish" $1` == "1" ]] && \
    [[ `grep -co "TEST_PASSED=1" $1` == "1" ]] || \
    [[ `grep -co "Test: PASS" $1` == "1" ]]

}

function log_expect_fail()
{
    # Can't have:
    # - TEST_PASSED=1
    # - Test: PASS
    # Must have:
    # - errors (1 or more)
    [[ `grep -o "TEST_PASSED=1" $1` == "" ]] && \
    [[ `grep -o "Test: PASS" $1` == "" ]] && \
    [[ `grep -o "\%Error" $1` != "" ]]
}

function save_artifacts()
{
    cp $RunLog "$TEST_UNDECLARED_OUTPUTS_DIR/$RunLog" || true;
    if [[ "$TraceArg" != "" ]]; then
        cp vlt_dump.vcd "$TEST_UNDECLARED_OUTPUTS_DIR/vlt_dump.vcd" || \
	    echo "Warning: Unable to copy waves, they may not exist!";
    fi
}

if [[ $# -eq 0 ]] ; then
    echo "Missing first arg for <bin_exe>"
    exit 1
fi
Cmd=$1
shift;

if [[ $# -eq 0 ]] ; then
    echo "Missing 2nd arg for <expect_fail>"
    exit 1
fi
ExpectFail=$1
shift;

if [[ $# -eq 0 ]] ; then
    echo "Missing 3rd arg for <seed>"
    exit 1
fi
Seed=$1;
shift;

RunLog="run.log"


# One interesting thing is a bazel run call like:
# > bazel run :target -- (-arg0 -arg1 ..)
# > bazel test :target --test_arg=-arg0 --test_arg=-arg1
# will have -arg0 -arg1 .. in our bash args (leftover_args) here as $@

# For handling a randomized simulation seed, we can also check if a special arg like
# "--rand_sim_seed" or "+verilator+seed+{someValue} exists in $@
# Example to run all tests and avoid lint:
# > time bazel test ... --test_arg=--rand_seed --nocache_test_results --test_tag_filters=-lint_test

# I really should use getopt, but my args are a little werid so a case-stmt is fine.
# This might get out of hand if I have to support --coverage, etc.

TraceArg=
RunArgs=

while [[ -n $1 ]]; do
    a=$1;
    case $a in
        # These --rand_* args are not verilator args, they are added to support
        # simulation seed randomization in bazel via bazel run (or bazel test) with
        # --test_arg=--rand_sim_seed
        --rand_sim_seed | --random_seed | --rand_seed)
            echo "-- leftover arg $a seen, setting Seed=random."
            Seed="random" ;;
        # +verilator+seed+Number is a verilator arg, but we'd like to fish out the
        # value for the logs, and then we'll re-add it to the $Cmd invocation
        +verilator+seed+*)
            Seed=`echo $a | egrep -o "\+verilator\+seed\+[0-9]+" | egrep -o "[0-9]+"`
            echo "-- leftover arg +verilator+seed+ seen, setting Seed=$Seed."
            ;;
        # +trace is a verilator arg, we "shift" it away and re-add it to the
        # $Cmd invocation, used for this shell script to print out the
        # waves location.
        +trace*)
            TraceArg="+trace"
            ;;
        *)
            RunArgs+=("$a")
    esac
    shift
done


if [[ "$Seed" == "0" || "$Seed" == "" ]]; then
    echo "Seed is 0 or '', so instead setting Seed=random."
    Seed="random"
fi

if [[ "$Seed" == "random" ]]; then
    echo "Seed=$Seed, so randomizing it..."
    Seed=`od -vAn -N4 -tu4 < /dev/urandom | sed 's/ //g'`

    # Verilator has this thing where (0 < seed < 2^31 (2147483648)), and since
    # the od call returns bytes, we'll divide-by-2 if the Seed is too big:
    if [ $Seed -gt 2147483647 ]; then
        Seed=$((Seed / 2));
    fi
    if [ $Seed -eq 0 ]; then
        Seed=1;
    fi

fi

echo "$Cmd:"
echo "  ExpectFail=$ExpectFail"
echo "  RunLog=${PWD}/$RunLog"
echo "  TraceArg=$TraceArg"
echo "  Seed=$Seed"
echo "  RunArgs: $RunArgs"

if [[ "$TraceArg" != "" ]]; then
    echo "  Waves will (might?) be in: outputs.zip"
    echo "  (if they aren't, try 'bazel run --test_output=all' instead of 'bazel test')"
    echo "  See link in (WORKSPACE root)/bazel-testlogs/$TEST_BINARY/test.outputs/outputs.zip"
    echo ""
    echo "    How to get your WORKSPACE root (copy paste):"
    echo ">      a=\$PWD; while [ ! -f \"WORKSPACE\" ]; do cd ..; if [[ \"\$PWD\" == \"/\" ]]; then echo \"WORKSPACE not found :(\"; cd \$a; fi; done; echo \"WORKSPACE -->\"; echo \"  \$PWD\"; cd \$a;"
fi


if [[ "$ExpectFail" == "True" || "$ExpectFail" == "1" ]]; then

    # Using set -o pipefail so $? is propagated through the | tee command.
    set -o pipefail;

    ! ./$Cmd +verilator+seed+$Seed $TraceArg $RunArgs | tee $RunLog; \
        echo $? && echo "Checking log $RunLog" && \
        save_artifacts && \
        log_expect_fail $RunLog && \
        echo "Good -- Expected test to fail and it did ($Cmd seed=$Seed)" && \
        exit 0

    echo "Bad -- Expected test to fail, but it passed ($Cmd seed=$Seed)"
    exit 1

fi

# Else expect it to pass:
set -o pipefail;

./$Cmd +verilator+seed+$Seed $TraceArg $RunArgs | tee $RunLog; \
    echo $? && echo "Checking log $RunLog" && \
    save_artifacts && \
    log_expect_pass $RunLog && \
    echo "Good -- Expected test to pass and it did ($Cmd seed=$Seed)" && \
    exit 0

echo "Bad -- Expected test to pass, but it failed ($Cmd seed=$Seed)"
exit 1
