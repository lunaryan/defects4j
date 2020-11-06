#!/usr/bin/env bash
################################################################################
#
# This script tests the export command.
# By default, executed for all projects.
# Test one or more specific projects by appending "-p" arguments.
# Examples: 
# * Verify Lang:    ./test_export_command.sh -p Lang
# * Verify Lang and Collections: ./test_export_command.sh -p Lang -p Collections
#
################################################################################
HERE=$(cd `dirname $0` && pwd)

# Import helper subroutines and variables, and init Defects4J
source "$HERE/test.include" || exit 1
init

# ------------------------------------------------------------- Common functions

_run_export_command() {
    [ $# -eq 2 ] || die "Usage: ${FUNCNAME[0]} <working directory> <export command>"

    local work_dir="$1"
    local exp_cmp="$2"
    local exp_out=""

    pushd . > /dev/null 2>&1
    cd "$work_dir"
        exp_out=$(defects4j export -p "$exp_cmp")
        if [ $? -ne 0 ]; then
            popd > /dev/null 2>&1
            return 1
        fi
    popd > /dev/null 2>&1

    echo "$exp_out"
    return 0
}

# ------------------------------------------------------------------- Test Cases


INSTRUMENT_LOG_DIR="/home/luyan/method_src_instrument/logs" 
cd "$INSTRUMENT_LOG_DIR"
DIFF_LOG="/home/luyan/method_src_instrument/diff_logs"
rm -rf $DIFF_LOG; mkdir -p $DIFF_LOG;

test_export_properties() {
    local pid=$1
    local bids="$(get_bug_ids $BASE_DIR/framework/projects/$PID/$BUGS_CSV_ACTIVE)"
    for bid in $bids; do
	local buggy_dir="/home/luyan/method_src_instrument/${pid}_${bid}_buggy"
	local count=0
	for line in $(cat "${buggy_dir}/tests.trigger.list"); do		diff "${pid}-${bid}-buggy-${count}.err" "${pid}-${bid}-fixed-${count}.err" >"$DIFF_LOG/${pid}-${bid}-${count}.diff" 2>"$DIFF_LOG/${pid}-${bid}-${count}.diff.err"
	     count=$((count+1))
        done

        # Clean up
    done

}


# If no arguments provided, iterate over all projects
if [ "$PIDS" == "" ]; then
    PIDS=$(cd "$BASE_DIR/framework/core/Project" && ls *.pm | sed -e 's/\.pm//g')
fi

for PID in $PIDS; do
    HALT_ON_ERROR=0
    # Run all test cases (and log all results), regardless of whether errors occur
    test_export_properties $PID || die "Test 'test_export_properties' has failed!"
done

# Print a summary of what went wrong
if [ "$ERROR" -ne "0" ]; then
    printf '=%.s' $(seq 1 80) 1>&2
    echo 1>&2
    echo "The following errors occurred:" 1>&2
    cat $LOG 1>&2
fi

# Indicate whether an error occurred
exit "$ERROR"
