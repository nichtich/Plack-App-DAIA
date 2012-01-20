use strict;
use warnings;

use Test::More;
use Plack::App::DAIA::Test;

daia_test_suite( 't/docid.json', server => './app.psgi', ids => [ 'foo:bar' ] );

done_testing;
