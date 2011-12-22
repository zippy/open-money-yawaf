#-------------------------------------------------------------------------------
# OM::AccountServiceSQL.pm
# ©2006 Harris-Braun Enterprises, LLC, All Rights Reserved
# License: This module is free software; you can redistribute it and/or modify
#          it under the terms of either the Perl Artistic License, or the GNU 
#          General Public License as published by the Free Software Foundation
# Author: Eric Harris-Braun <eric -at- harris-braun.com>
#-------------------------------------------------------------------------------

package OM::AccountServiceSQL;

use strict;
use Carp;
use base 'OM::Service';

sub record_trade {
	my $self = shift;
	my $transaction_id = shift;
	my $with_account = shift;
	my $currency = shift;
	my $datetime = shift;
	my $datetime_format = shift;
	my $spec = shift;

	my $account_id = $self->{'account_id'};
	
	my $spec_text = OM::Service::_encodeSpec($spec);
	
	my $sql = $self->{'sql'};

	my $date = OM::Service::date2SQLDateFormat($sql,$datetime,$datetime_format);

	my $table = $self->{'ledger_table'};
	my %recs = (
		'created'=>$sql->Quote($date),
		'transaction_id'=>$transaction_id,
		'account_id'=>$account_id,
		'with_account'=>$sql->Quote($with_account),
		'currency'=>$sql->Quote($currency),
		'transaction'=>$sql->Quote($spec_text)
		);
	my $r = $sql->GetRecord($table,"transaction_id=".$sql->Quote($transaction_id)." and account_id=$account_id",'id');
	if (defined $r) {
		$self->{'error'} = 'transaction id already exists';
		return 0;
	}
	
	#TODO: we should be locking the summary at this point so there aren't any collisions
	my $record_id = $sql->InsertRecord($table,\%recs,1);
	if ($record_id != 0) {
		my $r = $sql->GetRecord($self->{'summary_table'},"account_id=$account_id and currency=".$sql->Quote($currency),'summary','id');
		my $summary;
		if (defined $r) {
			$summary = &OM::Service::_decodeSummary($sql,$r->{'summary'});
		}
		$summary->{'balance'}+=$spec->{'amount'};
		$summary->{'volume'}+=abs($spec->{'amount'});
		$summary->{'last'} = $date;
		my %sumrec = ('summary'=> &OM::Service::_encodeSummary($summary));
		if (!defined($r)) {
			$sumrec{'account_id'} = $account_id;
			$sumrec{'currency'} = $currency;
			my $summary_id = $sql->InsertRecord($self->{'summary_table'},\%sumrec);
		}
		else {
			$sql->UpdateRecords($self->{'summary_table'},\%sumrec,"id=$r->{'id'}");
		}
	}
	return $record_id;

}

sub _filter2where
{
	my $sql = shift;
	my $filter = shift;
	my $whereP = shift;
	my $limitP = shift;
	my $offsetP = shift;
	if (exists $filter->{'currencies'}) {
		my @w;
		foreach (@{$filter->{'currencies'}}) {
			push @w,"currency = ".$sql->Quote($_);
		}
		$$whereP = "($$whereP) and (".join(' or ',@w).")";
	}
	if (exists $filter->{'limit'}) {
		$$limitP = $filter->{'limit'};
	}
	if (exists $filter->{'offset'}) {
		$$offsetP = $filter->{'offset'};
	}
}

sub get_trade_summary {
	my $self = shift;
	my $filter = shift;
	
	my $account_id = $self->{'account_id'};
	my $where = "account_id=$account_id";
	
	my $sql = $self->{'sql'};

	if ($filter) {
		_filter2where($sql,$filter,\$where);
	}
	
	my $table = $self->{'summary_table'};
	my $r = $sql->GetRecords($table,$where,['summary','currency']);
	foreach (@$r) {
		$_->{'summary'} = OM::Service::_decodeSummary($sql,$_->{'summary'});
	}
	return $r;
}

sub initialize_trade_summary {
	my $self = shift;
	my $currency = shift;
	
	my $account_id = $self->{'account_id'};
	my $sql = $self->{'sql'};

	my $summary;
	$summary->{'balance'} = 0;
	$summary->{'volume'} = 0;
	my %sumrec = ('summary'=>OM::Service::_encodeSummary($summary));
	$sumrec{'account_id'} = $account_id;
	$sumrec{'currency'} = $currency;
	my $summary_id = $sql->InsertRecord($self->{'summary_table'},\%sumrec);
}


sub get_trade_history {
	my $self = shift;
	my $filter = shift;
	
	my $account_id = $self->{'account_id'};
	my $where = "account_id=$account_id";
	my $limit;
	my $offset;
	
	my $sql = $self->{'sql'};

	if ($filter) {
		_filter2where($sql,$filter,\$where,\$limit,\$offset);
	}

	my $table = $self->{'ledger_table'};
	my $r = $sql->GetRecords($table,$where,['UNIX_TIMESTAMP(created) as created','with_account','currency','transaction','transaction_id'],'created desc',undef,undef,$limit,$offset);
	foreach (@$r) {
		$_->{'transaction'} = OM::Service::_decodeSpec($_->{'transaction'});
	}
	my $total;
	if ($limit) {
		$total = $sql->GetCount($table,$where);
	}
	else {
		$total = scalar @$r;
	}
	return ($r,$total);
}

1;