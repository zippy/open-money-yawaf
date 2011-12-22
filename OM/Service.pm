#-------------------------------------------------------------------------------
# OM::Service.pm
# ©2006 Harris-Braun Enterprises, LLC, All Rights Reserved
# License: This module is free software; you can redistribute it and/or modify
#          it under the terms of either the Perl Artistic License, or the GNU 
#          General Public License as published by the Free Software Foundation
# Author: Eric Harris-Braun <eric -at- harris-braun.com>
#-------------------------------------------------------------------------------

package OM::Service;

use strict;
use Carp;
use OM::AccessController;

sub new {
	my $class = shift;
	my $self = {@_};
	
	my $domain_id = $self->{'domain_id'};
	croak ('Tried to create a service with a null domain id.') if $domain_id == 0;
#	if ($domain_id != -1) {
		my $sql = $self->{'sql'};
		my $r = $sql->GetRecord($self->{'domain_table'},"id=$domain_id",'access_control');
		croak ("whoa! that domain id ($domain_id) doesn't exist!") if !defined($r);
		$self->{'access_controler'} = new OM::AccessController(_decodeSpec($r->{'access_control'}));
#	}

	bless $self, $class;
	$self->_initialize();

	return $self;
}

sub _initialize
{
	my $self = shift;
}


sub checkAccess {
	my $self = shift;
	if (exists $self->{'access_controler'}) {
		return 1 if ($self->{'access_controler'}->checkAccess($self->{'authorization'},@_));
		$self->{'error'} = 'access denied';
		return 0;
	}
	croak ('whops! no access controller defined') ;
}

#---------------
sub date2SQLDateFormat {
	my $sql = shift;
	my $datetime = shift;
	my $datetime_format = shift;

	if ($datetime_format eq 'SQL') {
		return $datetime;
	}

	my $result = $sql->Query("select from_unixtime($datetime)");
	my ($r) = $result->fetchrow_array();
	return $r;
	
}

sub SQLdate2UNIXDateFormat {
	my $sql = shift;
	my $datetime = shift;

	my $result = $sql->Query("select UNIX_TIMESTAMP('$datetime')");
	my ($r) = $result->fetchrow_array();
	return $r;
	
}


sub _encodeSpec
{
	my $spec = shift;
	my $spec_text;
	while (my($k,$v) = each(%$spec)) {
		$spec_text .= "$k:$v\n";
	}
	return $spec_text;
}
sub _decodeSpec
{
	my $text = shift;
	my %s;
	my @l = split(/\n/,$text);
	foreach (@l) {
		/([^:]*):(.*)/;
		$s{$1}=$2;
	}
	return \%s;
}

#-------

sub _decodeSummary
{
	my $sql = shift;
	my $s = shift;
	my ($b,$v,$l);
 	if ($s =~ /(.*)~(.*)~(.*)/) {
 		($b,$v,$l) = ($1,$2,$3);
 	}
 	else {
 		($b,$v,$l) = (0,0,undef);
 	}
 	return {'balance'=>$b,'volume'=>$v,'last'=>SQLdate2UNIXDateFormat($sql,$l)};
}
sub _encodeSummary
{
	my $s = shift;
	return "$s->{'balance'}~$s->{'volume'}~$s->{'last'}";
}


1;