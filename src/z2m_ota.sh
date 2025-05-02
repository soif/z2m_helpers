#!/bin/bash

##################################################################################
# This script is provided free of charge for your use, with love and care by its #
# author, soif (https://github.com/soif). It is designed to help force Over-The- #
# Air (OTA) updates for Zigbee devices in Zigbee2MQTT, particularly when the     #
# adapter or network encounters issues during updates.                           #
#                                                                                #
# Please note that this script is offered "as is," without any warranties or     #
# guarantees. Use it at your own risk, and neither the author nor contributors   #
# are responsible for any damages or issues that may arise from its use.         #
#                                                                                #
# For more details, contributions, or to report issues, visit the project at:    #
# https://github.com/soif/z2m_helpers/                                           #
##################################################################################



# Defaults ###############################################################################
MQTT_HOST='localhost'	# hostname or ip address of the MQTT server (default)
MQTT_USER=''		    # MQTT username (default: empty)
MQTT_PASS=''		    # MQTT password (default: empty)
WAIT_TIME=20		    # default wait time in seconds between requesting an update (after failed)

# Constants ##############################################################################
VERSION="1.0"
DESCRIPTION="$0 v$VERSION: Allows to force OTA updates for Zigbee devices when the adapter/network is crashing during OTA upgrades."
SPINNER=('-' '\\' '|' '/')	# spinner characters for wheel effect
SPINNER_INDEX=0		        # current spinner index

# Functions ##############################################################################

# Function to print spent time
EchoSpentTime() {
    local end_time=$(date +%s)
    local elapsed=$((end_time - START_TIME))
    local time_str=$(PrintSec2min_sec "$elapsed")
    echo "* Spent Time: $time_str"
}

# Function to handle SIGINT (Ctrl+C)
EchoSpentTime_sigint() {
    echo ""
    EchoSpentTime
}

# Function to convert seconds to <MM>m <SS>s format
PrintSec2min_sec() {
    local total_seconds=$1
    local minutes=$((total_seconds / 60))
    local seconds=$((total_seconds % 60))
    printf "%dm %ds" "$minutes" "$seconds"
}

# Function to display update summary
display_update_summary() {
    local current_time=$1
    local last_progress=$2
    local prev_step_progress=$3
    local last_state_change=$4
    local elapsed=$((current_time - last_state_change))
    local time_str=$(PrintSec2min_sec "$elapsed")
    local step_progress=$(awk -v last=$last_progress -v prev=$prev_step_progress 'BEGIN {print last - prev}')
    CleanPrevLine
    printf "\r* Updated to: %.2f%%. \tDone %.2f%% \tin %s" "$last_progress" "$step_progress" "$time_str"
    echo ""
}

# Function to format MQTT server details
PrintMqttServer() {
    local cmd=" -h \"$MQTT_HOST\" "
    [ -n "$MQTT_USER" ] && cmd="$cmd -u \"$MQTT_USER\" "
    [ -n "$MQTT_PASS" ] && cmd="$cmd -P \"$MQTT_PASS\" "
    echo "$cmd"
}

# Function to send OTA request via MQTT
MqttSendOtaRequest() {
    local topic=$1
    eval "mosquitto_pub $(PrintMqttServer) -t \"zigbee2mqtt/bridge/request/device/ota_update/update\" -m \"$topic\""
}

# Function to get MQTT message and parse it
MqttGetMessage() {
    local topic=$1
    local message
    local state
    local progress
    local installed_version
    local latest_version
    local remaining

    # Get the MQTT message
    message=$(eval "mosquitto_sub $(PrintMqttServer) -t \"zigbee2mqtt/$topic\" -C 1")

    # Check if jq is available
    if command -v jq >/dev/null 2>&1; then
        state=$(echo "$message" | jq -r '.update.state // "none"')
        progress=$(echo "$message" | jq -r '.update.progress // 0')
        installed_version=$(echo "$message" | jq -r '.update.installed_version // "unknown"')
        latest_version=$(echo "$message" | jq -r '.update.latest_version // "unknown"')
        remaining=$(echo "$message" | jq -r '.update.remaining // 0')
    else
        # Fallback to grep for state
        if echo "$message" | grep -q '"update":{"[^}]*"state":"idle"'; then
            state="idle"
        elif echo "$message" | grep -q '"update":{"[^}]*"state":"available"'; then
            state="available"
        elif echo "$message" | grep -q '"update":{"[^}]*"state":"updating"'; then
            state="updating"
        else
            state="none"
        fi
        # Extract progress using grep (assumes progress is a number)
        progress=$(echo "$message" | grep -o '"progress":[0-9]*\.[0-9]*' | grep -o '[0-9]*\.[0-9]*' || echo "0")
        # Extract installed_version and latest_version using grep and sed
        installed_version=$(echo "$message" | grep -o '"installed_version":[^,}]*' | sed 's/"installed_version"://; s/"//g' || echo "unknown")
        latest_version=$(echo "$message" | grep -o '"latest_version":[^,}]*' | sed 's/"latest_version"://; s/"//g' || echo "unknown")
        # Extract remaining using grep (assumes remaining is an integer)
        remaining=$(echo "$message" | grep -o '"remaining":[0-9]*' | grep -o '[0-9]*' || echo "0")
    fi

    # Return values as a space-separated string
    echo "$state $progress $installed_version $latest_version $remaining"
}

