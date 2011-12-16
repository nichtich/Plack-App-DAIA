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

use Plack::Util::Accessor qw(xsd xslt warnings);
use Plack::Request;

our %FORMATS = DAIA->formats;

sub prepare_app {
    my $self = shift;
    $self->warnings(1) unless defined $self->warnings;
}

sub call {
    my ($self, $env) = @_;
    my $req = Plack::Request->new($env);

    my $id = $req->param('id');
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

    if ( $id eq "" and $self->warnings ) {
        $daia->addMessage( 'en' => 'please provide a document identifier', 300 );
    }

    $self->as_psgi( $status, $daia, $format, $req->param('callback') );
}

sub retrieve {
    my ($self, $id) = @_;
    my $daia = response();
    return (200 => $daia);
}

sub as_psgi {
    my ($self, $status, $daia, $format, $callback) = @_;

    my $type    = $FORMATS{$format};
    my $content = $daia->serialize($format) if $type;
    if (!$type) {
        $type = "application/xml; charset=utf-8";
        if ( $self->warnings ) {
            if ( not $format ) {
                $daia->addMessage( 'en' => 'please provide an explicit parameter format=xml', 300 );
            } elsif ( $format ne 'xml' ) {
                $daia->addMessage( 'en' => 'unknown or unsupported format', 300 );
            }
        }
        $content = $daia->xml( ( $self->xslt ? (xslt => $self->xslt) : () )  );
    }

    return [ $status, [ "Content-Type" => $type ], [ encode('utf8',$content) ] ];
}

1;

=head1 SYNOPSIS
 
    package Your::App;
    use parent 'Plack::App::DAIA';

    sub retrieve {
        my ($self, $id) = @_;
        my $daia = DAIA::Response->new();

        # construct DAIA object

        return $daia;
    };

    1;

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
L<RDF::Trine::Exporter::GraphViz> is installed to visualize RDF graphs.

=method new ( [%options] )

Creates a new DAIA server. Known options are

=over 4

=item xslt

Path of a DAIA XSLT client to attach to DAIA/XML responses.

=item xsd

Path of a DAIA XML Schema to validate DAIA/XML response.

=item warnings

Enable warnings in the DAIA response (enabled by default).

=back

=method retrieve ( $id )

Must return a status and a L<DAIA::Response> object. Override this method
if you derive an application from Plack::App::DAIA.

=method as_psgi ( $status, $daia [, $format [, $callback ] ] )

Serializes a L<DAIA::Response> in some DAIA serialization format (C<xml> by
default) and returns a a PSGI response with given HTTP status code.

=method call

Core method of the L<Plack::Component>. You should not need to override this.

=head1 SEE ALSO

L<Plack::App::DAIA::Validator>

=cut
