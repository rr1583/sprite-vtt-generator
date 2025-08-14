#!/usr/bin/env bash

set -e

DOCKER_COMPOSE_BIN=$(command -v docker-compose || echo "docker compose")

usage() { echo "Usage: $0 [-r]"; exit 1; }

# default values - don't rebuild by default
FORCE_REBUILD_IMAGE=0

# take in options
while getopts ":r" o; do
    case "${o}" in
        r)
            FORCE_REBUILD_IMAGE=1
            ;;
        *)
            usage
            ;;
    esac
done
shift $((OPTIND-1))

# update the source code
#echo "Updating source code to latest..."
#git pull https://gitlab+deploy-token-1822562:Kt8Zs5n86HzZB6EbMd1n@gitlab.com/logangroup/development-tools/sprite-vtt-generator.git
#echo "Source code updated successfully"
#echo ""

# now bring the stack down and rebuild
echo "Bringing down the local stack..."
$DOCKER_COMPOSE_BIN down
echo "Stack successfully brought down"
echo ""

# only if we want to rebuild, actually rebuild
if [ "$FORCE_REBUILD_IMAGE" == "1" ]; then
  echo "Rebuilding image... this will take a while"
  docker build --no-cache -f Dockerfile -t mt-ffmpeg:latest  .
  echo "Build complete."
fi

# now bring back up the stack
echo "Bringing the local stack up..."
$DOCKER_COMPOSE_BIN up -d

echo "Update 100% Complete, Enjoy your new version! Now using version [$(cat version.txt)]"

