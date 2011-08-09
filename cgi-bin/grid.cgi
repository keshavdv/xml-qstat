#!/usr/bin/perl -w
use strict;
################################################################################
# CUSTOMIZE THIS TO MATCH YOUR REQUIREMENTS:
#

# physical location of the web-app directory:
my $webappPath = "/export/home/mark/xml-qstat/web-app";

# the default GridEngine root (SGE_ROOT):
my $sge_root = "/export/home/mark/xml-qstat/sge_root";

# name of the GridEngine architecture:
my $sge_arch = "lx-fake";

# name of the system library environment, for systems where runpath won't work:
my $libEnvName = 0;

# timeout (seconds)
my %timeout = (
    http  => 20,    # timeout for external http requests
    shell => 5,     # timeout for system commands like 'qstat -j', etc.
);

#
# END OF CUSTOMIZE SETTINGS
################################################################################
# ------------------------------------------------------------------------------
# Copyright 2009-2011 Mark Olesen
#
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
# -----------------------------------------------------------------------------
my $Debug = 0;

#
# initialization Perl modules, support FastCGI if possible
#
use CGI qw( :standard -nosticky );

# eval q{use CGI::Fast ()};
# my $whichCGI = $@ ? "CGI" : "CGI::Fast";
my $whichCGI = "CGI";

# -----------------------------------------------------------------------------
#
# maintain information about last modification time of the CGI script itself
# and of the config/config.xml file
my %mtime = ( cgi => 0, config => 0 );

# hashed values of cluster configuration, extracted from config/config.xml
my %clusterPaths;

#
# basic types for static content
#
my %contentTypes = (
    css  => "text/css",
    html => "text/html",
    js   => "application/x-javascript",
    png  => "image/png",
    txt  => "text/plain",
    xml  => "text/xml",
    xsl  => "text/xml",                   ## xsl  => "application/xslt+xml",
);

#
# callbacks for GridEngine commands
# - the names correspond both to the internal resource mapping
#   and to the xml file (w/o ending)
#
my %gridEngineQuery = (
    qhost => sub {
        my ( $self, $cluster ) = @_;
        $self->gridEngineCmd(
            $cluster,                     #
            qhost => qw( -xml -q -j )
        );
    },
    qstat => sub {
        my ( $self, $cluster ) = @_;
        $self->gridEngineCmd(
            $cluster,                     #
            qstat => qw( -xml -u * -r -s prs )
        );
    },
    qstatf => sub {
        my ( $self, $cluster ) = @_;
        $self->gridEngineCmd(
            $cluster,                     #
            qstat => qw( -xml -u * -r -f -explain aAcE ),
            ( -F => "load_avg,num_proc" )
        );
    },
    qstatj => sub {
        my ( $self, $cluster, $jobId ) = @_;
        $jobId and $jobId =~ /^\d+$/ or $jobId = '*';
        $self->gridEngineCmd(
            $cluster,                     #
            qstat => qw( -xml -j ),
            $jobId
        );
    },
);

# -----------------------------------------------------------------------------
package GridResource;
use POSIX qw();
use Socket qw();

# GridResource - handle xml-qstat requests

#
# create and reset new GridResource object
# - can also use 'process' method directly
#
# Return: SELF
#
sub new {
    my $class = shift;
    my $self = bless {} => $class;
    $self->reset(@_);

    return $self;
}

#
# reset GridResource object to a sane state
#
# Return: SELF
#
sub reset {
    my ( $self, %param ) = @_;
    %{$self} = (
        cgi    => 0,     # the cgi
        param  => {},    # named request parameters
        switch => {},    # unnamed request parameters
        xslt   => {},    # xslt parameters
        %param,
        error => [],     # error stack
    );

    # basic xslt parameters
    $self->{xslt}{timestamp} ||=
      POSIX::strftime( "%Y-%m-%d %H:%M:%S", localtime );

    $self->{xslt}{serverName} =
      $self->{cgi} ? $self->{cgi}->server_name() : "unknown";

    return $self;
}

#
# return number of error lines thus far
# can be used to conditionally avoid code if an error has already occurred
#
sub hasError {
    my ($self) = @_;
    return scalar @{ $self->{error} };
}

#
# set an error message
#
# Return: SELF
#
sub setError {
    my ($self) = shift;

    if (@_) {
        push @{ $self->{error} }, @_;
    }
    else {
        my ( $line, $sub ) = ( caller(1) )[ 2, 3 ];
        push @{ $self->{error} },    #
          "Error set by $sub line $line ",
          "- this information is only useful for the program developer";
    }

    return $self;
}

