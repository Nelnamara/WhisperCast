#!/bin/bash
# Runs every harness against the addon (default: this repo; set R=<folder> for another copy). Prints RESULT and FAIL lines only.
# Each harness runs on all five clients: Era 11509, TBC 20506, MoP 50504, Retail 120105, Forever 16001.
R=${R:-$(cd "$(dirname "$0")/../.." && pwd)}
T=$(dirname "$0")
run() {
	local out
	out=$(timeout 300 node $T/run.js $R "$@" 2>&1)
	if echo "$out" | grep -q "^RESULT"; then
		echo "$out" | grep -E "^RESULT|FAIL"
	else
		echo "NO RESULT: $* (lua errors 1)"
		echo "$out" | tail -n 3 | sed 's/^/  FAIL /'
	fi
}
CLIENTS="11509:WhisperCast_Vanilla.toc 20506:WhisperCast_TBC.toc 50504:WhisperCast_Mists.toc 120105:WhisperCast_Mainline.toc 16001:WhisperCast_Camelot.toc 16001:WhisperCast.toc"
for h in smoke engine ui options; do
	[ -f "$T/$h.lua" ] || continue
	for c in $CLIENTS; do run "${c%%:*}" "$T/$h.lua" "${c#*:}"; done
done
