"""Wait (max 2s) until no physical modifier key is held, then exec argv[1:].

Handy invokes wtype the instant a transcription finalizes — typically while
the SUPER of the SUPER+R stop-toggle is still physically held. Hyprland
merges modifier state across all keyboards on the seat, so the virtually
typed letters land as SUPER+<letter> and fire compositor keybinds. Gating
wtype on all-modifiers-released fixes that; dotool never showed the problem
only because its ~0.7s uinput settle delay acted as an accidental grace
period.

Perf notes (this machine, ~31 input devices): closing an evdev fd costs
10-25ms (synchronize_rcu in evdev_release), so a naive open/scan/close of
every device per poll costs ~0.6s. Instead: preselect modifier-capable
devices from sysfs (no device opens), open only those once, and hand the
fds across exec so their close cost is paid when wtype exits — after the
text has landed — rather than before it starts.
"""

import fcntl
import glob
import os
import sys
import time

# evdev KEY_* codes: L/R ctrl, shift, alt, meta
MODIFIERS = (29, 97, 42, 54, 56, 100, 125, 126)
KEY_STATE_BYTES = 96  # (KEY_MAX 0x2ff + 1) / 8
EVIOCGKEY = (2 << 30) | (KEY_STATE_BYTES << 16) | (ord("E") << 8) | 0x18


def modifier_capable(event):
    """Check the sysfs key-capability bitmap without opening /dev."""
    try:
        with open(f"/sys/class/input/{event}/device/capabilities/key") as f:
            words = f.read().split()  # 64-bit hex words, most significant first
    except OSError:
        return False
    bits = 0
    for w in words:
        bits = (bits << 64) | int(w, 16)
    return any(bits >> k & 1 for k in MODIFIERS)


fds = []
for path in glob.glob("/dev/input/event*"):
    if not modifier_capable(os.path.basename(path)):
        continue
    try:
        fd = os.open(path, os.O_RDONLY | os.O_NONBLOCK)
    except OSError:
        continue
    os.set_inheritable(fd, True)  # survive the exec; die with wtype
    fds.append(fd)


def any_modifier_held():
    state = bytearray(KEY_STATE_BYTES)
    for fd in fds:
        try:
            fcntl.ioctl(fd, EVIOCGKEY, state)
        except OSError:
            continue
        if any(state[k >> 3] & 1 << (k & 7) for k in MODIFIERS):
            return True
    return False


deadline = time.monotonic() + 2.0
waited = False
while time.monotonic() < deadline and any_modifier_held():
    waited = True
    time.sleep(0.01)
if waited:
    # give the compositor a moment to digest the release events
    time.sleep(0.03)

os.execv(sys.argv[1], sys.argv[1:])
