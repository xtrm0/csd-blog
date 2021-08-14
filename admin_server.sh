#! /bin/sh

if [ ! -x ./binaries/zola ]; then
    cd ./binaries/ || exit 255;
    tar xzf zola-*-x86_64-unknown-linux-gnu.tar.gz;
    cd ../;
fi

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 PULL-REQUEST-ID" >&2
  exit 1
fi

git fetch origin "pull/${1}/head:pr-${1}" || exit 1
git checkout "pr-${1}" || exit 2
git pull || exit 3

cd website/ || exit 255
../binaries/zola serve
cd ../
