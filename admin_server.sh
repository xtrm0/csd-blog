#! /bin/sh

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 PULL-REQUEST-ID" >&2
  exit 1
fi

git fetch origin "pull/${1}/head:pr-${1}" || exit 1
git checkout "pr-${1}" || exit 2
git pull || exit 3

cd website/ || exit 255
../binaries/use_zola serve
cd ../
