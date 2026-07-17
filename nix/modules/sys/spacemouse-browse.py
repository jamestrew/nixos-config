"""SpaceMouse browser-scroll daemon.

Speaks spacenavd protocol v1 and subscribes to RAW axis events, which
bypass the user's spacenavd sensitivity/deadzone tuning (that tuning is
calibrated for CAD apps and squashes some axes to ~3% of their range).
Raw axis state is turned into high-resolution scroll-wheel events and
back/forward mouse buttons on a virtual uinput mouse -- but only while a
browser window is focused in Hyprland and its title does not match the
exclude regex (Onshape).
"""

import argparse
import glob
import json
import math
import os
import re
import select
import socket
import struct
import sys
import time

from evdev import UInput, ecodes as ec

# spacenavd wire protocol (spacenavd src/proto.h, src/client.h)
UEV_MOTION = 0
UEV_PRESS = 1
UEV_RELEASE = 2
UEV_RAWAXIS = 5
REQ_TAG = 0x7FAA0000
REQ_CHANGE_PROTO = 0x5500
REQ_SET_EVMASK = 0x1003
EVMASK_BUTTON = 0x02
EVMASK_RAWAXIS = 0x10

FULL_DEFLECTION = 350.0  # raw axis range on 3Dconnexion devices
HIRES_PER_NOTCH = 120
# hi-res units per millisecond at full deflection and speed 1.0
# (3.0/ms = 25 wheel notches per second)
BASE_GAIN = 3.0


def log(msg):
    print(msg, flush=True)


class HyprFocus:
    """Answers 'is a browser (non-excluded) window focused?' with caching."""

    def __init__(self, browsers, exclude_re, ttl=0.3):
        self.browsers = {b.lower() for b in browsers}
        self.exclude_re = exclude_re
        self.ttl = ttl
        self._cached = False
        self._stamp = -1.0

    def _socket_path(self):
        runtime = os.environ.get("XDG_RUNTIME_DIR") or "/run/user/%d" % os.getuid()
        sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
        if sig:
            path = os.path.join(runtime, "hypr", sig, ".socket.sock")
            if os.path.exists(path):
                return path
        candidates = glob.glob(os.path.join(runtime, "hypr", "*", ".socket.sock"))
        if not candidates:
            return None
        # newest instance dir wins (stale dirs can survive restarts)
        return max(candidates, key=os.path.getmtime)

    def _query(self):
        path = self._socket_path()
        if path is None:
            return False
        try:
            with socket.socket(socket.AF_UNIX) as s:
                s.settimeout(0.25)
                s.connect(path)
                s.sendall(b"j/activewindow")
                buf = b""
                while True:
                    chunk = s.recv(8192)
                    if not chunk:
                        break
                    buf += chunk
        except OSError:
            return False
        try:
            win = json.loads(buf)
        except ValueError:
            return False
        cls = (win.get("class") or "").lower()
        title = win.get("title") or ""
        if cls not in self.browsers:
            return False
        if self.exclude_re is not None and self.exclude_re.search(title):
            return False
        return True

    def active(self):
        now = time.monotonic()
        if now - self._stamp >= self.ttl:
            self._cached = self._query()
            self._stamp = now
        return self._cached


class VirtualMouse:
    def __init__(self):
        caps = {
            ec.EV_REL: [
                ec.REL_X,
                ec.REL_Y,
                ec.REL_WHEEL,
                ec.REL_HWHEEL,
                ec.REL_WHEEL_HI_RES,
                ec.REL_HWHEEL_HI_RES,
            ],
            ec.EV_KEY: [
                ec.BTN_LEFT,
                ec.BTN_RIGHT,
                ec.BTN_MIDDLE,
                ec.BTN_SIDE,
                ec.BTN_EXTRA,
            ],
        }
        # IMPORTANT: no 3Dconnexion vendor id (0x256f) here -- spacenavd
        # claims ANY device with that vid, which made it grab this virtual
        # mouse, feed our scroll output back in as spacemouse motion, and
        # eventually segfault. Default evdev ids (1/1) are safely generic.
        self.ui = UInput(caps, name="SpaceMouse Browse")
        # fractional hi-res remainders and per-axis progress toward a
        # low-res notch (some apps only listen to REL_WHEEL)
        self._frac = {"v": 0.0, "h": 0.0}
        self._notch = {"v": 0, "h": 0}

    def _emit_axis(self, key, delta, hires_code, lowres_code):
        self._frac[key] += delta
        step = int(self._frac[key])
        if step == 0:
            return False
        self._frac[key] -= step
        self.ui.write(ec.EV_REL, hires_code, step)
        self._notch[key] += step
        notches = int(self._notch[key] / HIRES_PER_NOTCH)
        if notches != 0:
            self._notch[key] -= notches * HIRES_PER_NOTCH
            self.ui.write(ec.EV_REL, lowres_code, notches)
        return True

    def scroll(self, dv, dh):
        wrote = self._emit_axis("v", dv, ec.REL_WHEEL_HI_RES, ec.REL_WHEEL)
        wrote |= self._emit_axis("h", dh, ec.REL_HWHEEL_HI_RES, ec.REL_HWHEEL)
        if wrote:
            self.ui.syn()

    def button(self, code, pressed):
        self.ui.write(ec.EV_KEY, code, 1 if pressed else 0)
        self.ui.syn()

    def reset(self):
        self._frac = {"v": 0.0, "h": 0.0}
        self._notch = {"v": 0, "h": 0}


def axis_delta(value, deadzone, curve, gain, dt_ms):
    mag = abs(value)
    if mag <= deadzone:
        return 0.0
    norm = min((mag - deadzone) / (FULL_DEFLECTION - deadzone), 1.5)
    return math.copysign(norm ** curve * gain * dt_ms, value)


