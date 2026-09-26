#!/usr/bin/env python3
"""Run with python3 eww/tests/monitor-assignment.py."""
import json
import os
from pathlib import Path
import re
import subprocess

root = Path(__file__).resolve().parents[1]
config = (root / "eww.yuck").read_text()
widgets = (root / "widgets/bar-left.yuck").read_text()
for outputs in (["DP-2", "HDMI-A-1"], ["HDMI-A-1", "DP-2"]):
    monitors = [
        {"id": i, "name": name, "activeWorkspace": {"id": 5 if name == "DP-2" else 2}}
        for i, name in enumerate(outputs)
    ]
    for bar, name, workspace in (("bar0", "DP-2", 5), ("bar1", "HDMI-A-1", 2)):
        block = config.split(f"(defwindow {bar}", 1)[1].split("(defwindow", 1)[0]
        assert re.search(r':monitor\s+"' + name + '"', block)
        assert f'(bar-left :monitor "{name}")' in block
        assert f"scripts/workspace-widget.sh {name}" in widgets
        result = subprocess.check_output(
            ["bash", "-c", """
hyprctl() {
  if [ "$1" = monitors ]; then printf '%s\n' "$MONITORS"; else echo '[]'; fi
}
socat() { :; }
export -f hyprctl socat
bash "$1" "$2"
""", "test", str(root / "scripts/workspace-widget.sh"), name],
            env={**os.environ, "MONITORS": json.dumps(monitors)},
            text=True,
        )
        active = re.findall(r'\(button :class "workspace active"[^\n]*? "(\d+)"\)', result)
        assert active == [str(workspace)], (name, active)
print("PASS: bar placement and workspace highlighting survive reversed monitor IDs")
