#!/bin/bash

# MythMediaMonitor Version 0.07
# The latest version and information on MythMediaMonitor can
# be found at:
#       http://nowsci.com/mythmediamonitor

# Author: Benjamin Curtis

# Requires:
#       sed
#       tr
#       wget
#       grep
#       mysql
#       convert
#       mkvinfo
#       mkvextract
#       touch
#       sleep
#       ln
#       du
#       cat
#       wc

# Media formats supported:
# iso mpg mpe mpeg m1s mpa mp2 m2a mp2v m2v m2s avi mov qt asf
# asx wmv wma wmx real rm ra ram rmvb mp4 3gp ogm mkv flv

# Movie path format supported
#       */Movie Title/filename.ext

# TV path formats supported. Filenames will be searched in
# this order, and case insensitively.
#       */<title>.s##e##.*
#       */<title> - ##x##.*
#       */<title> - s##e##.*
#       */<title> - s##e##_*
#       */<title> - s##e## *
#       */<title>_s##e##_*
#       */<title>.s##e#.*
#       */<title>_s##e#_*
#       */<title>.s#e##.*
#       */<title>_s#e##_*
#       */<title>.s#e#.*
#       */<title>_s#e#_*
#       */<title>.s##.e##.*
#       */<title>_s##_e##_*
#       */<title>.s##.e#.*
#       */<title>_s##_e#_*
#       */<title>.s#.e##.*
#       */<title>_s#_e##_*
#       */<title>.s#.e#.*
#       */<title>_s#_e#_*
#       */<title>.###.*
#       */<title>_###_*
#       */<title>.####.*
#       */<title>_####_*
#       */<title>.##.##.*
#       */<title>_##_##_*
#       */<title>.##x##.*
#       */<title>_##x##_*
#       */<title>.#x##.*
#       */<title>_#x##_*
#       */<title>.##x#.*
#       */<title>_##x#_*
#       */<title>.#x#.*
#       */<title>_#x#_*

# Options
# ---------------------------------------------------------------

# Here you will need to enter your mysql credentials
MYSQLUSER="mythtv"
MYSQLPASS="mythconverg"
MYSQLDB="mythconverg"

# Directory to store data files. Do not use a trailing slash.
# This directory must be writeable by the user you run this
# script with.
DATADIR="/home/mythtv/.mythtv/mythmediamonitor"

# Directory where your TV files are stored. Do not use a trailing
# slash.
TVDIR="/home/mythtv/iomega1"

# Whether or not to search movies
INSERTMOVIES=false

# Directory where your movie files are stored. Do not use a
# trailing slash.
MOVIEDIR="/home/mythtv/videos/Movies"

# Recordings directory and group as configured in Myth. Do not
# use a trailing slash. This will be used to create a
# symlink to your movie and TV files
RECORDINGDIR="/home/mythtv/standard"
RECORDINGGROUP="Default"

# Set this to a valid chanid value from the channels table.
# All recordings will appear as if coming from this channel.
# This is a requirement as of MythTV 0.23
CHANID=1006;

# Select the subtitle language that you would like to strip out
# of mkv files into srt files for MythTV's internal player.
RIPSUBS=true
SUBLANG="swe"


# DEBUG Options
# ---------------------------------------------------------------

# Set RUN to true or false.  Enabling this will insert into the
# database.  Use false for testing.
RUN=true;

# Set DEBUG true to see debug messages printed out
DEBUG=false;


# DO NOT EDIT BELOW THIS LINE
# ---------------------------------------------------------------

