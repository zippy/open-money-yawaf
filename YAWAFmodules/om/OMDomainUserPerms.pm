#-------------------------------------------------------------------------------
# OMDomainUserPerms.pm
# ©2006 Harris-Braun Enterprises, LLC, All Rights Reserved
# License: This module is free software; you can redistribute it and/or modify
#          it under the terms of either the Perl Artistic License, or the GNU 
#          General Public License as published by the Free Software Foundation
# Author: Eric Harris-Braun <eric -at- harris-braun.com>
#-------------------------------------------------------------------------------

package OMDomainUserPerms;

use strict;
use base 'PAGE::Query';
use OMUtils;

sub _initialize
{
	my $self = shift;
	$self->SUPER::_initialize;
	
	$self->{'methods'}->{'submit'} = 1;
}



sub setup
{
	my $self = shift;
	my $page_name = shift;
	my $app = shift;

	my $domains = OMUtils::SetupUserDomains($self,$app,'admin,steward');

	if (@$domains > 0) {
		my @domains;
		my %labels;
	
		my $q = $app->query();
		my $selected_domain = int($q->param('domain_id'));
		
	
		if ($selected_domain == 0) {
			$selected_domain = $domains->[0]->{'domain_id'};
		}
		my $selected_class;
		foreach (@$domains) {
			my $d = $_->{'domain_id'};
			push @domains,$d;
			$labels{$d} = $_->{'domain_name'};
			if ($selected_domain == $d) {
				$selected_class = $_->{'class'};
			}
		}
		my $q = $app->query();
		$q->{'_selected_class'} = $selected_class;

		my $html = $q->popup_menu(
			-name => 'domain_id',
			-values => \@domains,
			-labels => \%labels,
			-default => $selected_domain
			);
		$self->addTemplatePairs('domain_id' => $html);
		$self->addTemplatePairs('d_id' => $selected_domain);
	
		my @classes = ('','user');
		my %class_labels = (''=> '--no permissions--','user'=>'User');
		if ($selected_class eq 'steward') {
			push @classes,('admin','steward');
			$class_labels{'admin'} = "Administrator";
			$class_labels{'steward'} = "Steward";
		}
		$html = $q->popup_menu(
			-name => 'new_class',
			-values => \@classes,
			-labels => \%class_labels,
			-default => 'user'
			);
	
		$self->addTemplatePairs('new_class' => $html);
	}
	$self->SUPER::setup($page_name,$app);
}

sub submit
{
	my $self = shift;
	my $app = $self->param('app');
	my $sql = $app->param('sql');
	my $q = $app->query();
	
	my $domain_id = int($q->param('domain_id'));
	
	#confirm that the current user actually has the right privs for this domain id
	my $selected_class = $q->{'_selected_class'};
	my $new_class =  $q->param('new_class');
	if (($new_class eq 'setward' || $new_class eq 'admin') && $selected_class ne 'steward') {
		die "whoa, your permission class ($selected_class) can't set that priv ($new_class)";
	}

	my @ids = $q->param('user_ids');
	my $where = "(".join(' or ',map($_ = "account.id = $_",@ids)).')';
	my $r = $sql->GetRecords('account',$where,['user_domains.id as link_id','account.id as user_id','class'],undef,"user_domains on user_domains.user_id = account.id and om_domain_id = $domain_id");

	my @update;
	my @insert;
	my @delete;
	my $lP;
	$lP = ($new_class eq '')?\@delete:\@update;
	foreach (@$r) {
		my $link_id = $_->{'link_id'};
		if ($selected_class eq 'steward' || ($selected_class eq 'admin' && ($_->{'class'} eq '' || $_->{'class'} eq 'member'))) {
			if ($link_id) {
				push(@$lP,$link_id);
			}
			else {
				push(@insert,$_->{'user_id'}) if ($new_class ne '');
			}
		}
	}

	#update the records
	if (@update) {
		$sql->UpdateRecords('user_domains',{'class'=>$new_class},join(' or ',map($_ = "id = $_",@update)));
	}
	if (@delete) {
		$sql->DeleteRecords('user_domains',join(' or ',map($_ = "id = $_",@delete)));
	}
	if (@insert) {
		my %rec = ('class'=>$sql->Quote($new_class), 'om_domain_id'=>$domain_id);
		foreach (@insert) {
			$rec{'user_id'} = $_;
			$sql->InsertRecord('user_domains',\%rec,1);
		}
	}
	
	return $self->show;
}

1;