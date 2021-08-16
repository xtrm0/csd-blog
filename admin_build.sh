#! /bin/sh

git checkout "main" || exit 1
git pull || exit 2

cd website/ || exit 255
../binaries/use_zola build
rm -f ../generated-website.zip
zip -r ../generated-website.zip public/
cd ../

echo "generated-website.zip has been generated. Please put this onto AFS at the right location."
