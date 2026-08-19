#!/bin/sh
set -eu

select_target() {
    direction=$1
    current=$2

    jq -r --arg direction "$direction" --argjson current "$current" '
        def center: [(.at[0] + .size[0] / 2), (.at[1] + .size[1] / 2)];
        def interval_gap($a0; $a1; $b0; $b1):
            if $b0 > $a1 then $b0 - $a1
            elif $a0 > $b1 then $a0 - $b1
            else 0 end;
        def geometry($window):
            ($current | center) as $source |
            ($window | center) as $target |
            if $direction == "left" then
                { signed: ($source[0] - $target[0]),
                  primary: ([0, $current.at[0] - ($window.at[0] + $window.size[0])] | max),
                  cross: interval_gap($current.at[1]; $current.at[1] + $current.size[1]; $window.at[1]; $window.at[1] + $window.size[1]) }
            elif $direction == "right" then
                { signed: ($target[0] - $source[0]),
                  primary: ([0, $window.at[0] - ($current.at[0] + $current.size[0])] | max),
                  cross: interval_gap($current.at[1]; $current.at[1] + $current.size[1]; $window.at[1]; $window.at[1] + $window.size[1]) }
            elif $direction == "up" then
                { signed: ($source[1] - $target[1]),
                  primary: ([0, $current.at[1] - ($window.at[1] + $window.size[1])] | max),
                  cross: interval_gap($current.at[0]; $current.at[0] + $current.size[0]; $window.at[0]; $window.at[0] + $window.size[0]) }
            else
                { signed: ($target[1] - $source[1]),
                  primary: ([0, $window.at[1] - ($current.at[1] + $current.size[1])] | max),
                  cross: interval_gap($current.at[0]; $current.at[0] + $current.size[0]; $window.at[0]; $window.at[0] + $window.size[0]) }
            end |
            ($target[0] - $source[0]) as $dx |
            ($target[1] - $source[1]) as $dy |
            . + { distance: ($dx * $dx + $dy * $dy) };

        [ .[]
          | select(.address != $current.address)
          | select(.workspace.id == $current.workspace.id)
          | select(.mapped != false and .hidden != true and .noFocus != true)
          | . as $window
          | geometry($window) + { window: $window }
        ] as $candidates |
        if any($candidates[]; .signed > 0) then
            $candidates
            | map(select(.signed > 0) | .score = (.primary + 1.61803398875 * .cross))
        elif ($candidates | length) > 0 then
            ($candidates | map(.signed) | min) as $wrap |
            $candidates
            | map(.score = ((.signed - $wrap) + 1.61803398875 * .cross))
        else [] end
        | sort_by(.score, .distance, .window.focusHistoryID)
        | first.window.address // empty
    '
}

self_test() {
    current='{"address":"current","at":[0,0],"size":[100,100],"workspace":{"id":1}}'
    clients='[
      {"address":"aligned","at":[200,0],"size":[100,100],"workspace":{"id":1}},
      {"address":"diagonal","at":[110,160],"size":[100,100],"workspace":{"id":1}}
    ]'
    [ "$(printf '%s' "$clients" | select_target right "$current")" = aligned ]
}

if [ "${1:-}" = --self-test ]; then
    self_test
    exit
fi

direction=${1:-}
case $direction in
    left|right|up|down) ;;
    *) echo "usage: golden-focus.sh left|right|up|down" >&2; exit 2 ;;
esac

current=$(hyprctl -j activewindow)
target=$(hyprctl -j clients | select_target "$direction" "$current")
[ -z "$target" ] || hyprctl -q dispatch "hl.dsp.focus({ window = \"address:$target\" })"
