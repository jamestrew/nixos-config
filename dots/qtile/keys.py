from libqtile.config import EzKey, Key, KeyChord
from libqtile.core.manager import Qtile
from libqtile.lazy import lazy
from libqtile.utils import guess_terminal

import groups

MOD = "mod4"
SHIFT = "shift"
CTRL = "control"
TAB = "Tab"
SPACE = "space"

TERMINAL: str = guess_terminal("ghostty")  # pyright: ignore[reportAssignmentType]
BROWSER: str = "firefox"


@lazy.function
def kill_all(qtile: Qtile):
    if qtile.current_screen is None:
        return
    screen_idx = qtile.current_screen.index
    _, window_ids = qtile.screens[screen_idx].group.items("window")
    if window_ids is not None:
        for window_id in window_ids:
            qtile.windows_map[int(window_id)].kill()


keys: list[Key | KeyChord] = [
    # QTILE
    EzKey("M-S-r", lazy.restart(), desc="Restart Qtile"),
    EzKey("M-S-q", lazy.shutdown(), desc="Shutdown Qtile"),
    # layouts and windows
    EzKey("M-j", lazy.group.prev_window(), desc="Focus prev window"),
    EzKey("M-k", lazy.group.next_window(), desc="Focus next window"),
    EzKey(
        "M-S-j",
        lazy.layout.swap_column_left().when(layout="cols"),
        lazy.layout.shuffle_up().when(layout="wide"),
        desc="Move window up",
    ),
    EzKey(
        "M-S-k",
        lazy.layout.swap_column_right().when(layout="cols"),
        lazy.layout.shuffle_down().when(layout="wide"),
        desc="Move window down",
    ),
    EzKey(
        "M-h",
        lazy.layout.grow_left().when(layout="cols"),
        lazy.layout.grow().when(layout="wide"),
        desc="Grow window to the left",
    ),
    EzKey(
        "M-l",
        lazy.layout.grow_right().when(layout="cols"),
        lazy.layout.shrink().when(layout="wide"),
        desc="Grow window to the right",
    ),
    EzKey("M-n", lazy.layout.normalize(), desc="Reset all window sizes"),
    EzKey("M-<space>", lazy.window.toggle_fullscreen(), desc="fullscreen"),
    EzKey("M-<Tab>", lazy.next_layout(), desc="Toggle between layouts"),
    EzKey("M-c", lazy.window.kill(), desc="Kill focused window"),
    EzKey("M-S-c", kill_all, desc="Kill all windows in group"),
    EzKey("M-w", lazy.to_screen(0), desc="Move to screen 0"),
    EzKey("M-e", lazy.to_screen(1), desc="Move to screen 1"),
    # programs
    EzKey(
        "M-p",
        lazy.spawn("rofi -show run"),
        desc="Run rofi",
    ),
    EzKey(
        "M-v",
        lazy.spawn("clipmenu"),
        desc="Open clipmenu",
    ),
    KeyChord(
        [MOD],
        "o",
        [
            Key([], "t", lazy.spawn(TERMINAL), desc="Open terminal"),
            Key([], "r", lazy.spawn(TERMINAL + " -e yazi"), desc="Open yazi"),
            Key([], "b", lazy.spawn(BROWSER), desc="Open browser"),
            Key([], "d", lazy.spawn("discord"), desc="Open discord"),
            Key([], "o", lazy.spawn("obsidian"), desc="Open obsidian"),
        ],
    ),
    EzKey("M-S-s", lazy.spawn("flameshot gui"), desc="flameshot"),
    # special keys
    Key([], "XF86AudioRaiseVolume", lazy.spawn("amixer set Master 5%+ unmute")),
    Key([], "XF86AudioLowerVolume", lazy.spawn("amixer set Master 5%- unmute")),
    Key([], "XF86AudioMute", lazy.spawn("amixer set Master toggle")),
    Key([], "XF86AudioNext", lazy.spawn("playerctl next")),
    Key([], "XF86AudioPrev", lazy.spawn("playerctl previous")),
    Key([], "XF86AudioPlay", lazy.spawn("playerctl play-pause")),
]

for key, group in zip(groups.group_bindings, groups.groups):
    keys.append(EzKey(f"M-{key}", lazy.group[group.name].toscreen(toggle=False)))
    keys.append(EzKey(f"M-S-{key}", lazy.window.togroup(group.name, switch_group=True)))
