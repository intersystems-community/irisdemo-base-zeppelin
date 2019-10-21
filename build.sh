#!/bin/bash

TAG=latest
GIT_REPO_NAME=irisdemo-base-zeppelin
IMAGE_NAME=intersystemsdc/$GIT_REPO_NAME:$TAG

docker build --force-rm -t $IMAGE_NAME . 
