from libqtile import bar
from libqtile.widget.base import (
    _Widget as Widget,  # pyright: ignore[reportPrivateUsage]
)
from libqtile.widget.clock import Clock
from libqtile.widget.currentlayout import CurrentLayout
from libqtile.widget.pomodoro import Pomodoro
from libqtile.widget.windowname import WindowName
from qtile_extras.widget.statusnotifier import StatusNotifier

from colors import OneDark as c
from widgets.custom_widgets import (
    audio,
    basic_sep,
    cpu,
    group_box,
    line_sep,
    music_player,
    ram,
    weather,
)


def status_bar(widgets: list[Widget]) -> bar.Bar:
    return bar.Bar(widgets, size=24, opacity=1)


widget_defaults = dict(
    background=c.base00,
    foreground=c.base05,
    fontsize=14,
    padding=1,
)

main_screen_widgets: list[Widget] = [
    basic_sep,
    group_box(),
    line_sep,
    CurrentLayout(
        foreground=c.base0E,
    ),
    line_sep,
    WindowName(
        max_chars=75,
    ),
    Pomodoro(
        length_pomodori=1,
        color_inactive=c.base02,
        color_active=c.base0D,
        color_break=c.base0B,
        prefix_inactive="Pomo",
        prefix_paused="Pomo - Paused ",
        prefix_break="Pomo - Break ",
        prefix_long_break="Pomo - Long Break ",
    ),
    line_sep,
    *music_player,
    line_sep,
    weather,
    line_sep,
    *cpu,
    line_sep,
    *ram,
    line_sep,
    *audio,
    line_sep,
    Clock(foreground=c.base0C, format="%a %b %d  %H:%M:%S"),
    StatusNotifier(icon_size=22, padding=4, icon_theme="Adwaita"),
    basic_sep,
]

sec_screen_widgets: list[Widget] = [
    basic_sep,
    group_box(),
    line_sep,
    CurrentLayout(
        foreground=c.base0E,
    ),
    line_sep,
    WindowName(
        max_chars=75,
    ),
    *audio,
    line_sep,
    Clock(
        foreground=c.base0C,
        format="%a %b %d  %H:%M:%S",
    ),
    basic_sep,
]

main_bar = status_bar(main_screen_widgets)
sec_bar = status_bar(sec_screen_widgets)
