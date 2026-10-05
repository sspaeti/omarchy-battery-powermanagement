#!/bin/bash
# Scenario test for charging-status.sh's level estimate (needs the TUXEDO sysfs attr).
set -euo pipefail
cd "$(dirname "$0")/.."
export BATTERY_STATE_FILE=$(mktemp)
trap 'rm -f "$BATTERY_STATE_FILE"' EXIT
run() { BATTERY_STATUS_OVERRIDE=$1 BATTERY_VOLTAGE_OVERRIDE=$2 BATTERY_CURRENT_OVERRIDE=$3 BATTERY_NOW_OVERRIDE=$4 ./charging-status.sh </dev/null | awk -F'\t' '$1=="display"{print $2}'; }
check() { [[ $2 == "$3" ]] && echo "ok   $1 -> $2" || { echo "FAIL $1 -> $2 (want $3)"; exit 1; }; }

check "rest at 16.49 V"                 "$(run Full 16490000 0 1000)"          80
check "EC says Full but 0.68 A, +10 min" "$(run Full 16889000 680000 1600)"   84   # 80 + 0.68A*600s/3.1Ah
check "+30 min more at 0.68 A"          "$(run Full 16889000 680000 3400)"    95
check "taper to rest at 16.87 V"        "$(run Full 16870000 0 4000)"         100
check "discharge clears anchor"         "$(run Discharging 16400000 900000 4100)" ""
check "charging with no anchor: defer"  "$(run Charging 16800000 700000 4200)" ""
