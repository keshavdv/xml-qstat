#!/bin/sh
# Script
#     make-httpi.sh
#
# Description
#     Get and make HTTPi webserver with xmlqstat components
#
# Mark Olesen
# -----------------------------------------------------------------------------
packageDir=httpi-1.6.2
tarFile=$packageDir.tar.gz
url="http://www.floodgap.com/httpi/$tarFile"

buildDir=build-httpi
downloadDir=build-download
configType="configure.demonic"
#
# NO FURTHER EDITING BELOW THIS LINE
#
# -----------------------------------------------------------------------------
#
# download file $1 from url $2 into download/ directory
#
downloadFile()
{
    file="$1"
    url="$2"

    if [ ! -e "$downloadDir/$file" ]
    then
        mkdir -p "$downloadDir"
        echo "downloading $tarFile from $url"
        ( cd "$downloadDir" && wget --no-check-certificate "$url" )
    fi
}

# -----------------------------------------------------------------------------
Script=${0##*/}

usage() {
    while [ "$#" -ge 1 ]; do echo "$1"; shift; done
    cat<<USAGE

usage: $Script [OPTION]
options:
  -clean             remove contents of build-httpi directory
  -rebuild SETTINGS  for repeated builds
  -version VERSION   specify an alternative version (current value: $packageDir)
  -help

Small helper script for getting/building HTTPi for xmlqstat
Currently only supports build for daemon-type.

USAGE
    exit 1
}

#------------------------------------------------------------------------------

unset settings
# parse options
while [ "$#" -gt 0 ]
do
    case "$1" in
    -h | -help)
        usage
        ;;
    -clean)             # stage 1: config only
        echo "removing $buildDir/"
        /bin/rm -rf $buildDir
        echo "done"
        exit 0
        ;;
    -rebuild)
        [ "$#" -ge 2 ] || usage "'$1' option requires an argument"
        settings="$2"
        # make absolute
        [ "${settings##/}" = "$settings" ] && settings="$(/bin/pwd)/$settings"
        shift 2
        ;;
    -version)
        [ "$#" -ge 2 ] || usage "'$1' option requires an argument"
        packageDir="$2"
        tarFile="$packageDir.tar.gz"
        url="http://www.floodgap.com/httpi/$tarFile"
        shift 2
        ;;
    *)
        usage "unknown option/argument: '$*'"
        ;;
    esac
done


# -----------------------------------------------------------------------------

# check plausibility of HTTPi installation
checkSource()
{
    dirName=$1
    unset bad

    for i in conquests.pl consubs.pl sockcons.c sockcons.pl $configType
    do
        [ -f "$dirName/$i" ] || bad="$bad $i"
    done

    [ -z "$bad" ] || {
        echo
        echo "FATAL:"
        echo "    HTTPi seems to be missing these files in $dirName/:"
        echo "   $bad"
        echo
        exit 1
    }
}


# create build directory if required
mkdir -p "$buildDir"

echo
echo fetch/unpack HTTPi $packageDir source
echo ========================================
if [ ! -d "build-httpi/$packageDir" ]
then
    downloadFile $tarFile $url

    if [ -e "$downloadDir/$tarFile" ]
    then
        echo "unpack $downloadDir/$tarFile -> $buildDir"
        # needs relative directories
        ( cd $buildDir && tar -xzf ../$downloadDir/$tarFile )
    else
        echo "no $buildDir/$tarFile to unpack"
    fi
fi

echo
echo synchronize HTTPi source
echo ========================================
# plausibility check:
checkSource $buildDir/$packageDir
/bin/ls $buildDir/$packageDir/*.{c,pl} $buildDir/$packageDir/configure.*
echo "    -> $buildDir"
echo
(
    cd $buildDir && rsync -a $packageDir/*.{c,pl} $packageDir/configure.* .
)

# plausibility check:
checkSource $buildDir


echo
echo synchronize xmlqstat httpi-modules/
echo ========================================
/bin/ls httpi-modules/*.{in,pl}
echo "    -> $buildDir"
echo
rsync -a httpi-modules/*.{in,pl} $buildDir

if [ -n "$settings" ]
then
    [ -f "$settings" ] || {
        echo
        echo "FATAL:"
        echo "    specified settings files does not exist:"
        echo "    $settings"
        echo
        exit 1
    }
    echo
    echo rebuild HTTPi with these settings:
    echo "    $settings"
    echo ========================================
    echo

    ( cd $buildDir && perl $configType -d $settings )
else
    echo
    echo configure HTTPi interactively
    echo ========================================
    ( cd $buildDir && perl $configType )
fi

# ----------------------------------------------------------------- end-of-file
