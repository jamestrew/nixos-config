-- Monitor setup - 1080p monitor centered above 1440p monitor
-- HDMI-A-1: 1920x1080 at top, centered (offset by (3440-1920)/2 = 760)
-- DP-2: 3440x1440 at bottom, starting at x=0
hl.monitor({ output = "HDMI-A-1", mode = "1920x1080@60", position = "760x0", scale = 1 })
hl.monitor({ output = "DP-2", mode = "3440x1440@143.92", position = "0x1080", scale = 1 })
hl.monitor({ output = "DP-1", disabled = true })
hl.monitor({ output = "DP-3", disabled = true })

-- Environment variables
hl.env("XCURSOR_SIZE", "22")
hl.env("HYPRCURSOR_SIZE", "22")
-- Wayland input method - correct fcitx5 setup per official docs
hl.env("XMODIFIERS", "@im=fcitx")
hl.env("QT_IM_MODULE", "fcitx")
-- Explicitly unset GTK_IM_MODULE for Wayland (fixes fcitx warning)
hl.env("GTK_IM_MODULE", "")
-- Add user bin paths

local home = os.getenv("HOME")
local paths = {
  home .. "/.cargo/bin",
  home .. "/go/bin",
  home .. "/apps/neovim/bin",
  home .. "/.npm-global/bin",
  os.getenv("PATH") or ""
}
hl.env("PATH", table.concat(paths, ":"))

hl.config({
  input = {
    kb_layout = "us",
    kb_variant = "",
    kb_model = "",
    kb_options = "",
    kb_rules = "",

    follow_mouse = 1,
    sensitivity = 0.8,
    accel_profile = "flat",
    force_no_accel = false,
    scroll_factor = 1
  },

  general = {
    gaps_in = 8,
    gaps_out = 8,
    border_size = 4,
    ["col.active_border"] = "rgba(be5046ff)",   -- OneDark base0F
    ["col.inactive_border"] = "rgba(1e222aff)", -- OneDark base00

    layout = "dwindle",
    allow_tearing = false
  },

  animations = {
    enabled = true
  },

  dwindle = {
    preserve_split = true
  },

  master = {
    new_status = "master"
  },

  misc = {
    force_default_wallpaper = -1
  }
})

hl.animation({ leaf = "global", enabled = true, speed = 2, bezier = "default" })

-- Window rules
hl.window_rule({ match = { class = ".*" }, suppress_event = "maximize" })
hl.window_rule({ match = { class = "^(?i)obsidian$" }, workspace = "2 silent" })
hl.window_rule({ match = { class = "^(?i)discord$" }, workspace = "3 silent" })
hl.window_rule({ match = { class = "^(?i)com\\.github\\.th_ch\\.youtube_music$" }, workspace = "3 silent" })
hl.window_rule({ match = { class = "^(?i)qalculate-gtk$" }, float = true, size = { 300, 400 } })
hl.window_rule({
  match = { class = "^(one.alynx.showmethekey)|(xdg-desktop-portal-gtk)|(showmethekey-gtk)$" },
  float = true
})
hl.window_rule({ match = { class = "^(showmethekey-gtk)$" }, pin = true })

local main_mod = "SUPER"

local function key(mods, key_name)
  if mods == "" then
    return key_name
  end

  return mods .. " + " .. key_name
end

local function bind(mods, key_name, dispatcher, flags)
  hl.bind(key(mods, key_name), dispatcher, flags)
end

local function bind_exec(mods, key_name, command, flags)
  bind(mods, key_name, hl.dsp.exec_cmd(command), flags)
end

