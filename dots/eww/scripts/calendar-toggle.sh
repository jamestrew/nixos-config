#!/usr/bin/env bash

if eww active-windows | rg -q "calendar"; then
    eww close calendar
else
    eww open calendar
fi