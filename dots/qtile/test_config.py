from libqtile.config import Group
from libqtile import layout
from libqtile.utils import guess_terminal


TERMINAL: str = guess_terminal()  # pyright: ignore[reportAssignmentType]
BROWSER: str = "firefox"


groups = [
    Group("1", spawn=BROWSER),
    Group("2", spawn=[TERMINAL, BROWSER]),
    Group("3"),
]

layouts = [
    layout.Columns(border_focus_stack=["#d75f5f", "#8f3d3d"], border_width=4),
    layout.Max(),
    # Try more layouts by unleashing below layouts.
    # layout.Stack(num_stacks=2),
    # layout.Bsp(),
    # layout.Matrix(),
    # layout.MonadTall(),
    # layout.MonadWide(),
    # layout.RatioTile(),
    # layout.Tile(),
    # layout.TreeTab(),
    # layout.VerticalTile(),
    # layout.Zoomy(),
]