-- Window management
bind(main_mod, "J", hl.dsp.window.cycle_next({ prev = true }))
bind(main_mod, "down", hl.dsp.window.cycle_next({ prev = true }))
bind(main_mod, "K", hl.dsp.window.cycle_next())
bind(main_mod, "up", hl.dsp.window.cycle_next())
bind(main_mod .. " + SHIFT", "J", hl.dsp.window.swap({ prev = true }))
bind(main_mod .. " + SHIFT", "down", hl.dsp.window.swap({ prev = true }))
bind(main_mod .. " + SHIFT", "K", hl.dsp.window.swap({ next = true }))
bind(main_mod .. " + SHIFT", "up", hl.dsp.window.swap({ next = true }))
bind(main_mod, "H", hl.dsp.window.resize({ x = -80, y = 0, relative = true }))
bind(main_mod, "left", hl.dsp.window.resize({ x = -80, y = 0, relative = true }))
bind(main_mod, "L", hl.dsp.window.resize({ x = 80, y = 0, relative = true }))
bind(main_mod, "right", hl.dsp.window.resize({ x = 80, y = 0, relative = true }))
bind(main_mod, "Space", hl.dsp.window.fullscreen({ mode = "maximized" }))
bind(main_mod, "F", hl.dsp.window.float())
bind(main_mod, "Tab", hl.dsp.window.cycle_next())
bind(main_mod, "C", hl.dsp.window.close())

-- Screen navigation
bind(main_mod, "W", hl.dsp.focus({ monitor = 0 }))
bind(main_mod, "E", hl.dsp.focus({ monitor = 1 }))

-- Program launchers
bind_exec(main_mod, "P", "wofi --show run")
bind_exec(main_mod, "V", "cliphist list | wofi -S dmenu | cliphist decode | wl-copy")

-- Application shortcuts
bind_exec(main_mod, "Return", "ghostty")
bind_exec(main_mod, "B", "brave --disable-features=WaylandWpColorManagerV1")

-- Screenshots
bind_exec(main_mod .. " + SHIFT", "S", [[grim -g "$(slurp)" - | wl-copy -t image/png]])

-- System controls
bind_exec(main_mod .. " + SHIFT", "R", "hyprctl reload")
bind(main_mod .. " + SHIFT", "Q", hl.dsp.exit())
bind_exec(main_mod, "O", "swaync-client --toggle-panel")
bind_exec(main_mod, "S", "swaync-client --close-all")

bind_exec(main_mod, "R", "handy --toggle-transcription")

-- Workspace navigation - dynamic per monitor
for workspace = 1, 9 do
  bind(main_mod, tostring(workspace), hl.dsp.focus({ workspace = workspace, on_current_monitor = true }))
end

-- Move windows to workspace
for workspace = 1, 9 do
  bind(main_mod .. " + SHIFT", tostring(workspace), hl.dsp.window.move({ workspace = workspace }))
end

-- Mouse bindings
bind(main_mod, "mouse:272", hl.dsp.window.drag(), { mouse = true })
bind(main_mod, "mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Media keys
bind_exec("", "XF86AudioRaiseVolume", "amixer set Master 5%+ unmute", { locked = true })
bind_exec("", "XF86AudioLowerVolume", "amixer set Master 5%- unmute", { locked = true })
bind_exec("", "XF86AudioMute", "amixer set Master toggle", { locked = true })
bind_exec("", "XF86AudioNext", "playerctl next", { locked = true })
bind_exec("", "XF86AudioPrev", "playerctl previous", { locked = true })
bind_exec("", "XF86AudioPlay", "playerctl play-pause", { locked = true })

-- Startup applications
hl.on("hyprland.start", function ()
  hl.exec_cmd("hypridle")
  hl.exec_cmd("hyprpaper")
  hl.exec_cmd("hyprsunset")                 -- color-temp daemon (replaced sunsetr; see psi4j/sunsetr#21)
  hl.exec_cmd("sleep 2 && bluelight-auto")  -- apply correct day/night state once the daemon is up
  hl.exec_cmd("eww daemon")
  hl.exec_cmd("eww open bar0 && eww open bar1")
  hl.exec_cmd("handy")

  hl.exec_cmd("fcitx5")
  hl.exec_cmd("udiskie --tray")
  hl.exec_cmd("brave --disable-features=WaylandWpColorManagerV1", { workspace = "1 silent" })
  hl.exec_cmd("discord", { workspace = "3 silent" })
  -- hl.exec_cmd("pear-desktop", { workspace = "3 silent" })
  hl.exec_cmd("obsidian", { workspace = "2 silent" })
  hl.exec_cmd("wl-paste --watch cliphist store")
end)
