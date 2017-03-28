#!/usr/bin/env perl
#-*- coding:utf8 -*-

# Tools to query/retrieve Swift-GRBs from NASA website.
#
# Swift GRBs data are officially released by the collaboration
# websites in UK(SSDC), Italy(ASDC) and USA(GSFC/NASA). Being
# the american one in a better shape (i.e, better coded and
# complete) for automatic searches.

# Function to retrieve all GRBs table detected by Swift only
use WWW::Mechanize;
sub _open_url(){
  $url = 'https://swift.gsfc.nasa.gov/archive/grb_table/';

  use WWW::Mechanize;
  my $mech = WWW::Mechanize->new();
  $mech->get( $url );
  return $mech;
}

use LWP::UserAgent;
sub get_all_grbs(){
  my $mech = _open_url();
  my $form = $mech->form_number(2);

  $mech->tick("bat_ra",1);
  $mech->tick("bat_dec",1);
  $mech->tick("bat_err_radius",1);
  $mech->tick("xrt_ra",1);
  $mech->tick("xrt_dec",1);
  $mech->tick("xrt_err_radius",1);
  $mech->tick("uvot_ra",1);
  $mech->tick("uvot_dec",1);
  $mech->tick("uvot_err_radius",1);

  use LWP::UserAgent;
  $ua = LWP::UserAgent->new;
  $response = $ua->request($form->click);
  $html = $response->decoded_content();
  parse_table($html)
}

use Scalar::Util qw(looks_like_number);
use HTML::TableExtract;
sub parse_table(){
  my $html = $_[0];

  use HTML::TableExtract;
  $te = HTML::TableExtract->new( attribs=>{ class=>'grbtable' } );
  $te->parse($html);
  foreach $ts ($te->tables) {
    # print "Table found\n";
    foreach $row ($ts->rows) {
      # print "ROW:\n";
      my @linha = ();
      foreach $field (@$row) {
        my $first = (split("\n",$field))[0];
        if (looks_like_number($first)) {
          $field = $first;
        } else {
          $field =~ s/\n/|/g;
        }
        # $field =~ s/([^\000-\200])/sprintf '&#x%X;', ord $1/ge;
        # $field =~ s/([^\000-\200])/'&#'.ord($1).';'/ge;
        $field =~ s/([^\000-\200])//ge;
        $field =~ s/\;/./g;
        push(@linha,$field);
      }
      print join (";",@linha), "\n";
    }
  }
}

get_all_grbs();
