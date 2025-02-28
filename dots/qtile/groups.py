from libqtile.config import Group, Match

from constants import BROWSER, TERMINAL

group_bindings = [1, 2, 3, 4, 5, 6, 7]

groups = [
    Group("gtd", layout="cols", spawn="obsidian", matches=[Match(wm_class="obsidian")]),
    Group(
        "www",
        layout="cols",
        spawn=BROWSER,
    ),
    Group(
        "coms",
        layout="cols",
        spawn=["discord", "youtube-music"],
        matches=[
            Match(wm_class="discord"),
            Match(wm_class="com.github.th_ch.youtube_music"),
        ],
    ),
    Group("doc", layout="cols"),
    Group(
        "dev",
        layout="cols",
        spawn=[BROWSER, TERMINAL],
    ),
    Group("dev2", layout="cols"),
    Group("fun", layout="cols", matches=[Match(wm_class="steam")]),
]
