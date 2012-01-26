use strict;
use warnings;
package Plack::App::DAIA;
#ABSTRACT: DAIA Server as Plack application

use parent 'Plack::Component';
use LWP::Simple qw(get);
use Encode;
use JSON;
use DAIA;
use Scalar::Util qw(blessed);

use Plack::Util::Accessor qw(xsd xslt warnings code idformat);
use Plack::Request;

our %FORMATS  = DAIA->formats;
our $IDFORMAT = qr{^.*$};

sub prepare_app {
    my $self = shift;
    $self->warnings(1) unless defined $self->warnings;
    $self->idformat($IDFORMAT) unless defined $self->idformat
}

sub call {
    my ($self, $env) = @_;
    my $req = Plack::Request->new($env);

    my $invalid_id;
    my $id = $req->param('id');
    if ( defined $id and $id ne '' and ref $self->idformat ) {
        if ( ref $self->idformat eq 'Regexp' ) {
            if ( $id !~ $self->idformat ) {
                $invalid_id = $id;
                $id = "";
            }
        }
    }
    $id = "" unless defined $id;

    my $format = lc($req->param('format')) || "";

    if (!$format) {
        # TODO: guess format via content negotiation
    }
    
    my $daia = $self->retrieve( $id );
    my $status = 200;

    if (!$daia) {
        $daia = DAIA::Response->new;
        $status = 500;
    }

    if ( $self->warnings ) {
        if ( defined $invalid_id ) {
            $daia->addMessage( 'en' => 'unknown identifier format', errno => 400 );
        } elsif ( $id eq ""  ) {
            $daia->addMessage( 'en' => 'please provide a document identifier', errno => 400 );
        }
    }

    $self->as_psgi( $status, $daia, $format, $req->param('callback') );
}

sub retrieve {
    my ($self, $id) = @_;
    return $self->code ? $self->code->($id) : undef;
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
    }

    return [ $status, [ "Content-Type" => $type ], [ encode('utf8',$content) ] ];
}

1;

=head1 SYNOPSIS

It is recommended to derive from this class:
 
    package Your::App;
    use parent 'Plack::App::DAIA';

    sub retrieve {
        my ($self, $id) = @_;

        # construct DAIA object (you must extend this in your application)
        my $daia = DAIA::Response->new;

        return $daia;
    };

    1;

Then create an C<app.psgi> that returns an instance of your class:

    use Your::App;
    Your::App->new;

To quickly hack a DAIA server you can also put all into C<app.psgi>:

    use Plack::App::DAIA;
    my $app = Plack::App::DAIA->new( code => sub {
        my $id = shift;
        # ...construct and return DAIA object
    } );
    $app;

This module contains a dummy application C<app.psgi> and a more detailed
example L<daia-ubbielefeld.pl>.

=head1 DESCRIPTION

This module implements a L<DAIA> server as PSGI application. It provides 
serialization in DAIA/XML and DAIA/JSON and automatically adds some warnings
and error messages. The core functionality must be implemented by deriving
from this class and implementing the method C<retrieve>. The following
serialization formats are supported by default:

=over 4

=item xml

DAIA/XML format (default)

=item json

DAIA/JSON format

=item rdfjson

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

Path of a DAIA XSLT client to attach to DAIA/XML responses.

=item xsd

Path of a DAIA XML Schema to validate DAIA/XML response.

=item warnings

Enable warnings in the DAIA response (enabled by default).

=item code

Code reference to the 'retrieve' method if you prefer not to create a
module derived from this module.

=item idformat

Optional regular expression to validate identifiers. Invalid identifiers
are set to the empty string before they are passed to the 'retrieve'
method. In addition an error message "unknown identifier format" is
added to the response, if warnings are enabled.

=back

=method retrieve ( $id )

Must return a status and a L<DAIA::Response> object. Override this method
if you derive an application from Plack::App::DAIA. By default it either
calls the retrieve code, as passed to the constructor, or returns undef,
so a HTTP 500 error is returned.

=method as_psgi ( $status, $daia [, $format [, $callback ] ] )

Serializes a L<DAIA::Response> in some DAIA serialization format (C<xml> by
default) and returns a a PSGI response with given HTTP status code.

=method call

Core method of the L<Plack::Component>. You should not need to override this.

=head1 SEE ALSO

L<Plack::App::DAIA::Validator>, L<Plack::DAIA::Test>.

=cut
