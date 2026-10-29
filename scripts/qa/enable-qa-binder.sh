#!/bin/sh
# Load the existing signed Binder driver for the local Android15 QA container.
# No installation, network change, password input, or boot configuration change.
set -eu
if [ "$(id -u)" -ne 0 ]; then echo 'BLOCKED: administrator access is required to load a kernel module' >&2; exit 3; fi
modprobe binder_linux
if [ ! -d /sys/module/binder_linux ]; then echo 'FAIL: binder_linux was not loaded' >&2; exit 1; fi
echo 'PASS: existing binder_linux module loaded for this boot'
