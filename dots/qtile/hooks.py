import os
import subprocess

from libqtile import hook


@hook.subscribe.startup_once
def start_once():
    qtile = os.path.dirname(os.path.abspath(__file__))
    subprocess.call([os.path.join(qtile, "scripts/startup.sh")])
