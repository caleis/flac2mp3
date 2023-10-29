#! /bin/bash
#
#set -xv
# This script converts a flat music directory structure to a hierarchical one
# (i.e. from Artist - Album format to Artist as separate directory)
#
VERSION="1.0"

print_usage () {
    echo "Usage: `basename $0` [options] <src-path>"
    echo "Options: -h Print usage"
    echo ""
    echo "Converts flat music directory structure to a hierachical one"
    echo "From:                    To:"
    echo "Artist1 - Album1   -->   Artist1 --- Album1"
    echo "Artist1 - Album2                  |- Album2"
    echo "Artist1 - Album3                  |- Album3"
    echo "Artist2 - Album1         Artist2 --- Album1"
    echo "..."
    echo ""
}

echo "`basename $0` [$VERSION] - Music library flat to hierarchical converter"

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

# Start real work here
for a;
do
   FULLNAME=$a
   echo "Processing $FULLNAME...."
   if echo "$FULLNAME" | grep -q " - "
   then
      echo "   Found valid looking directory: $FULLNAME"

      # separating parts of flat directory to before and after ' - ' separator
      ARTISTNAME=${FULLNAME%% - *}
      ALBUMNAME=${FULLNAME#* - }
      echo "   Artist directory:    $ARTISTNAME"
      echo "   Album sub-directory: $ALBUMNAME"
      if [ ! -e "$ARTISTNAME" ]
      then
         CRDIRSCRIPT=$(mktemp)
         echo "   Creating directory: $ARTISTNAME"
         echo "mkdir \"$ARTISTNAME\"" >$CRDIRSCRIPT
         chmod 700 $CRDIRSCRIPT
         $CRDIRSCRIPT
         rm $CRDIRSCRIPT
      else
         echo "   Artis directory already existing - does not create"
      fi
      MVSCRIPT=$(mktemp)
      echo "   Moving $ALBUMNAME to $ARTISTNAME"
      echo "mv \"$FULLNAME\" \"$ARTISTNAME\"/\"$ALBUMNAME\"" >$MVSCRIPT
      chmod 700 $MVSCRIPT
      $MVSCRIPT
      rm $MVSCRIPT
   else
      echo "   Skipping item Artist directory or incorrect format: $FULLNAME"
   fi
done
