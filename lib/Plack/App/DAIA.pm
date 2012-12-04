use strict;
use warnings;
package Plack::App::DAIA;
#ABSTRACT: DAIA Server as Plack application

use v5.10.1;

use parent 'Plack::Component';
use LWP::Simple qw(get);
use Encode;
use JSON;
use DAIA;
use Scalar::Util qw(blessed);

use Plack::Util::Accessor qw(xslt warnings code idformat initialized html);
use Plack::Middleware::Static;
use File::ShareDir qw(dist_dir);

use Plack::Request;

our %FORMATS  = DAIA->formats;

sub prepare_app {
    my $self = shift;
    return if $self->initialized;

    $self->warnings(1) unless defined $self->warnings;
    $self->idformat(qr{^.*$}) unless defined $self->idformat;

    $self->init;

    if ($self->html) {
        $self->html( Plack::Middleware::Static->new(
            path => qr{daia\.(xsl|css|xsd)$|xmlverbatim\.xsl$|icons/[a-z0-9_-]+\.png$},
            root => dist_dir('Plack-App-DAIA')
        ));
        $self->xslt( 'daia.xsl' ) unless $self->xslt; # TODO: fix base path
    }

    $self->initialized(1);
}

sub init {
    # initialization hook
}

sub call {
    my ($self, $env) = @_;
    my $req = Plack::Request->new($env);

    my $id = $req->param('id') // '';
    my $invalid_id = '';
    my %parts;

    if ( $self->html and $id eq '' ) {
        my $resp = $self->html->_handle_static( $env );
        if ($resp and $resp->[0] eq 200) {
            return $resp;
        }
    }

    if ( $id ne '' and ref $self->idformat ) {
        if ( ref $self->idformat eq 'Regexp' ) {
            if ( $id =~ $self->idformat ) {
                %parts = %+; # named capturing groups
            } else {
                $invalid_id = $id;
                $id = "";
            }
        }
    }

    my $format = lc($req->param('format') || "");

    if (!$format) {
        # TODO: guess format via content negotiation
    }
    
    my $status = 200;
    my $daia = $self->retrieve( $id, %parts );

    if (!$daia) {
        $daia = DAIA::Response->new;
        $status = 500;
    }

    if ( $self->warnings ) {
        if ( $invalid_id ne '' ) {
            $daia->addMessage( 'en' => 'unknown identifier format', errno => 400 );
        } elsif ( $id eq ""  ) {
            $daia->addMessage( 'en' => 'please provide a document identifier', errno => 400 );
        }
    }

    $self->as_psgi( $status, $daia, $format, $req->param('callback') );
}

sub retrieve {
    my $self = shift;
    return $self->code ? $self->code->(@_) : undef;
}

sub as_psgi {
    my ($self, $status, $daia, $format, $callback) = @_;
    my ($content, $type);

    $type = $FORMATS{$format} unless $format eq 'xml';
    $content = $daia->serialize($format) if $type;

    if (!$content) {
        $type = "application/xml; charset=utf-8";
        if ( $self->warnings ) {
            if ( not $format ) {
                $daia->addMessage( 'en' => 'please provide an explicit parameter format=xml', 300 );
            } elsif ( $format ne 'xml' ) {
                $daia->addMessage( 'en' => 'unknown or unsupported format', 300 );
            }
        }
        $content = $daia->xml( header => 1, xmlns => 1, ( $self->xslt ? (xslt => $self->xslt) : () )  );
    } elsif ( $type =~ qr{^application/javascript} and ($callback || '') =~ /^[\w\.\[\]]+$/ ) {
        $content = "$callback($content)";
    }

    return [ $status, [ "Content-Type" => $type ], [ encode('utf8',$content) ] ];
}

1;

=head1 SYNOPSIS

To quickly hack a DAIA server, create a simple C<app.psgi>:

    use Plack::App::DAIA;

    Plack::App::DAIA->new( code => sub {
        my $id = shift;
        # ...construct and return DAIA object
    } );

