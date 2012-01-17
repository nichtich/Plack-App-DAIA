package Plack::App::DAIA::Test;
#ABSTRACT: Test DAIA Servers

use URI::Escape;
use Test::More;
use Plack::Test;
use Plack::App::DAIA;
use Scalar::Util qw(reftype blessed);
use HTTP::Request::Common;

use base qw(Exporter Test::Builder::Module);
our @EXPORT = qw(test_daia_psgi test_daia daia_app if_daia_call);

my $CLASS = __PACKAGE__;

sub test_daia {
    my $app = daia_app(shift) || do {
        $CLASS->builder->ok(0,"Could not construct DAIA application");
        return;
    };
    while (@_) {
        my $id = shift;
        my $code = shift;
        my $res = $app->retrieve($id);
        if (!if_daia_call( $res, $code )) {
            $@ = "The thing isa DAIA::Response" unless $@;
            $CLASS->builder->ok(0, $@);
        }
    }
}

sub test_daia_psgi {
    my $app = daia_app(shift) || do {
        $CLASS->builder->ok(0,"Could not construct DAIA application");
        return;
    };
    while (@_) {
        my $id = shift;
        my $code = shift;
        test_psgi $app, sub {
            my $req = shift->(GET "/?id=".uri_escape($id));
            my $res = eval { DAIA::parse( $req->content ); };
            if ($@) {
                $@ =~ s/DAIA::([A-Z]+::)?[a-z_]+\(\)://ig;
                $@ =~ s/ at .* line.*//g;
                $@ =~ s/\s*$//sg;
            }
            if (!if_daia_call( $res, $code )) {
                $@ = "No valid The thing isa DAIA::Response" unless $@;
                $CLASS->builder->ok(0, $@);
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

sub if_daia_call {
    my ($daia, $code) = @_;
    if ( blessed($daia) and $daia->isa('DAIA::Response') ) {
        local $_ = $daia;
        $code->($daia);
        return $daia;
    }
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

=method daia_app ( $plack_app_daia | $url | $code )

Returns an instance of L<Plack::App::DAIA> or undef. Code references or URLs
are wrapped. For wrapped URLs C<$@> is set on failure.

=method if_daia_call ( $daia, $code )

Call C<$code> with C<$daia> and set as C<$_>, if C<$daia> is a L<DAIA::Response>
and return C<$daia> on success. Return C<undef> otherwise.

=cut