def spnav_connect(path):
    """Connect to spacenavd, switch to protocol v1, subscribe to raw axes."""
    announced = False
    while True:
        s = socket.socket(socket.AF_UNIX)
        try:
            s.connect(path)
        except OSError:
            s.close()
            if not announced:
                log("waiting for spacenavd socket at " + path)
                announced = True
            time.sleep(2)
            continue

        try:
            s.settimeout(3.0)
            s.sendall(struct.pack("=i", REQ_TAG | REQ_CHANGE_PROTO | 1))
            buf = b""
            ver = None
            while ver is None:
                if len(buf) >= 4:
                    (head,) = struct.unpack("=i", buf[:4])
                    if (head & 0xFFFFFF00) == (REQ_TAG | REQ_CHANGE_PROTO):
                        ver = head & 0xFF
                        buf = buf[4:]
                        break
                    if len(buf) >= 32:  # stray v0 event frame, drop it
                        buf = buf[32:]
                        continue
                buf += s.recv(4096)
            if ver < 1:
                log("spacenavd does not support protocol v1 (got %d)" % ver)
                sys.exit(1)
            s.sendall(struct.pack("=8i", REQ_SET_EVMASK,
                                  EVMASK_RAWAXIS | EVMASK_BUTTON, 0, 0, 0, 0, 0, 0))
        except (OSError, struct.error) as e:
            log("spacenavd handshake failed (%s), retrying" % e)
            s.close()
            time.sleep(2)
            continue

        s.settimeout(None)
        log("connected to spacenavd (protocol v1, raw axes)")
        return s, buf


def main():
    p = argparse.ArgumentParser(description="SpaceMouse browser scrolling via uinput")
    p.add_argument("--browsers", default="brave-browser,firefox,chromium-browser,zen",
                   help="comma-separated window classes treated as browsers")
    p.add_argument("--exclude-title", default="onshape",
                   help="case-insensitive regex; matching titles disable scrolling")
    p.add_argument("--speed", type=float, default=1.0)
    p.add_argument("--deadzone", type=int, default=30)
    p.add_argument("--curve", type=float, default=1.4,
                   help="response-curve exponent (>1 = finer control near center)")
    p.add_argument("--scroll-axis", type=int, default=2,
                   help="raw axis index for vertical scroll (0-5, default 2 = slide "
                        "forward/back; raw axes are in device order: on the wireless "
                        "SpaceMouse axis 1 is vertical lift, which reads negative during "
                        "almost any motion from incidental hand pressure -- don't use it)")
    p.add_argument("--hscroll-axis", type=int, default=0,
                   help="raw axis index for horizontal scroll (default 0 = left/right)")
    p.add_argument("--invert", action="store_true", help="invert vertical scroll")
    p.add_argument("--invert-h", action="store_true", help="invert horizontal scroll")
    p.add_argument("--back-button", type=int, default=0)
    p.add_argument("--forward-button", type=int, default=1)
    p.add_argument("--socket", default=os.environ.get("SPNAV_SOCKET", "/var/run/spnav.sock"))
    args = p.parse_args()

    exclude_re = re.compile(args.exclude_title, re.IGNORECASE) if args.exclude_title else None
    focus = HyprFocus([b for b in args.browsers.split(",") if b], exclude_re)
    mouse = VirtualMouse()
    log("virtual mouse created")

    gain = BASE_GAIN * args.speed
    # raw device z is positive sliding away (measured); positive REL_WHEEL
    # scrolls up, and slide-away should scroll down, so base sign is negative
    vsign = 1.0 if args.invert else -1.0
    hsign = -1.0 if args.invert_h else 1.0
    button_map = {
        args.back_button: ec.BTN_SIDE,
        args.forward_button: ec.BTN_EXTRA,
    }
    pressed = {}
    axes = [0] * 6

    sock, buf = spnav_connect(args.socket)
    last_tick = time.monotonic()
    while True:
        deflected = (abs(axes[args.scroll_axis]) > args.deadzone
                     or abs(axes[args.hscroll_axis]) > args.deadzone)
        timeout = 0.016 if deflected else 0.5
        readable, _, _ = select.select([sock], [], [], timeout)

        if readable:
            try:
                data = sock.recv(4096)
            except OSError:
                data = b""
            if not data:
                log("lost spacenavd connection, reconnecting")
                sock.close()
                mouse.reset()
                axes = [0] * 6
                sock, buf = spnav_connect(args.socket)
                last_tick = time.monotonic()
                continue
            buf += data
            while len(buf) >= 32:
                ev = struct.unpack("=8i", buf[:32])
                buf = buf[32:]
                etype = ev[0]
                if etype == UEV_RAWAXIS:
                    if 0 <= ev[1] < 6:
                        axes[ev[1]] = ev[2]
                elif etype in (UEV_PRESS, UEV_RELEASE):
                    bnum = ev[1]
                    code = button_map.get(bnum)
                    if code is None:
                        continue
                    if etype == UEV_PRESS:
                        if focus.active():
                            pressed[bnum] = True
                            mouse.button(code, True)
                    elif pressed.pop(bnum, False):
                        # always release what we pressed, even if focus moved
                        mouse.button(code, False)
                # anything else (request responses, other events): ignore

        now = time.monotonic()
        dt_ms = min((now - last_tick) * 1000.0, 100.0)
        last_tick = now
        if not deflected:
            continue
        if not focus.active():
            mouse.reset()
            continue
        dv = axis_delta(axes[args.scroll_axis], args.deadzone,
                        args.curve, gain, dt_ms) * vsign
        dh = axis_delta(axes[args.hscroll_axis], args.deadzone,
                        args.curve, gain, dt_ms) * hsign
        mouse.scroll(dv, dh)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        sys.exit(0)
