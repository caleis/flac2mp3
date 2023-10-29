#! /bin/bash
#
# This script converts a directory containing .flac files to MP3 using lame encoder
#
# Basic logic for FLAC --> ID3v1, v2 conversion
# If ALBUMARTIST defined then ALBUMARTIST --> (-, TPE2)
#   else if BAND defined then BAND --> (-, TPE2)
#     else ARTIST --> (-, TPE2)
# ALBUM --> (ALBUM, TALB)
# ARTIST --> (ARTIST, TPE1)
# TRACKNUMBER --> (TRACK, TRCK)
# TITLE --> (TITLE, TIT2)
# GENRE --> (GENRE, TCON)
# COMMENT --> (COMMENT, COMM)
# If DATE defined then DATE --> (YEAR, TYER)
#   else if YEAR defined then YEAR --> (YEAR, TYER)
# If DISCNUMBER defined then DISCNUMBER --> (-, TPOS)
#   else TPOS=1
# If coverfile defined, add that to MP3 as well (ID3v2 only, APIC):
#   search order for cover images: TPE2 - TALB.*, TALB.*, cover.* Cover.* 
#                                  folder.* Folder.* front.* Front.*
#                                  where extension can be jpg, png or gif
# Version history
# 1.0 first version
# 2.0 extended with command line options
# 2.1 in case of error in processing, dumps the content of lame command line
#     to help debug
#     uses mktemp instead of using fixed file names 
#     (can run multiple instances of script)
# 3.0 full directory walk added, so entire trees can be converted (if not existing already)
#

#set -xv

VERSION="3.0"

print_usage ()
{
   echo "Usage: `basename $0` [options] <src-path>"
   echo "Options: -h   Print usage"
   echo "         -d   Debug level (0..2)"
   echo "         -r   Remove FLAC input file after processing"
   echo "         -D<dest-path>   Path to output MP3 files (default is ../Mp3)"
   echo "         -Vn  Set the target bitrate (quality) of LAME VBR encoder"
   echo "          where n = 0 target bitrate 245 kbit/s"
   echo "                n = 1 target bitrate 225 kbit/s"
   echo "                n = 2 target bitrate 190 kbit/s"
   echo "                n = 3 target bitrate 175 kbit/s"
   echo "                n = 4 target bitrate 165 kbit/s"
   echo "                n = 5 target bitrate 130 kbit/s (default)"
   echo "                n = 6 target bitrate 115 kbit/s"
   echo "                n = 7 target bitrate 100 kbit/s"
   echo "                n = 8 target bitrate 85 kbit/s"
   echo "                n = 9 target bitrate 65 kbit/s"
   echo ""
   echo "Converts all *.flac files under <src-path> to MP3 format using LAME encoder"
   echo "result files are placed to <dest-path>/<src-path>, default is ../Mp3/<src-path>"
   echo "<src-path> should be a relative path for correct operation"
}

# Print diagnostic and error messages to stderr
# $1: diagnostic level. Message printed if parameter <= set debug level
# $2: message to be printed
#
printmsg ()
{
   if [ $(($1)) -le $((DBG_LEVEL)) ]
   then
      (>&2 echo "$2")
   fi
}


