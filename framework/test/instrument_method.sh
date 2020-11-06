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


INSTRUMENT_DIR="/home/luyan/method_src_instrument" #TODO: need to change hard-encoded path
cd "$INSTRUMENT_DIR"
javac -cp ".:./jp/javaparser/javaparser-core/target/javaparser-core-3.16.3-SNAPSHOT.jar" VoidVisitorComplete.java  > "compile.log" 2>&1 
JAVA_LOG="/home/luyan/method_src_instrument/java_logs"
rm -rf "$JAVA_LOG"; mkdir -p "$JAVA_LOG"

test_export_properties() {
    local pid=$1
    local bids="$(get_bug_ids $BASE_DIR/framework/projects/$PID/$BUGS_CSV_ACTIVE)"
    for bid in $bids; do
    	cd "$INSTRUMENT_DIR"
	## mkdir and checkout project ##    
        local buggy_dir="/home/luyan/method_src_instrument/${pid}_${bid}_buggy"
        local fixed_dir="/home/luyan/method_src_instrument/${pid}_${bid}_fixed"
        rm -rf "$buggy_dir"; rm -rf "$fixed_dir"; mkdir -p "$buggy_dir" "$fixed_dir"

        defects4j checkout -p "$pid" -v "${bid}b" -w "$buggy_dir" || die "Checkout of buggy version $pid-$bid has failed"
        defects4j checkout -p "$pid" -v "${bid}f" -w "$fixed_dir" || die "Checkout of fixed version $pid-$bid has failed"

	## compile and run instrument java script ##
	java -cp ".:./jp/javaparser/javaparser-core/target/javaparser-core-3.16.3-SNAPSHOT.jar" VoidVisitorComplete "${pid}_${bid}_buggy" > "$JAVA_LOG/$pid-$bid-buggy.log" 2> "$JAVA_LOG/$pid-$bid-buggy.err"
	java -cp ".:./jp/javaparser/javaparser-core/target/javaparser-core-3.16.3-SNAPSHOT.jar" VoidVisitorComplete "${pid}_${bid}_fixed" > "$JAVA_LOG/$pid-$bid-fixed.log" 2> "$JAVA_LOG/$pid-$bid-fixed.err"

	## run d4j test -t and record the related method ##
	cd "$buggy_dir"
	
	local counter=0
	defects4j export -p tests.trigger 1>"tests.trigger.list" 2>/dev/null 
	for line in $(cat "tests.trigger.list"); do
		defects4j test -t ${line} 1>"${pid}-${bid}-buggy-${counter}.log" 2>"${pid}-${bid}-buggy-${counter}.err"
		cp "${pid}-${bid}-buggy-${counter}.err" "../logs/"
		counter=$((counter+1))
	done

	cd "$fixed_dir"
	counter=0
	defects4j export -p tests.trigger 1>"tests.trigger.list" 2>/dev/null 
	for line in $(cat "tests.trigger.list"); do
		defects4j test -t ${line} 1>"${pid}-${bid}-fixed-${counter}.log" 2>"${pid}-${bid}-fixed-${counter}.err"
		cp "${pid}-${bid}-fixed-${counter}.err" "../logs/"
		counter=$((counter+1))
	done


        #################################################################
        # Clean up
        #################################################################
    done

    #################################################################
    # Clean up
    #################################################################
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
