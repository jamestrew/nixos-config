from libqtile.config import Group, Match

group_bindings = [1, 2, 3, 4, 5, 6, 7]
groups = [
    Group("gtd", layout="cols", matches=[Match(wm_class="obsidian")]),
    Group("www", layout="cols"),
    Group(
        "coms",
        layout="cols",
        matches=[
            Match(wm_class="discord"),
            Match(wm_class="com.github.th_ch.youtube_music"),
        ],
    ),
    Group("doc", layout="cols"),
    Group("dev", layout="cols"),
    Group("dev2", layout="cols"),
    Group("fun", layout="cols", matches=[Match(wm_class="steam")]),
]
