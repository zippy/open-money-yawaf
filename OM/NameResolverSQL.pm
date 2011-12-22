#-------------------------------------------------------------------------------
# OM::NameResolverSQL.pm
# ©2006 Harris-Braun Enterprises, LLC, All Rights Reserved
# License: This module is free software; you can redistribute it and/or modify
#          it under the terms of either the Perl Artistic License, or the GNU 
#          General Public License as published by the Free Software Foundation
# Author: Eric Harris-Braun <eric -at- harris-braun.com>
#-------------------------------------------------------------------------------

package OM::NameResolverSQL;

use strict;
use Carp;
use base 'OM::NameResolver';


sub ResolveAccountName {
	my $self = shift;
	my $account_ids = $self->ResolveAccountNames(@_);
	if (defined ($account_ids)) {
		my @account_ids = values(%$account_ids);
		return $account_ids[0];
	}
	return 0;
}

sub ResolveAccountNames {
	my $self = shift;
	return $self->_resolve_names('user_om_accounts','om_account','account_name','om_account_id',@_);
}

sub ResolveAccountID {
	my $self = shift;
	my $names = $self->ResolveAccountIDs(@_);
	if (defined ($names)) {
		my @names = values(%$names);
		return $names[0];
	}
	return 0;
}

sub ResolveAccountIDs {
	my $self = shift;

	return $self->_resolve_ids('user_om_accounts','om_account','om_account_id','account_name',@_);
}


sub ResolveCurrencyName {
	my $self = shift;
	my $ids = $self->ResolveCurrencyNames(@_);
	if (defined ($ids)) {
		my @ids = values(%$ids);
		return $ids[0];
	}
	return 0;
}

sub ResolveCurrencyNames {
	my $self = shift;

	return $self->_resolve_names('user_owned_currencies','om_currency','currency_name','om_currency_id',@_);
}

sub ResolveCurrencyID {
	my $self = shift;
	my $names = $self->ResolveCurrencyIDs(@_);
	if (defined ($names)) {
		my @names = values(%$names);
		return $names[0];
	}
	return 0;
}

sub ResolveCurrencyIDs {
	my $self = shift;

	return $self->_resolve_ids('user_owned_currencies','om_currency','om_currency_id','currency_name',@_);
}


#----------

sub _resolve_names
{
	my $self = shift;
	my $table = shift;
	my $om_table = shift;
	my $name_field = shift;
	my $id_field = shift;
	my @names = @_; #make a copy!

	my $sql = $self->{'sql'};
	
	my $where = join(' or ',grep($_ = "$name_field = ".$sql->Quote($_),@names));
	$where = "($where) and domain_id = $self->{'domain_id'} and $om_table.id=$id_field";
	my $r = $sql->GetRecords("$table,$om_table",$where,[$name_field,$id_field]);

	if (@$r > 0) {
		my %ids;
		foreach (@$r) {
			$ids{$_->{$name_field}} = $_->{$id_field};
		}
		return \%ids;
	}	
	return undef;
}

sub _resolve_ids
{
	my $self = shift;
	my $table = shift;
	my $om_table = shift;
	my $id_field = shift;
	my $name_field = shift;
	my @ids = @_; #make a copy!
	
	my $sql = $self->param('sql');
	
	my $where = join(' or ',grep($_ = "$id_field = ".int($_),@ids));
	$where = "($where) and domain_id = $self->{'domain_id'} and $om_table.id=$id_field";
	my $r = $sql->GetRecords($table,$where,[$name_field,$id_field]);

	if (@$r > 0) {
		my %names;
		foreach (@$r) {
			$names{$_->{$id_field}} = $_->{$name_field};
		}
		return \%names;
	}	
	return undef;
}


1;