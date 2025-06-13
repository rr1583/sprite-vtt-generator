#!/usr/bin/env bash

set -e

err_report() {
    echo "Error on line $1"
}

trap 'err_report $LINENO' ERR

usage() { echo "Usage: $0 [-n <int>] [-i <int>] [-r <int>] [-s <int>] FILE_LOCATION SHOOT_CODE NO_WATERMARK_FILE_LOCATION" 1>&2; exit 1; }

win2lin () { f="${1/C://c}"; printf '%s' "${f//\\//}"; }

# take in a time hh:mm:ss and convert to num seconds
timeToSeconds () { echo "$1" | awk -F: '{ print ($1 * 3600) + ($2 * 60) + $3 }'; }

# take in num seconds and convert back to hh:mm:ss time
secondsToTime () {
  if [ "$SYSTEM" == "linux" ]; then
    date -d@"$1" -u +%H:%M:%S
  else
    date -u -r "$1" +%T
  fi
}

# logic to go and rename files with correct naming convention:
#   - drop the shoot code from the filename
#   - pad numbers to always be three digits
#   - thumbnails should retain the "tn" prefix
renameScreencaps () {
  SCREENCAPS_DIR=$1

  for filename in "$SCREENCAPS_DIR"/*.jpg; do
    SC_FILE_NAME=$(basename "$filename")                   # e.g. tnpb13624-18.jpg
    SC_FILE_NO_EXTENSION="${SC_FILE_NAME%.*}"               # remove extension
    SC_FILE_NUMBER="${SC_FILE_NO_EXTENSION##*-}"            # number after the hyphen

    # remove leading zeros and convert to int
    SC_NUMBER=$((10#${SC_FILE_NUMBER}))

    if [[ "$SC_FILE_NO_EXTENSION" == tn* ]]; then
      PREFIX="tn"
    else
      PREFIX=""
    fi

    if [ "$SC_NUMBER" -lt 10 ]; then
      SC_NEW_FILE_NAME_NO_EXTENSION=${PREFIX}00$SC_NUMBER
    elif [ "$SC_NUMBER" -lt 100 ]; then
      SC_NEW_FILE_NAME_NO_EXTENSION=${PREFIX}0$SC_NUMBER
    else
      SC_NEW_FILE_NAME_NO_EXTENSION=${PREFIX}$SC_NUMBER
    fi

    FINAL_FILE_NAME="$SCREENCAPS_DIR/$SC_NEW_FILE_NAME_NO_EXTENSION.jpg"
    mv "$filename" "$FINAL_FILE_NAME"
  done
}

SYSTEM="UNKNOWN"

if [ "$(uname)" == "Darwin" ]; then
    SYSTEM="mac"
elif [ "$(expr substr "$(uname -s)" 1 5)" == "Linux" ]; then
    SYSTEM="linux"
elif [ "$(expr substr "$(uname -s)" 1 10)" == "MINGW32_NT" ]; then
    SYSTEM="windows"
elif [ "$(expr substr "$(uname -s)" 1 10)" == "MINGW64_NT" ]; then
    SYSTEM="windows"
fi

echo "Running script on a [$SYSTEM] machine"
echo ""

# default values
declare -i NUM_SCREENCAPS=500
declare -i SCREENCAPS_INTERVAL=2
declare -i NUM_ROLLOVERS=17
declare -i NUM_SECONDS_INTERVAL_VTT=10

# take in options
while getopts ":n:r:i:s:" o; do
    case "${o}" in
#        n)
#            NUM_SCREENCAPS=${OPTARG}
#            ;;
        r)
            NUM_ROLLOVERS=${OPTARG}
            ;;
        i)
            NUM_SECONDS_INTERVAL_VTT=${OPTARG}
            ;;
        s)
            SCREENCAPS_INTERVAL=${OPTARG}
            ;;
        *)
            usage
            ;;
    esac
done
shift $((OPTIND-1))
# end of options

if [ "$#" -ne 3 ]; then
  echo "You must provide the location of the shoot, the shoot code and the location of the shoot with no watermark"
  echo "For example (mac):"
  echo ""
  echo "./run.sh ~/Downloads/pb13624-480p.mp4 pb13624 ~/Downloads/pb13624-480p.mp4"
  echo ""
  usage
  exit
fi


echo "Num screencaps is [to be calculated], num rollovers is [$NUM_ROLLOVERS] and VTT interval in seconds is [$NUM_SECONDS_INTERVAL_VTT]"
echo ""
echo ""

# start a timer
START=$SECONDS

# Where is the local media (which is mounted inside the docker) stored and what is the location inside the container
DOCKER_MOUNT_MEDIA_LOCATION="/mnt/media"
LOCAL_MEDIA_PATH="./media"

#ARGS - what file and what shoot
FILE_LOCATION="$1"
SHOOT_NAME="$2"
NO_WATERMARK_FILE_LOCATION="$3"

#### IF IT'S WINDOWS
# we need to change the location format passed in, because we'll get something like C:\Users\tomc\Downloads\video.mp4
# we need to convert it to be recognizable in windows bash e.g. /mnt/c/Users/tomc/Downloads/video.mp4
# so we can just do a find and replace here
#if [ "$SYSTEM" == "windows" ]; then
#    FILE_LOCATION="/mnt"$(win2lin "$FILE_LOCATION")
#    NO_WATERMARK_FILE_LOCATION="/mnt"$(win2lin "NO_WATERMARK_FILE_LOCATION")
#    echo "Updated file path for windows from [$1] to: [$FILE_LOCATION]"
#    echo "Updated no watermark file path for windows from [$3] to: [$NO_WATERMARK_FILE_LOCATION]"
#fi
### END OF WINDOWS SPECIFIC

FILE_NAME=$(basename "$FILE_LOCATION")
FILE_NAME_WITHOUT_EXTENSION=${FILE_NAME%.*}

FILE_NAME_NO_WATERMARK=$(basename "$NO_WATERMARK_FILE_LOCATION")

LOCAL_FILE_PATH="$LOCAL_MEDIA_PATH/$SHOOT_NAME"
LOCAL_FILE_LOCATION="$LOCAL_FILE_PATH/$FILE_NAME"
LOCAL_FILE_LOCATION_NO_WATERMARK="$LOCAL_FILE_PATH/$FILE_NAME_NO_WATERMARK"

LOCAL_VTT_LOCATION="$LOCAL_FILE_PATH/sprite/${SHOOT_NAME}_sprite.vtt"
LOCAL_VTT_LOCATION_MOVED="$LOCAL_FILE_PATH/sprite/${SHOOT_NAME}_thumbs.vtt"

DOCKER_DIR_LOCATION="$DOCKER_MOUNT_MEDIA_LOCATION/$SHOOT_NAME"
FILE_LOCATION_INSIDE_DOCKER="$DOCKER_DIR_LOCATION/$FILE_NAME"
FILE_LOCATION_NO_WATERMARK_INSIDE_DOCKER="$DOCKER_DIR_LOCATION/$FILE_NAME_NO_WATERMARK"
DOCKER_SPRITEMAP_LOCATION="$DOCKER_DIR_LOCATION/sprite/${SHOOT_NAME}_sprite.jpg"

# just in case it had already ran before, delete old files (default to unknown if somehow blank so we don't delete everyone's everything!
echo "Going to remove all media from previous runs before executing (${LOCAL_FILE_PATH:?UNKNOWN}/*)..."
rm -rf "${LOCAL_FILE_PATH:?UNKNOWN}"/*
echo "Local directory cleaned up"
echo ""

# first copy to the local folder mount (no watermark and the normal shoot)
echo "Copying file [$FILE_NAME] from [$FILE_LOCATION] to temp dir from [$LOCAL_FILE_PATH/]"
mkdir -p "$LOCAL_FILE_PATH"
cp "$FILE_LOCATION" "$LOCAL_FILE_PATH/"
echo "File [$FILE_NAME] copied to [$LOCAL_FILE_LOCATION]"
echo ""
echo "Copying file [$FILE_NAME_NO_WATERMARK] from [$NO_WATERMARK_FILE_LOCATION] to temp dir from [$LOCAL_FILE_PATH/]"
cp "$NO_WATERMARK_FILE_LOCATION" "$LOCAL_FILE_PATH/"
echo "File [$FILE_NAME_NO_WATERMARK] copied to [$LOCAL_FILE_LOCATION_NO_WATERMARK]"
echo ""


####################
# do the rollovers #
####################
echo "Making [$NUM_ROLLOVERS] rollovers..."
# run and then mogrify to resize to correct size
# make one more than we need so we can delete it later (because we don't want the end credits)
declare -i NUM_ROLLOVERS_PLUS_ONE=$((NUM_ROLLOVERS+1))
docker-compose run --workdir="/go" mt-ffmpeg sh -c "mt $FILE_LOCATION_INSIDE_DOCKER --single-images=true --verbose=true --overwrite=true --padding=0 --width=240 --numcaps=$NUM_ROLLOVERS_PLUS_ONE --output=$DOCKER_DIR_LOCATION/rollover/180/.jpg; mogrify -resize 240x180^ -gravity center -extent 240x180 $DOCKER_DIR_LOCATION/rollover/180/*.jpg"


# we need to rename the rollovers
declare -i COUNTER=0
for i in "$LOCAL_FILE_PATH"/rollover/180/*
do
  # replace the trailing "-" and "0" if there is one as they get outputted as -09.jpg etc.
  NEWNAME="${i/-0/}"
  NEWNAME="${NEWNAME/-/}"
  mv -- "$i" "$NEWNAME"
  ((COUNTER+=1))
done

# we need to remove the last one - (because we don't want the end credits in it)
rm "$LOCAL_FILE_PATH/rollover/180/$COUNTER.jpg"

echo "Rollovers took $(( SECONDS - START - DURATION )) seconds to run"
DURATION=$(( SECONDS - START ))
echo ""

##################################
# do the VTT / sprite generation #
##################################
echo "Running mt script against file [$FILE_NAME]"
echo "Making spritemap and VTT..."
docker-compose run --workdir="/go" mt-ffmpeg sh -c "mt $FILE_LOCATION_INSIDE_DOCKER --webvtt=true --interval=$NUM_SECONDS_INTERVAL_VTT --verbose=true --overwrite=true --header=false --disable-timestamps=true --padding=0 --width=240 --output=$DOCKER_SPRITEMAP_LOCATION; mogrify -quality 75 $DOCKER_SPRITEMAP_LOCATION"


#####################
# rename the sprite #
#####################
mv "$LOCAL_VTT_LOCATION" "$LOCAL_VTT_LOCATION_MOVED"
echo "VTT and spritemap complete"
DURATION=$(( SECONDS - START ))
echo "VTT and Sprite took $DURATION seconds to run"
echo ""


###########################################################################################################################################
# get the length of the video so we can figure out screencaps, one every 3 seconds, starting at 15 seconds and ending 6 seconds before end #
###########################################################################################################################################
VIDEO_LENGTH_SECONDS=$(docker-compose run --workdir="/go" mt-ffmpeg sh -c "ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 $FILE_LOCATION_INSIDE_DOCKER")
VIDEO_LENGTH_SECONDS=${VIDEO_LENGTH_SECONDS%.*}

echo "Video length seconds: [$VIDEO_LENGTH_SECONDS]"

# now we need to minus the end buffer, we're already setting the start to "00:00:15" so we minus 6 seconds for the end credits
((VIDEO_LENGTH_SECONDS-=6))

# now figure out the start and end time for screencaps
SCREENCAP_START_TIME='00:00:15'
SCREENCAP_END_TIME=$(secondsToTime "$VIDEO_LENGTH_SECONDS")
NUM_SCREENCAPS=$((VIDEO_LENGTH_SECONDS/SCREENCAPS_INTERVAL))
echo "Going to do [$NUM_SCREENCAPS] screencaps from [$SCREENCAP_START_TIME] to [$SCREENCAP_END_TIME]"
echo ""

#####################
# do the screencaps #
#####################
echo "Making [$NUM_SCREENCAPS] screencaps..."
docker-compose run --workdir="/go" mt-ffmpeg sh -c "mt $FILE_LOCATION_INSIDE_DOCKER --single-images=true --verbose=true --overwrite=true --padding=0 --width=1278 --interval=$SCREENCAPS_INTERVAL --from='$SCREENCAP_START_TIME' --to='$SCREENCAP_END_TIME' --output=$DOCKER_DIR_LOCATION/screencaps/$SHOOT_NAME.jpg;"
# (this is super hacky but only way I could get it to work properly...) - use mogrify to resize the screencaps to make thumbs in a separate dir then move back to main dir and rename tn*
echo "Generating thumbs for normal screencaps..."
docker-compose run --workdir="$DOCKER_DIR_LOCATION/screencaps/" mt-ffmpeg sh -c 'mkdir -p thumbs; mogrify -path thumbs -resize 245x180^ -gravity center -extent 245x180 *.jpg; cd thumbs; for filename in *.jpg; do mv "$filename" ../tn"$filename"; done;'
# HACK to rename the files as they need to be (see function for details)
renameScreencaps "$LOCAL_FILE_PATH/screencaps"
# cleanup - remove the empty thumbs dir
rm -rf "$LOCAL_FILE_PATH/screencaps/thumbs/"

echo "Screencaps took $(( SECONDS - START - DURATION )) seconds to run"
DURATION=$(( SECONDS - START ))
echo ""


###  and for the no watermark ###
echo "Making [$NUM_SCREENCAPS] screencaps with no watermark..."
docker-compose run --workdir="/go" mt-ffmpeg sh -c "mt $FILE_LOCATION_NO_WATERMARK_INSIDE_DOCKER --single-images=true --verbose=true --overwrite=true --padding=0 --width=1278 --interval=$SCREENCAPS_INTERVAL --from='$SCREENCAP_START_TIME' --to='$SCREENCAP_END_TIME' --output=$DOCKER_DIR_LOCATION/screencapsnw/$SHOOT_NAME.jpg"
# (this is super hacky but only way I could get it to work properly...) - use mogrify to resize the screencaps to make thumbs in a separate dir then move back to main dir and rename tn*
echo "Generating thumbs for no watermark screencaps..."
docker-compose run --workdir="$DOCKER_DIR_LOCATION/screencapsnw/" mt-ffmpeg sh -c 'mkdir -p thumbs; mogrify -path thumbs -resize 245x180^ -gravity center -extent 245x180 *.jpg; cd thumbs; for filename in *.jpg; do mv "$filename" ../tn"$filename"; done;'
# HACK to rename the files as they need to be (see function for details)
renameScreencaps "$LOCAL_FILE_PATH/screencapsnw"
# cleanup - remove the empty thumbs dir
rm -rf "$LOCAL_FILE_PATH/screencapsnw/thumbs/"

echo "No watermark screencaps took $(( SECONDS - START - DURATION )) seconds to run"
DURATION=$(( SECONDS - START ))
echo ""


#####################################################################
# now spin up the nginx to show the results / test video and images #
#####################################################################

if [ -z $(docker-compose ps -q mt-nginx) ] || [ -z $(docker ps -q --no-trunc | grep $(docker-compose ps -q mt-nginx)) ]; then
  echo ""
  echo "Nginx is not running so starting up..."
  docker-compose up -d mt-nginx
else
  echo ""
  echo "Nginx already running so moving to open test."
fi

TEST_URL="http://localhost:8066/web/index.html?file=$FILE_NAME_WITHOUT_EXTENSION&shoot=$SHOOT_NAME&num_screencaps=$NUM_SCREENCAPS&num_rollovers=$NUM_ROLLOVERS"

echo ""
echo "Going to open $TEST_URL"

DURATION=$(( SECONDS - START ))
echo "Total script took $DURATION seconds to run"

if [ "$(uname)" == "Darwin" ]; then
    open "$TEST_URL"
else
    FILE_LOCATION="/mnt"$(win2lin "$FILE_LOCATION")
    echo "You can now see the samples here: [$TEST_URL]"
fi
