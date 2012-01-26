use Plack::Builder;
use Plack::App::DAIA::Validator;

{
    # This dummy DAIA server always returns a document 
    # if queried for an alphanumerical identifier
    package MyDAIAServer;
    use parent 'Plack::App::DAIA';

    my $idformat = qr{^[a-z0-9]+$}i;

    sub retrieve {
        my ($self, $id) = @_;
        my $daia = DAIA::Response->new();

        $daia->document( id => $id );

        return $daia;
    };
}

# Run the DAIA server at '/' and a validator at '/validator'

my $app = MyDAIAServer->new;

builder {
    mount '/validator' => Plack::App::DAIA::Validator->new; 
    mount '/' => $app;
};
