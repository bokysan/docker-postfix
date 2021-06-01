#!/usr/bin/env sh

if [ $# -eq 0 ]; then
  echo "No alpine build versions supplied"
  echo "example usage: $0 latest 3.10 3.9"
  exit 1
fi

# Authenticate to push images
docker login

# build, tag, and push alpine versions supplied as script arguments
base_repo=boky/postfix
for alpine_version in "$@"; do
  $(dirname $0)/build.sh -t "$base_repo" --build-arg=BASE_IMAGE="alpine:$alpine_version"
done
