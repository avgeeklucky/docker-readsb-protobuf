#!/usr/bin/env bash

# This script is designed to test /scripts/autogain.sh.
#
# It achieves this by running the autogain script against collected protobuf data,
# in rapid succession, by fudging the timestamp.
#
# If there is any output to stderr that is not listed in ALLOWED_STDERR, the test fails.
# 

# Colors
NOCOLOR='\033[0m'
RED='\033[0;31m'
GREEN='\033[0;32m'
ORANGE='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
LIGHTGRAY='\033[0;37m'
DARKGRAY='\033[1;30m'
LIGHTRED='\033[1;31m'
LIGHTGREEN='\033[1;32m'
YELLOW='\033[1;33m'
LIGHTBLUE='\033[1;34m'
LIGHTPURPLE='\033[1;35m'
LIGHTCYAN='\033[1;36m'
WHITE='\033[1;37m'

# Define valid gain levels
gain_levels=()
gain_levels+=(0.0)
gain_levels+=(0.9)
gain_levels+=(1.4)
gain_levels+=(2.7)
gain_levels+=(3.7)
gain_levels+=(7.7)
gain_levels+=(8.7)
gain_levels+=(12.5)
gain_levels+=(14.4)
gain_levels+=(15.7)
gain_levels+=(16.6)
gain_levels+=(19.7)
gain_levels+=(20.7)
gain_levels+=(22.9)
gain_levels+=(25.4)
gain_levels+=(28.0)
gain_levels+=(29.7)
gain_levels+=(32.8)
gain_levels+=(33.8)
gain_levels+=(36.4)
gain_levels+=(37.2)
gain_levels+=(38.6)
gain_levels+=(40.2)
gain_levels+=(42.1)
gain_levels+=(43.4)
gain_levels+=(43.9)
gain_levels+=(44.5)
gain_levels+=(48.0)
gain_levels+=(49.6)

# Define allowed stderr output
ALLOWED_STDERR=()
for i in "${gain_levels[@]}"; do
    ALLOWED_STDERR+=("Insufficient messages received for accurate measurement, extending runtime of gain $i dB.")
    ALLOWED_STDERR+=("Reducing gain to: $i dB")
    ALLOWED_STDERR+=("Insufficient data available, extending runtime of gain $i dB.")
    ALLOWED_STDERR+=("Container restart detected, resuming auto-gain state 'init' with gain $i dB")
done
ALLOWED_STDERR+=("Entering auto-gain stage: init")

set -eo pipefail

# set up environment
echo -e "${LIGHTBLUE}==== SETTING UP TEST ENVIRONMENT ====${NOCOLOR}"

# pretend user wants autogain  & initialise gain script has been run
READSB_GAIN="autogain"
export READSB_GAIN
echo "49.6" > "$AUTOGAIN_CURRENT_VALUE_FILE"

# prepare testing timestamp variable
AUTOGAIN_TESTING_TIMESTAMP=$(date +%s)
export AUTOGAIN_TESTING_TIMESTAMP

echo ""

# test loop
while true; do
    for testdatafile in /autogain_test_data/*.pb.*; do

        echo -e "${LIGHTBLUE}==== TESTING TIMESTAMP $AUTOGAIN_TESTING_TIMESTAMP ====${NOCOLOR}"

        rm /tmp/test_* > /dev/null 2>&1 || true

        # copy test data file
        cp "$testdatafile" "$READSB_STATS_PB_FILE" > /dev/null

        # run test
        if bash -xeo pipefail /scripts/autogain.sh > /tmp/test_stdout 2> /tmp/test_stderr; then
            :
        else
            echo -e "${LIGHTRED}FAIL - non zero exit code${NOCOLOR}"
            exit 1
        fi

        if [[ -s /tmp/test_stdout ]]; then
            echo -e "${CYAN}stdout:${NOCOLOR}"
            cat /tmp/test_stdout
        fi

        if [[ -s /tmp/test_stderr ]]; then
            echo -e "${CYAN}stderr:${NOCOLOR}"

            while read -r line; do
                if echo "$line" | grep -P '^\++ ' > /dev/null 2>&1; then
                    # output from set -x, ignore this
                    :
                else
                    unset KNOWN_STDERR
                    for i in "${ALLOWED_STDERR[@]}"; do
                        if [[ "$line" == "$i" ]]; then
                            KNOWN_STDERR=1
                        fi
                    done
                    if [[ -z "$KNOWN_STDERR" ]]; then
                        echo ""
                        echo -e "${LIGHTRED}==== FULL STDERR ====${NOCOLOR}"
                        cat /tmp/test_stderr
                        echo ""
                        echo -e "${LIGHTRED}=====================${NOCOLOR}"
                        echo ""
                        echo -e "${YELLOW}$line${NOCOLOR}"
                        echo -e "${LIGHTRED}FAIL - unknown stderr${NOCOLOR}"
                        echo ""
                        exit 1
                    else
                        echo "$line"
                    fi
                fi
            done < /tmp/test_stderr
            echo ""
        fi

        echo -e "${LIGHTGREEN}PASS${NOCOLOR}"

        # advance clock
        AUTOGAIN_TESTING_TIMESTAMP=$((AUTOGAIN_TESTING_TIMESTAMP + 900))

        echo ""

    done

    rm "$AUTOGAIN_RUNNING_FILE"

done
