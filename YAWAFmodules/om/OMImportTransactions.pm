#-------------------------------------------------------------------------------
# OMImportTransactions.pm
# ©2006 Harris-Braun Enterprises, LLC, All Rights Reserved
# License: This module is free software; you can redistribute it and/or modify
#          it under the terms of either the Perl Artistic License, or the GNU 
#          General Public License as published by the Free Software Foundation
# Author: Eric Harris-Braun <eric -at- harris-braun.com>
#-------------------------------------------------------------------------------

package OMImportTransactions;

use strict;
use base 'PAGE::Form';
use OMUtils;
use Carp;

sub setup
{
	my $self = shift;
	my $page_name = shift;
	my $app = shift;

	my $q = $app->query();
	
#	$self->OMUtils::AddCurrencySelect($app,'currency');
#	$self->OMUtils::AddDomainSelect($app,'domain','steward');
	$self->{'params'}->{'fieldspec'}->{'import'} =
	Field::TextArea->new(
		'name' => 'import',
		'validation' => ['required'],
		'rows' => 24,
		'columns' => 70
		);
	push (@{$self->{'params'}->{'fields'}},'import');

	$self->SUPER::setup($page_name,$app);
}

sub doSubmit
{
	my $self = shift;
	my $app = $self->param('app');
	my $q = $app->query();
	my $om = $app->param('om');
	
	my $sql = $self->param('sql');

	my @txs = split(/\n/,OMUtils::_unixify($q->param('import')));	
	my $x;
	my @errs;
	foreach (@txs) {
		my @fields = split(/,/);
		my ($transaction_id,$account_from,$account_to,$date,$currency,$amount,$description,$tax_status) = @fields;
		if (@fields != 8) {
			push @errs, "incorrect number of fields for account transaction $transaction_id";
		}
		my ($account_id_from,$domain_id_from,$is_local_from) = $om->_resolve_name($account_from,'^');
		if (!$account_id_from) {
			push @errs, "account $account_id_from doesn't exist";
		}
		my ($account_id_to,$domain_id_to,$is_local_to) = $om->_resolve_name($account_from,'^');
		if (!$account_id_to) {
			push @errs, "account $account_id_to doesn't exist";
		}
	
		if (!@errs) {
			my $spec = {
				'amount' => -$amount,
				'description' => $description,
				'tax-status' => $tax_status,
			};
			my $s = $om->record_trade(
				'datetime' => $date,
				'datetime_format' => 'SQL',
				'transaction_id' => $transaction_id,
				'account' => $account_from,
				'with' => $account_to,
				'currency' =>  $currency,
				'specification' => $spec
				);
		
			if ($s == 0) {
				push (@errs,qq#there was a problem while importing transaction id $transaction_id: $om->{'error'}#);
				}
			}
		}
	if (@errs) {
		my $err = join('<br>',@errs);
		$self->addTemplatePairs('error.import' => qq#<span class="errortext">$err</span>#);
		return $self->show();	
	}
	
	$self->addTemplatePairs('import_successful' => 1);
	return $self->show();
}


1;