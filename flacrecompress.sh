#! /bin/bash
#
# Check compressed/uncompressed ratio of FLAC files and recompress if higher than threshold
# Version history
# 1.0 first version
# 1.1 'norecompress' folder tagfile option added
# 1.2 wrong filename error in help text output corrected
#
#

#set -xv

VERSION="1.2"

# Print usage information
# $1: base name of script to be displayed for command
# $2: default ratio threshold percentage
# $3: default FLAC compression level
#
print_usage ()
{
   echo "Usage: $1 [options] <src-path>"
   echo "Options: -h   Print usage"
   echo "         -d   Debug level (0..2)"
   echo "         -n   Dry-run option, no directories created and files converted"
   echo "         -t#  Compressed/Uncompressed ratio threshold in percentage [0..99], default: $2%"
   echo "         -c#  FLAC compression level [0..8], default: $3"
   echo ""
   echo "Check compressed/uncompressed ratio of FLAC files"
   echo "and re-compress if higher than ratio threshold"
   echo "When re-compressing the compression level cen be defined,"
   echo "which is passed to flac command."
   echo "Depending on compression level, resulting file could be more or less"
   echo "compressed than the original file"
   echo "if a directory has a file called '.norecompress' then that directory"
   echo "and anything underneath will not be processed"
   echo ""
   echo "The script walks the entire directory tree starting from <src-path>"
   echo ""
   echo "Run first with -n (dry run) option to see files to be re-compressed"
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
#
function traverse()
{
   declare -i RESULT
   declare -i CURCHANNELNUM
   declare -i CURSAMPLEBITS
   declare -i CURSAMPLERATE
   declare -i CURUNCOMPSIZE
   declare -i CURACTUALZIZE
   declare -i CURSIZERATIO
   
   if [ -e "$1/.norecompress" ]
   then
      printmsg 0 "__Directory $1 has 'norecompress' option and skipped"
   else
      for file in "$1"/* ; do
         if [ ! -d "${file}" ]
         then
            printmsg 2 "__Checking file: ${file} for processing, extension: ${file##*.}"
            if [ "${file##*.}" = "flac" ]
            then
               printmsg 1 "__File ${file} is a FLAC file and to be checked"
               (( NUMFILES++ ))
               CURCHANNELNUM=$(metaflac --show-channels "${file}")
               CURSAMPLERATE=$(metaflac --show-sample-rate "${file}")
               CURSAMPLEBITS=$(metaflac --show-bps "${file}")
               CURNUMSAMPLES=$(metaflac --show-total-samples "${file}")
               CURUNCOMPSIZE=$((CURSAMPLEBITS*CURCHANNELNUM*CURNUMSAMPLES/8))
               CURACTUALZIZE=$(stat --format %s "${file}")
               CURSIZERATIO=$((CURACTUALZIZE*100/CURUNCOMPSIZE))
               printmsg 1 "__File parameters: $CURSAMPLERATE Hz x $CURSAMPLEBITS bits X $CURCHANNELNUM channels, ratio: $CURSIZERATIO ($CURUNCOMPSIZE / $CURACTUALZIZE)"
               if (( CURSIZERATIO > COMPTHRESHOLD ))
               then
                  printmsg 0 "__File ${file} has ratio: $CURSIZERATIO and now being re-compressed"
                  if [ $DRY_RUN == 0 ]
                  then
                     TEMPFNAME="${file%.*}.tmp"
                     printmsg 2 "__Temporary file name for re-compressed file: $TEMPFNAME"
                     if [ -e "$TEMPFNAME" ]
                     then
                        printmsg 1 "__Temporary file $TEMPFNAME exists, deleting.."
                        rm "$TEMPFNAME"
                     fi
                     if [ -e "$TEMPFNAME" ]
                     then
                        printmsg 0 "*** Error, temporary file $TEMPFNAME could not be deleted, skipping FLAC"
                     else
                        flac -"$FLACCOMPLEVEL" "${file}" -o "$TEMPFNAME"
                        if (( $? != 0 ))
                        then
                           printmsg 0 "*** Error compressing to temporary file, original FLAC file ${file} not changed"
                           rm "$TEMPFNAME"
                        else
                           printmsg 1 "__Backing up original file ${file} as ${file}.org"
                           mv "${file}" "${file}.org"
                           if (( $? == 0 ))
                           then
                              printmsg 1 "__Renaming temp file $TEMPFNAME to ${file}"
                              touch --no-create "$TEMPFNAME"
                              mv "$TEMPFNAME" "${file}"
                              if (( $? == 0 ))
                              then
                                 printmsg 0 "__File ${file} is re-compressed"
                                 (( NUMRECOMPRESSED++ ))
                              else
                                 printmsg 0 "*** Error: renaming temporary file was unsuccessful, deleting temp file.."
                                 rm "$TEMPFNAME"
                              fi
                           else
                              printmsg 0 "*** Error: renaming old file as ${file}, file not re-comressed, deleting temporary file.."
                              rm "$TEMPFNAME"
                           fi
                        fi
                     fi
                  else
                     (( NUMRECOMPRESSED++ ))
                  fi
               fi
            fi
         else
            printmsg 2 "__${file} is a directory, entering recursively"
            (( NUMDIRS++ ))
            traverse "${file}"
         fi
      done
   fi
}

declare -i NO_ARGS
declare -i E_OPTERROR
declare -i DRY_RUN
declare -i DBG_LEVEL
declare -i NUMFILES
declare -i NUMDIRS
declare -i NUMRECOMPRESSED
declare -i COMPTHRESHOLD
declare -i FLACCOMPLEVEL

NO_ARGS=0
E_OPTERROR=85
DRY_RUN=0
DBG_LEVEL=0
NUMFILES=0
NUMDIRS=0
NUMRECOMPRESSED=0
COMPTHRESHOLD=85
FLACCOMPLEVEL=5

SCRIPTNAME="${0##*/}"
echo "${SCRIPTNAME%.*} [$VERSION] - FLAC re-compression tool"
 
# Test if script invoked without command-line arguments
if [ $# -eq "$NO_ARGS" ]
then
   print_usage $SCRIPTNAME $COMPTHRESHOLD $FLACCOMPLEVEL
   exit $E_OPTERROR
fi

while getopts "d:nt:c:h" OPTION
   do
      case $OPTION in
         d ) if [ "$OPTARG" -ge 0 ] && [ "$OPTARG" -le 2 ]
            then
               DBG_LEVEL=$OPTARG
               printmsg 0 "Debug level is set to $DBG_LEVEL"
            else
               printmsg 0 "*** Error in debug level parameter"
               print_usage $SCRIPTNAME $COMPTHRESHOLD $FLACCOMPLEVEL
               exit 1
            fi;;
         n ) DRY_RUN=1
             printmsg 0 "Dry-run only";;
         t ) if [ "$OPTARG" -ge 0 ] && [ "$OPTARG" -le 99 ]
            then
               COMPTHRESHOLD=$OPTARG
               printmsg 0 "Compressed/Uncompressed threshold for re-compression is set to $COMPTHRESHOLD%"
            else
               printmsg 0 "*** Error in compression ratio threshold parameter"
               print_usage $SCRIPTNAME $COMPTHRESHOLD $FLACCOMPLEVEL
               exit 1
            fi;;
         c ) if (( $OPTARG >= 0 )) && (( $OPTARG <= 8 ))
            then
               FLACCOMPLEVEL=$OPTARG
               printmsg 0 "Compression level for FLAC command is set to $FLACCOMPLEVEL"
            else
               printmsg 0 "*** Error in FLAC compression level parameter"
               print_usage $SCRIPTNAME $COMPTHRESHOLD $FLACCOMPLEVEL
               exit 1
            fi;;
         h ) print_usage $SCRIPTNAME $COMPTHRESHOLD $FLACCOMPLEVEL
            exit 0;;
      esac
   done
shift $(($OPTIND - 1))

# walk the source directory tree: create missing directories, convert missing files
traverse "$1"

printmsg 0 "Directories processed: $NUMDIRS"
printmsg 0 "Files processed: $NUMFILES"
printmsg 0 "Number of files re-compressed: $NUMRECOMPRESSED"

exit 0
