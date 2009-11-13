# This file contains custom questions for configuring the HTTPi-xmlqstat
# It hooks into the configure system provided by HTTPi-1.6.2


# get GridEngine arch/lib information
print "GridEngine configuration\n";
print "Trying to determine the architecture and library requirements\n";
print "... checking what '$archScript' reports\n";

( $DEF_SGE_ARCH, $DEF_LIBENV ) = ( '', '' );

if ( $ENV{SGE_ROOT} and -d $ENV{SGE_ROOT} ) {
    my $archScript = "$ENV{SGE_ROOT}/util/arch";
    # use 'arch' script if possible

    chomp( $DEF_SGE_ARCH = qx{$archScript 2>/dev/null} );
    if ($DEF_SGE_ARCH)
    {
        chomp( $DEF_LIBENV = qx{$archScript -lib 2>/dev/null} );
    }
    else
    {
        print "Hmm. Couldn't seem to execute $archScript\n";
    }
}


if ($DEF_SGE_ARCH) {
    print "Using $DEF_SGE_ARCH for the GridEngine architecture\n";
}
else {
    print
"Couldn't get GridEngine architecture automatically, need to do it ourselves\n";
    $DEF_SGE_ARCH = "undef";
}

while (1) {
    $DEF_SGE_ARCH = &prompt( <<"EOF", $DEF_SGE_ARCH, 1 );

Define the architecture used for the GridEngine commands.
This should correspond to the value emitted by the \$SGE_ROOT/util/arch
except that we couldn't seem to find that script.

Hint: the 'arch' value here should allow us to find
\$SGE_ROOT/bin/<arch>/qstat

Which value should be used for the GridEngine architecture?
EOF

    if ( $DEF_SGE_ARCH eq "undef" or not $DEF_SGE_ARCH ) {
        print <<"EOF";
The GridEngine architecture value '$DEF_SGE_ARCH' looks implausible
Please try again ...

EOF
    }
    else {
        last;
    }
}


# library path setting for architectures where RUNPATH is not supported
if ( $DEF_SGE_ARCH =~ /^(lx|sol)/ or $DEF_SGE_ARCH eq "hp11-64" ) {
    print "Good. We can apparently use RUNPATH for this architecture!\n";
    $DEF_LIBENV = '';
}
else
{
    $DEF_LIBENV = &prompt(<<"EOF", 'LD_LIBRARY_PATH', 1);

Define the name of the dynamic link library environment variable
for your machine. This is needed to load the GridEngine libraries.

Which environment variable is used for the libraries?
EOF
}


# get xmlqstat root
$DEF_XMLQSTAT_ROOT = &interprompt(<<"EOF", '~/xml-qstat', 1, \&inter_homedir);

xml-qstat customization:
------------------------
Specify where the xml-qstat root is located.
The 'xmlqstat' directory under this root will be served by HTTPi
as the resource '/xmlqstat'.

You can use Perl variables for this option (example: \$ENV{'HOME'}/xml-qstat).
As a shortcut, ~/ in first position will be turned into \$ENV{'HOME'}/,
which is "$ENV{'HOME'}/".

xml-qstat resource root:?
EOF

# verify directory plausibility
for ($DEF_XMLQSTAT_ROOT)
{
    if (
        -d $_
        and -d "$_/xmlqstat"
        and -d "$_/xmlqstat/css"
        and -d "$_/xmlqstat/xsl"
      )
    {
        print <<"EOF";
Okay. The directory '$_'
Seems to have the correct xml-qstat directory structure.

EOF
    }
    else {
        print <<"EOF";
WARNING: The directory '$_'
Does not appear to contain the correct xml-qstat directory structure!!

EOF
    }
}


$DEF_XMLQSTAT_TIMEOUT = &prompt(<<"EOF", '10', 1);

------------------------
xml-qstat customization:
Define the maximum timeout (seconds) when executing GridEngine commands
EOF


1; # loaded ok
# ----------------------------------------------------------------- end-of-file
