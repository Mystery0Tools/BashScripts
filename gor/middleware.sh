#!/usr/bin/env bash
while read line; do
    decoded=$(echo -e "$line" | xxd -r -p)
    header=$(echo -e "$decoded" | head -n +1)
    payload=$(echo -e "$decoded" | tail -n +2)

    # modified by this line

    encoded=$(echo -e "$header\n$payload" | xxd -p | tr -d "\\n")
    echo "$encoded"
done;