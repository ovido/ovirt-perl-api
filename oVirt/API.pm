#!/usr/bin/perl -w
#
# COPYRIGHT:
#
# This software is Copyright (c) 2013 by Rene Koch
#                             <r.koch@ovido.at>
#
# This file is part of oVirt::API, a perl API for oVirt and RHEV.
#
# (Except where explicitly superseded by other copyright notices)
# oVirt::API is free software: you can redistribute it and/or modify it 
# under the terms of the GNU General Public License as published by the 
# Free Software Foundation, either version 3 of the License, or any later
# version.
#
# oVirt::API is distributed in the hope that it will be useful, but WITHOUT 
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or 
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License 
# for more details.
#
# You should have received a copy of the GNU General Public License
# along with oVirt::API.  
# If not, see <http://www.gnu.org/licenses/>.


package oVirt::API;

BEGIN {
    $VERSION = '0.100'; # Don't forget to set version and release
}              # date in POD below!

use strict;
use warnings;
use Carp;
use LWP::UserAgent;
use HTTP::Request;
use XML::Simple;

# for debugging only
#use Data::Dumper;


=head1 NAME

  oVirt::API - Provide Perl-API for oVirt und RHEV

=head1 SYNOPSIS

  use oVirt::API;
  my $oa = oVirt::API->new(
  		url			=> $url,
  		username	=> $username,
  		password	=> $password,
  		ca_file		=> $ca_file
  	 );
  my $vms = $oa->vms( 'list' );

=head1 DESCRIPTION

This module provides an API for Perl to fetch information from oVirt
and RHEV REST-API.
It's not intended to be a full API (yet).

=head1 CONSTRUCTOR

=head2 new ( [ARGS] )

Creates an oVirt::API object. <new> takes at least the url, username
and password. Arguments are in key-value pairs.
See L<EXAMPLES> for more complex variants.

=over 4

=item url

url of oVirt REST-API (e.g. https://localhost/api)

Instead of specifying an url, it's possible to add all url parameters
seperatly.

=item protocol

optional - protocol to use (http|https)

=item host

optional if url is used
hostname/ip address of oVirt engine/ RHEV Manager which serves the REST-API.

=item port

optional - port of REST-API (most likely 443 or 8443)

=item api

optional - path to api (/api)

=item username

Username incl. domain name to connect to REST-API (e.g. admin@internal).

=item password

Password for this user.

=item timeout

Connection timeout (default: 10 seconds)

=item ca_file

Path to CA certificate file of oVirt engine / RHEV Manager.
This is required to verify the REST-API certificate unless you disabled
this check.

=item insecure

Enable/Disable certificate verification.
0 ... verify certificate
1 ... don't verify certificate

=cut


sub new {
  my $invocant  = shift;
  my $class   = ref($invocant) || $invocant;
  my %options  = @_;
    
  my $self     = {
    "url"    => undef,  # REST-API url
    "protocol"  => "https",  # REST-API protocol (http|https)
    "host"    => undef,  # engine hostname
    "port"    => 443,    # REST-API port
    "api"    => "/api",  # REST-API path
    "username"  => undef,  # REST-API user
    "password"  => undef,  # REST-API password
    "timeout"  => 10,    # timeout for web request
    "ca_file"  => undef,  # path to server CA file
    "insecure"  => 0    # don't verify server certificate
  };
  
  for my $key (keys %options){
    if (exists $self->{ $key }){
      $self->{ $key } = $options{ $key };
    }else{
      croak "Unknown option: $key";
    }
  }
  
  bless $self, $class;
  
  # parameter validation
  #---------------------
  
  if (! defined $self->{ 'url' }){
    my @components = qw(protocol host port api);
    $self->_check_component(\@components);
  }
  
  # username and password are required
  my @components = qw(username password);
  $self->_check_component(\@components);
  
  # verify CA?
  if (! $self->{ 'insecure' } == 1 && ! $self->{ 'ca_file' }){
    croak ("Missing ca_file!");
  }
  
  return $self;
}


#----------------------------------------------------------------

=head1 METHODS	

=head2 vms

 vms ( 'list' )

Fetch vm information.
Returns hash reference.

=cut

sub vms{

  my $self    = shift;
  my $action   = shift;
  
  my $result = $self->_fetch("vms", $action);
  return $result;
  
}
    

#----------------------------------------------------------------

# internal methods
##################

# check if component is defined and croak if so
sub _check_component {

  my $self      = shift;
  my $components  = shift or croak ("_check_component: Missing input!");
  
  foreach my $component (@{ $components }){
    
    croak ("$component is required") if ! defined $self->{ $component };
    
  }
}


#----------------------------------------------------------------

# connect to REST-API
sub _connect{

  my $self    = shift;
  my $query    = shift;
  
  # construct URL if not given
  if (! $self->{ 'url' }){
    bless $self->{ 'url '} = $self->{ 'protocol' } . "://" . $self->{ 'host' } . ":" . $self->{ 'port' } . $self->{ 'api' };
  }
  
  my $url = $self->{ 'url' } . $query;

  # connect to REST-API
  my $ra = LWP::UserAgent->new();
  $ra->timeout( $self->{ 'timeout' } );

  # SSL certificate verification
  if ( $self->{ 'insecure' } == 1){
    $ra->ssl_opts(verify_hostname => 0, SSL_verify_mode => 0x00);
  }else{
    # check certificate
    $ra->ssl_opts(verfiy_hostname => 1, SSL_ca_file => $self->{ 'ca_file' });
  }

  # TODO: cookie based authentication!
  my $rr = HTTP::Request->new( GET => $url );
  $rr->authorization_basic($self->{ 'username' },$self->{ 'password' });
  
  my $re = $ra->request($rr);
  if (! $re->is_success){  
    carp ("Failed to fetch result from REST-API."); 
  }

  my $result = eval { XMLin($re->content) };
  croak ("Error in XML returned from REST-API.") if $@;
  return $result;

}


#----------------------------------------------------------------

# fetch XML from REST-API
sub _fetch {

  my $self    = shift;
  my $object  = shift or croak ("_fetch: Missing object!");
  my $action  = shift or croak ("_fetch: Missing action!");
  
  my $result;
  
  if ($action eq "list"){
    
    $result = $self->_connect( "/" . $object)
     
  }else{
    
    croak ("Unsupported action: $action");
    
  }
  
  return $result;
  
}


1;


=head1 EXAMPLES

Get host information from oVirt API without certificate validation.

  use oVirt::API;
  my $oa = oVirt::API->new(
    	url			=> 'https://localhost:8443/api',
  		username	=> 'admin@internal',
  		password	=> password,
  		insecure	=> 1
  	 );
  my $vms = $oa->vms( 'list' );
  

=head1 SEE ALSO


=head1 AUTHOR

Rene Koch, E<lt>r.koch@ovido.atE<gt>

=head1 VERSION

Version 0.100  (August 8 2013))

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2013 by Rene Koch

This library is free software and released under GPLv3.

=cut
