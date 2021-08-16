#! /bin/sh

cd website/ || exit 255
../binaries/use_zola serve
cd ../
