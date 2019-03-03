#!/usr/bin/env bash

# make sure we're in the correct directory
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
pushd $DIR/..

cp -R src/generated/ /tmp/hoplon_src_generated

hashdeep -c sha256 -r src | sort > /tmp/hoplon_src_before.txt
mix compile
hashdeep -c sha256 -r src | sort > /tmp/hoplon_src_after.txt

diff /tmp/hoplon_src_generated/ src/generated

diff /tmp/hoplon_src_before.txt /tmp/hoplon_src_after.txt || exit 1

popd
exit 0
