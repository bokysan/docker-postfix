#!/usr/bin/env sh

if [ $# -eq 0 ]; then
  echo "No alpine build versions supplied"
  echo "example usage: ./push.sh latest 3.10 3.9"
  exit 1
fi

# Authenticate to push images
docker login

# build, tag, and push alpine versions supplied as script arguments
base_repo=boky/postfix
for alpine_version in "$@"
do
  docker build -t "$base_repo":"$alpine_version" --build-arg=ALPINE_VERSION="$alpine_version" .
  docker push "$base_repo":"$alpine_version"
done


