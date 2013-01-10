package SampleDAIAApp;
use parent 'Plack::App::DAIA';

sub IDFORMAT { qr{^foo:.+} };

sub retrieve {
    my ($self, $id, %idparts) = @_;

    my $daia = DAIA::Response->new;

    $daia->addDocument( id => ($id || "foo:default") );

    # construct full response ...

    return $daia;
}

1;
