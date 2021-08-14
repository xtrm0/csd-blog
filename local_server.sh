#! /bin/sh

if [ ! -x ./binaries/zola ]; then
    cd ./binaries/ || exit 255;
    tar xzf zola-*-x86_64-unknown-linux-gnu.tar.gz;
    cd ../;
fi

cd website/ || exit 255
../binaries/zola serve
cd ../