# Function to update the spinner display
UpdateSpinner() {
    local progress=$1
    local remaining=$2
    CleanPrevLine
    printf "\r${SPINNER[$SPINNER_INDEX]} Updating: %.2f%% (estimated remaining time: %s) " "$progress" "$(PrintSec2min_sec "$remaining")"
    SPINNER_INDEX=$(( (SPINNER_INDEX + 1) % 4 ))
}

# Function to clean previous line (quick and dirty: someone want to enhance it ?)
CleanPrevLine() {
    printf "\r                                                                                                                          "
    printf "\r"
}

# Function to display usage
usage() {
    echo "$DESCRIPTION"
    echo ""
    echo "USAGE: $0 [-s host] [-u user] [-p password] [-t wait_time] [-h|--help] <TOPIC>"
    echo "Options:"
    echo "  -s host        MQTT Server host	(default: $MQTT_HOST)"
    echo "  -u user        MQTT username		(default: none) --> UNTESTED, PLEASE REPORT"
    echo "  -p password    MQTT password		(default: none) --> UNTESTED, PLEASE REPORT"
    echo "  -t wait_time   Seconds until next retry	(default: $WAIT_TIME sec)"
    echo "  -h, --help     Displays this help message and exit"
    echo "  TOPIC          MQTT topic for the device (REQUIRED)"
    echo ""
    exit 0
}


# MAIN ###################################################################################

# Start timer
START_TIME=$(date +%s)

# Trap Ctrl+C (SIGINT) to print spent time and exit -
trap 'EchoSpentTime_sigint; exit 1' SIGINT

# Check dependencies ---------------------------------------------------------------------
if ! command -v mosquitto_pub >/dev/null 2>&1; then
    echo "Error: 'mosquitto_pub' is required but not installed."
    echo "Please install it on Debian with: sudo apt update && sudo apt install mosquitto-clients"
    exit 1
fi
if ! command -v mosquitto_sub >/dev/null 2>&1; then
    echo "Error: 'mosquitto_sub' is required but not installed."
    echo "Please install it on Debian with: sudo apt update && sudo apt install mosquitto-clients"
    exit 1
fi
if ! command -v jq >/dev/null 2>&1; then
    echo "Warning: 'jq' is recommended but not installed. Using a less robust grep/sed workaround."
    echo "To install jq on Debian, run: sudo apt update && sudo apt install jq"
    echo ""
fi

# Process options and arguments ----------------------------------------------------------

# Check for --help before getopts
for arg in "$@"; do
    if [ "$arg" = "--help" ]; then
        usage
    fi
done

# Parse command-line options
while getopts ":s:t:u:p:h" opt; do
    case $opt in
        s)
            MQTT_HOST="$OPTARG"
            ;;
        t)
            WAIT_TIME="$OPTARG"
            # Validate WAIT_TIME is a positive integer
            if ! [[ "$WAIT_TIME" =~ ^[0-9]+$ ]] || [ "$WAIT_TIME" -le 0 ]; then
                echo "Error: Wait time must be a positive integer"
                exit 1
            fi
            ;;
        u)
            MQTT_USER="$OPTARG"
            ;;
        p)
            MQTT_PASS="$OPTARG"
            ;;
        h)
            usage
            ;;
        \?)
            echo "Error: Invalid option: -$OPTARG"
            usage
            ;;
        :)
            echo "Error: Option -$OPTARG requires an argument"
            usage
            ;;
    esac
done

# Shift past options to get the topic
shift $((OPTIND - 1))

# Check if a topic argument is provided
if [ -z "$1" ]; then
    echo "Error: Please provide a topic as an argument"
    usage
