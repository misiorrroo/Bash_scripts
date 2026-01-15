#!/bin/bash

LOG_DIR="/var/log"
ERROR_PATTERNS=("ERROR" "FATAL" "CRITICAL")

echo "analysing log files"
echo "---------------------"

echo -e "\nList of log files updated in last 24h"
LOG_FILES=$(find "$LOG_DIR" -name "*.log" -mtime -1 2>/dev/null)
echo "$LOG_FILES"

for LOG_FILE in $LOG_FILES; do

    echo
    echo "=============================="
    echo "========== $LOG_FILE ========="
    echo "=============================="

    for PATTERN in "${ERROR_PATTERNS[@]}"; do

        echo
        echo "searching $PATTERN logs in $LOG_FILE"
        grep "$PATTERN" "$LOG_FILE"

        echo
        echo "Number of $PATTERN logs found in $LOG_FILE"
        grep "$PATTERN" "$LOG_FILE" | wc -l

    done
done
