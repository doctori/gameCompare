#!/usr/bin/perl -w

##############################################################################################
# Copyright 2009 Amazon.com, Inc. or its affiliates. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"). You may not use this file 
# except in compliance with the License. A copy of the License is located at
#
#       http://aws.amazon.com/apache2.0/
#
# or in the "LICENSE.txt" file accompanying this file. This file is distributed on an "AS IS"
# BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations under the License. 
#
#############################################################################################
#
#  Amazon Product Advertising API
#  Signed Requests Sample Code
#
#  API Version: 2009-03-31
#
#############################################################################################
package AmazonUtils;

use strict;
use warnings;

use Data::Dumper;

use RequestSignatureHelper;
use LWP::UserAgent;
use XML::Simple;
use base 'Exporter';
our @EXPORT = qw($itemId );
use constant myAWSId	    => 'AKIAJWXNHXS4I7TCKV4Q';
use constant myAWSSecret    => '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';
use constant myEndPoint	    => 'webservices.amazon.fr';
use constant myAssociateID  => 'angrygamersfr-20';
# see if user provided ItemId on command-line
my $itemId = shift @ARGV || '0545010225';

# Set up the helper
my $helper = new RequestSignatureHelper (
    +RequestSignatureHelper::kAWSAccessKeyId => myAWSId,
    +RequestSignatureHelper::kAWSSecretKey => myAWSSecret,
    +RequestSignatureHelper::kEndPoint => myEndPoint,
);

# A simple ItemLookup request
my $request = {
    Service => 'AWSECommerceService',
    AssociateTag => myAssociateID,
    Operation => 'ItemSearch',
    BrowseNode => '548026', # VideoGaming PC node
    SearchIndex => 'SoftwareVideoGames',
    Version => '2011-08-01',
    Title => $itemId,
    ResponseGroup => 'Small',
};

my $xml = &sendRequest($request);
open(XMLFILE , '>log_amazon.xml');

#close(XMLFILE)
	foreach my $item (@{$xml->{Items}->{Item}}){
		my $name = $item->{ItemAttributes}->{Title};
		my $ASIN = $item->{ASIN};
		$request = {
			Service => 'AWSECommerceService',
			AssociateTag => myAssociateID,
			Operation => 'ItemLookup',
			Version => '2011-08-01',
			ItemId => $ASIN,
			ResponseGroup => 'Offers',
		};
		my $sub_xml = &sendRequest($request);
		my $price = $sub_xml->{Items}->{Item}->{OfferSummary}->{LowestNewPrice}->{FormattedPrice};
		print XMLFILE "Name : ".$name." ASIN : ".$ASIN." Price ".$price." \n";
	}
close(XMLFILE);


##############
#Receive Parameters and return xml as hash table
##############
sub sendRequest {
	my $request = shift;
	# Sign the request
	my $signedRequest = $helper->sign($request);
	
	# # We can use the helper's canonicalize() function to construct the query string too.
	 my $queryString = $helper->canonicalize($signedRequest);
	 my $url = "http://" . myEndPoint . "/onca/xml?" . $queryString;
	 print "Sending request to URL: $url \n";
	
	 my $ua = new LWP::UserAgent();
	 my $response = $ua->get($url);
	 my $content = $response->content();
	 #print "Recieved Response: $content \n";
	
	 my $xmlParser = new XML::Simple();
	 my $xml = $xmlParser->XMLin($content);
	
	 print "Parsed XML is: " . Dumper($xml) . "\n";
	$xml;
}
sub findError {
    my $xml = shift;
    
    return undef unless ref($xml) eq 'HASH';

    if (exists $xml->{Error}) { return $xml->{Error}; };

    for (keys %$xml) {
	my $error = findError($xml->{$_});
	return $error if defined $error;
    }

    return undef;
}
