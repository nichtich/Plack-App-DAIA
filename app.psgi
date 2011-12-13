use Plack::Builder;
use Plack::App::DAIA::Validator;

{
    package MyDAIAServer;
    use parent 'Plack::App::DAIA';

    sub retrieve {
        my ($self, $id) = @_;
        my $daia = DAIA::Response->new();

        # construct DAIA object

        return $daia;
    };
}

my $app = MyDAIAServer->new;

builder {
    mount '/validator' => Plack::App::DAIA::Validator->new; 
    mount '/' => $app;
};
