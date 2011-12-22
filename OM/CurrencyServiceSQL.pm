#-------------------------------------------------------------------------------
# OM::CurrencyServiceSQL.pm
# ©2006 Harris-Braun Enterprises, LLC, All Rights Reserved
# License: This module is free software; you can redistribute it and/or modify
#          it under the terms of either the Perl Artistic License, or the GNU 
#          General Public License as published by the Free Software Foundation
# Author: Eric Harris-Braun <eric -at- harris-braun.com>
#-------------------------------------------------------------------------------

package OM::CurrencyServiceSQL;

use strict;
use Carp;
use base 'OM::Service';

sub join_currency {
	my $self = shift;
	my $accounts = shift;
	my $join_authorization = shift;
	
	my $table = $self->{'currency_accounts_table'};
	my $sql = $self->{'sql'};
	my %ids;
	my $currency_id = $self->{'currency_id'};
	foreach (@$accounts) {
		my $act = $sql->Quote($_);
		if (!$sql->GetCount($table,"account = $act and currency_id=$currency_id")) {
			my %recs = ('created'=>'NOW()','account' => $act, 'currency_id'=> $currency_id);
			$ids{$_} = $sql->InsertRecord($table,\%recs,1);
		}
		else {
			my $e = $self->{'error'};
			if (!defined($e)) {
				$e = [];
				$self->{'error'} = $e;
			}
			push @$e,"$act is already a member of this currency";
		}
	}
	return \%ids;
}

sub prepare_trade {
	my $self = shift;
	my $account = shift;
	my $with = shift;
	my $trade_spec = shift;

	my $table = $self->{'currency_accounts_table'};
	my $sql = $self->{'sql'};
	my $currency_id = $self->{'currency_id'};

	# right now we are just checking that both accounts have joined the currency.
	# many other checks should be made.
	my $c = $sql->GetCount($table,"account = ".$sql->Quote($account)." and currency_id=$currency_id");
	if ($c == 0) {
		$self->{'error'} = "$account is not a member of this currency";
		return 0;
	}
	$c = $sql->GetCount($table,"account = ".$sql->Quote($with)." and currency_id=$currency_id");
	if ($c == 0) {
		$self->{'error'} = "$with is not a member of this currency";
		return 0;
	}
	return 1;
}

sub get_currency_stats
{
	my $self = shift;
	my $currency_name = $self->{'currency_name'};
	my $filter = shift;
	
	my $sql = $self->{'sql'};
	
	
	#this is a cheat because we should be getting the table name from elsewhere!
	my $r = $sql->GetRecords('om_summary',"currency = ".$sql->Quote($currency_name),['summary','account_id']);
	my $volume;
	my @a;
	foreach (@$r) {
		my $s = OM::Service::_decodeSummary($sql,$_->{'summary'});
		$volume += $s->{'volume'};
		foreach my $k (keys %$s) {
			$_->{$k} = $s->{$k};
		}
		push @a,$_;
	}
	my $spec = OM::Service::_decodeSpec($sql->GetValue('om_currency',"id = ".$self->{'currency_id'},'specification'));

	my $where = 'currency='.$sql->Quote($currency_name);
	my $transaction_count = $sql->GetCount('om_ledger',$where)/2;

	my ($limit,$offset);
	
	if ($filter) {
		_filter2where($filter,\$where,\$limit,\$offset);
	}	

	my $history = $sql->GetRecords('om_ledger',$where,['UNIX_TIMESTAMP(created) as created','account_id','with_account','currency','transaction','transaction_id'],'created desc',undef,undef,$limit*2,$offset*2);

	my @h;
	foreach (@$history) {
		my $h = OM::Service::_decodeSpec($_->{'transaction'});
		next if $h->{'amount'} > 0;
		$h->{'amount'} *= -1;
		$_->{'transaction'} = $h;
		push @h,$_;
	}

	return {
		'volume' => $volume/2,  #gotta devide by two because the volume is the sum of everybodys volume...
		'unit' =>$spec->{'unit'},
		'transaction_count' => $transaction_count,
		'history' => \@h,
		'accounts' => \@a,
	};
}

sub reverse_trade
{
	my $self = shift;
	my $datetime = shift;
	my $id = shift;
	my $comment = shift;

	my $currency_name = $self->{'currency_name'};
	my $sql = $self->{'sql'};
	
	if ($id =~ /-r$/) {
		$self->{'error'} = 'you cannot reverse a reversal';
		return undef;
	}
	
	#this is a cheat because we should be getting the table name from elsewhere!
	my $r = $sql->GetRecords('om_ledger',"currency = ".$sql->Quote($currency_name).'and transaction_id like '.$sql->Quote($id."%"),['account_id','with_account','transaction','transaction_id','currency']);
	if (scalar @$r < 2) {
		$self->{'error'} = 'unknown transaction id in currency '.$currency_name;
		return undef;
	}
	if (scalar @$r > 2) {
		$self->{'error'} = 'transaction already reversed';
		return undef;
	}
	
	_insertReversal($sql,$datetime,$comment,$r->[0]);
	_insertReversal($sql,$datetime,$comment,$r->[1]);
	
	return 1;

}
sub _insertReversal
{
	my $sql = shift;
	my $datetime = shift;
	my $comment = shift;
	my $r = shift;
	
	my $id = $r->{'transaction_id'}."-r",
	my $spec = OM::Service::_decodeSpec($r->{'transaction'});
	$spec->{'amount'} *=-1;
	$spec->{'description'} = qq#reversal of $r->{'transaction_id'}: $comment#;	
	
	my $account_id = $r->{'account_id'};
	my $currency = $r->{'currency'};
	my %recs = (
	'created'=>"from_unixtime($datetime)",
	'transaction_id'=>$sql->Quote($id),
	'account_id'=>$account_id,
	'with_account'=>$sql->Quote($r->{'with_account'}),
	'currency'=>$sql->Quote($currency),
	'transaction'=>$sql->Quote(OM::Service::_encodeSpec($spec))
	);

	my $record_id = $sql->InsertRecord('om_ledger',\%recs,1);
	#we should be locking the summary at this point so there aren't any collisions
	if ($record_id != 0) {
		my $r = $sql->GetRecord('om_summary',"account_id=$account_id and currency=".$sql->Quote($currency),'summary','id');
		my $summary;
		if (defined $r) {
			$summary = &OM::Service::_decodeSummary($sql,$r->{'summary'});
		}
		$summary->{'balance'}+=$spec->{'amount'};
		$summary->{'volume'}-=abs($spec->{'amount'});
		$summary->{'last'} = $datetime;
		my %sumrec = ('summary'=> &OM::Service::_encodeSummary($summary));
		if (!defined($r)) {
			$sumrec{'account_id'} = $account_id;
			$sumrec{'currency'} = $currency;
			my $summary_id = $sql->InsertRecord('om_summary',\%sumrec);
		}
		else {
			$sql->UpdateRecords('om_summary',\%sumrec,"id=$r->{'id'}");
		}
	}
	return $record_id;
}


sub _filter2where
{
	my $filter = shift;
	my $whereP = shift;
	my $limitP = shift;
	my $offsetP = shift;
	if (exists $filter->{'limit'}) {
		$$limitP = $filter->{'limit'};
	}
	if (exists $filter->{'offset'}) {
		$$offsetP = $filter->{'offset'};
	}
}

1;