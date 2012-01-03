#!/bin/sh
# ------------------------------------------------------------------------------
# Copyright (c) 2009-2011 Mark Olesen
#
# License
#     This file is part of xml-qstat.
#
#     xml-qstat is free software: you can redistribute it and/or modify it under
#     the terms of the GNU Affero General Public License as published by the
#     Free Software Foundation, either version 3 of the License,
#     or (at your option) any later version.
#
#     xml-qstat is distributed in the hope that it will be useful, but
#     WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
#     or FITNESS FOR A PARTICULAR PURPOSE.
#     See the GNU Affero General Public License for more details.
#
#     You should have received a copy of the GNU Affero General Public License
#     along with xml-qstat. If not, see <http://www.gnu.org/licenses/>.
#
# Script
#     make-httpi.sh
#
# Description
#     Get and make HTTPi webserver with xmlqstat components
#
# -----------------------------------------------------------------------------
# packageDir=httpi-1.7
# downloadURL=http://www.floodgap.com/httpi/$packageDir.tar.gz

packageDir=httpi-1.7c
downloadURL=https://github.com/olesenm/httpi/tarball/v1.7c

buildDir=build-httpi
downloadDir=build-download
configType="configure.demonic"
#
# NO FURTHER EDITING BELOW THIS LINE
#
# -----------------------------------------------------------------------------
Script=${0##*/}

usage() {
    while [ "$#" -ge 1 ]; do echo "$1"; shift; done
    cat<<USAGE

usage: $Script [OPTION]
options:
  -clean             remove contents of build-httpi directory
  -rebuild SETTINGS  for repeated builds
  -curl              only use curl for downloads
  -wget              only use wget for downloads
  -help

Small helper script for getting/building HTTPi (version $packageDir)
for xmlqstat. Currently only supports building the daemon-type.

Will try to use either curl or wget for downloads.

USAGE
    exit 1
}

#------------------------------------------------------------------------------

unset fetchCmd settings
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
        shift
        ;;
    -curl | -wget)
        fetchCmd="${1#-}"
        ;;
    *)
        usage "unknown option/argument: '$*'"
        ;;
    esac
    shift
done

#
# check curl/wget availability
#
if [ -n "$fetchCmd" ]
then
   type $fetchCmd >/dev/null 2>&1 || \
       usage "specified '-$fetchCmd', but cannot find command '$fetchCmd'"
else
    for i in curl wget
    do
        if type $i >/dev/null 2>&1
        then
            fetchCmd=$i
            break
        fi
    done
fi

# -----------------------------------------------------------------------------

#
# check plausibility of HTTPi installation
#
checkSource()
{
    dirName=$1
    shift
    unset bad

    for i in conquests.pl consubs.pl sockcons.c sockcons.pl $configType $@
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

#
# download from url $1 to file $2 in the current directory
#
# use curl or wget
#
getDownload()
{
    echo "downloading $1 -> $2"

    case "$fetchCmd" in
    curl)
        curl \
            --insecure \
            --location \
            --output "$2" \
            "$1"
        ;;
    wget)
        wget \
            --no-check-certificate \
            --output-document "$2" \
            "$1"
        ;;
    *)
        echo
        echo "FATAL:"
        echo "    no '$fetchCmd' available"
        echo
        exit 1
        ;;
    esac
}



# -----------------------------------------------------------------------------
# create build directory if required
mkdir -p "$buildDir"

echo
echo fetch/unpack HTTPi $packageDir source
echo ========================================
if [ ! -d "build-httpi/$packageDir" ]
then
    # extra prefix for github downloads, we need transform when extracting
    case "$downloadURL" in
    http*://github.com/*)
        tarFile="github-$packageDir.tar.gz"
        ;;
    *)
        tarFile="$packageDir.tar.gz"
        ;;
    esac

    [ -f "$downloadDir/$tarFile" ] || (
        mkdir -p $downloadDir
        cd $downloadDir && getDownload $downloadURL $tarFile
    )

    if [ -f "$downloadDir/$tarFile" ]
    then
    (
        echo "unpack $downloadDir/$tarFile -> $buildDir"
        cd $buildDir || exit

        # special transform for extracting github tarballs
        case "$tarFile" in
        github-*.tar.gz)
            tar \
                --transform="s@^[^/][^/]*\$@$packageDir/@" \
                --transform="s@^[^/][^/]*/@$packageDir/@" \
                --show-transformed-names \
                --extract \
                --gunzip --verbose \
                --file ../$downloadDir/$tarFile
            ;;
        *)
            tar \
                --show-transformed-names \
                --extract \
                --gunzip --verbose \
                --file ../$downloadDir/$tarFile

            ;;
        esac
    )
    else
        echo "no $buildDir/$tarFile to unpack"
    fi
fi

echo
echo synchronize HTTPi source
echo ========================================
# plausibility check:
checkSource $buildDir/$packageDir httpi.in
/bin/ls \
    $buildDir/$packageDir/*.{c,pl} \
    $buildDir/$packageDir/httpi.in \
    $buildDir/$packageDir/configure.*
echo "    -> $buildDir"
echo
/bin/cp -f -p \
    $buildDir/$packageDir/*.{c,pl} \
    $buildDir/$packageDir/httpi.in \
    $buildDir/$packageDir/configure.* \
    $buildDir

# plausibility check (again):
checkSource $buildDir httpi.in


echo
echo synchronize xmlqstat httpi-modules/
echo ========================================
/bin/ls httpi-modules/*.{in,pl}
echo "    -> $buildDir"
echo
/bin/cp -f -p httpi-modules/*.{in,pl} $buildDir

if [ -n "$settings" ]
then
    [ -f "$settings" ] || {
        echo
        echo "FATAL: specified settings file does not exist:"
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
