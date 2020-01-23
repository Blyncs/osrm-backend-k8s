#!/bin/bash

if [ "$OSRM_MODE" != "CREATE" ] && [ "$OSRM_MODE" != "RESTORE" ]; then
    # Default to CREATE
    OSRM_MODE="CREATE"
fi

if [ "$FILE_MODE" != "OVERWRITE" ] && [ "$FILE_MODE" != "KEEP" ]; then
    # Default to CREATE
    FILE_MODE="KEEP"
fi

# Defaults
OSRM_DATA_PATH=${OSRM_DATA_PATH:="/osrm-data"}
OSRM_DATA_LABEL=${OSRM_DATA_LABEL:="data"}
OSRM_GRAPH_PROFILE=${OSRM_GRAPH_PROFILE:="car"}
OSRM_PBF_URL=${OSRM_PBF_URL:="http://download.geofabrik.de/asia/maldives-latest.osm.pbf"}
# Google Storage variables
OSRM_PROJECT_ID=${OSRM_PROJECT_ID:=""}
OSRM_GS_BUCKET=${OSRM_GS_BUCKET:=""}
OSRM_MAX_TABLE_SIZE=${OSRM_MAX_TABLE_SIZE:="8000"}


_sig() {
  kill -TERM $child 2>/dev/null
}
trap _sig SIGKILL SIGTERM SIGHUP SIGINT EXIT

mkdir -p $OSRM_DATA_PATH

CP_FLAG=""
if [ "$FILE_MODE" == "KEEP" ]; then
    CP_FLAG="-n"
fi

if [ "$OSRM_MODE" == "CREATE" ]; then
    
    # Retrieve the PBF file
    curl -L $OSRM_PBF_URL --create-dirs -o $OSRM_DATA_PATH/$OSRM_DATA_LABEL.osm.pbf
    
    # Build the graph
    osrm-extract $OSRM_DATA_PATH/$OSRM_DATA_LABEL.osm.pbf -p /osrm-profiles/$OSRM_GRAPH_PROFILE.lua
    osrm-contract $OSRM_DATA_PATH/$OSRM_DATA_LABEL.osrm

    if [ ! -z "$OSRM_PROJECT_ID" ] && [ ! -z "$OSRM_GS_BUCKET" ]; then
    
        # Set the Google Cloud project ID
        gcloud config set project $OSRM_PROJECT_ID

        # Copy the graph to storage
        gsutil -m cp $OSRM_DATA_PATH/*.osrm* $OSRM_GS_BUCKET/$OSRM_DATA_LABEL

    fi
    
else

    if [ ! -z "$OSRM_PROJECT_ID" ] && [ ! -z "$OSRM_GS_BUCKET" ]; then

        # Set the Google Cloud project ID
        gcloud config set project $OSRM_PROJECT_ID

        # Copy the graph from storage
        gsutil -m cp $CP_FLAG $OSRM_GS_BUCKET/$OSRM_DATA_LABEL/*.osrm* $OSRM_DATA_PATH

    fi
    
fi

# Start serving requests
osrm-routed $OSRM_DATA_PATH/$OSRM_DATA_LABEL.osrm --max-table-size $OSRM_MAX_TABLE_SIZE &
child=$!
wait "$child"
