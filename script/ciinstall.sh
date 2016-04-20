#!/usr/bin/env bash
set -e # halt script on error

cd ..
git clone --depth=3 --branch=gh-pages https://github.com/BricksandMortar/plugin-doc-template.git
rm -rf plugin-doc-template/.git
cp -r -n -p plugin-doc-template/* $TRAVIS_BUILD_DIR/
cd $TRAVIS_BUILD_DIR
bundle install
sed -i -e 's/$VERSION_NUMBER/'$TRAVIS_BUILD_NUMBER'/g' ./_layouts/*.html
sed -i -e  's/'#baseurl'/baseurl/' ./_config.yml
