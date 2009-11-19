#!/bin/sh
# This wrapper interprets these initial parameters:
#     CELL=... interpret as SGE_CELL
#     ROOT=... interpret as SGE_ROOT - should be an absolute path
#     JOB=...  interpret as '-j' option for qstat, but handle empty argument as '*'
#
# It also provides a quick fix for issue
#     http://gridengine.sunsource.net/issues/show_bug.cgi?id=1949
# and for issue
#     http://gridengine.sunsource.net/issues/show_bug.cgi?id=2515
#     [for older installations]
#
# It can also be used to add file logging about when a command was called.
# For example, to track how often a command is 'hit' from a webserver request.
#
# don't rely on the exit code
# -----------------------------------------------------------------------------

# The command is basename w/o trailing .sh
cmd=${0##*/}
cmd="${cmd%%.sh}"

logfile=/dev/null
## logfile=/tmp/commandlog-$cmd

if [ ! -s $logfile ]
then
    echo "# command logger: $0" >| $logfile 2>/dev/null
    chmod 0666 $logfile 2>/dev/null
fi

## Note: "date --rfc-3339" is not a valid option for some systems (eg, Mac OSX)
## Uncomment whichever line works on your system

# echo "$(date --rfc-3339=s) $USER@$HOST: $cmd $@" >> $logfile 2>/dev/null
# echo "$(date) $USER@$HOST: $cmd $@" >> $logfile 2>/dev/null

#
# NB: using CDATA in the error messages doesn't really help with bad characters
#
error()
{
    echo "<?xml version='1.0'?><error>$@</error>"
    exit 1
}

# adjust the GridEngine environment based on the leading parameters:
#    CELL= (SGE_CELL), ROOT= (SGE_ROOT)
#    JOB=  the '-j' option for qstat, but handle empty argument as '*'
#
unset jobArgs qualifiedCmd
while [ "$#" -gt 0 ]
do
    case "$1" in
    CELL=*)
        export SGE_CELL="${1##CELL=}"
        shift
        ;;
    ROOT=*)
        export SGE_ROOT="${1##ROOT=}"
        shift
        ;;
    JOB=*)
        jobArgs="${1##JOB=}"
        [ -n "$jobArgs" ] || jobArgs="*" # missing job number is '*' (all jobs)
        shift
        ;;
    *)
        break
        ;;
    esac
done


# require a good SGE_ROOT and an absolute path:
[ -d "$SGE_ROOT" -a "${SGE_ROOT##/}" != "$SGE_ROOT" ] || \
    error "invalid SGE_ROOT directory '$SGE_ROOT'"

# require a good SGE_CELL:
: ${SGE_CELL:=default}
[ -d "$SGE_ROOT/$SGE_CELL" ] || \
    error "invalid SGE_CELL directory '$SGE_ROOT/${SGE_CELL:=default}'"


# Expand the path $SGE_ROOT/bin/<ARCH>/ (the essential bit from settings.sh).
# We need this for handling different SGE_ROOT values.
if [ -f "$SGE_ROOT/util/arch" -a -x "$SGE_ROOT/util/arch" ]
then
    arch=$($SGE_ROOT/util/arch)

    # works on Linux and SunOS without adjusting LD_LIBRARY_PATH
    case $arch in
    sol*|lx*|hp11-64)
       ;;
    *)
        shlib_path_name=$($SGE_ROOT/util/arch -lib)
        old_value=$(eval echo '$'$shlib_path_name)
        if [ -n "$old_value" ]
        then
            eval $shlib_path_name=$SGE_ROOT/lib/$arch:$old_value
        else
            eval $shlib_path_name=$SGE_ROOT/lib/$arch
        fi
        export $shlib_path_name
        unset old_value shlib_path_name
        ;;
    esac

    qualifiedCmd="$SGE_ROOT/bin/$arch/$cmd"
    unset arch
else
    error "'$SGE_ROOT/util/arch' not found"
fi


[ -f "$qualifiedCmd" -a -x "$qualifiedCmd" ] || \
    error "'$qualifiedCmd' not found"


# special output for -xml, which is actually the standard case for
# the cocoon webserver integration
xmlOutput=false
case "$@" in *-xml*) xmlOutput=true;; esac

# special clean up for xmlOutput
case "$@" in
*-xml*)
    case "$cmd" in
    qhost)
        echo $($qualifiedCmd "$@" 2>/dev/null | sed -e 's@xmlns=@xmlns:xsd=@')
        ;;
    qstat)
        if [ -n "$jobArgs" ]
        then
            echo $($qualifiedCmd "$@" -j "$jobArgs" 2>/dev/null | sed -e 's@</*>@@g')
        else
            echo $($qualifiedCmd "$@" 2>/dev/null)
        fi
        ;;
    *)
        echo $($qualifiedCmd "$@" 2>/dev/null)
        ;;
    esac
    ;;
*)
    if [ -n "$jobArgs" ]
    then
        exec $qualifiedCmd "$@" -j "$jobArgs"
    else
        exec $qualifiedCmd "$@"
    fi
    ;;
esac

# ----------------------------------------------------------------- end-of-file
