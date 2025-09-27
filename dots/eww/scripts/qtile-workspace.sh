#!/usr/bin/env bash


tail -n0 -F /tmp/qtile-layouts.ndjson | jq -r 'map(.group) | join(",")'

