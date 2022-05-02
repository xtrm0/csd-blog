#! /bin/sh

for year in website/content/20*; do
    if [ ! -e "$year/_index.md" ]; then
        cp website/content/2021/_index.md "$year/_index.md"
    elif diff website/content/2021/_index.md "$year/_index.md" >/dev/null; then
        true
    else
        echo "Unexpected inconsistency for $(basename "$year"), fixing"
        cp website/content/2021/_index.md "$year/_index.md"
    fi
done

cd website/ || exit 255
../binaries/use_zola serve
cd ../
