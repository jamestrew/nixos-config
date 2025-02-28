import os
import subprocess

from libqtile import hook
from libqtile.lazy import lazy


@hook.subscribe.startup_once
def start_once():
    qtile = os.path.dirname(os.path.abspath(__file__))
    subprocess.call([os.path.join(qtile, "scripts/startup.sh")])


@hook.subscribe.addgroup
def group_added(group_name):
    lazy.group[group_name].toscreen(1)
