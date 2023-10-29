#! /bin/bash
#
#set -xv
# This script is to generate a catalog CSV file for FLAC or MP3 archives
# Fields in the CSV file
# - Directory Name (i.e. Artist - Album)
# - File Name (i.e Song) - only .flac and .mp3 files are listed
# - Rip Source - if Directory Name.rip file exists, first 20 characters included, otherwise set to unknown
# - Rip Quality, the following values are possible
#   0 - No Log File
#   1 - Invalid log file content (could be wrong version of EAC)
#   2 - Error(s) in Process
#   3 - No Errors, Not in AutoRip DB
#   4 - No Errors, different from AutoRip DB
#   5 - No Errors, Partially Accurate
#   6 - No Errors, Fully Accurate
# - Album Art - if file exists in directory (same specs as in flac2mp3)

VERSION="1.0"

print_usage ()
{
    echo "Usage: `basename $0` [options] <src-path>"
    echo "Options: -h   Print usage"
}

# This pattern match function checks pattern in logfile, both for ASCII/UTF-8 and Unicode
# $1 is pattern, $2 log file name
pattern_in_log ()
{
    local i=0
    local len=0
    local PATTERN=""
    if grep -q "$1" "$2"
    then
        return 0
    else
        len=${#1}
        while [ $i -lt "$len" ]
        do
            PATTERN=""$PATTERN""${1:i:1}"."
            (( i += 1 ))   
        done
        if grep -q -a "$PATTERN" "$2"
        then
            return 0
        fi
   fi

   return 1
}


echo "`basename $0` [$VERSION] - FLAC structure lister"
echo "\"Directory (Album)\",\"Filename (Track)\",\"Rip source\",\"Qual\",\"Quality Text\",\"Album art\""
 
# Test if script invoked without command-line arguments
NO_ARGS=0

if [ $# -eq "$NO_ARGS" ]
then
   print_usage
   exit $E_OPTERROR
fi

while getopts ":h" Option
   do
      case $Option in
         h ) print_usage;;
      esac
   done
shift $(($OPTIND - 1))

for a; do
    L1DIRNAME=`basename "$a"`
    LOGFNAME="$a/$L1DIRNAME.log"

    RIPSOURCE=""
    for RIPFNAME in "$a/"*.rip; do
        if [[ -e "$RIPFNAME" ]]
        then  
            RIPSOURCE="`basename "${RIPFNAME%.rip}"`"
        else
            RIPSOURCE="Unknown source"
        fi
    done

    # The following solution is not very elegant, we need to handle ASCII/UTF-8 and Unicode log files separately
    # Unicode looks as binary file to grep with a 0x00 character between ASCII characters.
    if [ -e "$LOGFNAME" ]
    then
        if pattern_in_log "No errors occurred" "$LOGFNAME"
        then
            if pattern_in_log "All tracks accurately ripped" "$LOGFNAME"
            then
                RIPQUAL=6
                RIPQUALTXT="No Errors, fully accurate"
            fi
            if pattern_in_log "Some tracks could not be verified as accurate" "$LOGFNAME"
            then
                RIPQUAL=5
                RIPQUALTXT="No Errors, partially accurate"
            fi
            if pattern_in_log "No tracks could be verified as accurate" "$LOGFNAME"
            then
                RIPQUAL=4
                RIPQUALTXT="No Errors, different from AutoRip DB"
            fi
            if pattern_in_log "None of the tracks are present in the AccurateRip database" "$LOGFNAME"
            then
                RIPQUAL=3
                RIPQUALTXT="No Errors, not in AutoRip DB"
            fi
        else
            if pattern_in_log "There were errors" "$LOGFNAME"
            then
                RIPQUAL=2
                RIPQUALTXT="Error(s) in process"
            else
                RIPQUAL=1
                RIPQUALTXT="Invalid log file content (could be wrong version of EAC)"
            fi
        fi
    else
        RIPQUAL=0
        RIPQUALTXT="No log file"
    fi

    COVEREXIST=0
    for img in "$L1DIRNAME" "cover" "Cover" "folder" "Folder" "front" "Front" 
    do
        for ext in "jpg" "gif" "png"
        do
            COVERFNAME=""$a"/"$img"."$ext""
            if [ -e "$COVERFNAME" ]
            then
                COVEREXIST=1
                break 2 # breaks from inner and outer loop
            fi
        done
    done
    if [ $COVEREXIST -eq 1 ]
    then
        COVEREXISTTXT="Album art exists"
    else
        COVEREXISTTXT="No album art"
    fi
    echo "\""$L1DIRNAME"\",,\""${RIPSOURCE:0:20}"\","$RIPQUAL",\""$RIPQUALTXT"\",\""$COVEREXISTTXT"\""

    for b in "$a/"*.*; do
        L2FNAME=`basename "$b"`
        if [[ $L2FNAME == *.flac ]] || [[ $L2FNAME == *.mp3 ]]
        then
            echo ","\"$L2FNAME"\""
        else
            if [[ $L2FNAME == `basename "$LOGFNAME"` ]] || [[ $L2FNAME == `basename "$COVERFNAME"` ]] || [[ $L2FNAME == *.rip ]]
            then
                :
            else
                echo ",\"Unknown file: "$L2FNAME"\""
            fi
        fi
    done
done

exit $RESULTALL
