#!/bin/sh
# The X11 clipboard both ways with another program (xclip), under an X server ($DISPLAY):
# Envo copies and xclip pastes; xclip copies and Envo pastes. CI runs it under Xvfb.
#
#   sh adapters/os/linux/x11/check/clipboard.sh <envo>
set -eu
envo=$1
here=$(dirname "$0")
command -v xclip > /dev/null || { echo "clipboard.sh: needs xclip"; exit 2; }

"$envo" run --native "$here/copy.envo" > copy.out &
copier=$!
i=0
while [ "$(cat copy.out 2> /dev/null)" != "copied" ] && [ $i -lt 600 ]; do sleep 0.1; i=$((i + 1)); done
got=$(timeout 3 xclip -selection clipboard -o || true)
wait $copier
[ "$got" = "copied by envo" ] || { echo "xclip pasted [$got], not what Envo copied"; exit 1; }
echo "envo copies, xclip pastes: ok"

printf 'copied by xclip' | xclip -selection clipboard -i
got=$("$envo" run --native "$here/paste.envo")
[ "$got" = "copied by xclip" ] || { echo "Envo pasted [$got], not what xclip copied"; exit 1; }
echo "xclip copies, envo pastes: ok"