#
# Parse request string utility function
# Prototype: ->parseRequestString( QUERY_STRING )
#
# - place named parameters in \%param and unnamed parameters in \%switch
#
# Return: SELF
#
sub parseRequestString {
    my ( $self, $str ) = @_;

    $self->{param}  ||= {};
    $self->{switch} ||= {};

    defined $str or $str = '';
    for ( grep { defined and length } split /[\&;]/, $str ) {
        ## decode chars, eg %20 -> space etc
        s{%([\dA-Fa-f]{2})}{chr hex $1}eg;

        ## remove shell meta-chars
        s{[*?&<>{}\[\]\\\`]}{}g;

        if (/=/) {
            my ( $k, $v ) = split /=/;
            ## remove leading/trailing commas
            $v =~ s{^,+|,+$}{}g;
            $self->{param}{$k} = $v;
        }
        else {
            $self->{switch}{$_}++;
        }
    }

    return $self;
}

#
# Parse XML attributes utility function
#
# extract attrib="value" ... attrib="value"
#
# Return: hash of attributes
#
sub parseXMLattrib {
    my ( $self, $str ) = @_;
    defined $str or $str = '';

    my %attr;
    while ($str =~ s{^\s*(\w+)=\"([^\"]*)\"}{}s
        or $str =~ s{^\s*(\w+)=\'([^\']*)\'}{}s )
    {
        $attr{$1} = $2;
    }

    %attr;
}

#
# Resource not found error handler
# - does not exit, since this would not work with FastCGI
#
# Return: SELF
#
sub httpError404 {
    my $self = shift;
    my $cgi  = $self->{cgi};

    print $cgi->header(
        -type    => 'text/html',
        -charset => 'utf-8',
        -status  => 404
    );
    print qq{<h1>Not Found</h1>\n},    #
      qq{Resource <blockquote><pre>}, $cgi->request_uri(),
      qq{</pre></blockquote>\n};

    print @{ $self->{error} || [] };
    print @_ if @_;
    print "<hr/>";

    return $self;
}

#
# report cluster name as unknown
#
# Return: SELF
#
sub setErrorUnknownCluster {
    my ( $self, $clusterName ) = @_;

    $clusterName ||= "undef";

    my $count = scalar keys %clusterPaths;
    my $known = join( "\n" => sort keys %clusterPaths );

    $self->setError(<<"ERROR");
Unknown cluster configuration
<blockquote><pre>
$clusterName
</pre></blockquote>
There are $count known cluster configurations:
<blockquote><pre>
$known
</pre></blockquote>
Note that the <em>default</em> cluster cannot be explicitly named
ERROR

    return $self;
}

#
# get a xml/html etc via HTTP
# - ideas taken from LWP::Simple
#
# Return: [ \@response, \%header, $buf ];
#
sub getHTTP {
    my ( $self, $url ) = @_;
    my $timeout = $timeout{http} || 20;

    my ( $proto, $host, $port, $path ) =
      ( $url =~ m{^(https?)://([^/:\@]+)(?::(\d+))?(/\S*)?$} )
      or return $self->setError(<<"ERROR");
Badly formatted url or unsupported protocol
ERROR

    $port or $port = $proto eq "https" ? 443 : 80;

    if ($path) {
        $path =~ s{//+}{/}g;
    }
    else {
        $path = "/";
    }

    my $serverName   = $self->{cgi}->server_name();
    my $serverPort   = $self->{cgi}->server_port();
    my $ipaddr       = gethostbyname $host;
    my $serverIPaddr = gethostbyname $serverName;

    # avoid internal loops
    if ( $port == $serverPort and $ipaddr eq $serverIPaddr ) {
        return $self->setError(<<"ERROR");
Potential circular reference in request to
<blockquote><pre>
From: $serverName:$port
To:   $host:$port
</pre></blockquote>
ERROR
    }

    local *SOCK;
    my $packaddr = pack 'S n a4 x8', Socket::AF_INET, $port, $ipaddr;
    socket SOCK, Socket::PF_INET, Socket::SOCK_STREAM, getprotobyname('tcp');
    connect SOCK, $packaddr or return $self->setError(<<"ERROR");
Could not connect to $host:$port
ERROR

    # use syswrite to avoid buffering
    syswrite SOCK,
      join(
        "\015\012" => "GET $path HTTP/1.0",
        "Host: $host",
        "User-Agent: CGI/1.0",
        "",
        ""
      );

    # get buffer, handle timeout too
    # use die handler for timeouts etc
    my ( $buf, $n ) = ( "", undef );
    local $SIG{'__DIE__'} = sub {
        undef $n;
        $self->hasError() or $self->setError(<<"ERROR");
Timeout ($timeout sec)
ERROR
    };

    eval {
        local $SIG{ALRM} = sub { die "TIMEOUT\n"; };    # NB: '\n' required
        alarm $timeout;

        1 while $n = sysread( SOCK, $buf, 8 * 1024, length($buf) );
        alarm 0;
    };

    defined $n or return undef;

    $buf =~ s{^HTTP/(\d+\.\d+)\s+(\d+)\s*([^\012\015]*)\015?\012}{}
      or return undef;

    my ( $ver, @response ) = ( $1, $2, $3 );  # http-version, status and message

    # only deal with status "200 OK"
    $response[0] == 200 or return $self->setError(<<"ERROR");
Remote server reported status
<blockquote><pre>HTTP/$ver @response</pre></blockquote>
ERROR

    # remove header, but extract information too
    $buf =~ s{^(.+?)\015?\012\015?\012}{}s or return undef;
    my $head = $1;

    # extract Content-Type from header
    my %header;
    for ( split /\015?\012/, $head ) {
        if ( my ($v) = m{^Content-Type:\s*(.+?)\s*$}i ) {
            $header{'Content-Type'} = $v;
            last;
        }
    }

    # calculate Content-Length
    $header{'Content-Length'} = length $buf;

    return [ \@response, \%header, $buf ];
}

#
# get cluster settings from config/config.xml file
#
# Return: SELF
#
sub updateClusterConfig {
    my ($self) = @_;
    my $configFile = "$webappPath/config/config.xml";

    my ($mtime) = ( lstat $configFile )[9] || 0;

    local ( *CONFIG, $_, $/ );    ## slurp mode
    if (    $mtime
        and $mtime > ( $mtime{config} ||= 0 )
        and -f $configFile
        and open CONFIG, $configFile )
    {

        # reset paths, assign new modification time
        $mtime{config} = $mtime;
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

            my %attr = $self->parseXMLattrib($attr);
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
            %attr = $self->parseXMLattrib($attr);

            # remove unneed/unwanted attributes
            delete $attr{name};
        }

        my $enabled = delete $attr{enabled};
        if ( $enabled and $enabled eq "false" ) {
            %attr = ();
        }
        else {
            $clusterPaths{default} = {%attr};
        }
    }

    return $self;
}

#
# output <?xml .. ?> processing-instruction
# with mozilla-style <?xslt-param name=.. ?> processing-instructions
# and  <?stylesheet ... ?> processing-instruction
#
# Prototype ->xmlProlog( param => value, ... )
#
# Return: String
#
sub xmlProlog {
    my $self  = shift;
    my %param = ( %{ $self->{xslt} }, @_ );

    # special treatment for these
    my $encoding = delete $param{encoding} || "utf-8";
    my $disabled   = delete $param{rawxml} ? "no-" : "";
    my $stylesheet = delete $param{stylesheet};

    my $prolog = qq{<?xml version="1.0" encoding="$encoding"?>\n};
    for ( keys %param ) {
        if ( defined $param{$_} and length $param{$_} ) {
            $prolog .= qq{<?xslt-param name="$_" value="$param{$_}"?>\n};
        }
    }

    if ($stylesheet) {
        $prolog .=
qq{<?${disabled}xml-stylesheet type="$contentTypes{xsl}" href="$stylesheet"?>\n};
    }

    $prolog;
}

#
# execute a shell-type of command with a error 404 on timeout or other error
#
# Return: Array or String (of content)
#
sub shellCmd {
    my ( $self, @command ) = @_;
    my $timeout = $timeout{shell} || 5;

    if ( not @command ) {
        my ( $line, $sub ) = ( caller(1) )[ 2, 3 ];

        return $self->setError(<<"ERROR");
$sub (line $line): Shell->cmd with an undefined query
ERROR
    }

    my ( @lines, $redirected, $pid );

    # die handler for timeouts etc
    local $SIG{'__DIE__'} = sub {
        kill 9, $pid if $pid;    # kill off truant child as well

        $self->hasError() or $self->setError(<<"ERROR");
Timeout ($timeout sec) or error when executing command:
<blockquote><pre>@command</pre></blockquote>
ERROR
    };

    # command evaluation
    local ( *OLDERR, $@ );
    eval {
        local $SIG{ALRM} = sub { die "TIMEOUT\n"; };    # NB: '\n' required
        alarm $timeout;

        local *PIPE;
        open OLDERR, ">&", \*STDERR and $redirected++;
        open STDERR, ">/dev/null";

        # open without shell (fork)
        $pid = open PIPE, '-|', @command;
        if ($pid) {
            @lines = <PIPE>;
        }
        close PIPE;

        die "(EE) ", @lines if $?;
        alarm 0;
    };

    # restore stderr
    open STDERR, ">&OLDERR" if $redirected;

    # eval errors are handled via the previous die handler
    wantarray ? @lines : join '' => @lines;
}

#
# Execute <sge_root>/bin/<arch>/cmd with a timeout.
# For security, only allow absolute paths.
#
# Prototype ->gridEngineCmd(clusterName, command => [command args] )
#
# %clusterPaths must be up-to-date before calling
#
# Return: String (of content)
#
sub gridEngineCmd {
    my ( $self, $cluster, $cmd, @cmdArgs ) = @_;
    my ( $root, $cell, $arch );

    ## programming error
    $cmd or return $self->setError(<<"ERROR");
gridEngineCmd called without a command - this is a programming error
ERROR

    $cluster ||= '';

    # get root/cell from config information,
    # allow 'default' to use pre-configured value
    if (    exists $clusterPaths{$cluster}
        and exists $clusterPaths{$cluster}{root} )
    {
        $root = $clusterPaths{$cluster}{root};
        $cell = $clusterPaths{$cluster}{cell};
        $arch = $clusterPaths{$cluster}{arch};
    }
    elsif ( $cluster eq "default" ) {
        $root = $sge_root;
    }
    $root ||= '';
    $cell ||= "default";    # fallback
    $arch ||= $sge_arch;    # fallback

    # need root + cell directory
    -d $root and $root =~ m{^/} and -d "$root/$cell"
      or return $self->setError(<<"ERROR");
Root or Cell directory does not exist for cluster <em>$cluster</em>
<blockquote><pre>
SGE_ROOT="$root"
SGE_CELL="$cell"
arch="$arch"
</pre></blockquote>
while executing command:
<blockquote><pre>$cmd @cmdArgs</pre></blockquote>
ERROR

    #
    # resolve cmd in the <sge_root>/bin/<arch>/ directory
    #
    my $cmdPath = "$root/bin/$arch/$cmd";

    -f $cmdPath and -x _ or return $self->setError(<<"ERROR");
For cluster <em>$cluster</em>
<blockquote><pre>
SGE_ROOT="$root"
SGE_CELL="$cell"
arch="$arch"
</pre></blockquote>
Could not resolve command
<blockquote><pre>
$root/bin/$arch/
$cmd @cmdArgs
</pre></blockquote>
ERROR

    # localizing is a good idea, but seems to fail?!
    $ENV{SGE_ROOT} = $root;
    $ENV{SGE_CELL} = $cell;

    my $libDir = "$root/lib/$arch";
    if ( $libEnvName and -d $libDir ) {
        $ENV{$libEnvName} = $libDir;
    }

    # execute shell command
    my $content = $self->shellCmd( $cmdPath, @cmdArgs );

    $content =~ s{</*>\s*}{}g if $content;    # cleanup incorrect XML
    $content;
}

#
# Search cache-{clusterName}/ and cache/ for cache files. If this
# fails, attempt the fallback command.
# If the first parameter of the fallback command is a code reference,
# call directly with the remaining arguments.
#
# Prototype ->xmlFromCache(clusterName, cacheName, [command] )
#
# Return: String (of content)
#
sub xmlFromCache {
    my ( $self, $cluster, $cacheName, $altCmd ) = @_;

    $cacheName =~ s{\.xml$}{};

    my $cacheFile;
    for (
          ( not $cluster or $cluster eq "default" )
        ? ("cache/$cacheName")
        : ( "cache-$cluster/$cacheName", "cache/$cacheName~$cluster", )
      )
    {
        my $x = "$webappPath/$_.xml";

        if ( -f $x ) {
            $cacheFile = $x;
            last;
        }
    }

    my $content = '';

    if ($cacheFile) {
        local ( *XMLFILE, $/ );    ## slurp mode
        if ( open XMLFILE, $cacheFile ) {
            $content = <XMLFILE>;
        }
    }
    elsif ( $cluster
        and exists $clusterPaths{$cluster}
        and exists $clusterPaths{$cluster}{baseURL} )
    {
        ## url may or may not have trailing slash
        ( my $url = "$clusterPaths{$cluster}{baseURL}" ) =~ s{/+$}{};
        $url .= "/$cacheName.xml";

        # getHTTP returns [ \@response, \%header, $buf ]
        my $got = $self->getHTTP("$url");
        if ( ref $got eq "ARRAY" ) {
            $content = $got->[2];
        }
        else {
            return $self->setError(<<"ERROR");
<br/>Error while fetching <blockquote><pre>$url</pre></blockquote>
ERROR
        }
    }
    elsif ( ref $altCmd eq "ARRAY" ) {
        my ( $cmd, @cmdArgs ) = @$altCmd;

        if ( ref $cmd eq "CODE" ) {
            ## code ref gets called directly
            $content = &$cmd(@cmdArgs);
        }
        else {
            ## array ref gets called via command generator
            $content = $self->shellCmd( $cmd, @cmdArgs );
        }
    }

    if ($content) {
        ## strip <?xml ...?>  --  or else have problems later!
        $content =~ s{^\s*<\?xml[^?]+\?>\s*}{}sx;

        # we could also do a simple check for non-truncated content?
    }
    elsif ( not $self->hasError() ) {
        return $self->setError( "xmlFromCache line ", (caller)[2] );
    }

    $content;
}

#
# serve a static file, default is UTF-8
#
# Return: N/A
#
sub serveFile {
    my ( $self, $file, %header ) = @_;
    my $cgi = $self->{cgi};
    $header{-charset} ||= 'utf-8';

    my ($sz) = ( stat "$file" )[7];
    if ( $sz and -f _ and -r _ ) {
        my $buf;
        local *FILE;
        if ( sysopen FILE, $file, 0 ) {
            binmode FILE;
            print $self->{cgi}->header( %header, -content_length => $sz );
            while ( sysread FILE, $buf, 1024 ) {
                print $buf;
            }
            return;
        }
    }

    # not found, readable or no size
    $self->httpError404(<<"ERROR");
Could not resolve backend file
<blockquote><pre>$file</pre></blockquote>
ERROR
}

#
# serve XML with a prolog
#
# Return: N/A
#
sub serveXMLwithProlog {
    my ( $self, %param ) = @_;
    my $cgi = $self->{cgi};

    # there might be errors getting contents
    my $content = $param{-content} || '';

    # catch previous errors
    if ( $self->hasError() or not $content ) {
        $self->httpError404();
    }
    else {
        my $prolog = $self->xmlProlog( %{ $param{-prolog} || {} } );

        print    #
          $self->{cgi}->header( -type => 'text/xml', -charset => 'utf-8' ),    #
          $prolog, $content;
    }
}

# -----------------------------------------------------------------------------
# general service routines
#

# get xml content from an file and stripping the <?xml ... ?>
# processing-instructions, since the file contents are likely to be
# inserted after a stylesheet instruction
#
# Prototype xmlFromFile( fileName )
# ---------------------------------------------
sub xmlFromFile {
    my ( $self, $fileName ) = @_;

    my $content;
    local ( *XMLFILE, $/ );    ## slurp mode
    if ( open XMLFILE, "$webappPath/$fileName" ) {
        $content = <XMLFILE>;

        # strip <?xml version="1.0" encoding="utf-8"?>}
        $content =~ s{^\s*<\?xml[^?]+\?>\s*}{}sx;

        # we could also do a simple check for non-truncated content
    }

    $content ? $content : "<fileNotFound>$fileName</fileNotFound>\n";
}

#
# provide similar output to Apache Cocoon Directory Generator
# but with depth=1 and limited to (png|xml|xsl) files
# didn't bother with full compatibility, attributes etc, since none of
# it is used in our transformations
#
# also don't bother sorting the entries
# ---------------------------------------------
sub directoryGenerator {
    my ( $self, $dir ) = @_;

    my $content =
qq{<dir:directory xmlns:dir="http://apache.org/cocoon/directory/2.0" name="$dir">\n};

    local ( *DIR, *SUBDIR );
    if ( opendir DIR, "$webappPath/$dir" ) {
        while ( my $f = readdir DIR ) {
            if ( -f "$webappPath/$dir/$f" and $f =~ /^.+\.(png|xml|xsl)$/ ) {
                $content .= qq{<dir:file name="$f"/>\n};
            }
        }
    }

    qq{$content</dir:directory>\n};
}

# special purpose Directory Generator
#
# max depth=2, limit first level to cache, cache-* directories
# and limit second level to (xml) files only
#
# also don't bother sorting the entries
# ---------------------------------------------
sub directoryGeneratorCacheFiles {
    my ($self) = @_;
    my $content =
qq{<dir:directory xmlns:dir="http://apache.org/cocoon/directory/2.0" name="cache">\n};

#      qq{<dir:directory xmlns:dir="http://apache.org/cocoon/directory/2.0">\n};

    local ( *DIR, *SUBDIR );
    if ( opendir DIR, $webappPath ) {
        while ( my $subDir = readdir DIR ) {
            my $thisDir = "$webappPath/$subDir";
            if ( $subDir =~ /^cache(-.+)?$/ and -d $thisDir ) {
                $content .= qq{<dir:directory name="$subDir">\n};

                if ( opendir SUBDIR, $thisDir ) {
                    while ( my $f = readdir SUBDIR ) {
                        if ( $f =~ /^.+\.xml$/ and -f "$thisDir/$f" ) {
                            $content .= qq{<dir:file name="$f"/>\n};
                        }
                    }
                }
                $content .= qq{</dir:directory>\n};
            }
        }
    }

    qq{$content</dir:directory>\n};
}

#
# main handler can also be called directly without an initial 'new'
#
sub process {
    my ( $class, $cgi ) = @_;
    my $self = ref $class ? $class : $class->new();

    # some convenient variables for commonly used ENV values
    # - prefix for redirection
    # - CGI PATH_INFO
    my ( $prefix, $pathInfo ) = ( $cgi->script_name(), $cgi->path_info(), );

    $self->reset( cgi => $cgi );
    $self->parseRequestString( $ENV{QUERY_STRING} );

    # stylesheet can be disabled upon request
    if ( exists $self->{switch}{rawxml} or delete $self->{param}{rawxml} ) {
        $self->{xslt}{rawxml} = "true";
    }

    #
    # Fundamental re-direct rules first
    # ---------------------------------

    #    /<webapp>
    # or /<webapp>/cluster
    # or /<webapp>/cluster/
    # -> /<webapp>/
    if ( not defined $pathInfo or $pathInfo =~ m{^(/cluster/*)?$} ) {
        print $cgi->redirect("$prefix/");
        return;
    }

    # the file paths must exist
    # give diagnosis of what is missing or mis-configured:
    -d $webappPath
      or return $self->httpError404(<<"ERROR");
Possible installation error for handler <blockquote><pre>$prefix</pre></blockquote>
The underlying web-app path:
<blockquote>$webappPath</blockquote>
does not seem to exist.
ERROR

    if ($Debug) {
        print STDERR "processing ", $cgi->request_uri(), "\n";
        print STDERR "resource handler: $pathInfo\n";
    }

    #
    # resource handler for /<webapp> path
    #
    # ------------------------------

    # update what we know about the cluster configuration
    $self->updateClusterConfig();

    #
    # direct serving of qhost/qstat information
    # These can be provided without the xslt files
    # --------------------------------------------
    #    /<webapp>/qhost.xml
    #    /<webapp>/qstat.xml
    #    /<webapp>/qstatf.xml
    #    /<webapp>/qstatj.xml
    #
    if ( $pathInfo =~ m{^/(qhost|qstat[fj]?)\.xml$} ) {
        my ( $function, $clusterName ) = ( $1, "default" );

        if ($Debug) {
            warn "function: $function\n";
            warn "clusterName: $clusterName\n";
        }

        if ( exists $gridEngineQuery{$function} ) {
            if ($Debug) {
                warn "gridEngineQuery { $function }\n";
            }

            $self->serveXMLwithProlog(    #
                -content => $self->xmlFromCache(    #
                    $clusterName,                   #
                    $function =>
                      [ $gridEngineQuery{$function}, $self, $clusterName ]
                )
            );
        }

        return;
    }

    # silently disable stylesheets if the xsl/ directory is missing
    # this can help with minimal installations
    -d "$webappPath/xsl" or $self->{xslt}{rawxml} = "true";

    #
    # re-direct rules first
    # ---------------------

    #    /<webapp>/cluster/{clusterName}
    # -> /<webapp>/cluster/{clusterName}/jobs
    if ( $pathInfo =~ m{^/cluster/([^\s/]+?)/*$} ) {
        my ($clusterName) = ($1);
        $pathInfo =~ s{/+$}{};

        # redirect for known clusters (excluding "default")
        if ( exists $clusterPaths{$clusterName} ) {
            print $cgi->redirect("$prefix$pathInfo/jobs");
        }
        else {
            $self->setErrorUnknownCluster($clusterName)->httpError404();
        }
        return;
    }

    # path rewriting for static files - remap relative paths transparently
    #
    # With the CGI handler, relative files included via XSL likely have
    # the wrong prefix
    #
    #    /<webapp>/.../css/.../*.(css|png)
    #    /<webapp>/..../javascript/*.js
    #    /<webapp>/..../xsl/*.xsl
    # etc
    # -> /<webapp>/css/.../*.(css|png) etc
    if (
           $pathInfo =~ m{/xsl/((?:css|javascript)/.+\.(css|js|png))$}x
        or $pathInfo =~ m{/(
            (?:config|css|javascript|x[ms]l)/.+\.(css|js|png|x[ms]l))
              $}x
      )
    {
        $self->serveFile( "$webappPath/$1", -type => $contentTypes{$2} );

        return;
    }

    #
    #  /<webapp>/
    #  /<webapp>/index.xml
    #
    if ( $pathInfo =~ m{^/(?:index(\.xml))?$} ) {
        $self->{xslt}{urlExt} = $1 if $1;

        $self->serveXMLwithProlog(    #
            -prolog => {              #
                "server-info" => $self->{cgi}->server_software(),
                stylesheet    => "xsl/index-xhtml.xsl",
            },
            -content => $self->directoryGeneratorCacheFiles()
        );

        return;
    }

    #
    #  /<webapp>/cache
    #
    if ( $pathInfo =~ m{^/cache$} ) {
        $self->serveXMLwithProlog(    #
            -prolog => {              #
                dir        => "cache",
                stylesheet => "xsl/directory-xhtml.xsl"
            },
            -content => $self->directoryGeneratorCacheFiles()
        );

        return;
    }

    #
    # create directory listings
    #  /<webapp>/config
    #  /<webapp>/xsl
    #
    if ( $pathInfo =~ m{^/(config|xsl)$} ) {
        my $dir = $1;

        $self->serveXMLwithProlog(    #
            -prolog => {              #
                stylesheet => "xsl/directory-xhtml.xsl"
            },
            -content => $self->directoryGenerator($dir)
        );

        return;
    }

    #
    # /<webapp>/info/*
    #
    if ( $pathInfo =~ m{^/(info/.+)\.html$} ) {
        my $file = "xml/$1.xml";

        $self->serveXMLwithProlog(    #
            -prolog => {              #
                stylesheet => "/xsl/info-to-xhtml.xsl"
            },
            -content => $self->xmlFromFile($file)
        );

        return;
    }

    #
    # /<webapp>/cluster/{clusterName}/{function}(.xml)
    #
    if ( $pathInfo =~ m{^/cluster/([^\s/]+?)/([^\s/]+?)(\.xml)?/*$} ) {
        my ( $clusterName, $function, $urlExt ) = ( $1, $2, $3 );

        $self->{xslt}{urlExt}      = $urlExt if $urlExt;
        $self->{xslt}{clusterName} = $clusterName;

        # redirect for known clusters (excluding "default")
        exists $clusterPaths{$clusterName}
          or return $self->setErrorUnknownCluster($clusterName)->httpError404();

        #
        # job : with optional user=... filter
        #
        if ( $function eq "jobs" ) {
            if ( defined $self->{param}{user}
                and $self->{param}{user} =~ m{^\w+$} )
            {
                $self->{xslt}{filterByUser} = $self->{param}{user};
            }

            $self->serveXMLwithProlog(    #
                -prolog => {              #
                    stylesheet => "xsl/qstat-xhtml.xsl"
                },
                -content => $self->xmlFromCache(    #
                    $clusterName,                   #
                    qstat => undef
                ),
            );

            return;
        }

        #
        # jobinfo : with optional jobId
        #
        if ( $function eq "jobinfo" ) {
            my ($jobId) = grep { $_ and /^\d+/ } keys %{ $self->{switch} };

            $self->serveXMLwithProlog(    #
                -prolog => {              #
                    stylesheet => "xsl/qstatj-xhtml.xsl"
                },
                -content => $self->xmlFromCache(    #
                    $clusterName,                   #
                    qstatj =>
                      [ $gridEngineQuery{qstatj}, $self, $clusterName, $jobId ]
                ),
            );
            return;
        }

        #
        # queues : with optional renderMode (summary|free|warn)
        #
        if ( $function eq "queues" ) {
            ( $self->{xslt}{renderMode} ) =
              grep { m{^(summary|free|warn)$} } keys %{ $self->{switch} };

            $self->serveXMLwithProlog(    #
                -prolog => {              #
                    stylesheet => "xsl/qhost-xhtml.xsl"
                },
                -content => $self->xmlFromCache(    #
                    $clusterName,                   #
                    qhost => undef
                ),
            );

            return;
        }

        #
        # resources : display licenses etc
        #
        if ( $function eq "resources" ) {
            $self->serveXMLwithProlog(              #
                -prolog => {                        #
                    stylesheet => "xsl/qlic-xhtml.xsl"
                },
                -content => $self->xmlFromCache(    #
                    $clusterName,                   #
                    qlicserver => undef
                ),
            );

            return;
        }

        #
        # cache : display directory of cluster cache files
        #
        if ( $function eq "cache" ) {
            $self->serveXMLwithProlog(              #
                -prolog => {                        #
                    prefix     => ".",
                    stylesheet => "xsl/directory-xhtml.xsl",
                },
                -content => $self->directoryGenerator("cache-$clusterName"),
            );

            return;
        }

        # *.xml specified - attempt to serve cached file
        if ( delete $self->{xslt}{urlExt} ) {
            $self->serveXMLwithProlog(              #
                -content => $self->xmlFromCache(    #
                    $clusterName, $function
                ),
            );

            return;
        }

        return $self->httpError404(
            "/<webapp>/cluster/{clusterName}/{function}(.xml)");
    }

    # top-level rendering again
    # -------------------------

    #
    # special handling for
    # qstatf.xml, qstatf[@~].xml and qstatf[@~]{clusterName}.xml
    #
    if (   $pathInfo =~ m{^/(qstatf)[@~]([^\s/]*)\.xml$}
        or $pathInfo =~ m{^/(qstatf)\.xml$} )
    {
        my ( $function, $clusterName ) = ( $1, $2 );

        if ($Debug) {
            warn "function: $function\n";
            warn "clusterName: $clusterName\n";
        }

        #
        # raw qstat -f query
        #
        if ( $function eq "qstatf" ) {
            $self->serveXMLwithProlog(    #
                -prolog => {              #
                    clusterName => $clusterName,
                    rawxml      => "true",
                },
                -content => $self->xmlFromCache(    #
                    $clusterName,                   #
                    qstatf => [ $gridEngineQuery{qstatf}, $self, $clusterName ]
                ),
            );

            return;

        }
    }

    if (   $pathInfo =~ m{^/cache/[^\s/]+\.xml$}
        or $pathInfo =~ m{^/cache-[^\s/]+/[^\s/]+\.xml$} )
    {
        ( my $file = $pathInfo ) =~ s{^/}{};
        $self->serveXMLwithProlog(    #
            -content => $self->xmlFromFile($file)
        );

        return;
    }

    #
    #    /<webapp>/(resource|jobs|..)[@~]{clusterName}(.xml)
    # or /<webapp>/(resource|jobs|..)(.xml)
    #
    if (   $pathInfo =~ m{^/(\w+)[@~]([^\s/]*?)(\.xml)?$}
        or $pathInfo =~ m{^/(\w+)(\.xml)?$} )
    {
        my ( $function, $clusterName, $urlExt ) = ( $1, $2, $3 );

        $self->{xslt}{urlExt}      = $urlExt if $urlExt;
        $self->{xslt}{clusterName} = $clusterName;
        $self->{xslt}{menuMode}    = "qstatf";

        if ($Debug) {
            warn "function: $function\n";
            warn "clusterName: $clusterName\n";
        }

        #
        # job : with optional user=... filter
        #
        if ( $function eq "jobs" ) {
            if ( defined $self->{param}{user}
                and $self->{param}{user} =~ m{^\w+$} )
            {
                $self->{xslt}{filterByUser} = $self->{param}{user};
            }

            $self->serveXMLwithProlog(    #
                -prolog => {              #
                    renderMode => "jobs",
                    stylesheet => "xsl/qstatf-xhtml.xsl",
                },
                -content => $self->xmlFromCache(    #
                    $clusterName,                   #
                    qstatf => [ $gridEngineQuery{qstatf}, $self, $clusterName ]
                ),
            );

            return;
        }

        #
        # jobinfo : with optional jobId
        #
        if ( $function eq "jobinfo" ) {
            my ($jobId) = grep { $_ and /^\d+/ } keys %{ $self->{switch} };

            $self->serveXMLwithProlog(    #
                -prolog => {              #
                    stylesheet => "xsl/qstatj-xhtml.xsl",
                },
                -content => $self->xmlFromCache(    #
                    $clusterName,                   #
                    qstatj =>
                      [ $gridEngineQuery{qstatj}, $self, $clusterName, $jobId ]
                ),
            );

            return;
        }

        #
        # queues : with optional renderMode (summary|free|warn)
        #
        if ( $function eq "queues" ) {
            ( $self->{xslt}{renderMode} ) =
              grep { m{^(summary|free|warn)$} } keys %{ $self->{switch} };

            # default is "queues", but state it explicitly anyhow
            $self->{xslt}{renderMode} ||= "queues";

            $self->serveXMLwithProlog(    #
                -prolog => {              #
                    stylesheet => "xsl/qstatf-xhtml.xsl",
                },
                -content => $self->xmlFromCache(    #
                    $clusterName,                   #
                    qstatf => [ $gridEngineQuery{qstatf}, $self, $clusterName ]
                ),
            );

            return;
        }

        #
        # report : renderMode 'report'
        #
        if ( $function eq "report" ) {
            $self->serveXMLwithProlog(              #
                -prolog => {                        #
                    renderMode => "report",
                    stylesheet => "xsl/qstatf-xhtml.xsl",
                },
                -content => $self->xmlFromCache(    #
                    $clusterName,                   #
                    qstatf => [ $gridEngineQuery{qstatf}, $self, $clusterName ]
                ),
            );

            return;
        }

        #
        # resources : display licenses etc
        #
        if ( $function eq "resources" ) {
            $self->serveXMLwithProlog(              #
                -prolog => {                        #
                    stylesheet => "xsl/qlic-xhtml.xsl",
                },
                -content => $self->xmlFromCache(    #
                    $clusterName,                   #
                    qlicserver => undef
                ),
            );

            return;
        }

    }

    return $self->httpError404();
}

# -----------------------------------------------------------------------------
# Main loop
# -----------------------------------------------------------------------------
package main;

while ( my $cgiObj = $whichCGI->new() ) {

    # no-parsed-headers
    # * when the script has a 'nph-' prefix
    # * or when using HTTPi, which only supports no-parsed-headers
    if ( $0 =~ m{/nph-[^/]*$}
        or ( $cgiObj->server_software() || '' ) =~ m{^HTTPi/}i )
    {
        $cgiObj->nph(1);
    }

    GridResource->process($cgiObj);

    last if $whichCGI eq 'CGI';    # normal CGI - break out of while loop
}

1;

# ----------------------------------------------------------------- end-of-file
