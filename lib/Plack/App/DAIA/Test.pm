use strict;
use warnings;
package Plack::App::DAIA::Test;
#ABSTRACT: Test DAIA Servers

use base 'Test::Builder::Module';
our @EXPORT = qw(test_daia_psgi test_daia daia_app daia_test_suite);

use URI::Escape;
use Test::More;
use Plack::Test;
use Plack::App::DAIA;
use Scalar::Util qw(reftype blessed);
use Carp;
use HTTP::Request::Common;
use Test::JSON::Entails;

sub test_daia {
    my $app = daia_app(shift) || do {
        __PACKAGE__->builder->ok(0,"Could not construct DAIA application");
        return;
    };
    my $test_name = pop @_ if @_ % 2;
    while (@_) {
        my $id = shift;
        my $expected = shift;
        my $res = $app->retrieve($id);
        if (!_if_daia_check( $res, $expected, $test_name )) {
            $@ = "The thing isa DAIA::Response" unless $@;
            __PACKAGE__->builder->ok(0, $@);
        }
    }
}

sub test_daia_psgi {
    my $app = shift;

    # TODO: load psgi file if string given and allow for URL

    my $test_name = pop @_ if @_ % 2;
    while (@_) {
        my $id = shift;
        my $expected = shift;
        test_psgi $app, sub {
            my $req = shift->(GET "/?id=".uri_escape($id));
            my $res = eval { DAIA::parse( $req->content ); };
            if ($@) {
                $@ =~ s/DAIA::([A-Z]+::)?[a-z_]+\(\)://ig;
                $@ =~ s/ at .* line.*//g;
                $@ =~ s/\s*$//sg;
            }
            if (!_if_daia_check( $res, $expected, $test_name )) {
                $@ = "No valid The thing isa DAIA::Response" unless $@;
                __PACKAGE__->builder->ok(0, $@);
            }
        };
    }
}

