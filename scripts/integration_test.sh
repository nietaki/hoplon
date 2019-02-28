#!/usr/bin/env bash

# make sure we're in the correct directory
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
pushd $DIR/..

printf "\n# cloning suffixer\n\n"

rm -rf suffixer

git clone --branch hoplon-integration-test git@github.com:nietaki/suffixer.git || exit 1

pushd suffixer

printf "\n# getting dependencies and compiling\n\n"

mix clean || exit 1
mix deps.get || exit 1
mix compile 2>/dev/null || exit 1

printf "\n# checking if hoplon works \n\n"

mix hoplon.check
# this should return a "12" exit code
rc=$?; if [[ $rc != 12 ]]; then exit 1; fi

# a loose assertion on the error message
mix hoplon.check | grep evil_left_pad | grep CORRUPT || exit 1

printf "\n## INTEGRATION TESTS SUCCEEDED ##\n\n"

popd
popd
exit 0
