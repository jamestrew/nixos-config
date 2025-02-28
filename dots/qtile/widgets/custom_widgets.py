import subprocess

from libqtile import bar, qtile
from libqtile.log_utils import logger
from libqtile.widget.base import InLoopPollText, _TextBox
from libqtile.widget.clock import Clock
from libqtile.widget.cpu import CPU
from libqtile.widget.groupbox import GroupBox
from libqtile.widget.memory import Memory
from libqtile.widget.open_weather import (
    OpenWeather,
    OpenWeatherResponseError,
    _OpenWeatherResponseParser,
)
from libqtile.widget.pulse_volume import PulseVolume
from libqtile.widget.sep import Sep
from qtile_extras.widget.mixins import ExtendedPopupMixin

from constants import OneDark as c

__all__ = [
    "audio",
    "basic_sep",
    "clock",
    "cpu",
    "group_box",
    "line_sep",
    "music_player",
    "ram",
    "weather",
]


class Icon(_TextBox):
    def __init__(self, text=" ", width=bar.CALCULATED, **config):
        super().__init__(text=text, width=width, **config)
        self.fmt = "{} "
        self.fontsize = 22
        self.padding = 0
        # TODO: add vertical padding?


class CustomWeather(OpenWeather):
    symbols = {
        "Unknown": "",
        "01d": " ",
        "01n": " ",
        "02d": " ",
        "02n": " ",
        "03d": " ",
        "03n": " ",
        "04d": " ",
        "04n": " ",
        "09d": " ",
        "09n": " ",
        "10d": " ",
        "10n": " ",
        "11d": " ",
        "11n": " ",
        "13d": "󰒷",
        "13n": "󰒷",
        "50d": " ",
        "50n": " ",
    }

    def __init__(self, **config):
        super().__init__(**config)
        self.format = "{icon} {main_feels_like:.0f}󰔄 {humidity} {wind_speed:.0f} "

    def parse(self, response):
        try:
            rp = _OpenWeatherResponseParser(response, self.dateformat, self.timeformat)
        except OpenWeatherResponseError as e:
            return "Error {}".format(e.resp_code)

        data = rp.data
        data["units_temperature"] = "C" if self.metric else "F"
        data["units_wind_speed"] = "Km/h" if self.metric else "m/h"
        data["icon"] = self.symbols.get(data["weather_0_icon"], self.symbols["Unknown"])

        return self.format.format(**data)


basic_sep = Sep(foreground=c.base00, linewidth=4)
line_sep = Sep(foreground=c.base05, linewidth=1, padding=10)


def group_box() -> GroupBox:
    return GroupBox(
        background=c.base00,
        active=c.base0B,
        inactive=c.base0D,
        other_current_screen_border=c.base0A,
        other_screen_border=c.base05,
        this_current_screen_border=c.base0E,
        this_screen_border=c.base05,
        urgent_border=c.base08,
        urgent_text=c.base08,
        disable_drag=True,
        highlight_method="line",
        invert_mouse_wheel=True,
        margin=2,
        padding=0,
        rounded=True,
        urgent_alert_method="text",
    )


cpu = (
    Icon(foreground=c.base08, text="󰍛"),
    CPU(foreground=c.base08, format="{load_percent: >4}%", update_interval=1.0),
)

ram = (
    Icon(foreground=c.base0B, text="󰉉"),
    Memory(foreground=c.base0B, format="{MemPercent: >4.1f}%", update_interval=1.0),
)

speaker_on = True
volume_app = "pavucontrol"
channel = "Master"
mixer = "amixer"


def toggle_speaker():
    global speaker_on
    logger.debug(f"toggle_speaker: {speaker_on=}")
    qtile.spawn(f"{mixer} set {channel} toggle")
    speaker_on = not speaker_on


audio = (
    Icon(
        foreground=c.base0D,
        mouse_callbacks={
            "Button1": toggle_speaker,
            "Button3": lambda: qtile.spawn(volume_app),
            "Button4": lambda: qtile.spawn(f"{mixer} set {channel} 1%+ unmute"),
            "Button5": lambda: qtile.spawn(f"{mixer} set {channel} 1%- unmute"),
        },
        text="󰕾" if speaker_on else "󰖁",
    ),
    PulseVolume(
        foreground=c.base0D,
        update_interval=0.1,
        volume_app=volume_app,
        step=1,
    ),
)


weather = CustomWeather(
    cityid=6167865,
    fontsize=16,
    foreground=c.base0E,
)


class MusicPlayer(InLoopPollText):
    player = "chromium"  # youtube music

    def __init__(self, width=bar.CALCULATED, **config):
        super().__init__(width=width, **config)
        self.update_interval = 3
        self.add_callbacks(
            {
                "Button1": lambda: qtile.cmd_spawn(
                    f"playerctl -p {self.player} play-pause"
                )
            }
        )

    def track_name(self) -> str:
        try:
            artist = (
                subprocess.check_output(
                    ["playerctl", "--player", self.player, "metadata", "artist"]
                )
                .strip()
                .decode("utf-8")
            )
            song = (
                subprocess.check_output(
                    ["playerctl", "--player", self.player, "metadata", "title"]
                )
                .strip()
                .decode("utf-8")[:60]
            )
            return f"{artist} · {song}"
        except subprocess.CalledProcessError:
            return ""

    def poll(self):  # type: ignore
        return self.track_name()


music_player = (Icon(foreground=c.base08, text="󰝚"), MusicPlayer(foreground=c.base08))


class CustomClock(Clock, ExtendedPopupMixin):
    def __init__(self, **config):
        Clock.__init__(self, **config)
        ExtendedPopupMixin.__init__(self, **config)
        self.add_defaults(Clock.defaults)
        self.add_defaults(ExtendedPopupMixin.defaults)

    #     self.add_callbacks(
    #         {
    #             "Button1": self.show_popup,
    #         }
    #     )

    # def _update_popup(self):

    #     self.extended_popup.update_controls()

    # def show_popup(self):
    #     self._update_popup()


clock = CustomClock(foreground=c.base0C, format="%a %b %d  %H:%M:%S")
