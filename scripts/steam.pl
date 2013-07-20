#! /bin/perl
use strict;
use warnings;
use utf8;

use LWP::Simple;
use Data::Dumper;
use WWW::Mechanize;
use Mojo::DOM;
use XML::LibXML;
use MongoDB;
use MongoDB::OID;
use XML::Twig;
use Encode;
#############
# VARIABLES
#############
my $url = "http://store.steampowered.com/search";
our @apps;

my $mech = WWW::Mechanize->new();
my $client = MongoDB::MongoClient->new;
my $db = $client->get_database( 'angrygamers' );
my $steam_apps = $db->get_collection( 'steamapps' );
my $header_url = "http://cdn2.steampowered.com/v/gfx/apps/";

print "Started\n";
sub add_app {
	my $html = shift;
	my @app_name;
	my @app_price;
	my @app_type;
	my @app_metascore;
	my @app_url;
	my @app_release;
	my $dom = Mojo::DOM->new($html);
	my $sub_xml = $dom->at('#search_result_container');
	$sub_xml =~ s/col search/col_search/g;
	$sub_xml =~ s/name ellipsis/name_ellipsis/g;
	$sub_xml =~ s/<div class="col_search_capsule"(.*)<\/div>//g;
	$sub_xml = encode("utf8",$sub_xml);
	#open (LOGFILE , '>log.xml');
	#print LOGFILE $sub_xml;
	#close (LOGFILE);
	my $t= XML::Twig->new( twig_handlers => 
        	{ 	
		'a[@class=~/^search_result_row/]' 			=> sub { push(@app_url,$_->att('href')); },
		'a[@class=~/^search_result_row/]/div[@class="col_search_name_ellipsis"]/h4'		=> sub { push(@app_name,$_->text) ;},
		'a[@class=~/^search_result_row/]/div[@class="col_search_price"]'			=> sub { push(@app_price,$_->text); },
		'a[@class=~/^search_result_row/]/div[@class="col_search_type"]/img'			=> sub { push(@app_type,$_->att('src')) ; },
 		'a[@class=~/^search_result_row/]/div[@class="col_search_metascore"]'			=> sub { push(@app_metascore,$_->text) ; },
		'a[@class=~/^search_result_row/]/div[@class="col_search_released"]'			=> sub { push(@app_release,$_->text) ; }
		} 
	);
  $t->parse($sub_xml);
  # String processing and inserting into the mongo db
  chomp @app_price;
	for(my $i = 0; $i<@app_name;$i++){
		if ($app_url[$i] =~ m/\/app\//){
			unless($app_price[$i] =~ m/(Free Demo|Free to Play)/ || $app_price[$i] =~ m/^\s*$/ || $app_type[$i] =~ m/type_dlc.gif/i || $app_type[$i] =~ m/guide.gif/i ){
				# Catching the App ID
				$app_url[$i] =~ m#http://store.steampowered.com/app/(.*?)/# ;	
				my $app_id = $1;
				#URL epuration
				($app_url[$i]) = $app_url[$i] =~ m/(.*?)\?/;
				
				print "Updating ".$app_name[$i]."\n";
				my $local_time = time;
				$steam_apps->update({"id" => $app_id},
					{'$set' =>{
					"name"		=> $app_name[$i],
                                        "price"		=> $app_price[$i],
                                        "release"	=> $app_release[$i],
                                        "type"		=> $app_type[$i],
					"url"		=> $app_url[$i],
					"Last_update"	=> $local_time,
					"metascore"	=> $app_metascore[$i]}},
					{'upsert' 	=> 1});

			}
		}
	}
}


$mech->get($url) ;

print "Finding links \n";

&add_app($mech->content);
my $i = 0;
while($mech->find_link(text => '>>') ){
		$mech->follow_link(text => '>>');
	print "Next page  ".$mech->uri()." \n";
	&add_app($mech->content);
	$i++;
}



##########################
#
# INSERT INTO DATABASE
#
##########################


my $all_id = $steam_apps->find;

while (my $id = $all_id->next)
{
	print "Downloading : ".$header_url.$id->{'id'}."/header.jpg \n";
	getstore($header_url.$id->{'id'}."/header.jpg","/home/angrygamers.fr/secret/".$id->{'id'}.".jpg") 
		or die "Can't fetch the $id.jpg ".$@ ;
	 }