sub daia_app {
    my $app = shift;
    if ( blessed($app) and $app->isa('Plack::App::DAIA') ) {
        return $app;
    } elsif ( $app =~ qr{^https?://} ) {
        my $baseurl = $app . ($app =~ /\?/ ? '&id=' : '?id=');
        $app = sub {
            my $id = shift;
            my $url = $baseurl.$id;
            my @daia = eval { DAIA->parse($url) };
            if (!@daia) {
                $@ ||= '';
                if ($@) {
                    $@ =~ s/DAIA::([A-Z]+::)?[a-z_]+\(\)://ig;
                    $@ =~ s/ at .* line.*//g;
                    $@ =~ s/\s*$//sg;
                }
                $@ = "invalid DAIA from $url: $@";
            }
            return $daia[0];
        };
    }
    if ( ref($app) and reftype($app) eq 'CODE' ) {
        return Plack::App::DAIA->new( code => $app );
    }
    return;
}

# Call C<$code> with C<$daia> and set as C<$_>, if C<$daia> is a L<DAIA::Response>
# and return C<$daia> on success. Return C<undef> otherwise.
sub _if_daia_check {
    my ($daia, $expected, $test_name) = @_;
    if ( blessed($daia) and $daia->isa('DAIA::Response') ) {
        if ( (reftype($expected)||'') eq 'CODE') {
            local $_ = $daia;
            $expected->($daia);
        } else {
            local $Test::Builder::Level = $Test::Builder::Level + 2;
            entails $daia->json, $expected, $test_name;
        }
        return $daia;
    }
}

sub daia_test_suite {
    my ($suite, %args) = @_;

    my $test  = __PACKAGE__->builder;
    my @lines;

    if ( ref($suite) ) {
        croak 'usage: daia_test_suite( $file | $glob | $string )'
            unless reftype($suite) eq 'GLOB' or blessed($suite) and $suite->isa('IO::File');
        @lines = <$suite>;
    } elsif ( $suite !~ qr{^https?://} and $suite !~ /[\r\n]/ ) {
        open (SUITE, '<', $suite) or croak "failed to open daia test suite $suite";
        @lines = <SUITE>;
        close SUITE;
    } else {
        @lines = split /\n/, $suite;
    }

    my $line = 0;
    my $comment = '';
    my $json = undef;
    my $server = $args{server};
    my @ids = @{$args{ids}} if $args{ids};

    my $run = sub {
        return unless $server;
        $json ||= '{ }';
        my $server_name = $server;
        if ($server and $server !~ qr{^https?://}) {
            $_ = Plack::Util::load_psgi($server);
            if ( ref($_) ) {
                diag("loaded PSGI from $server");
                $server = $_;
            } else {
                fail("failed to load PSGI from $server");
                return;
            }
        }
        foreach my $id (@ids) {
            my $test_name = "$server_name?id=$id";
            $comment =~ s/^\s+|\s+$//g;
            $test_name .= " ($comment)" if $comment ne '';
            local $Test::Builder::Level = $Test::Builder::Level + 2; # called 2 levels above
            my $test_json = $json;
            $test_json =~ s/\$id/$id/mg;
            if (ref($server)) {
                test_daia_psgi $server, $id => $test_json, $test_name;
            } else {
                test_daia $server, $id => $test_json, $test_name;
            }
        }
    };

    foreach (@lines) { 
        chomp;
        $comment = $1 if /^#(.*)/;
        s/^(#.*|\s+)$//; # empty line or comment
        $line++;

        if (defined $json) {
            $json .= $_;
            if ($_ eq '') {
                $run->();
                @ids = ();
                $json = undef;
                $comment = '';
            }
        } elsif ( $_ eq '' ) {
            next;
        } elsif( $_ =~ qr{^server=(.*)}i ) {
            $comment = '';
            $server = $1;
        } elsif( $_ =~ qr/^\s*{/ ) {
            $json = $_; 
        } else { # identifier
            $comment = '';
            push @ids, $_;
        }
    }
    $run->();
}

1;

=head1 SYNOPSIS

    use Test::More;
    use Plack::App::DAIA::Test;

    use Your::App; # your subclass of Plack::App::DAIA
    my $app = Your::App->new;

    # or wrap a DAIA server
    my $app = daia_app( 'http://your.host/pathtodaia' );

    test_daia $app,
        'some:id' => sub {
            my $daia = shift; # or = $_
            my @docs = $daia->document;
            is (scalar @docs, 1, 'returned one document');
            ...
        },
        'another:id' => sub {
            my $daia = shift;
            ...
        };

    # same usage, shown here with an inline server

    test_daia_psgi 
        sub {
            my $id = shift;
            my $daia = DAIA::Response->new();
            ...
            return $daia;
        },
        'some:id' => sub {
            my $daia = $_; # or shift
            ...
        };

    done_testing;

=head1 DESCRIPTION

This model is experimental, so take care! The current version has different
behaviour for C<test_daia> and C<test_daia_psgi>.

This module exports two methods for testing L<DAIA> servers. You must provide a
DAIA server as code reference or as instance of L<Plack::App::DAIA> and a list
of request identifiers and testing code. The testing code is passed a valid
L<DAIA::Response> object on success (C<$_> is also set to this response).

=method test_daia ( $app, $id1 => sub { }, $id2 => ...  )

Calls a DAIA server C<$app>'s request method with one or more identifiers,
each given a test function.

=method test_daia_psgi ( $app, $id => sub { }, $id => ...  )

Calls a DAIA server C<$app> as L<PSGI> application with one or more
identifiers, each given a test function.

=method daia_test_suite ( $input [ %options ] )

Run a DAIA test suite from a string or stream (GLOB or L<IO::File>). The only
option supported so far is C<server>. A DAIA test suite lists servers,
identifiers, and DAIA/JSON response fragments to test DAIA servers. The command
line client L<provedaia> is included in this distribution, see its
documentation for further details.

=method daia_app ( $plack_app_daia | $url | $code )

Returns an instance of L<Plack::App::DAIA> or undef. Code references or URLs
are wrapped. For wrapped URLs C<$@> is set on failure. This method may be removed
to be used internally only!

=cut