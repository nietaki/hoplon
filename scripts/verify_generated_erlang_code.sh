#!/usr/bin/env bash

# make sure we're in the correct directory
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
pushd $DIR/..

hashdeep -c sha256 -r src | sort > /tmp/hoplon_src_before.txt
mix compile
hashdeep -c sha256 -r src | sort > /tmp/hoplon_src_after.txt

diff /tmp/hoplon_src_before.txt /tmp/hoplon_src_after.txt || exit 1

popd
exit 0
