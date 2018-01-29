#!/usr/bin/perl

# tests from KjetilK

use strict;
use Test::More;
use Test::Modern;

BEGIN {
  use_ok('Attean') or BAIL_OUT "Attean required for tests";
  use_ok('AtteanX::Serializer::RDFa');
  use_ok('RDF::RDFa::Generator');
}

use Attean::RDF qw(iri);
use URI::NamespaceMap;
use Module::Load::Conditional qw[check_install];

my $rdfns = check_install( module => 'RDF::NS', version => 20130802);

my $store = Attean->get_store('Memory')->new();
my $parser = Attean->get_parser('Turtle')->new(base=>'http://example.org/');

my $iter = $parser->parse_iter_from_bytes('<http://example.org/foo> a <http://example.org/Bar> ; <http://example.org/title> "Dahut"@fr ; <http://example.org/something> [ <http://example.org/else> "Foo" ; <http://example.org/pi> 3.14 ] .')->materialize;


subtest 'Default generator' => sub {
  plan skip_all => 'RDF::NS is not installed' unless $rdfns;
  ok(my $ser = Attean->get_serializer('RDFa')->new, 'Assignment OK');
  my $string = tests($ser);
  like($string, qr|<link|, 'link element just local part');
  like($string, qr|resource="http://example.org/Bar"|, 'Object present');
  like($string, qr|property="ex:title" content="Dahut"|, 'Literals OK');
};

subtest 'Default generator with base and namespacemap' => sub {
  my $ns = URI::NamespaceMap->new(ex => iri('http://example.org/'));
  $ns->guess_and_add('foaf');
  $iter->reset;
  ok(my $ser = Attean->get_serializer('RDFa')->new(base => iri('http://example.org/'),
																	namespaces => $ns)
	  , 'Assignment OK');
  my $string = tests($ser);
  print $string;
  like($string, qr|xmlns:foaf="http://xmlns.com/foaf/0.1/"|, 'FOAF is in there');
  unlike($string, qr|xmlns:hydra="http://www.w3.org/ns/hydra/core#"|, 'But not hydra');
  like($string, qr|resource="http://example.org/Bar"|, 'Object present');
  like($string, qr|property="ex:title" content="Dahut"|, 'Literals OK');
};


done_testing;
exit 0;

my $model;
subtest 'Hidden generator' => sub {
  ok(my $document = RDF::RDFa::Generator::HTML::Hidden->new->create_document($model), 'Assignment OK');
  my $string = tests($document);
  like($string, qr|<body>\s?<i|, 'i element just local part');
  like($string, qr|resource="http://example.org/Bar"|, 'Object present');
  like($string, qr|property="ex:title" content="Dahut"|, 'Literals OK');
};

subtest 'Pretty generator' => sub {
  ok(my $document = RDF::RDFa::Generator::HTML::Pretty->new->create_document($model), 'Assignment OK');
  my $string = tests($document);
  like($string, qr|<dd property="ex:title" class="typed-literal" xml:lang="fr" datatype="xsd:langString">Dahut</dd>|, 'Literals OK');
};

subtest 'Pretty generator with interlink' => sub {
  ok(my $document = RDF::RDFa::Generator::HTML::Pretty->new()->create_document($model, interlink => 1, id_prefix => 'test'), 'Assignment OK');
  my $string = tests($document);
  like($string, qr|<main>\s?<div|, 'div element just local part');
  like($string, qr|<dd property="ex:title" class="typed-literal" xml:lang="fr" datatype="xsd:langString">Dahut</dd>|, 'Literals OK');
};

subtest 'Pretty generator with Note' => sub {
  ok(my $note = RDF::RDFa::Generator::HTML::Pretty::Note->new(iri('http://example.org/foo'), 'This is a Note'), 'Note creation OK');
  ok(my $document = RDF::RDFa::Generator::HTML::Pretty->new->create_document($model, notes => [$note]), 'Assignment OK');
  my $string = tests($document);
  like($string, qr|<aside>|, 'aside element found');
  like($string, qr|This is a Note|, 'Note text found');
};


sub tests {
  my $ser = shift;
  my $string = $ser->serialize_iter_to_bytes($iter);
  like($string, qr|about="http://example.org/foo"|, 'Subject URI present');
  like($string, qr|rel="rdf:type"|, 'Type predicate present');
  like($string, qr|property="ex:pi"|, 'pi predicate present');
  like($string, qr|3\.14|, 'pi decimal present');
  like($string, qr|datatype="xsd:decimal"|, 'pi decimal datatype present');
  return $string;
}
done_testing();
