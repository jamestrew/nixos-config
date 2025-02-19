from libqtile.config import Match
from libqtile.layout.columns import Columns
from libqtile.layout.floating import Floating
from libqtile.layout.max import Max
from libqtile.layout.xmonad import MonadWide

from colors import OneDark as c

_layout_theme = {
    "border_width": 4,
    "margin": 8,
    "border_focus": c.base0F,
    "border_normal": c.base00,
}
layouts = [
    Columns(name="cols", num_columns=3, **_layout_theme),
    Max(),
    # Try more layouts by unleashing below layouts.
    # Stack(num_stacks=2),
    # Bsp(),
    # Matrix(),
    # MonadTall(),
    MonadWide(name="wide", **_layout_theme),
    # layout.RatioTile(),
    # layout.Tile(),
    # layout.TreeTab(),
    # layout.VerticalTile(),
    # layout.Zoomy(),
]

floating_layout = Floating(
    float_rules=[
        # Run the utility of `xprop` to see the wm class and name of an X client.
        *Floating.default_float_rules,
        Match(wm_class="confirmreset"),  # gitk
        Match(wm_class="makebranch"),  # gitk
        Match(wm_class="maketag"),  # gitk
        Match(wm_class="ssh-askpass"),  # ssh-askpass
        Match(title="branchdialog"),  # gitk
        Match(title="pinentry"),  # GPG key password entry
    ]
)
