#!/bin/sh
# Runs in the existing PBX image as root, with explicit runtime-only mounts.
set -eu
cp -an /var/lib/asterisk/. /seed/
chown -R 1001:1001 /seed /control /pbx-config
chmod 700 /control
find /pbx-config -type d -exec chmod 750 {} +
# Keep the operator as owner; only the intended service group can also read.
for name in ami admin-password apns.p8 fcm-service-account.json; do
    test -f "/runtime-secrets/$name"
    chgrp 1001 "/runtime-secrets/$name"
    chmod 640 "/runtime-secrets/$name"
done
