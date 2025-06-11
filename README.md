# sprite-vtt-generator

This project contains a tool to generate spritemaps and VTT files for a given video. This is essentially just a wrapper for [mutschler/mt](https://github.com/mutschler/mt). So big thanks to [mutschler](https://github.com/mutschler) for doing the hard work!

My goal here was to have something simple that anyone could run on any machine with no crazy configuration and compiling of ffmpeg etc. and just generate screencaps, spritemaps and VTT for any given video. 

I have not had the time to make the generic, it is specific to my use case but can easily be forked and changed, the idea is that this can run on windows, mac or linux running docker, and is easy to setup on any machine. In general this is not tidy or extensible, I just open sourced in case anyone struggled to get this done quickly as I did and to share a possible easy solution.

## Project Structure

### run.sh
This is what executes the logic i.e. does the following steps:
1. Copy the video file from the specified location on your machine, to the local `./media` folder (this ensures it can be used inside docker mount)
2. Run the `mt` go command and create a spritemap and VTT file from the video
3. Use Imagemagick mogrify to lower the quality of the spritemap to 75 to make the file smaller
4. Rename the spritemap and VTT file
5. Run the `mt` go command and create 500 screencaps for the video
6. Open a webpage to allow you to view and test a screencap and the video with the spritemap / VTT.

*As mentioned in the beginning, this is custom for my needs, to make something custom for you, use this as a base and make another .sh file e.g. `custom-run.sh` and do whatever is needed in there for you*

### Dockerfile
The main docker image that will be running is simply based off of the go docker image and just downloads and installs ffmpeg and imagemagick and then the [mutschler/mt](https://github.com/mutschler/mt) go package.

### Docker compose
The docker compose is just the docker mentioned above and also an nginx server so we can view and verify the results after the screencaps have been generated 

### Web Folder
As mentioned, after the script has run and generated the spritemap, VTT and screencaps, it opens up a local webpage (using the nginx mentioned above) which embeds a player with the video which you can test the spritemps and also gives and example screencap. 

## Usage

### First Run Notice
Because you will not have the image locally, note - the first run may take quite a while, this is normal.

### How to run
To generate VTT and spritemap and screencaps for any file please run the following command (replace `~/Downloads/pb13624-2160p.mp4` with the location of the file).
Note the first argument is the file and the second argument is the shoot code, shoot code is essentially just an identifier for a video, this will be how the files are named and also the name of the directory that all the output files will be inside of.
```shell script
./run.sh FILE_NAME SHOOT_CODE
```
For example:
```shell script
./run.sh ~/Downloads/pb13624-2160p.mp4 pb13624
```
Or to run in Powershell in Windows 10:
```shell script
wsl -d ubuntu sudo .\run.sh C:\Users\tmoc\Downloads\btra17593-2160p.mp4 btra17593
```

The vtt, jpg and screencaps will use the shoot code for the filename they will output (for example) in the `./media/pb13624/` directory there would be:
```shell script
sprite/pb13624_thumbs.vtt
sprite/pb13624_sprite.jpg
screencaps/pb13624-01.jpg
screencaps/pb13624-02.jpg
screencaps/pb13624-03.jpg
...
screencaps/pb13624-500.jpg
```

#### Overriding Defaults
There are only 2 optional arguments in the run command:

| Flag | Description |
| --- | ----------- |
| `-r` | Number of rollovers |
| `-i` | The interval in seconds between caps in the spritemap / VTT |
| `-s` | The interval in seconds between the screencaps |

For example
```shell script
./run.sh -r 2 -i 60 ~/Downloads/pb13624-2160p.mp4 pb13624
```
Would give you a screencap every 2 seconds and a spritemap image every 60 seconds

*Note: these optional arguments are not validated, they are just sent straight through*

## Updating
In order to update to the latest version of the scripts and docker images you can run the following

### Updating on mac
```shell script
./update.sh
```

### Updating on windows 10
```shell script
wsl -d ubuntu sudo .\update.sh
```

### Major updates with image rebuild
There is a rare chance the base image will need to be rebuit in an update, in this case you can simply amend the `-r` option to specify to rebuild the image
#### Overriding Defaults
There are only 2 optional arguments in the run command:

| Flag | Description |
| --- | ----------- |
| `-r` | Specify to rebuild the mt-ffmpeg image |

For example in mac
```shell script
./update.sh -r
``` 

Or Windows 10:
```shell script
wsl -d ubuntu sudo .\update.sh -r
```

## Prerequisites
You must have docker installed on your machine for this to work.  

### Running on windows
This will not work in < Windows 10, you will need to of course install [Docker for Windows](https://docs.docker.com/docker-for-windows/install/), because you will then have a linux flavor installed on your machine, you should be able to run bash.

*NOTE: If you're thinking for some crazy reason, about running on windows on a mac in a VM, this will not work. You cannot run docker in a windows VM (VM in VM). I was trying to test this on Windows on my mac (as I don't use Windows) and came to this realization...*

#### Installation on WINDOWS
install docker
login to dhub
follow a few steps to install linux
launch the linux
set username: user
set password: password
change in docker desktop settings: WSL - configure to use linux

### Running on mac
Just install [Docker for Mac](https://docs.docker.com/docker-for-mac/install/) and then just run the script as instructed, that should be all.


## Troubleshooting

### File Mount Issues
If you are having trouble getting errors that the file mounts are not working, please ensure that you have checked out the code in a directory that docker has share access to i.e. check in Docker -> Preferences -> Resources -> File Sharing.

If you have checked out the code in a location that is not listed directly or is a sub-directory of a shared folder, this will not work. You can simply add the folder in here.
