#!/usr/bin/env bash
set -euo pipefail
script="$(dirname -- "${BASH_SOURCE[0]}")/idle-suspend.sh"
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
export XDG_RUNTIME_DIR="$tmp" CALLS="$tmp/calls"
export PATH="$tmp:$PATH"
printf '#!/usr/bin/env bash\necho "${0##*/} $*" >> "$CALLS"\n' > "$tmp/systemctl"
cp "$tmp/systemctl" "$tmp/notify-send"
chmod +x "$tmp/systemctl" "$tmp/notify-send"
touch "$CALLS"

[[ $(bash "$script" status) == true ]]
bash "$script" warn
bash "$script" suspend
grep -qx 'systemctl suspend' "$CALLS"
grep -q '^notify-send System Idle ' "$CALLS"
[[ $(wc -l < "$CALLS") == 2 ]]

bash "$script" toggle
[[ $(bash "$script" status) == false ]]
> "$CALLS"
bash "$script" warn
bash "$script" suspend
[[ ! -s "$CALLS" ]]

bash "$script" toggle
[[ $(bash "$script" status) == true ]]
bash "$script" suspend
grep -qx 'systemctl suspend' "$CALLS"
echo 'idle-suspend: PASS'
