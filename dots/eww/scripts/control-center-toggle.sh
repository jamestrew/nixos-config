#!/usr/bin/env bash

# Toggle the control center window
if eww active-windows | rg -q "control-center"; then
  eww close control-center
else
  eww open control-center
fi
