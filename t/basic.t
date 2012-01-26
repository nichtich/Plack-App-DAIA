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
        like( $res->content, qr{^<\?xml.*xmlns}s, 'XML header and namespace' );

        $res = $cb->(GET "/?id=abc&format=json");
        $daia = eval { DAIA::parse_json( $res->content ); };
        isa_ok( $daia, 'DAIA::Response' );
        
        $res = $cb->(GET "/?id=x");
        $daia = eval { DAIA::parse( $res->content ); };
        like( $daia->json, qr{"please provide an explicit parameter format=xml"}m, "missing format" );

        $res = $cb->(GET "/?id=x\ny&format=xml");
        $daia = eval { DAIA::parse( $res->content ); };
        like( $daia->json, qr{"unknown identifier format"}m, "invalid identifier" );
    };

done_testing;
