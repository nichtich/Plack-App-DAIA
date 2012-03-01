use Plack::Builder;
use Plack::App::DAIA::Validator;

{
    # This dummy DAIA server always returns a document if queried for 
    # an identifier that consists of a alphanumerical chars and ':'
    package MyDAIAServer;
    use parent 'Plack::App::DAIA';

    no warnings 'redefine'; # because this is loaded multiple times

    sub init {
        shift->idformat(qr{^[a-z0-9:]+$}i);
    }

    sub retrieve {
        my ($self, $id) = @_;
        my $daia = DAIA::Response->new();

        eval { $daia->document( id => $id ); };

        return $daia;
    };
}

# Run the DAIA server at '/' and a validator at '/validator'

my $app = MyDAIAServer->new;

builder {
    mount '/validator' => Plack::App::DAIA::Validator->new; 
    mount '/' => $app;
};

__END__

foo:123
bar:456

# the response must contain at least one document with the query id
{ "document" : [ { "id" : "$id" } ] }

# warning message expected
{ "message" : [ { "content" : "please provide an explicit parameter format=xml" } ] }
