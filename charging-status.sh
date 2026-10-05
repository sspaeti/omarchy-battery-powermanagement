#!/bin/bash
# Prints tab-separated key/values for the io.github.sspaeti.battery panel.
# Read-only; no root needed. Silent on non-TUXEDO machines.
bat=/sys/class/power_supply/BAT0
prof=/sys/devices/platform/tuxedo_keyboard/charging_profile

if [[ -r $prof/charging_profile ]]; then
  profile=$(<"$prof/charging_profile")
  printf 'profile\t%s\n' "$profile"
  printf 'profiles\t%s\n' "$(<"$prof/charging_profiles_available")"

  # The uniwill EC reports the capped range as 100%, so "Full" under a cap is
  # a lie. Pack voltage tells the truth: ~16.87 V (4.22 V/cell) when truly
  # full, ~16.49 V under the 80% cap. When the EC says Full but voltage is
  # below the true-full band, show the cap value instead of 100.
  case $profile in balanced) cap=90 ;; stationary) cap=80 ;; *) cap= ;; esac
  if [[ -n $cap && -r $bat/status && -r $bat/voltage_now ]] \
     && [[ $(<"$bat/status") == Full ]] \
     && (( $(<"$bat/voltage_now") < 16700000 )); then
    printf 'display\t%s\n' "$cap"
  fi
fi

# Uniwill EC reports cycle_count=0; the real counter is raw_cycle_count.
for f in raw_cycle_count cycle_count; do
  if [[ -r $bat/$f ]] && (( $(<"$bat/$f") > 0 )); then
    printf 'cycles\t%s\n' "$(<"$bat/$f")"
    break
  fi
done

for pair in "charge_full charge_full_design" "energy_full energy_full_design"; do
  set -- $pair
  if [[ -r $bat/$1 && -r $bat/$2 ]]; then
    awk -v now="$(<"$bat/$1")" -v design="$(<"$bat/$2")" \
      'BEGIN { if (design > 0) printf "health\t%d%%\n", now / design * 100 + 0.5 }'
    break
  fi
done
