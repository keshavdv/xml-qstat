#!/usr/bin/perl -w
use strict;

# -----------------------------------------------------------------------------
# xmlqstat-cgibits.pl
#
# cgibits elements for the xmlqstat CGI scripts.
#
# Global variables used (input):
# - $webappPath (needed to find config/config.xml)
#
# Global variables used (output):
# - %param, %switch, @ids
#
# sets SGE_ROOT and SGE_CELL according to the 'cluster=' CGI parameter
#
# -----------------------------------------------------------------------------
# boilerplate for hand-rolled cgi scripts

#
# HTTPi seems to like having HTTP/1.1 at the start, but Apache doesn't:
#
my $httpHeader =
  ( $ENV{SERVER_SOFTWARE} and $ENV{SERVER_SOFTWARE} =~ m{^HTTPi/} )
  ? "HTTP/1.1 200 OK\015\012"
  : "Status: 200 OK\015\012";

#
# output XML content
#
sub outputXML {
    my $content = shift;
    print $httpHeader, "Content-Type: text/xml;\015\012";
    print "Content-Length: ", length($content), "\015\012";
    print "\015\012";
    print $content;
}

#
# output HTML content
#
sub outputHTML {
    my $content = shift;
    print $httpHeader, "Content-Type: text/html;\015\012";
    print "Content-Length: ", length($content), "\015\012";
    print "\015\012";
    print $content;
}

#
# simple error message
#
sub error {
    outputXML qq{<?xml version="1.0"?>\n<error>@_</error>\n};
    exit 1;
}

#
# extract attrib="value" ... attrib="value"
#
sub parseXMLattrib {
    my $str = shift || '';
    my %attr;

    while ($str =~ s{^\s*(\w+)=\"([^\"]*)\"}{}s
        or $str =~ s{^\s*(\w+)=\'([^\']*)\'}{}s )
    {
        $attr{$1} = $2;
    }

    %attr;
}

#
# get cluster settings from config/config.xml file
#
my %clusterPaths;
{
    my $configFile = "$::webappPath/config/config.xml";

    local ( *CONFIG, $_, $/ );    ## slurp mode
    if ( -f $configFile and open CONFIG, $configFile ) {

        # reset paths, assign new modification time
        %clusterPaths = ();

        # slurp file and strip out all xml comments
        $_ = <CONFIG>;
        s{<!--.*?-->\s*}{}sg;

        # only retain content of <clusters> .. </clusters> bit
        s{^.*<clusters>|</clusters>.*$}{}sg;

        ## process <cluster .../> and <cluster ...> .. </cluster>
        while (s{<cluster \s+([^<>]+?) />}{}sx
            or s{<cluster \s+([^<>]+) > (.*?) </cluster>}{}sx )
        {
            my ( $attr, $content ) = ( $1, $2 );

            my %attr = parseXMLattrib($attr);
            my $name = delete $attr{name};

            if ( defined $name ) {
                $clusterPaths{$name} = {%attr};
            }
        }

        ## handle <default ... />
        my ( $name, %attr ) = ("default");

        if (   s{<default \s+([^<>]+?) />}{}sx
            or s{<default \s+([^<>]+) > (.*?) </default>}{}sx )
        {
            my ( $attr, $content ) = ( $1, $2 );
            %attr = parseXMLattrib($attr);

            # remove unneed/unwanted attributes
            delete $attr{name};
        }

        my $enabled = delete $attr{enabled};
        if ( $enabled and $enabled eq "no" ) {
            %attr = ();
        }
        else {
            $clusterPaths{"default"} = {%attr};
        }
    }
}

# %param  = named parameters
# %switch = unnamed parameters
# @ids    = raw numbers
%::param  = ();
%::switch = ();
@::ids    = ();

# parameter checking: '&' is the normal separator, but split on '&amp;' too
# pander to calling directly from the command-line as well (no QUERY_STRING)
{
    my @params = grep { defined and length } split /\&(?:amp;)?/,
      ( $ENV{QUERY_STRING} || '' );

    for (@params) {
        s{%([\dA-Fa-f]{2})}{chr hex $1}eg;  ## decode chars, eg %20 -> space etc
        s{[*?&<>{}\[\]\\\`]}{}g;            ## remove meta-chars

        if (/=/) {
            my ( $k, $v ) = split /=/;
            $v =~ s{^,+|,+$}{}g;            ## remove leading/trailing commas
            $::param{$k} = $v;
        }
        elsif (/^\d+$/) {
            push @::ids, $_;
        }
        else {
            $::switch{$_}++;
        }
    }
}

#
# select GridEngine environment based on cluster= parameter or use default
#
my $cluster = "default";
$cluster = $::param{cluster} if exists $::param{cluster};

my ( $root, $cell );

if (    exists $clusterPaths{$cluster}
    and exists $clusterPaths{$cluster}{root} )
{
    $root = $clusterPaths{$cluster}{root};
    $cell = $clusterPaths{$cluster}{cell};
}
$cell ||= "default";    # fallback

unless ( defined $root ) {
    error "Undefined SGE_ROOT for cluster <em>$cluster</em>";
}

#
# GridEngine environment:
#
$ENV{"SGE_ROOT"} = $root;
$ENV{"SGE_CELL"} = $cell;

# require a good SGE_ROOT and an absolute path:
defined $ENV{SGE_ROOT} and -d $ENV{SGE_ROOT} and $ENV{SGE_ROOT} =~ m{^/}
  or error "invalid SGE_ROOT directory:", ( $ENV{SGE_ROOT} || "undef" ),
  "for cluster <em>$cluster</em>";

# require a good SGE_CELL:
-d "$ENV{SGE_ROOT}/$ENV{SGE_CELL}"
  or error "invalid SGE_CELL directory '$ENV{SGE_ROOT}/$ENV{SGE_CELL}'",
  "for cluster <em>$cluster</em>";

# -----------------------------------------------------------------------------

1;    # loaded okay

# ----------------------------------------------------------------- end-of-file