# Call as insertShow TITLE SEASON EPISODE FILENAME FILEPAT
function insertShow {
        TITLE="";
        SEASON="";
        EPISODE="";
        FILEPATH=`echo "$1" |sed 's/%20/ /g'`
        FILENAME=${FILEPATH##*/}
        NOTFOUND=true
        # Time to find the season and episode numbers
        # *.s##e##.*
        if $NOTFOUND; then
                if [[ "$FILENAME" =~ [\.\_][sS][0-9][0-9][eE][0-9][0-9][\.\_] ]]; then
                        TITLE=`echo "${FILENAME%${BASH_REMATCH[0]}*}" |sed 's/[\.\_]/ /g'`
                        [[ "$FILENAME" =~ [sS][0-9][0-9] ]]
                        [[ "${BASH_REMATCH[0]}" =~ [0-9][0-9] ]]
                        SEASON="${BASH_REMATCH[0]}"
                        [[ "$FILENAME" =~ [eE][0-9][0-9] ]]
                        [[ "${BASH_REMATCH[0]}" =~ [0-9][0-9] ]]
                        EPISODE="${BASH_REMATCH[0]}"
                        NOTFOUND=false;
                fi;
        fi;
        # * - ##x##.*
        if $NOTFOUND; then
                if [[ "$FILENAME" =~ [\ ][\-][\ ][0-9][0-9][xX][0-9][0-9][\.\_\ ] ]]; then
                        TITLE=`echo "${FILENAME%${BASH_REMATCH[0]}*}" |sed 's/[\.\_]/ /g'`
                        [[ "$FILENAME" =~ [0-9][0-9][xX] ]]
                        [[ "${BASH_REMATCH[0]}" =~ [0-9][0-9] ]]
                        SEASON="${BASH_REMATCH[0]}"
                        [[ "$FILENAME" =~ [xX][0-9][0-9] ]]
                        [[ "${BASH_REMATCH[0]}" =~ [0-9][0-9] ]]
                        EPISODE="${BASH_REMATCH[0]}"
                        NOTFOUND=false;
                fi;
        fi;
        # * - s##e##.*
        if $NOTFOUND; then
                if [[ "$FILENAME" =~ [\ ][\-][\ ][sS][0-9][0-9][eE][0-9][0-9][\.\_\ ] ]]; then
                        TITLE=`echo "${FILENAME%${BASH_REMATCH[0]}*}" |sed 's/[\.\_]/ /g'`
                        [[ "$FILENAME" =~ [sS][0-9][0-9] ]]
                        [[ "${BASH_REMATCH[0]}" =~ [0-9][0-9] ]]
                        SEASON="${BASH_REMATCH[0]}"
                        [[ "$FILENAME" =~ [eE][0-9][0-9] ]]
                        [[ "${BASH_REMATCH[0]}" =~ [0-9][0-9] ]]
                        EPISODE="${BASH_REMATCH[0]}"
                        NOTFOUND=false;
                fi;
        fi;
        # *.s##e#.*
        if $NOTFOUND; then
                if [[ "$FILENAME" =~ [\.\_][sS][0-9][0-9][eE][0-9][\.\_] ]]; then
                        TITLE=`echo "${FILENAME%${BASH_REMATCH[0]}*}" |sed 's/[\.\_]/ /g'`
                        [[ "$FILENAME" =~ [sS][0-9][0-9] ]]
                        [[ "${BASH_REMATCH[0]}" =~ [0-9][0-9] ]]
                        SEASON="${BASH_REMATCH[0]}"
                        [[ "$FILENAME" =~ [eE][0-9] ]]
                        [[ "${BASH_REMATCH[0]}" =~ [0-9] ]]
                        EPISODE="0${BASH_REMATCH[0]}"
                        NOTFOUND=false;
                fi;
        fi;
        # *.s#e##.*
        if $NOTFOUND; then
                if [[ "$FILENAME" =~ [\.\_][sS][0-9][eE][0-9][0-9][\.\_] ]]; then
                        TITLE=`echo "${FILENAME%${BASH_REMATCH[0]}*}" |sed 's/[\.\_]/ /g'`
                        [[ "$FILENAME" =~ [sS][0-9] ]]
                        [[ "${BASH_REMATCH[0]}" =~ [0-9] ]]
                        SEASON="0${BASH_REMATCH[0]}"
                        [[ "$FILENAME" =~ [eE][0-9][0-9] ]]
                        [[ "${BASH_REMATCH[0]}" =~ [0-9][0-9] ]]
                        EPISODE="${BASH_REMATCH[0]}"
                        NOTFOUND=false;
                fi;
        fi;
        # *.s#e#.*
        if $NOTFOUND; then
                if [[ "$FILENAME" =~ [\.\_][sS][0-9][eE][0-9][\.\_] ]]; then
                        TITLE=`echo "${FILENAME%${BASH_REMATCH[0]}*}" |sed 's/[\.\_]/ /g'`
                        [[ "$FILENAME" =~ [sS][0-9] ]]
                        [[ "${BASH_REMATCH[0]}" =~ [0-9] ]]
                        SEASON="0${BASH_REMATCH[0]}"
                        [[ "$FILENAME" =~ [eE][0-9] ]]
                        [[ "${BASH_REMATCH[0]}" =~ [0-9] ]]
                        EPISODE="0${BASH_REMATCH[0]}"
                        NOTFOUND=false;
                fi;
        fi;
        # *.s##.e##.*
        if $NOTFOUND; then
                if [[ "$FILENAME" =~ [\.\_][sS][0-9][0-9][\.\_][eE][0-9][0-9][\.\_] ]]; then
                        TITLE=`echo "${FILENAME%${BASH_REMATCH[0]}*}" |sed 's/[\.\_]/ /g'`
                        [[ "$FILENAME" =~ [sS][0-9][0-9] ]]
                        [[ "${BASH_REMATCH[0]}" =~ [0-9][0-9] ]]
                        SEASON="${BASH_REMATCH[0]}"
                        [[ "$FILENAME" =~ [eE][0-9][0-9] ]]
                        [[ "${BASH_REMATCH[0]}" =~ [0-9][0-9] ]]
                        EPISODE="${BASH_REMATCH[0]}"
                        NOTFOUND=false;
                fi;
        fi;
        # *.s##.e#.*
        if $NOTFOUND; then
                if [[ "$FILENAME" =~ [\.\_][sS][0-9][0-9].[eE][0-9][\.\_] ]]; then
                        TITLE=`echo "${FILENAME%${BASH_REMATCH[0]}*}" |sed 's/[\.\_]/ /g'`
                        [[ "$FILENAME" =~ [sS][0-9][0-9] ]]
                        [[ "${BASH_REMATCH[0]}" =~ [0-9][0-9] ]]
                        SEASON="${BASH_REMATCH[0]}"
                        [[ "$FILENAME" =~ [eE][0-9] ]]
                        [[ "${BASH_REMATCH[0]}" =~ [0-9] ]]
                        EPISODE="0${BASH_REMATCH[0]}"
                        NOTFOUND=false;
                fi;
        fi;
        # *.s#.e##.*
        if $NOTFOUND; then
                if [[ "$FILENAME" =~ [\.\_][sS][0-9][\.\_][eE][0-9][0-9][\.\_] ]]; then
                        TITLE=`echo "${FILENAME%${BASH_REMATCH[0]}*}" |sed 's/[\.\_]/ /g'`
                        [[ "$FILENAME" =~ [sS][0-9] ]]
                        [[ "${BASH_REMATCH[0]}" =~ [0-9] ]]
                        SEASON="0${BASH_REMATCH[0]}"
                        [[ "$FILENAME" =~ [eE][0-9][0-9] ]]
                        [[ "${BASH_REMATCH[0]}" =~ [0-9][0-9] ]]
                        EPISODE="${BASH_REMATCH[0]}"
                        NOTFOUND=false;
                fi;
        fi;
        # *.s#.e#.*
        if $NOTFOUND; then
                if [[ "$FILENAME" =~ [\.\_][sS][0-9][\.\_][eE][0-9][\.\_] ]]; then
                        TITLE=`echo "${FILENAME%${BASH_REMATCH[0]}*}" |sed 's/[\.\_]/ /g'`
                        [[ "$FILENAME" =~ [sS][0-9] ]]
                        [[ "${BASH_REMATCH[0]}" =~ [0-9] ]]
                        SEASON="0${BASH_REMATCH[0]}"
                        [[ "$FILENAME" =~ [eE][0-9] ]]
                        [[ "${BASH_REMATCH[0]}" =~ [0-9] ]]
                        EPISODE="0${BASH_REMATCH[0]}"
                        NOTFOUND=false;
                fi;
        fi;
        # *.###.*
        if $NOTFOUND; then
                if [[ "$FILENAME" =~ [\.\_][0-9][0-9][0-9][\.\_] ]]; then
                        TITLE=`echo "${FILENAME%${BASH_REMATCH[0]}*}" |sed 's/[\.\_]/ /g'`
                        [[ "$FILENAME" =~ [\.\_][0-9] ]]
                        [[ "${BASH_REMATCH[0]}" =~ [0-9] ]]
                        SEASON="0${BASH_REMATCH[0]}"
                        [[ "$FILENAME" =~ [0-9][0-9][\.\_] ]]
                        [[ "${BASH_REMATCH[0]}" =~ [0-9][0-9] ]]
                        EPISODE="${BASH_REMATCH[0]}"
                        NOTFOUND=false;
                fi;
        fi;
        # *.####.*
        if $NOTFOUND; then
                if [[ "$FILENAME" =~ [\.\_][0-9][0-9][0-9][0-9][\.\_] ]]; then
                        TITLE=`echo "${FILENAME%${BASH_REMATCH[0]}*}" |sed 's/[\.\_]/ /g'`
                        [[ "$FILENAME" =~ [\.\_][0-9][0-9] ]]
                        [[ "${BASH_REMATCH[0]}" =~ [0-9][0-9] ]]
                        SEASON="${BASH_REMATCH[0]}"
                        [[ "$FILENAME" =~ [0-9][0-9][\.\_] ]]
                        [[ "${BASH_REMATCH[0]}" =~ [0-9][0-9] ]]
                        EPISODE="${BASH_REMATCH[0]}"
                        NOTFOUND=false;
                fi;
        fi;
        # *.##.##.*
        if $NOTFOUND; then
                if [[ "$FILENAME" =~ [\.\_][0-9][0-9][\.\_][0-9][0-9][\.\_] ]]; then
                        TITLE=`echo "${FILENAME%${BASH_REMATCH[0]}*}" |sed 's/[\.\_]/ /g'`
                        [[ "$FILENAME" =~ [\.\_][0-9][0-9][\.\_][0-9] ]]
                        [[ "${BASH_REMATCH[0]}" =~ [0-9][0-9] ]]
                        SEASON="${BASH_REMATCH[0]}"
                        [[ "$FILENAME" =~ [0-9][\.\_][0-9][0-9][\.\_] ]]
                        [[ "${BASH_REMATCH[0]}" =~ [0-9][0-9] ]]
                        EPISODE="${BASH_REMATCH[0]}"
                        NOTFOUND=false;
                fi;
        fi;
        # *.##x##.*
        if $NOTFOUND; then
                if [[ "$FILENAME" =~ [\.\_][0-9][0-9][x][0-9][0-9][\.\_] ]]; then
                        TITLE=`echo "${FILENAME%${BASH_REMATCH[0]}*}" |sed 's/[\.\_]/ /g'`
                        [[ "$FILENAME" =~ [\.\_][0-9][0-9][x][0-9] ]]
                        [[ "${BASH_REMATCH[0]}" =~ [0-9][0-9] ]]
                        SEASON="${BASH_REMATCH[0]}"
                        [[ "$FILENAME" =~ [0-9][x][0-9][0-9][\.\_] ]]
                        [[ "${BASH_REMATCH[0]}" =~ [0-9][0-9] ]]
                        EPISODE="${BASH_REMATCH[0]}"
                        NOTFOUND=false;
                fi;
        fi;
        # *.#x##.*
        if $NOTFOUND; then
                if [[ "$FILENAME" =~ [\.\_][0-9][x][0-9][0-9][\.\_] ]]; then
                        TITLE=`echo "${FILENAME%${BASH_REMATCH[0]}*}" |sed 's/[\.\_]/ /g'`
                        [[ "$FILENAME" =~ [\.\_][0-9][x][0-9][0-9] ]]
                        [[ "${BASH_REMATCH[0]}" =~ [0-9] ]]
                        SEASON="0${BASH_REMATCH[0]}"
                        [[ "$FILENAME" =~ [0-9][x][0-9][0-9][\.\_] ]]
                        [[ "${BASH_REMATCH[0]}" =~ [0-9][0-9] ]]
                        EPISODE="${BASH_REMATCH[0]}"
                        NOTFOUND=false;
                fi;
        fi;
        # *.##x#.*
        if $NOTFOUND; then
                if [[ "$FILENAME" =~ [\.\_][0-9][0-9][x][0-9][\.\_] ]]; then
                        TITLE=`echo "${FILENAME%${BASH_REMATCH[0]}*}" |sed 's/[\.\_]/ /g'`
                        [[ "$FILENAME" =~ [\.\_][0-9][0-9][x][0-9] ]]
                        [[ "${BASH_REMATCH[0]}" =~ [0-9][0-9] ]]
                        SEASON="${BASH_REMATCH[0]}"
                        [[ "$FILENAME" =~ [x][0-9][\.\_] ]]
                        [[ "${BASH_REMATCH[0]}" =~ [0-9] ]]
                        EPISODE="0${BASH_REMATCH[0]}"
                        NOTFOUND=false;
                fi;
        fi;
        # *.#x#.*
        if $NOTFOUND; then
                if [[ "$FILENAME" =~ [\.\_][0-9][x][0-9][\.\_] ]]; then
                        TITLE=`echo "${FILENAME%${BASH_REMATCH[0]}*}" |sed 's/[\.\_]/ /g'`
                        [[ "$FILENAME" =~ [\.\_][0-9][x] ]]
                        [[ "${BASH_REMATCH[0]}" =~ [0-9] ]]
                        SEASON="0${BASH_REMATCH[0]}"
                        [[ "$FILENAME" =~ [x][0-9][\.\_] ]]
                        [[ "${BASH_REMATCH[0]}" =~ [0-9] ]]
                        EPISODE="0${BASH_REMATCH[0]}"
                        NOTFOUND=false;
                fi;
        fi;
        SQL="select * from recorded where basename='`echo $FILENAME |sed "s/'/\\\\\'/g"`';"
        SEARCHRESULT=`echo "$SQL" | mysql $MYSQLOPTS`
        if [ "$SEARCHRESULT" = "" ]; then
                RANDOM_VAR=`echo "${FILENAME}" | sed 's/ //g'`
                SHOWDATAFILE="${DATADIR}/showData_${RANDOM_VAR}.tmp"
                if [ ! -f "${SHOWDATAFILE}" ]; then
                        wget -q -O "${SHOWDATAFILE}" "http://services.tvrage.com/tools/quickinfo.php?show=${TITLE}&ep=${SEASON}x${EPISODE}";
                        if $DEBUG; then echo "wget -q -O \"${SHOWDATAFILE}\" \"http://services.tvrage.com/tools/quickinfo.php?show=${TITLE}&ep=${SEASON}x${EPISODE}\""; fi;
                fi;
                HTML=`grep -i "No Show Results Were Found For" ${SHOWDATAFILE}`;
                if test -z "$HTML"; then
                        HTML=`grep -i "Show Name" ${SHOWDATAFILE}`;
                        TITLE=${HTML##*\@};
                        HTML=`grep -i "Episode Info" ${SHOWDATAFILE}`;
                        SUBTITLE=${HTML##*[0-9][0-9][x][0-9][0-9]\^};SUBTITLE=${SUBTITLE%%\^*}
                        DESC="S${SEASON}E${EPISODE}: ${FILENAME}";
                        HTML=`grep -i "Episode Info" ${SHOWDATAFILE}`;
                        [[ "$HTML" =~ [0-9][0-9]/[a-zA-Z][a-zA-Z][a-zA-Z]/[0-9][0-9][0-9][0-9] ]]; AIRDATE="${BASH_REMATCH[0]}";
                        [[ "$AIRDATE" =~ [0-9][0-9] ]]; DAY="${BASH_REMATCH[0]}";
                        [[ "$AIRDATE" =~ [a-zA-Z][a-zA-Z][a-zA-Z] ]]; MONTHTEXT="${BASH_REMATCH[0]}";
                        [[ "$AIRDATE" =~ [0-9][0-9][0-9][0-9] ]]; YEAR="${BASH_REMATCH[0]}";
                        case "$MONTHTEXT" in
                                Jan)
                                        MONTH="01";;
                                Feb)
                                        MONTH="02";;
                                Mar)
                                        MONTH="03";;
                                Apr)
                                        MONTH="04";;
                                May)
                                        MONTH="05";;
                                Jun)
                                        MONTH="06";;
                                Jul)
                                        MONTH="07";;
                                Aug)
                                        MONTH="08";;
                                Sep)
                                        MONTH="09";;
                                Oct)
                                        MONTH="10";;
                                Nov)
                                        MONTH="11";;
                                Dec)
                                        MONTH="12";;
                        esac;
                        AIRDATE="${YEAR}-${MONTH}-${DAY}"
                else
                        TITLE="Unknown"
                        SUBTITLE="Unknown"
                        DESC="${FILENAME}"
                        AIRDATE=`date +%F`;
                fi;
                FILESIZE=`du -b "$FILEPATH" |awk '{print $1}'`
                echo "Inserting: $FILENAME...";
                if test -z "$TITLE"; then
                        TITLE="$FILENAME";
                fi;
                SQL="insert into recorded (commflagged,filesize,title,subtitle,description,basename,storagegroup,starttime,endtime,originalairdate,progstart,progend,chanid) values"
                SQL="$SQL (3,$FILESIZE,'`echo $TITLE |sed "s/'/\\\\\'/g"`','`echo $SUBTITLE |sed "s/'/\\\\\'/g"`','`echo $DESC |sed "s/'/\\\\\'/g"`','`echo mmm.tv.$FILENAME |sed "s/'/\\\\\'/g"`','$RECORDINGGROUP',NOW(),NOW(),'$AIRDATE',NOW(),NOW(),$CHANID);"
                # Insert and Link
                if $DEBUG; then echo "ln -s \"$FILEPATH\" \"$RECORDINGDIR/mmm.tv.$FILENAME\""; fi;
                if $DEBUG; then echo "echo \"$SQL\" | mysql $MYSQLOPTS"; fi;
                if $DEBUG; then echo "sleep 5;"; fi;
                if $RUN; then
                        ln -s "$FILEPATH" "$RECORDINGDIR/mmm.tv.$FILENAME"
                        echo "$SQL" | mysql $MYSQLOPTS
                        echo "Sleeping 5...";
                        sleep 5;
                fi;
        else
                echo "Already in Database: $FILENAME";
        fi;
}

