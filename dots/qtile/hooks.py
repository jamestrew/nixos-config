import os
import subprocess
import json
from pathlib import Path

from libqtile import hook, qtile


@hook.subscribe.startup_once
def start_once():
    qtile = os.path.dirname(os.path.abspath(__file__))
    subprocess.call([os.path.join(qtile, "scripts/startup.sh")])


OUT = Path("/tmp/qtile-layouts.ndjson")


def groups_with_windows():
    return [
        g.name
        for g in qtile.groups
        if getattr(g, "windows", None) and len(g.windows) > 0
    ]


def snapshot_all_screens():
    screens = []
    for screen in qtile.screens:
        grp = screen.group
        if not grp:
            continue
        try:
            layout_obj = grp.layouts[grp.current_layout]
            layout_name = getattr(layout_obj, "name", None) or grp.layout
        except Exception:
            layout_name = grp.layout
        screens.append(
            {
                "screen": screen.index,
                "group": grp.name,
                "layout": layout_name,
            }
        )

    return {
        "screens": screens,
        "groups_with_windows": groups_with_windows(),
        "active_screen": qtile.current_screen.index,
    }


def append_layout_file(data):
    with OUT.open("a") as f:
        f.write(json.dumps(data) + "\n")  # newline for tail -F
        f.flush()
        os.fsync(f.fileno())


# @hook.subscribe.layout_change
# def on_layout_change(layout, group):
#     data = snapshot_all_screens()
#     append_layout_file(data)


# @hook.subscribe.group_window_add
# def group_window_add(group, window):
#     data = snapshot_all_screens()
#     if group.name not in data["groups_with_windows"]:
#         data["groups_with_windows"].append(group.name)
#     append_layout_file(data)


# @hook.subscribe.group_window_remove
# def group_window_remove(group, window):
#     data = snapshot_all_screens()
#     if len(group.windows) < 2 and group.name in data["groups_with_windows"]:
#         data["groups_with_windows"].remove(group.name)
#     append_layout_file(data)


# @hook.subscribe.screen_change
# def screen_change(screen):
#     data = snapshot_all_screens()
#     append_layout_file(data)


@hook.subscribe.focus_change
def on_focus_change():
    data = snapshot_all_screens()
    append_layout_file(data)
