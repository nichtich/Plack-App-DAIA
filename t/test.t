use strict;
use warnings;

use Test::Builder::Tester tests => 1;
use Test::More;
use Plack::App::DAIA::Test;
use DAIA;

# no valid DAIA response
test_out("not ok 1 - The thing isa DAIA::Response");
test_fail(+1);
test_daia sub { return 1; }, 'my:id' => sub { };

# test_out("not ok 2 - Unknown DAIA serialization format");
# test_fail(+1);
# test_daia_psgi sub { return 1; }, 'my:id' => sub { };

test_test("Plack::App::DAIA::Test works (at least a bit)");

