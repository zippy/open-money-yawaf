#-------------------------------------------------------------------------------
# YAWAF::SQL.pm
# ©2002 Eric Harris-Braun, All Rights Reserved
#-------------------------------------------------------------------------------
package YAWAF::SQL;

use strict;
use base 'SQL';


sub doSQLsearch
{
	my $self = shift;
	my $p = shift;
	my $q = shift;
	my $items_per_page = shift;
	my $offset = shift;
	my $substitutionsH = shift;
	my $extra_where = shift;
	my $total_countP = shift;
	
	my $where;
	
	if ($p->{'where'} ne '') {
		$where .= ' and ' if $where ne '';
		$where .= "($p->{'where'})";
	}
	
	if ($extra_where ne '') {
		$where .= ' and ' if $where ne '';
		$where .= $extra_where;
	}

	if (exists $p->{'search_pop_up'}) {
		my $sp = $p->{'search_pop_up'};
		my $n = $sp->{'name'};
		my $search_field_map = $p->{'search_field_map'};
		my $item = $q->param($n);
		$item = $sp->{'default'} if !defined($item);
		my $search_for = $sp->{'vals'}->[$item*2];
		$self->addSearch($search_field_map,\$where,"$n-$sp->{'type'}",$search_for);
	}
	
	if (exists $p->{'checkbox_list'}) {
		my $n = $p->{'checkbox_list'};
		if (defined $q->param($n)) {
			my @vals = $q->param($n);
			$where .= ' and ' if $where ne '';
			my @w;
			foreach (@vals) {
				push @w,"$n = ".$self->Quote($_);
			}
			$where .= '('.join(' or ',@w).')';
		}
	}
	
	if (exists $p->{'search_field_map'}) {
		my $search_field_map = $p->{'search_field_map'};
		my $search_on = $q->param('_search_on');
		my $search_for = $q->param('_search_for');
		$self->addSearch($search_field_map,\$where,$search_on,$search_for) if $search_for ne '';

		foreach (grep (/^_search_on_/,$q->param)) {
			 /_search_on_(.*)/;
			 $search_for = $q->param($_);
			 $self->addSearch($search_field_map,\$where,$1,$search_for) if $search_for ne '';
		}
	}

	if (defined $substitutionsH) {
		while (my($k,$v) = each (%$substitutionsH)) {
			$where =~ s/__$k/$v/g;
		}
	}
	my $left_join = $p->{'left_join'};
	my $fieldsP;
	if (exists $p->{'fieldquerysub'}) {
		my $qsub = $p->{'fieldquerysub'};
		my @fields = @{$p->{'fields'}};
		$fieldsP = \@fields;
		my $fieldname;
		my $fieldCookies = $p->{'fieldcookiesub'};
		foreach $fieldname (keys %$qsub) {
			my $fn = '_'.$fieldname.'_';
			my $fv = $q->param($fieldname);
			if (defined $fieldCookies && $fieldCookies->{$fieldname}) {

				#only use the cookie if there isn't a query value that overrides it
				my $fc = $q->cookie($fn);
				if (!defined($fv) && defined($fc)) {
					$fv = $fc;
				}
			}
			if (exists $p->{'fieldquerysubvaluemap'}) {
				$fv = $p->{'fieldquerysubvaluemap'}->{$fv};
			}
			my $qsType = $qsub->{$fieldname};
			if ($qsType eq 'i') {
				$fv = int($fv);
			}
			elsif ($qsType ne 'nq') {
				if (!defined($fv)) {
					$fv = "''";
				}
				else {
					$fv = $self->Quote($fv);
				}
			}
			grep (s/$fn/$fv/g && 0,@fields);
			$where =~ s/$fn/$fv/g;
			$left_join =~ s/$fn/$fv/g if defined($left_join);
		}
	}
	else {
		$fieldsP = $p->{'fields'};
	}
	my $order;
	if (exists $p->{'order'}) {
		my $o = $p->{'order'};
		if ( ref($o) eq 'HASH') {
			my $qo = $q->param('_order');
			if ($qo eq '') {
				$qo = $o->{'_default'};
			}
			$order = $o->{$qo};
		}
		else {
			$order = $o;
		}
		if ($q->param('_orderd')) {
			$order .= ' DESC';
		}
	}
	my $records = $self->GetRecords($p->{'table'},$where,$fieldsP,$order,$left_join,$p->{'distinct'},$items_per_page,$offset);
	
	my $ss = $p->{'subsearches'};
	if (defined $ss) {
		foreach my $subp (@$ss) {
			my $r;
			my %sp = %$subp;
			my $w = $sp{'where'};
			foreach $r (@$records) {
				my $mw = $w;
				$mw =~ s/_id_/$r->{'id'}/;
				$sp{'where'} = $mw;
				$r->{$sp{'name'}} = $self->doSQLsearch(\%sp);
			}
		}
	}
	
	if (defined $total_countP) {
		$$total_countP = $self->GetCount($p->{'table'},$where,$left_join);
	}
	
	return $records;
}

sub addSearch
{
	my $self = shift;
	my $fieldMap = shift;
	my $whereP = shift;
	my $search_on = shift;
	my $search_for = shift;
	
	$search_on =~ /(.*)-(.*)/;
	my $f = $1;
	my $type = $2;

	my $field = $fieldMap->{$f};
	my $w;
	if ($type eq 'b') {
		$w = "$field like '$search_for%'";
	}
	elsif ($type eq 'c') {
		$w = "$field like '%$search_for%'" ;
	}
	elsif ($type eq 'is') {
		$w = "$field = ".$self->Quote($search_for) ;
	}
	elsif ($type eq 'r') {
		$w = "$field rlike ".$self->Quote($search_for) ;
	}
	if ($w ne '') {
		$$whereP .= ' and ' if $$whereP ne '';
		$$whereP.= $w;
	}
}

1;
