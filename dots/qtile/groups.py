from libqtile.config import Group, Match

group_bindings = [1, 2, 3, 4, 5, 6, 7]
groups = [
    Group("www", layout="cols"),
    Group(
        "coms",
        layout="cols",
        matches=[
            Match(wm_class="discord"),
            Match(wm_class="com.github.th_ch.youtube_music"),
        ],
    ),
    Group("fun", layout="cols", matches=[Match(wm_class="steam")]),
    Group("doc", layout="cols"),
    Group("dev", layout="cols"),
    Group("dev2", layout="cols"),
    Group("gtd", layout="cols", matches=[Match(wm_class="obsidian")]),
]
