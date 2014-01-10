requires 'perl', '>= 5.10.0';
requires 'DAIA','0.43';
requires 'Carp';
requires 'CGI';
requires 'Encode';
requires 'File::ShareDir';
requires 'File::Spec::Functions';
requires 'Getopt::Long';
requires 'HTTP::Request::Common';
requires 'JSON';
requires 'LWP::Simple';
requires 'Plack::Component';
requires 'Plack::Middleware::Static';
requires 'Plack::Request';
requires 'Plack::Test';
requires 'Plack::Util::Accessor';
requires 'Pod::Usage';
requires 'Scalar::Util';
requires 'Test::Builder::Module';
requires 'Test::JSON::Entails';
requires 'Test::More';
requires 'Try::Tiny';
requires 'URI::Escape';

on test => sub {
    requires 'Test::Warn';
};
