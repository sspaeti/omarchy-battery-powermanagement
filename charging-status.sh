#!/bin/bash
# Prints tab-separated key/values for the io.github.sspaeti.battery panel.
# Read-only on sysfs; no root needed. Silent on non-TUXEDO machines.
#
# Overrides for tests: BATTERY_STATUS_OVERRIDE, BATTERY_VOLTAGE_OVERRIDE (µV),
# BATTERY_CURRENT_OVERRIDE (µA), BATTERY_NOW_OVERRIDE (epoch s), BATTERY_STATE_FILE.
bat=/sys/class/power_supply/BAT0
prof=/sys/devices/platform/tuxedo_keyboard/charging_profile
state=${BATTERY_STATE_FILE:-${XDG_RUNTIME_DIR:-/tmp}/omarchy-battery-estimate}

if [[ -r $prof/charging_profile ]]; then
  profile=$(<"$prof/charging_profile")
  printf 'profile\t%s\n' "$profile"
  printf 'profiles\t%s\n' "$(<"$prof/charging_profiles_available")"

  # The uniwill EC lies while a cap is involved: capacity/charge_now sit at
  # 100% and status says Full even while 0.7 A flows in. What is trustworthy:
  #   - pack voltage, but only at rest (current 0). Anchors measured on the
  #     InfinityBook Pro AMD Gen10 (4 cells): 16.87 V = full, 16.49 V = 80%.
  #   - current_now, integrated over time (coulomb counting) while charging.
  # So: at rest, estimate from voltage and remember it; while current flows,
  # add current x time to the remembered value. Discharge is left to the EC
  # and clears the memory so the next rest re-anchors from voltage.
  case $profile in balanced) cap=90 ;; stationary) cap=80 ;; *) cap=100 ;; esac
  status=${BATTERY_STATUS_OVERRIDE:-$(cat "$bat/status" 2>/dev/null)}
  uv=${BATTERY_VOLTAGE_OVERRIDE:-$(cat "$bat/voltage_now" 2>/dev/null)}
  ua=${BATTERY_CURRENT_OVERRIDE:-$(cat "$bat/current_now" 2>/dev/null || echo 0)}
  full_uah=$(cat "$bat/charge_full" 2>/dev/null || echo 0)
  now=${BATTERY_NOW_OVERRIDE:-$(date +%s)}
  prev_ts=; prev_soc=
  [[ -r $state ]] && read -r prev_ts prev_soc < "$state"

  est=
  if [[ $status == Discharging ]]; then
    rm -f "$state"
  elif [[ -n $uv && ( $status == Full || $status == Charging ) ]]; then
    if (( ua < 50000 )); then
      # Resting: voltage is the truth.
      est=$(awk -v uv="$uv" 'BEGIN {
        v = uv / 1000000
        n = split("16.87:100 16.49:80 16.10:60 15.60:40 15.10:20 14.60:5", a, " ")
        for (i = 1; i <= n; i++) { split(a[i], p, ":"); V[i] = p[1]; S[i] = p[2] }
        if (v >= V[1]) soc = 100
        else if (v <= V[n]) soc = S[n]
        else for (i = 1; i < n; i++) if (v <= V[i] && v > V[i+1]) {
          soc = S[i+1] + (v - V[i+1]) / (V[i] - V[i+1]) * (S[i] - S[i+1]); break }
        printf "%.2f", soc }')
      printf 'flow\trest\n'
    elif [[ -n $prev_ts && -n $prev_soc && $full_uah -gt 0 ]]; then
      # Charging: voltage is the charger's, not the cell's. Integrate current.
      est=$(awk -v p="$prev_soc" -v ua="$ua" -v dt="$((now - prev_ts))" -v full="$full_uah" \
        'BEGIN { s = p + ua * dt / 3600 / full * 100; if (s > 100) s = 100; printf "%.2f", s }')
      printf 'flow\tcharging\n'
    else
      printf 'flow\tcharging\n'   # no anchor yet: leave the number to the EC
    fi
  fi

  if [[ -n $est ]]; then
    printf '%s %s\n' "$now" "$est" > "$state"
    disp=$(awk -v s="$est" -v cap="$cap" 'BEGIN {
      if (s > cap) s = cap
      if (cap - s < 3) s = cap          # within noise of the cap: show the cap
      printf "%d", s + 0.5 }')
    printf 'cap\t%s\n' "$cap"
    printf 'display\t%s\n' "$disp"
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