# Call as insertMovie FILEPATH
function insertMovie {
        FILEPATH=`echo "$1" |sed 's/%20/ /g'`
        DIRECTORY=${FILEPATH%/*}
        PLOT="";
        FILENAME=${FILEPATH##*/}
        TITLE=${FILEPATH%/*};TITLE=${TITLE##*/}
        # For future VIDEO_TS DVD Support
        #DVD=`echo $FILENAME |tr a-z A-Z`
        #if [[ "$DVD" = "VIDEO_TS" ]]; then
                #FILENAME="${TITLE}.dvd"
                #DVD=true;
        #else
                #DVD=false;
        #fi;
        COUNT=0
        SQL="select * from recorded where basename='`echo $FILENAME |sed "s/'/\\\\\'/g"`';"
        SEARCHRESULT=`echo "$SQL" | mysql $MYSQLOPTS`
        if [ "$SEARCHRESULT" = "" ]; then
                wget -q -O ${DATADIR}/movieData.tmp "http://www.deanclatworthy.com/imdb/?q=${TITLE}&type=text&token=94";
                RESULTS=`cat ${DATADIR}/movieData.tmp`
                RESULTS="^${RESULTS}";
                REALPAGE=${RESULTS#*^imdburl|};REALPAGE=${REALPAGE%%^*}
                wget -q -O ${DATADIR}/movieData.tmp "$REALPAGE"
                ##SEARCHTITLE=`echo "$TITLE" |sed 's/ /\+/g'`
                ##wget -q -O ${DATADIR}/movieData.tmp "http://www.imdb.com/find?s=tt&q=$SEARCHTITLE"
                ### Is this a movie page or a results page?
                ##RESULTS=`grep "Media from" ${DATADIR}/movieData.tmp`
                ##if test -n "$RESULTS"; then
                        ### It is a results page, so lets select the top result (link 46)
                        ###REALPAGE=${RESULTS##*href=\"};REALPAGE=${REALPAGE%\" on*}
                        ###REALPAGE=${RESULTS##*link=};REALPAGE=${REALPAGE%\'\;\"}
                        ##RESULTS=`perl -pe 's/link=/\r\nlink=/g' ${DATADIR}/movieData.tmp |grep 'link=' |grep -i "$SEARCHTITLE"`
                        ##REALPAGE=${RESULTS#*link=};REALPAGE=${REALPAGE%%\'*}
                        ##wget -q -O ${DATADIR}/movieData.tmp "http://www.imdb.com$REALPAGE"
                ##fi;

                #PLOT=`grep -A 1 "Plot:" ${DATADIR}/movieData.tmp`;
                #PLOT=`echo $PLOT |sed -e 's/<[^>]*>//g'`
                #PLOT=${PLOT##*Plot: };PLOT=${PLOT% full summary*}

                PLOT=`grep -A 2 "<h2>Storyline" ${DATADIR}/movieData.tmp`;
                PLOT=${PLOT#*<p>};
                PLOT=`echo $PLOT |sed -e 's/<[^>]*>//g'`
                if test -z "$PLOT"; then
                        PLOT="Not found in IMDB.";
                fi;
                PLOT=`echo $PLOT |sed 's/^ //g'`;
                #IMG=`grep "primary-photo" ${DATADIR}/movieData.tmp`
                #IMG=${IMG##*src=\"};IMG=${IMG%\"*}
                #IMG=`echo $IMG |sed 's/SX[0-9][0-9][0-9]/SX500/g;s/SY[0-9][0-9][0-9]/SY500/g'`
                rm ${DATADIR}/movieData.tmp
                CD1=`echo "$FILENAME" |grep -i "cd1"`;
                if test -n "$CD1"; then
                        TITLE="$TITLE (CD1)";
                fi;
                CD2=`echo "$FILENAME" |grep -i "cd2"`;
                if test -n "$CD2"; then
                        TITLE="$TITLE (CD2)";
                fi;
                FILESIZE=`du -b "$FILEPATH" |awk '{print $1}'`
                echo "Inserting $FILENAME...";
                SQL="insert into recorded (commflagged,filesize,title,subtitle,description,basename,storagegroup,starttime,endtime,originalairdate,progstart,progend,chanid) values"
                SQL="$SQL (3,$FILESIZE,'Movies','`echo $TITLE |sed "s/'/\\\\\'/g"`','`echo $PLOT |sed "s/'/\\\\\'/g"`','`echo mmm.movies.$FILENAME |sed "s/'/\\\\\'/g"`','$RECORDINGGROUP',NOW(),NOW(),NOW(),NOW(),NOW(),$CHANID);"
                if $DEBUG; then echo "echo \"$SQL\" | mysql $MYSQLOPTS"; fi;
                if $DEBUG; then echo "ln -s \"$FILEPATH\" \"$RECORDINGDIR/mmm.movies.$FILENAME\""; fi;
                if [ -n "$IMG" ]; then
                        if $DEBUG; then echo "wget -O \"$DIRECTORY/$FILENAME.jpg\" \"$IMG\""; fi;
                        if $DEBUG; then echo "convert \"$DIRECTORY/$FILENAME.jpg\" \"$DIRECTORY/$FILENAME.png\""; fi;
                        if $DEBUG; then echo "rm \"$DIRECTORY/$FILENAME.jpg\""; fi;
                        if $DEBUG; then echo "ln -s \"$DIRECTORY/$FILENAME.png\" \"$RECORDINGDIR/mmm.movies.$FILENAME.png\""; fi;
                fi;
                if $DEBUG; then echo "sleep 5;"; fi;
                # Insert and Link
                if $RUN; then
                        echo "$SQL" | mysql $MYSQLOPTS
                        ln -s "$FILEPATH" "$RECORDINGDIR/mmm.movies.$FILENAME"
                        if [ -n "$IMG" ]; then
                                wget -O "$DIRECTORY/$FILENAME.jpg" "$IMG"
                                convert "$DIRECTORY/$FILENAME.jpg" "$DIRECTORY/$FILENAME.png"
                                rm "$DIRECTORY/$FILENAME.jpg"
                                ln -s "$DIRECTORY/$FILENAME.png" "$RECORDINGDIR/mmm.movies.$FILENAME.png"
                        fi;
                        addSubtitles "$FILEPATH";
                        echo "Sleeping 5...";
                        sleep 5;
                fi;
        else
                echo "Already in Database: $FILENAME";
        fi;
}

function findShows {
                NEWSHOWLIST=`find ${TVDIR} |grep -iv 'sample\.' |grep -iv '_UNPACK_' |grep -i '\.iso$\|\.mpg$\|\.mpe$\|\.mpeg$\|\.m1s$\|\.mpa$\|\.mp2$\|\.m2a$\|\.mp2v$\|\.m2v$\|\.m2s$\|\.avi$\|\.mov$\|\.qt$\|\.asf$\|\.asx$\|\.wmv$\|\.wma|\.wmx$\|\.real$\|\.rm$\|\.ra$\|\.ram$\|\.rmvb$\|\.mp4$\|\.3gp$\|\.flv$\|\.ogm$\|\.mkv$' |sed 's/ /\%20/g'`
                SQL="select basename from recorded where basename like 'mmm.tv.%';";
                SHOWLIST=`echo "$SQL" | mysql $MYSQLOPTS -N |sed 's/ /\%20/g'`;
                INSERTED=false
                for N in $NEWSHOWLIST; do
                        F=false
                        N2=${N##*/}
                        for S in $SHOWLIST; do
                                if [ "$S" == "mmm.tv.$N2" ]; then
                                        F=true
                                        break;
                                fi;
                        done;
                        if ! $F; then
                                insertShow "$N"
                                INSERTED=true
                        fi;
                done;
                if $INSERTED; then
                        rm "${DATADIR}/showData_"*
                fi
}

function findMovies {
                NEWMOVIELIST=`find ${MOVIEDIR} |grep -iv 'sample\.' |grep -iv '_UNPACK_' |grep -i '\.iso$\|\.mpg$\|\.mpe$\|\.mpeg$\|\.m1s$\|\.mpa$\|\.mp2$\|\.m2a$\|\.mp2v$\|\.m2v$\|\.m2s$\|\.avi$\|\.mov$\|\.qt$\|\.asf$\|\.asx$\|\.wmv$\|\.wma|\.wmx$\|\.real$\|\.rm$\|\.ra$\|\.ram$\|\.rmvb$\|\.mp4$\|\.3gp$\|\.flv$\|\.ogm$\|\.mkv$' |sed 's/ /\%20/g'`
                SQL="select basename from recorded where basename like 'mmm.movies.%';";
                MOVIELIST=`echo "$SQL" | mysql $MYSQLOPTS -N |sed 's/ /\%20/g'`;
                INSERTED=false
                for N in $NEWMOVIELIST; do
                        F=false
                        N2=${N##*/}
                        for M in $MOVIELIST; do
                                if [ "$M" == "mmm.movies.$N2" ]; then
                                        F=true
                                        break;
                                fi;
                        done;
                        if ! $F; then
                                insertMovie "$N"
                                INSERTED=true
                        fi;
                done;
                if $INSERTED; then
                        sortMovies;
                        ripSubtitles;
                fi
}

function findMoviesOLD {
        if ! test -a ${DATADIR}/movieList.tmp; then
                # This is the first run
                MOVIELIST=`find ${MOVIEDIR} |grep -iv 'sample\.' |grep -iv '_UNPACK_' |grep -i '\.iso$\|\.mpg$\|\.mpe$\|\.mpeg$\|\.m1s$\|\.mpa$\|\.mp2$\|\.m2a$\|\.mp2v$\|\.m2v$\|\.m2s$\|\.avi$\|\.mov$\|\.qt$\|\.asf$\|\.asx$\|\.wmv$\|\.wma|\.wmx$\|\.real$\|\.rm$\|\.ra$\|\.ram$\|\.rmvb$\|\.mp4$\|\.3gp$\|\.flv$\|\.ogm$\|\.mkv$' |sed 's/ /\%20/g'`
                # For future VIDEO_TS DVD support
                #MOVIELIST=`find ${MOVIEDIR} |grep -v 'sample\.' |grep -i 'VIDEO_TS$\|\.iso\|\.mpg\|\.mpe\|\.mpeg\|\.m1s\|\.mpa\|\.mp2\|\.m2a\|\.mp2v\|\.m2v\|\.m2s\|\.avi\|\.mov\|\.qt\|\.asf\|\.asx\|\.wmv\|\.wma|\.wmx\|\.real\|\.rm\|\.ra\|\.ram\|\.rmvb\|\.mp4\|\.3gp\|\.flv\|\.ogm\|\.mkv' |sed 's/ /\%20/g'`
                echo "Creating ${DATADIR}/movieList.tmp";
                if $DEBUG; then echo "echo \"$MOVIELIST\" > ${DATADIR}/movieList.tmp"; fi;
                if $RUN; then
                        echo "$MOVIELIST" > ${DATADIR}/movieList.tmp
                fi
                for FILEPATH in $MOVIELIST; do
                        insertMovie "$FILEPATH"
                done;
                sortMovies;
                ripSubtitles;
        else
                # Check for changes
                NEWMOVIELIST=`find ${MOVIEDIR} |grep -iv 'sample\.' |grep -iv '_UNPACK_' |grep -i '\.iso$\|\.mpg$\|\.mpe$\|\.mpeg$\|\.m1s$\|\.mpa$\|\.mp2$\|\.m2a$\|\.mp2v$\|\.m2v$\|\.m2s$\|\.avi$\|\.mov$\|\.qt$\|\.asf$\|\.asx$\|\.wmv$\|\.wma|\.wmx$\|\.real$\|\.rm$\|\.ra$\|\.ram$\|\.rmvb$\|\.mp4$\|\.3gp$\|\.flv$\|\.ogm$\|\.mkv$' |sed 's/ /\%20/g'`
                # For future VIDEO_TS DVD support
                #NEWMOVIELIST=`find ${MOVIEDIR} |grep -v 'sample\.' |grep -i 'VIDEO_TS$\|\.iso\|\.mpg\|\.mpe\|\.mpeg\|\.m1s\|\.mpa\|\.mp2\|\.m2a\|\.mp2v\|\.m2v\|\.m2s\|\.avi\|\.mov\|\.qt\|\.asf\|\.asx\|\.wmv\|\.wma|\.wmx\|\.real\|\.rm\|\.ra\|\.ram\|\.rmvb\|\.mp4\|\.3gp\|\.flv\|\.ogm\|\.mkv' |sed 's/ /\%20/g'`
                NEWMOVIELIST=`echo "$NEWMOVIELIST"`
                if [ "$MOVIELIST" != "$NEWMOVIELIST" ]; then
                        DIFFERENCE=`diff <(echo "$MOVIELIST" |sed 's/ /\n/g') <(echo "$NEWMOVIELIST" |sed 's/ /\n/g') |sed 's/ /%20/g'`;
                        # Difference is now the list of movies that are removed or added
                        # > means add the movie, < means it was removed.
                        if test -n "$DIFFERENCE"; then
                                for FILEPATH in $DIFFERENCE; do
                                        if [[ $FILEPATH == \>* ]]; then
                                                FILEPATH=`echo "$FILEPATH" |sed 's/>%20//g'`
                                                insertMovie "$FILEPATH"
                                        fi;
                                done;
                                # Update movieList
                                echo "Replacing ${DATADIR}/movieList.tmp";
                                if $DEBUG; then echo "echo \"$NEWMOVIELIST\" > ${DATADIR}/movieList.tmp"; fi;
                                if $RUN; then
                                        echo "$NEWMOVIELIST" > ${DATADIR}/movieList.tmp
                                fi;
                                sortMovies;
                                ripSubtitles;
                        fi;
                fi;
        fi;
}

function checkReqs {
        if [ ! `which grep` ]; then
                echo "Missing dependency: grep'";
        fi;
        if [ ! `which sed` ]; then
                echo "Missing dependency: sed'";
        fi;
        if [ ! `which tr` ]; then
                echo "Missing dependency: tr'";
        fi;
        if [ ! `which wget` ]; then
                echo "Missing dependency: wget'";
        fi;
        if [ ! `which mysql` ]; then
                echo "Missing dependency: mysql'";
        fi;
        if [ ! `which convert` ]; then
                echo "Missing dependency: convert'";
        fi;
        if [ ! `which mkvinfo` ]; then
                echo "Missing dependency: mkvinfo'";
        fi;
        if [ ! `which mkvextract` ]; then
                echo "Missing dependency: mkvextract'";
        fi;
        if [ ! `which touch` ]; then
                echo "Missing dependency: touch'";
        fi;
        if [ ! `which sleep` ]; then
                echo "Missing dependency: sleep'";
        fi;
        if [ ! `which ln` ]; then
                echo "Missing dependency: ln'";
        fi;
        if [ ! `which du` ]; then
                echo "Missing dependency: du'";
        fi;
        if [ ! `which awk` ]; then
                echo "Missing dependency: awk'";
        fi;
        if [ ! `which wc` ]; then
                echo "Missing dependency: wc'";
        fi;
        if [ ! `which cat` ]; then
                echo "Missing dependency: cat'";
        fi;
}

function sortMovies {
        if $DEBUG; then echo "Using dates to sort movies alphabetically, watched last..."; fi;
        SQL="select \"update recorded set starttime=NOW() - INTERVAL @C DAY,endtime=NOW() - INTERVAL @C DAY,progstart=NOW() - INTERVAL @C DAY,progend=NOW() - INTERVAL @C DAY"
        SQL="$SQL where title='Movies' and basename=\",quote(basename),\" and starttime=\",quote(starttime),\";set @C=@C+1;\" from recorded where title='Movies' order by watched,subtitle";
        echo "set @C=300;" > ${DATADIR}/movieQuery.tmp
        echo "$SQL" | mysql $MYSQLOPTS |sed 's/\t//g' |sed 1d |sed "s/\\\\\\\'/\\\'/g" >> ${DATADIR}/movieQuery.tmp
        if $DEBUG; then echo "mysql $MYSQLOPTS < ${DATADIR}/movieQuery.tmp"; fi;
        if $DEBUG; then echo "sleep 5"; fi;
        if $DEBUG; then echo "touch \"$RECORDINGDIR/mmm.movies.\"*"; fi;
        if $RUN; then
                mysql $MYSQLOPTS < ${DATADIR}/movieQuery.tmp
                sleep 5;
                touch "$RECORDINGDIR/mmm.movies."*
        fi;
        rm ${DATADIR}/movieQuery.tmp
}

function ripSubtitles {
        if $RIPSUBS; then
                echo "Ripping subtitiles..."
                for F in $SUBLIST; do
                        F=`echo $F |sed 's/%20/ /g'`
                        FILEPATH=`echo "${F%/*}"`
                        FILENAME=`echo "${F##*/}"`
                        EXTENSION=`echo "${FILENAME##*.}" |tr a-z A-Z`
                        FILENAME=`echo "${FILENAME%.*}"`
                        SRTFILE="${FILEPATH}/${FILENAME}.srt";
                        if [[ "$EXTENSION" = "MKV" ]]; then
                                if [[ ! -a "$SRTFILE" ]]; then
                                        SUBS=`mkvinfo "$F" |grep "Language: ${SUBLANG}\|Track number\|S_TEXT" |sed 's/|  + //g;s/Track number: //g;s/Language: //g;s/Codec ID: //g'`
                                        PP="";
                                        P="";
                                        TRACK="0";
                                        for S in $SUBS; do
                                                S=`echo "${S%/*}"`
                                                if [[ "$S" = "$SUBLANG" ]]; then
                                                        if [[ "$P" = "S_TEXT" ]]; then
                                                                TRACK="$PP";
                                                        fi;
                                                fi;
                                                PP="$P";
                                                P="$S";
                                        done
                                        if [[ "$TRACK" != "0" ]]; then
                                                if $DEBUG; then echo "mkvextract tracks \"$F\" ${TRACK}:\"${SRTFILE}\""; fi;
                                                echo "Creating $FILENAME.srt...";
                                                if $RUN; then
                                                        mkvextract tracks "$F" ${TRACK}:"${SRTFILE}";
                                                fi;
                                        fi;
                                fi;
                        fi;
                done;
        fi;
}

function addSubtitles {
        SUB=`echo $1 |sed 's/ /%20/g'`
        SUBLIST="$SUBLIST $SUB";
}

function checkIfRunning {
        if [ -f ${DATADIR}/program.lock ] ; then
                # the lock file already exists, so what to do?
                if [ "$(ps -p `cat ${DATADIR}/program.lock` | wc -l)" -gt 1 ]; then
                        # process is still running
                        echo "$0: quit at start: lingering process `cat ${DATADIR}/program.lock`"
                        exit 0
                else
                        # process not running, but lock file not deleted?
                        echo " $0: orphan lock file warning. Lock file deleted."
                        rm ${DATADIR}/program.lock
                fi
        fi
}

if test ! -d "${DATADIR}"; then
        mkdir ${DATADIR}
fi;

checkIfRunning;

echo $$ > ${DATADIR}/program.lock

if test -a "${DATADIR}/showList.tmp"; then
        SHOWLIST=`cat ${DATADIR}/showList.tmp`
fi
if test -a "${DATADIR}/movieList.tmp"; then
        MOVIELIST=`cat ${DATADIR}/movieList.tmp`
fi
MYSQLOPTS="$MYSQLDB -u$MYSQLUSER"
if [[ -n "$MYSQLPASS" ]]; then
        MYSQLOPTS="$MYSQLOPTS -p$MYSQLPASS"
fi;
SUBLIST="";

checkReqs;
findShows;
if $INSERTMOVIES; then
        findMovies;
fi;

rm ${DATADIR}/program.lock
