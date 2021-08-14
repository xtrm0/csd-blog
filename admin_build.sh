#! /bin/sh

if [ ! -x ./binaries/zola ]; then
    cd ./binaries/ || exit 255;
    tar xzf zola-*-x86_64-unknown-linux-gnu.tar.gz;
    cd ../;
fi

git checkout "main" || exit 1
git pull || exit 2

cd website/ || exit 255
../binaries/zola build
rm -f ../generated-website.zip
zip -r ../generated-website.zip public/
cd ../

echo "generated-website.zip has been generated. Please put this onto AFS at the right location."
