#!/bin/bash
# Invoked by sleepwatcher after macOS wakes from sleep.
exec /bin/bash "$(dirname "$0")/hfut-campus-login.sh" --wait-seconds 20
