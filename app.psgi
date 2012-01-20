use Plack::Builder;
use Plack::App::DAIA::Validator;

{
    package MyDAIAServer;
    use parent 'Plack::App::DAIA';

    sub retrieve {
        my ($self, $id) = @_;
        my $daia = DAIA::Response->new();

        if ($id and $id =~ /^[a-z0-9-]+:/) {
            $daia->document( id => $id );
        }

        return $daia;
    };
}

my $app = MyDAIAServer->new;

builder {
    # TODO: enable RDF::Flow middleware ( make MyDAIAServer a RDF::FLow
    # enable 'RDF::Flow', source => $model; pass_through = 1?
    mount '/validator' => Plack::App::DAIA::Validator->new; 
    mount '/' => $app;
};