fi

# here we start ---------------------------------------------------------------------------
TOPIC="$1"
LAST_OTA_TIME=0	               # Store the timestamp of the last OTA request
LAST_STATE_CHANGE=$(date +%s)  # Store the timestamp of the last state change
LAST_PROGRESS=0		           # Store the last progress percentage
PREV_STEP_PROGRESS=0	       # Store the progress at the last completed step

# Handle initial state
printf "? Waiting for new state message from MQTT server at $MQTT_HOST, in topic: \"$TOPIC\" ..."

# Get initial MQTT message
read -r UPDATE_STATE PROGRESS INSTALLED_VERSION LATEST_VERSION REMAINING < <(MqttGetMessage "$TOPIC")

CleanPrevLine
printf "\r* Got state message from MQTT server at $MQTT_HOST, in topic: \"$TOPIC\" "
echo ""

case "$UPDATE_STATE" in
    "updating")
        echo "* There is an upgrade in progress (v$INSTALLED_VERSION to v$LATEST_VERSION):"
        UpdateSpinner "$PROGRESS" "$REMAINING"
        sleep 0.5
        UpdateSpinner "$PROGRESS" "$REMAINING"
        ;;
    "available")
        echo "* Upgrading Version $INSTALLED_VERSION to $LATEST_VERSION :"
        MqttSendOtaRequest "$TOPIC"
        sleep 5
        LAST_OTA_TIME=$(date +%s)
        LAST_STATE_CHANGE=$(date +%s)
        PREV_STEP_PROGRESS=0	# Reset for new OTA cycle
        ;;
    "idle")
        echo "* No OTA upgrade available!"
        EchoSpentTime
        exit 0
        ;;
    *)
        ;;
esac

LAST_PROGRESS=$PROGRESS



# Main loop ##############################################################################
while true; do
    # Get MQTT message
    read -r NEW_STATE PROGRESS INSTALLED_VERSION LATEST_VERSION REMAINING < <(MqttGetMessage "$TOPIC")

    # If state has changed and previous state was updating, display the update summary
    if [ "$NEW_STATE" != "$UPDATE_STATE" ] && [ "$UPDATE_STATE" = "updating" ]; then
        CURRENT_TIME=$(date +%s)
        display_update_summary "$CURRENT_TIME" "$LAST_PROGRESS" "$PREV_STEP_PROGRESS" "$LAST_STATE_CHANGE"
        PREV_STEP_PROGRESS=$LAST_PROGRESS
        LAST_STATE_CHANGE=$CURRENT_TIME
    fi

    # If state remains updating, update PREV_STEP_PROGRESS for next incremental calculation
    if [ "$NEW_STATE" = "updating" ] && [ "$UPDATE_STATE" = "updating" ] && [ "$PROGRESS" != "$LAST_PROGRESS" ]; then
        PREV_STEP_PROGRESS=$LAST_PROGRESS
    fi

    # Update state
    UPDATE_STATE=$NEW_STATE

    # Handle states
    case $UPDATE_STATE in
        "idle")
            if [ "$LAST_PROGRESS" != "0" ]; then
                CURRENT_TIME=$(date +%s)
                display_update_summary "$CURRENT_TIME" "$LAST_PROGRESS" "$PREV_STEP_PROGRESS" "$LAST_STATE_CHANGE"
            fi
            echo "* OTA has finished!"
            EchoSpentTime
            exit 0
            ;;
        "available")
            for ((i=$WAIT_TIME; i>=0; i--)); do
                CleanPrevLine
                printf "\r? Waiting ${WAIT_TIME}s until new OTA request: %ds " "$i"
                sleep 1
            done
            CleanPrevLine
            printf "\r> Sending OTA request, then wait for an MQTT message... "
            MqttSendOtaRequest "$TOPIC"
            LAST_OTA_TIME=$(date +%s)
            LAST_STATE_CHANGE=$(date +%s)
            PREV_STEP_PROGRESS=0	# Reset for new OTA cycle
        	sleep 1
            ;;
        "updating")
            echo "* There is an upgrade in progress (v$INSTALLED_VERSION to v$LATEST_VERSION):" | grep -v ".*" > /dev/null
            UpdateSpinner "$PROGRESS" "$REMAINING"
            sleep 0.5
            UpdateSpinner "$PROGRESS" "$REMAINING"
            sleep 0.5
            ;;
        *)
        	sleep 1
            ;;
    esac

    LAST_PROGRESS=$PROGRESS
done
