use strict;
use warnings;
use Test::More;
use Plack::Test;
use HTTP::Request::Common;

use Plack::App::DAIA;
use Plack::App::DAIA::Validator;
use DAIA;

my $app = Plack::App::DAIA->new;

test_psgi $app, sub {
        my $cb  = shift;

        my $res = $cb->(GET "/?id=abc");
        my $daia = eval { DAIA::parse_xml( $res->content ); };
        isa_ok( $daia, 'DAIA::Response' );

        $res = $cb->(GET "/?id=abc&format=json");
        $daia = eval { DAIA::parse_json( $res->content ); };
        isa_ok( $daia, 'DAIA::Response' );
    };

done_testing;
