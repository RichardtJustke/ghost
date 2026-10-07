#!/usr/bin/env bash
# Usage: bt_device_info.sh <MAC>
# Prints the PipeWire/Pulse card for a Bluetooth device as JSON:
# {"card":"bluez_card.XX_..","active":"a2dp-sink","profiles":[{"name":"a2dp-sink","desc":"...","available":true}]}

mac="${1^^}"
[[ -z "$mac" ]] && { echo '{}'; exit 0; }
card="bluez_card.${mac//:/_}"

LC_ALL=C pactl list cards 2>/dev/null | awk -v card="$card" '
    /^Card #/ { inCard = 0; inProfiles = 0 }
    $1 == "Name:" { inCard = ($2 == card) }
    !inCard { next }
    /^\tProfiles:/ { inProfiles = 1; next }
    /^\t[A-Z]/ && !/^\tProfiles:/ { inProfiles = 0 }
    inProfiles && /^\t\t[^ ]+: / {
        line = $0
        sub(/^\t\t/, "", line)
        name = line; sub(/: .*/, "", name)
        desc = line; sub(/^[^ ]+: /, "", desc)
        avail = (desc ~ /available: no\)/) ? "no" : "yes"
        sub(/ \(sinks:.*$/, "", desc)
        printf "P\037%s\037%s\037%s\n", name, desc, avail
    }
    /^\tActive Profile:/ { a = $0; sub(/.*Active Profile: /, "", a); printf "A\037%s\n", a }
' | jq -R -s -c --arg card "$card" '
    split("\n") | map(select(length > 0) | split("\u001f")) as $rows
    | if ($rows | length) == 0 then {} else {
        card: $card,
        active: ([$rows[] | select(.[0] == "A") | .[1]] | first // ""),
        profiles: [$rows[] | select(.[0] == "P") | {name: .[1], desc: .[2], available: (.[3] == "yes")}]
    } end
'