However, you should better derive from this class:
 
    package Your::App;
    use parent 'Plack::App::DAIA';

    sub retrieve {
        my ($self, $id, %parts) = @_;

        # construct DAIA object (you must extend this in your application)
        my $daia = DAIA::Response->new;

        return $daia;
    };

    1;

Then create an C<app.psgi> that returns an instance of your class:

    use Your::App;
    Your::App->new;

You can also mix this application with L<Plack> middleware.
   
It is highly recommended to test your services! Testing is made as easy as
possible with the L<provedaia> command line script.

This module contains a dummy application C<app.psgi> and a more detailed
example C<examples/daia-ubbielefeld.pl>.

=head1 DESCRIPTION

This module implements a L<DAIA> server as PSGI application. It provides 
serialization in DAIA/XML and DAIA/JSON and automatically adds some warnings
and error messages. The core functionality must be implemented by deriving
from this class and implementing the method C<retrieve>. The following
serialization formats are supported by default:

=over 4

=item B<xml>

DAIA/XML format (default)

=item B<json>

DAIA/JSON format

=item B<rdfjson>

DAIA/RDF in RDF/JSON.

=back

In addition you get DAIA/RDF in several RDF formats (C<rdfxml>, 
C<turtle>, and C<ntriples> if L<RDF::Trine> is installed. If L<RDF::NS> is
installed, you also get known namespace prefixes for RDF/Turtle format.
Furthermore the output formats C<svg> and C<dot> are supported if
L<RDF::Trine::Exporter::GraphViz> is installed to visualize RDF graphs 
(you may need to make sure that C<dot> is in your C<$ENV{PATH}>).

=method new ( [%options] )

Creates a new DAIA server. Supported options are

=over 4

=item xslt

Path of a DAIA XSLT client to attach to DAIA/XML responses. Not set by default
and set to C<daia.xsl> if option C<html> is set. You still may need to adjust
the path if your server rewrites the request path.

=item html

Enable a HTML client for DAIA/XML via XSLT. The client is returned in form of
three files (C<daia.xsl>, C<daia.css>, C<xmlverbatim.xsl>) and DAIA icons, all
shipped together with this module. Enabling HTML client also enables serving
the DAIA XML Schema as C<daia.xsd>.

=item warnings

Enable warnings in the DAIA response (enabled by default).

=item code

Code reference to the C<retrieve> method if you prefer not to create a
module derived from this module.

=item idformat

Optional regular expression to validate identifiers. Invalid identifiers
are set to the empty string before they are passed to the C<retrieve>
method. In addition an error message "unknown identifier format" is
added to the response, if warnings are enabled.

It is recommended to use regular expressions with named capturing groups
as introduced in Perl 5.10. The named parts are also passed to the
C<retrieve method>. For instance:

  idformat => qr{^ (?<prefix>[a-z]+) : (?<local>.+) $}x
  
will give you C<$parts{prefix}> and C<$parts{local}> in the retrieve method.

=item initialized

Stores whether the application had been initialized.

=back

=method retrieve ( $id [, %parts ] )

Must return a status and a L<DAIA::Response> object. Override this method
if you derive an application from Plack::App::DAIA. By default it either
calls the retrieve code, as passed to the constructor, or returns undef,
so a HTTP 500 error is returned.

This method is passed the original query identifier and a hash of named
capturing groups from your identifier format.

=method init

This method is called by Plack::Component::prepare_app, once before the first
request. You can define this method in you subclass as initialization hook, for
instance to set default option values. Initialization during runtime can be
triggered by setting C<initialized> to false.

=method as_psgi ( $status, $daia [, $format [, $callback ] ] )

Serializes a L<DAIA::Response> in some DAIA serialization format (C<xml> by
default) and returns a a PSGI response with given HTTP status code.

=head1 SEE ALSO

Plack::App::DAIA is derived from L<Plack::Component>. Use L<Plack::DAIA::Test>
and L<provedaia> (using L<Plack::App::DAIA::Test::Suite>) for writing tests.
See L<Plack::App::DAIA::Validator> for a DAIA validator and converter.

=cut
