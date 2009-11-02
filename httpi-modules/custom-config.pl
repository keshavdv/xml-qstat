# This file contains custom questions for configuring the HTTPi-xmlqstat
# It hooks into the configure system provided by HTTPi-1.6.2

# get xmlqstat root
$DEF_XMLQSTAT_ROOT = &prompt(<<"EOF", '$ENV{HOME}/xml-qstat', 1);

xml-qstat customization:
------------------------
Specify where the xml-qstat root is located.
The 'xmlqstat' directory under this root will be served by HTTPi
as the resource '/xmlqstat'.
EOF

# verify directory plausibility
{
    my $root;

    eval qq{\$root = "$DEF_XMLQSTAT_ROOT"};

    if (
            not $@
        and -d $root
        and -d "$root/xmlqstat"
        and -d "$root/xmlqstat/css"
        and -d "$root/xmlqstat/xsl"
      )
    {
        print <<"EOF";
Okay. Seems to have the correct xml-qstat directory structure

EOF
    }
    else {
        print <<"EOF";
WARNING: That directory has not been created or does not appear to contain
the xml-qstat directories!!

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
