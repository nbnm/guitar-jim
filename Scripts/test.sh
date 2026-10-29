#!/bin/zsh
set -euo pipefail
task_root="${0:A:h:h}"
cd "$task_root"
# Standalone Command Line Tools ship Swift Testing as a framework without adding
# its framework search path. Full Xcode and other Swift toolchains need no override.
developer_dir="$(xcode-select -p)"
testing_frameworks="$developer_dir/Library/Developer/Frameworks"
if [[ -d "$testing_frameworks/Testing.framework" ]]; then
    swift test -Xswiftc -F -Xswiftc "$testing_frameworks" -Xlinker -rpath -Xlinker "$testing_frameworks" -Xlinker -rpath -Xlinker "$developer_dir/Library/Developer/usr/lib" "$@"
else
    swift test "$@"
fi
