from libqtile.config import Screen

import groups as Groups
import hooks as _  # noqa: F401
import keys as Keys
import layouts as Layouts
import mouse as Mouse
import widgets as Widgets

keys = Keys.keys
groups = Groups.groups
layouts = Layouts.layouts
floating_layout = Layouts.floating_layout
widget_defaults = Widgets.widget_defaults
screens = [Screen(), Screen()]
mouse = Mouse.mouse
dgroups_key_binder = None
dgroups_app_rules = []
follow_mouse_focus = True
bring_front_click = False
cursor_warp = False
auto_fullscreen = False
auto_minimize = False
focus_on_window_activation = "smart"
reconfigure_screens = True
auto_minimize = True
wmname = "LG3D"
