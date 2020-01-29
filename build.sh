#!/bin/bash -e

docker_image="us.gcr.io/blyncsy/osrm-backend-k8s:1.21.7"

docker build -t "$docker_image" .