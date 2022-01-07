#! /bin/sh

for year in website/content/20*; do
    if [ ! -e "$year/_index.md" ]; then
        cp website/content/2021/_index.md "$year/_index.md";
    fi
done

cd website/ || exit 255
../binaries/use_zola serve
cd ../
