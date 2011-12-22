#-------------------------------------------------------------------------------
# OM::DomainServiceSQL.pm
# ©2006 Harris-Braun Enterprises, LLC, All Rights Reserved
# License: This module is free software; you can redistribute it and/or modify
#          it under the terms of either the Perl Artistic License, or the GNU 
#          General Public License as published by the Free Software Foundation
# Author: Eric Harris-Braun <eric -at- harris-braun.com>
#-------------------------------------------------------------------------------

package OM::DomainServiceSQL;

use strict;
use Carp;
use base 'OM::Service';

sub new_account {
	my $self = shift;
	my $access_control = shift;

	my $table = $self->{'account_table'};
	my $sql = $self->{'sql'};
		
	my %recs = ('created'=>'NOW()','domain_id' => $self->{'domain_id'});
	$recs{'access_control'} = $sql->Quote($access_control) if defined $access_control ;
	return $sql->InsertRecord($table,\%recs,1);
}

sub new_currency {
	my $self = shift;
	my $spec = OM::Service::_encodeSpec( shift);
	my $access_control = shift;

	my $table = $self->{'currency_table'};
	my $sql = $self->{'sql'};	
	my %recs = ('created'=>'NOW()','domain_id' => $self->{'domain_id'},'specification' => $sql->Quote($spec));
	$recs{'access_control'} = $sql->Quote($access_control) if defined $access_control ;
	return $sql->InsertRecord($table,\%recs,1);
}

sub new_domain {
	my $self = shift;
	my $name = shift;
	my $spec = OM::Service::_encodeSpec(shift);
	my $access_control = shift;

	my $table = $self->{'domain_table'};
	my $sql = $self->{'sql'};
	
	my $parent;
	my $parent_id = $self->{'domain_id'};
	if ($parent_id == -1) {
		$parent = '';
		$parent_id = 0;
		# this can only be done if you are an admin
	}
	else {
		my $r = $sql->GetRecord($table,"id=$parent_id",'name','parent');	
		croak ("undefined parent domain id $parent_id (currently we can't create subdomains of off server domains)") if !defined($r);
		$parent = $r->{'name'};
		$parent .= '.'.$r->{'parent'} if $r->{'parent'} ne '';
	}
	
	return 0 if (!$self->checkAccess('new_domain'));
		
	if ($sql->GetCount($table,"parent_id=$parent_id and name=".$sql->Quote($name))) {
		$self->{'error'} = 'there is already a domain with that name';
		return 0;
	}

	my %recs = (
		'created'=>'NOW()',
		'name' => $sql->Quote($name),
		'parent' => $sql->Quote($parent),
		'parent_id' => $parent_id,
		'specification' => $sql->Quote($spec),
		);
	$recs{'access_control'} = $sql->Quote($access_control) if defined $access_control ;
	return $sql->InsertRecord($table,\%recs,1);
}

sub domains {
	my $self = shift;
	my $table = $self->{'domain_table'};
	my $sql = $self->{'sql'};	

	my $domain_id = $self->{'domain_id'};

	my $r = $sql->GetRecords($table,'',['created','name','specification','parent','id'],'created desc');
	my @d;
	foreach (@$r) {
		my $d = $_->{'name'};
		$d .= '.'.$_->{'parent'} if $_->{'parent'} ne '';
		push @d,{
			'domain'=>$d,
			'created'=>$_->{'created'},
			'spec'=>OM::Service::_decodeSpec($_->{'specification'})
			};
	}
#	my %domains;
#	my %parents;
#	my $i = 0;
#	_scan(0,$r,\%domains,\%parents);
#	foreach (keys %domains) {
#		push @d,{'domain'=>$_};
#	}
	return \@d;
}

#sub _scan {
#	my $parent = shift;
#	my $r = shift;
#	my $domains = shift;
#	my $parents = shift;
#	my @r;
#	my @parents;
#	foreach (@$r) {
#		my $parent_id = $_->{'parent_id'};
#		if ($parent_id == $parent) {
#			my $id = $_->{'id'};
#			push @parents,$id;
#			my $name = 	$_->{'name'}.'.'.$parents->{$parent};
#			$domains->{$name} = $id;
#			$parents->{$id} = $name;
#		}
#		else {
#			push (@r,$_);
#		}
#	}
#	if (@r) {
#		foreach (@parents) {
#			_scan($_,\@r,$domains,$parents);
#		}
#	}
#}

1;