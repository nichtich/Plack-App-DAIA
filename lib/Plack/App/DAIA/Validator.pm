use strict;
use warnings;
package Plack::App::DAIA::Validator;
#ABSTRACT: DAIA validator and converter

use CGI qw(:standard);
use Encode;

use parent 'Plack::App::DAIA';
use Plack::Util::Accessor qw(xsd xslt warnings);

sub call {
    my ($self, $env) = @_;
    my $req = Plack::Request->new($env);

    my $msg = "";
    my $error = "";
    my $url  = $req->param('url') || '';
    my $data = $req->param('data') || '';
    #eval{ $data = Encode::decode_utf8( $data ); }; # icoming raw data is UTF-8

    my $eurl = $url; # url_encode
    $eurl =~ s/([^A-Za-z0-9])/sprintf("%%%02X", ord($1))/seg;

    my $xsd = $self->xsd;

    my $informat  = lc($req->param('in'));
    my $outformat = lc($req->param('out')) || lc($req->param('format'));

    my $callback  = $req->param('callback') || ""; 
    $callback = "" unless $callback =~ /^[a-z][a-z0-9._\[\]]*$/i;

    my @daiaobjs;

    # parse DAIA
    if ( $data ) {
        @daiaobjs = eval { DAIA->parse( data => $data, format => $informat ) };
    } elsif( $url ) {
        @daiaobjs = eval { DAIA->parse( file => $url, format => $informat ) };
    }
    if ($@) {
        $error = $@;
        $error =~ s/DAIA::([A-Z]+::)?[a-z_]+\(\):| at .* line.*//ig;
    }

    my $daia;
    if (@daiaobjs > 1) {
        $error = "Found multiple DAIA elements (".(scalar @daiaobjs)."), but expected one";
    } elsif (@daiaobjs) {
        $daia = shift @daiaobjs;
    }

    if ( $outformat =~ /^(json|xml)$/ ) {
        $daia = DAIA::Response->new() unless $daia;
        $daia->addMessage(error(500,'en' => $error)) if $error;
        return $self->serialize( 200, $daia, $outformat, $req->param('callback') );
    } elsif ( $outformat and $outformat ne 'html' ) {
        $error = "Unknown output format - using HTML instead";
    }

    # HTML output
    $error = "<div class='error'>".escapeHTML($error)."!</div>" if $error;
    if ( $url and not $data ) {
        $msg = "Data was fetched from URL " . a({href=>$url},escapeHTML($url));
        $msg .= " (" . a({href=>'#result'}, "result...") . ")" if $daia;
        $msg =  div({class=>'msg'},$msg);
#        $msg .= div({class=>'msg'},"Use ". 
#                    a({href=>url()."?url=$eurl"},'this URL') .
#                    " to to directly pass the URL to this script.");

    }

    my $html = <<HTML;
<html>
<head>
  <title>DAIA Validator</title>
  <meta http-equiv="Content-Type" content="text/html;charset=utf-8" />
  <style>
    body { font-family: arial, sans-serif;}
    h1, p { margin: 0; text-align: center; }
    h2 { margin-top: 2px; border-bottom: 1px dotted #666;}
    form { margin: 1em; border: 1px solid #333; }
    fieldset { border: 1px solid #fff; }
    label, .error, .msg { font-weight: bold; }
    .submit, .error { font-size: 120%; }
    .error { color: #A00; margin: 1em; }
    .msg { color: #0A0; margin: 1em; }
    .footer { font-size: small; margin: 1em; }
    #result { border: 1px dotted #666; margin: 1em; padding: 0.5em; }
  </style>
</head>
<body>
<h1 id='top'>DAIA Converter</h1>
<p>Convert and Validate <a href="http://purl.org/NET/DAIA">DAIA response format</a></p>
<form method="post" accept-charset="utf-8" action="">
HTML

    # TODO: current value of informat/outformat

    $html .= $msg . $error .
     fieldset(label('Input: ',
            popup_menu('in',['','json','xml'],'',
                       {''=>'Guess','json'=>'DAIA/JSON','xml'=>'DAIA/XML'})
      )).
      fieldset('either', label('URL: ', textfield(-name=>'url', -size=>70, -value => $url)),
        'or', label('Data:'),
        textarea( -name=>'data', -rows=>20, -cols=>80, -value => $data),
      ).
      fieldset(
        label('Output: ',
            popup_menu('out',['html','json','xml'],'html',
                       {'html'=>'HTML','json'=>'DAIA/JSON','xml'=>'DAIA/XML'})
        ), '&#xA0;', 
        label('JSONP Callback: ', textfield(-name=>'callback',-value=>$callback))
      ).
      fieldset('<input type="submit" value="Convert" class="submit" />')
    ;
    $html .= '</form>';

    if ($daia) {
      if ( $informat eq 'xml' or DAIA::guess($data) eq 'xml' ) {
        my ($schema, $parser); # TODO: move this into a DAIA library method
        eval { require XML::LibXML; };
        if ( $@ ) {
            $error = "XML::LibXML::Schema required to validate DAIA/XML";
        } elsif($xsd) {
            $parser = XML::LibXML->new;
            $schema = eval { XML::LibXML::Schema->new( location => $xsd ); };
            if ($schema) {
                my $doc = $parser->parse_string( $data );
                eval { $schema->validate($doc) };
                $error = "DAIA/XML not valid but parseable: " . $@ if $@;
            } else {
                $error = "Could not load XML Schema - validating was skipped";
            }
        }
        if ( $error ) {
          $html .= "<p class='error'>".escapeHTML($error)."</p>";
        } else {
          $html .= p("DAIA/XML valid according to ".a({href=>$xsd},"this XML Schema"));
        }
      } else {
         $html .= p("validation is rather lax so the input may be invalid - but it was parseable");
      }
      $html .= "<div id='result'>";
      my ($pjson, $pxml) = ("","");
      if (!$data && $url) {
        $pjson = $pxml = "?callback=$callback&url=$eurl";
        $pjson = " (<a href='$pjson&format=json'>get via proxy</a>)";
        $pxml  = " (<a href='$pxml&format=xml'>get via proxy</a>)";
      }
      $html .= "<h2 id='json'>Result in DAIA/JSON$pjson <a href='#top'>&#x2191;</a> <a href='#xml'>&#x2193;</a></h2>";
      $html .= pre(escapeHTML( encode('utf8',$daia->json( $callback ) )));
      $html .= "<h2 id='xml'>Result in DAIA/XML$pxml <a href='#json'>&#x2191;</a></h2>";
      $html .= pre(escapeHTML( encode('utf8',$daia->xml( xmlns => 1 ) )));
      $html .= "</div>";
    }

    my $VERSION = $DAIA::VERSION;
    $html .= <<HTML;
<div class='footer'>
Based on <a href='http://search.cpan.org/perldoc?Plack::App::DAIA'>Plack::App::DAIA</a> $VERSION.
Visit the <a href="http://github.com/gbv/daia/">DAIA project at github</a> for sources and details. 
</div></body>
HTML

    return [ 200, [ 'Content-Type' => 'text/html; charset=utf-8' ], [ $html ] ];
}

1;

=head1 SYNOPSIS

    use Plack::Builder;
    use Plack::App::DAIA::Validator;

    builder {
        enable 'JSONP';
        Plack::App::DAIA::Validator->new( 
            xsd      => $location_of_daia_xsd,
            xslt     => "/daia.xsl",
            warnings => 1
        );
    };
    
=head1 DESCRIPTION

This module provides a simple L<DAIA> validator and converter as PSGI web
application.

=head1 CONFIGURATION

All configuration parameters (C<xsd>, C<xslt>, and C<warnings>) are optional.

=cut
