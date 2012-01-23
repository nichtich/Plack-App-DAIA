use strict;
use warnings;

use Test::Builder::Tester tests => 1;
use Test::More;
use Plack::App::DAIA::Test;
use DAIA;

# no valid DAIA response
test_out("not ok 1 - The thing isa DAIA::Response");
test_fail(+1);
test_daia sub { 1; }, 'my:id' => sub { };

test_out("ok 2 - simple DAIA response");
test_daia 
    sub { DAIA::Response->new; }, 
    'my:id' 
        => { },
    'simple DAIA response';

test_test("Plack::App::DAIA::Test works (at least a bit)");

__END__
daia_test_suite(<<SUITE);
# bla
http://daia.gbv.de/

abc

# invalid identifier warning
{ "message": [ { "content" : "unknown identifier format" } ] }

http://daia.gbv.de/isil/DE-Hil2
ppn:16523315X
{ "document" : [ ] }

SUITE