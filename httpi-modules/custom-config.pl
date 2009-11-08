# This file contains custom questions for configuring the HTTPi-xmlqstat
# It hooks into the configure system provided by HTTPi-1.6.2

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
