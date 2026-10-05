#!/bin/bash
# Prints tab-separated key/values for the io.github.sspaeti.battery panel.
# Read-only; no root needed. Silent on non-TUXEDO machines.
bat=/sys/class/power_supply/BAT0
prof=/sys/devices/platform/tuxedo_keyboard/charging_profile

if [[ -r $prof/charging_profile ]]; then
  profile=$(<"$prof/charging_profile")
  printf 'profile\t%s\n' "$profile"
  printf 'profiles\t%s\n' "$(<"$prof/charging_profiles_available")"

  # The uniwill EC reports the capped range as 100%, so capacity/charge_now
  # lie whenever a cap is set. Pack voltage does not. Anchors measured on the
  # InfinityBook Pro Gen10 (4 cells): 16.87 V = truly full, 16.49 V = 80% cap.
  # Below that the Li-ion curve is approximated piecewise. Used whenever the
  # EC claims Full or Charging (it also claims Full at 80% right after the cap
  # is lifted, until its hysteresis lets charging resume); discharge is left
  # to the EC.
  case $profile in balanced) cap=90 ;; stationary) cap=80 ;; *) cap=100 ;; esac
  status=${BATTERY_STATUS_OVERRIDE:-$(cat "$bat/status" 2>/dev/null)}
  uv=${BATTERY_VOLTAGE_OVERRIDE:-$(cat "$bat/voltage_now" 2>/dev/null)}
  if [[ -n $cap && -n $uv && ( $status == Full || $status == Charging ) ]]; then
    est=$(awk -v uv="$uv" -v cap="$cap" 'BEGIN {
      v = uv / 1000000
      n = split("16.87:100 16.49:80 16.10:60 15.60:40 15.10:20 14.60:5", a, " ")
      for (i = 1; i <= n; i++) { split(a[i], p, ":"); V[i] = p[1]; S[i] = p[2] }
      if (v >= V[1]) soc = 100
      else if (v <= V[n]) soc = S[n]
      else for (i = 1; i < n; i++) if (v <= V[i] && v > V[i+1]) {
        soc = S[i+1] + (v - V[i+1]) / (V[i] - V[i+1]) * (S[i] - S[i+1]); break }
      if (soc > cap) soc = cap
      if (cap - soc < 3) soc = cap           # within noise of the cap: show the cap
      printf "%d", soc + 0.5
    }')
    printf 'cap\t%s\n' "$cap"
    printf 'display\t%s\n' "$est"
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
