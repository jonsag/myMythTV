#!/bin/bash

TIME=$(date +%y%m%d-%H:%M:%S)

OUTPUT=$1

#echo "1 OUTPUT $OUTPUT"

if [ -z $OUTPUT ]; then
    echo "No output file given, exiting..."
    exit 1
fi

#echo "2 OUTPUT $OUTPUT"

PROCESSES=$(pgrep -c mythlogserver)
MAX_INSTANCES=1

if [ $PROCESSES -gt $MAX_INSTANCES ]; then
    killall mythlogserver >> $OUTPUT 2>&1
    echo "$TIME: Killed $PROCESSES mythlogserver processes, Max is set to $MAX_INSTANCES." >> $OUTPUT
else

#    PID=$(ps x | grep mythlogserver | grep -v grep | gawk '{print $1}')

    PERCENTAGE=$(ps aux | grep mythlogserver | grep -v grep | gawk '{ print $3 }')
    PERCENTAGE=${PERCENTAGE%.*}
#    PERCENTAGE=51
    MAX_PERCENTAGE=50
   
    if [ $PERCENTAGE -gt $MAX_PERCENTAGE ]; then
        killall mythlogserver  >> $OUTPUT 2>&1
        echo "$TIME: Killed mythlogserver because it was running at $PERCENTAGE % CPU usage. Max is set to $MAX_PERCENTAGE" >> $OUTPUT
    else
        echo "$TIME: Only $PROCESSES process of mythlogserver, running at $PERCENTAGE % CPU usage. Letting it continue..." >> $OUTPUT
    fi
fi