# Traverse directory trees
# $1: source path
# $2: dest path
#
function traverse()
{
   for file in "$1"/* ; do
      if [ ! -d "${file}" ]
      then
         printmsg 2 "__Checking file: ${file} for processing, extension: ${file##*.}"
         if [ "${file##*.}" = "flac" ]
         then
            printmsg 1 "__File ${file} is a FLAC file and to be processed"
            if [ ! -e "$2/${file%.*}.mp3" ]
            then
               printmsg 0 "__Converting file: ${file%.*}.flac"
               printmsg 1 "__Destination file: $2/${file%.*}.mp3"
               convertf2m "${file%.*}" "$2/${file%.*}"
            else
               printmsg 1 "__No conversion: $2/${file%.*}.mp3 exists"
            fi
         fi
      else
         printmsg 2 "__${file} is a directory, entering recursively"
         printmsg 1 "__Checking existense of $2/${file}"
         if [ ! -e "$2/${file}" ]
         then
            printmsg 2 "__Destination directory $2/${file} does not exist"
            COUNTFILES=`ls -1 "${file}"/*.* 2>/dev/null | wc -l`
            COUNTFLAC=`ls -1 "${file}"/*.flac 2>/dev/null | wc -l`
            if [ $COUNTFILES == 0 ] || [ $COUNTFLAC != 0 ]
            then
               CRPATH="$2/${file}"
               CRDIRSCRIPT=$(mktemp)
               printmsg 0 "__Creating directory: $CRPATH"
               echo "mkdir \"$CRPATH\"" >$CRDIRSCRIPT
               chmod 700 $CRDIRSCRIPT
               $CRDIRSCRIPT
               rm $CRDIRSCRIPT
            else
               printmsg 1 "__Directory $2/${file} not created as source not empty and does not have FLAC files, files: $COUNTFILES, FLACs: $COUNTFLAC"
            fi
         else
            printmsg 2 "__Directory $2/${file} exists"
         fi
         traverse "${file}" "$2"
      fi
   done
}

# Convert single FLAC file to Mp3
# $1: source file with path (without .flac extension)
# $2: destination file with path (without .mp3 extension)
#
convertf2m ()
{
   declare -i RESULT
   declare -i COVEREXIST

   printmsg 0 "============================================================"
   printmsg 0 "File to be processed: $1.flac"
   OUTF=$2.mp3
   printmsg 0 "Output file name:    `basename "$OUTF"`"
   
   printmsg 0 "-------------------- Source tags ---------------------------"
   ALBUM=`metaflac "$1.flac" --show-tag=ALBUM | sed s/.*=//g`
   printmsg 0 "Album:                       <$ALBUM>"
   ALBUMARTIST=`metaflac "$1.flac" --show-tag=ALBUMARTIST | sed s/.*=//g`
   if [ -n "$ALBUMARTIST" ]
   then
      printmsg 0 "Album artist:                <$ALBUMARTIST>"
   fi
   ARTIST=`metaflac "$1.flac" --show-tag=ARTIST | sed s/.*=//g`
   printmsg 0 "Artist:                      <$ARTIST>"
   BAND=`metaflac "$1.flac" --show-tag=BAND | sed s/.*=//g`
   if [ -n "$BAND" ]
   then
      printmsg 0 "Band/orchesra:               <$BAND>"
   fi
   COMMENT=`metaflac "$1.flac" --show-tag=COMMENT | sed s/.*=//g`
   if [ -n "$COMMENT" ]
   then
      printmsg 0 "Comment:                     <$COMMENT>"
   fi
   COMPOSER=`metaflac "$1.flac" --show-tag=COMPOSER | sed s/.*=//g`
   if [ -n "$COMPOSER" ]
   then
      printmsg 0 "Composer:                    <$COMPOSER>"
   fi
   DATE=`metaflac "$1.flac" --show-tag=DATE | sed s/.*=//g`
   if [ -n "$DATE" ]
   then
      printmsg 0 "Date:                        <$DATE>"
   fi
   DISCNUMBER=`metaflac "$1.flac" --show-tag=DISCNUMBER | sed s/.*=//g`
   if [ -n "$DISCNUMBER" ]
   then
      printmsg 0 "Disc #:                      <$DISCNUMBER>"
   fi
   GENRE=`metaflac "$1.flac" --show-tag=GENRE | sed s/.*=//g`
   if [ -n "$GENRE" ]
   then
      printmsg 0 "Genre:                       <$GENRE>"
   fi
   TITLE=`metaflac "$1.flac" --show-tag=TITLE | sed s/.*=//g`
   printmsg 0 "Title:                       <$TITLE>"
   TOTALDISCS=`metaflac "$1.flac" --show-tag=TOTALDISCS | sed s/.*=//g`
   if [ -n "$TOTALDISCS" ]
   then
      printmsg 0 "# of Discs:                  <$TOTALDISCS>"
   fi
   TOTALTRACKS=`metaflac "$1.flac" --show-tag=TOTALTRACKS | sed s/.*=//g`
   if [ -n "$TOTALTRACKS" ]
   then
      printmsg 0 "# of Tracks:                 <$TOTALTRACKS>"
   fi
   TRACKNUMBER=`metaflac "$1.flac" --show-tag=TRACKNUMBER | sed s/.*=//g`
   printmsg 0 "Track #:                     <$TRACKNUMBER>"
   YEAR=`metaflac "$1.flac" --show-tag=YEAR | sed s/.*=//g`
   if [ -n "$YEAR" ]
   then
      printmsg 0 "Year:                        <$YEAR>"
   fi

   if [ -n "$ALBUMARTIST" ]
   then
      TPE2=$ALBUMARTIST
   else
      if [ -n "$BAND" ]
      then
         TPE2=$BAND
      else
         TPE2=$ARTIST
      fi
   fi
   if [ -n "$DATE" ]
   then
      TYER=$DATE
   else
	   if [ -n $YEAR ]
		then
         TYER=$YEAR
      fi
   fi
   TALB=$ALBUM
   TPE1=$ARTIST
   TRCK=$TRACKNUMBER
   TIT2=$TITLE
   TCON=$GENRE
   COMM=$COMMENT
   if [ -n "$DISCNUMBER" ]
   then
      TPOS=$DISCNUMBER
   else
      TPOS="1"
   fi
   if [ -n "$TOTALDISCS" ]
   then
      TPOS="$TPOS/$TOTALDISCS"
   else
      TPOS="$TPOS/1"
   fi
   COVEREXIST=0
   for img in "$TPE2 - $TALB" "$TALB" "cover" "Cover" "folder" "Folder" "front" "Front" 
   do
      for ext in "jpg" "gif" "png"
      do
         COVERFILE="`dirname "$1"`/"$img"."$ext""
         printmsg 2 "Trying: $COVERFILE"
         if [ -e "$COVERFILE" ]
         then
            COVEREXIST=1
            break
         fi
      done
      if [ $COVEREXIST -eq 1 ]
      then
         printmsg 1 "Cover image file found:      <`basename "$COVERFILE"`>"
         APIC=$COVERFILE
         break
      fi
   done
   if [ $COVEREXIST -eq 0 ]
   then
      printmsg 0 "Cover image file:            <-none->"
   fi

   printmsg 0 "-------------------- Output tags ---------------------------"
   printmsg 0 "TPOS (Disc number):          <$TPOS>"
   printmsg 0 "TPE2 (Album artist/band):    <$TPE2>"
   printmsg 0 "TALB (Album):                <$TALB>"
   printmsg 0 "TRCK (Track number):         <$TRCK>"
   printmsg 0 "TPE1 (Track artist):         <$TPE1>"
   printmsg 0 "TIT2 (Track title):          <$TIT2>"
   printmsg 0 "TCON (Genre):                <$TCON>"
   printmsg 0 "TYER (Album date/year):      <$TYER>"
   printmsg 0 "COMM (Comment):              <$COMM>"
   if [ $COVEREXIST -eq 1 ]
   then
      printmsg 0 "APIC (Cover art file):       <`basename "$APIC"`>"
   else
      printmsg 0 "APIC (Cover art file):       <-none->"
   fi
   printmsg 0 ""

   LAMEPARAMS="--ta \"${TPE1}\" --tl \"${TALB}\" --tn \"$TRCK\" --tt \"$TIT2\" "
   if [ -n "$TPOS" ]
   then
      LAMEPARAMS="$LAMEPARAMS --tv TPOS=\"$TPOS\""
   fi
   if [ -n "$TPE2" ]
   then
      LAMEPARAMS="$LAMEPARAMS --tv TPE2=\"$TPE2\""
   fi
   if [ -n "$TCON" ]
   then
      LAMEPARAMS="$LAMEPARAMS --tg \"$TCON\""
   fi
   if [ -n "$TYER" ]
   then
      LAMEPARAMS="$LAMEPARAMS --ty \"$TYER\""
   fi
   if [ -n "$COMM" ]
   then
      LAMEPARAMS="$LAMEPARAMS --tc \"$COMM\""
   fi
   if [ -n "$APIC" ]
   then
      LAMEPARAMS="$LAMEPARAMS --ti \"$APIC\""
   fi

   LAMEPARAMS="flac -c -d \"$1.flac\" | lame  -V$LAME_VBR --add-id3v2 --pad-id3v2 $LAMEPARAMS - \"$OUTF\""
   LAMESCRIPT=$(mktemp)
   printmsg 2 "Temporary file for lame parameters: $LAMESCRIPT"
   echo $LAMEPARAMS > $LAMESCRIPT
   chmod 700 $LAMESCRIPT
   $LAMESCRIPT
   RESULT=$?
   RESULTALL=$RESULTALL+$RESULT
   if [ $RESULT = 0 ]
   then
      printmsg 0 "Current operation result: OK ($RESULT)"
   else
      printmsg 0 "Current operation result: *** Error *** ($RESULT)"
      cat "$LAMESCRIPT"
   fi
   if [ -e "$LAMESCRIPT" ]
   then
      rm $LAMESCRIPT
   fi
   if [ $FLAC_DELETE -eq 1 ] && [ $RESULT -eq 0 ]; then
      rm "$1.flac"
      printmsg 0 "Input file $1.flac deleted."
   fi
   (( NUMFILES++ ))
}

NO_ARGS=0
E_OPTERROR=85
FLAC_DELETE=0
MP3PATH="../Mp3"
LAME_VBR=5
DBG_LEVEL=0
declare -i RESULTALL
declare -i NUMFILES
RESULTALL=0
NUMFILES=0

echo "$(basename $0) [$VERSION] - FLAC to MP3 conversion script"
 
# Test if script invoked without command-line arguments
if [ $# -eq "$NO_ARGS" ]
then
   print_usage
   exit $E_OPTERROR
fi

while getopts "d:rhD:V:" OPTION
   do
      case $OPTION in
         d ) if [ "$OPTARG" -ge 0 ] && [ "$OPTARG" -le 2 ]
            then
               DBG_LEVEL=$OPTARG
               echo "Debug level is set to $DBG_LEVEL"
            else
               print_usage
            fi;;
         r ) FLAC_DELETE=1
             printmsg 0 "FLAC source files will be deleted after conversion";;
         h ) print_usage;;
         D ) MP3PATH=$OPTARG
            printmsg 0 "MP3 output files will be written directory (relative to source dir): $MP3PATH";;
         V ) if [ "$OPTARG" -ge 0 ] && [ "$OPTARG" -le 9 ]
            then
               LAME_VBR=$OPTARG
               printmsg 0 "LAME VBR quality is set to $LAME_VBR"
            else
               print_usage
            fi;;
      esac
   done
shift $(($OPTIND - 1))

traverse $1 $MP3PATH

printmsg 0 "============================================================"
printmsg 0 "Conversion complete"
printmsg 0 "Files processed: $NUMFILES"
if [ $RESULTALL = 0 ]
then
    printmsg 0 "Conversion process result: OK ($RESULTALL)"
else
    printmsg 0 "Conversion process result: *** Error *** ($RESULTALL)"
fi

exit $RESULTALL
