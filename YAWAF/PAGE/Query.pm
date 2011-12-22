#-------------------------------------------------------------------------------
# PAGE::Query.pm
# ©2004 Harris-Braun Enterprises, LLC, All Rights Reserved
#-------------------------------------------------------------------------------

package PAGE::Query;

use strict;

use base 'PAGE';

sub setup
{
	my $self = shift;
	my $page_name = shift;
	my $app = shift;

	my $q = $app->query();
	my $sql = $app->param('sql');

	my $params = $self->{'params'};
	
	$self->specErrorDie($page_name,'params undefined') if not defined($params);

	# this whole thing doesn't work great because you can only use one 
	# filter set because they are global to the template!!
	if (ref($params) eq 'HASH') {
		$params = [$params];
	}
	foreach my $p (@$params) {

		if (exists $p->{'queryOnSearchOnly'}) {
			if (not defined $q->param('_search_on')) {
				if (exists $p->{'fieldDefaults'}) {
					while (my ($k,$v) = each(%{$p->{'fieldDefaults'}})) {
						$q->param($k => $v);
					}
				}
				$self->SUPER::setup($page_name,$app);
				$self->addFlagsToTemplatPairs('_no_search_done');
				return;
			}
		}
		
		if (exists $p->{'search_pop_up'}) {
			my $sp = $p->{'search_pop_up'};
			my @v = @{$sp->{'vals'}};
			my @values;
			my %labels;
			my $i = 0;
			while (@v) {
				my $key = shift @v;
				my $val = shift @v;
				push @values,$i;
				$labels{$i} = $val;
				$i++;
			}
			my @params = (
				'-name' => $sp->{'name'},
				'-labels' => \%labels,
				'-values' => \@values,
			);
			push @params, @{$sp->{'params'}} if exists $sp->{'params'};
			push (@params, '-default',"$sp->{'default'}") if exists($sp->{'default'});
			$self->addTemplatePairs(
				$sp->{'name'} => $q->popup_menu(@params)
			);
		}
	
		my $id_where;
		if (exists $p->{'thisUserIdWhere'}) {
			$id_where = $p->{'thisUserIdWhere'};
			my $id = $app->getUserID();
			$id_where =~ s/_id_/$id/g;
			$p->{'left_join'} =~ s/_id_/$id/g;
		}
		
		my $fieldCookies = $p->{'fieldcookiesub'};
		if (defined $fieldCookies) {
			foreach (keys %$fieldCookies) {
				my $fn = '_'.$_.'_';
				my $fc = $q->cookie($fn);
				my $fv = $q->param($_);
				if (defined($fv) && (!defined($fc)|| $fv ne $fc)) {
					$app->add_cookie($q->cookie(-name=>$fn,-value=>$fv,-expires=>'+'.$fieldCookies->{$_}.'s'));
				}
			}
		}
		
		my $total_count;
		my $offset;
		my $default_items_per_page = $p->{'default_items_per_page'};
		$default_items_per_page = int($q->param('_i')) if $q->param('_i');
		$offset = $q->param("_n");
		my $rP = $sql->doSQLsearch($p,$q,$default_items_per_page,$offset,undef,$id_where,\$total_count);

		if (exists $p->{'fieldsTimeZoneConvertDate'}) {
			my $tzFields = $p->{'fieldsTimeZoneConvertDate'};
			my $tz = $app->getUserTimeZone;
			foreach my $r (@$rP) {
				foreach (@$tzFields) {
					$r->{$_} = $app->convertUnixTimeToTimeZoneTime($r->{$_},$tz);
				}
			}
		}
		
		if ((not defined $rP) || (scalar @$rP == 0)) {
			$self->addFlagsToTemplatPairs('_search_failed');
		}
		else {
			my $processP = $p->{'fieldsProcess'};
			if (exists $p->{'singleRecordQuery'}) {
				my $hP = $rP->[0];
				if (defined $processP) {
					if (ref($processP) eq 'CODE') {
						&$processP($app,$self,$hP);
					}
					else {
						&processRecord($hP,$processP);
					}
				}
				foreach (keys %$hP) {
					$self->addTemplatePairs($_ => $hP->{$_});
				}
			}
			else {
				if (defined $processP) {
					if (ref($processP) eq 'CODE') {
						$rP = &$processP($app,$self,$rP);
					}
					else {
						$rP = $self->postProcess($rP,$processP);
					}
				}
				$self->addTemplatePairs(
					$p->{'name'} => $rP,
					'_count' => $total_count
				);
				
				if ($default_items_per_page != 0){
					my @page_array;
					my $n;
					my $current_page_num;
					$current_page_num = $offset / ($default_items_per_page);
					foreach (0..$total_count/$default_items_per_page){
						push @page_array,{'index_num'=> $n,'page_num'=> $_ +1,'current_page'=>($_ == $current_page_num)};
						$n += $default_items_per_page;
					};
					$self->addTemplatePairs('_pages' => \@page_array);
				};
			
				
			}
		}
		if (exists $p->{'search_field_map'}) {
			$self->addTemplatePairs('_order'=> $q->param('_order'));
			$self->addTemplatePairs('_order_'.$q->param('_order') => 'selected');
			$self->addTemplatePairs('_search_on_'.$q->param('_search_on') => 'selected');
			foreach (grep (/^_search_on_/,$q->param)) {
				$self->addTemplatePairs($_ => $q->param($_));
				$self->addTemplatePairs($_.'_'.$q->param($_) => 'selected');
			}
			$self->addTemplatePairs('_search_for' => $q->param('_search_for'));
			$self->addTemplatePairs('_search_on' => $q->param('_search_on'));
		}
	}
	$self->SUPER::setup($page_name,$app);
}

sub postProcess
{
	my $self = shift;
	my $recordsP = shift;
	my $specP = shift;
	my $r;
	foreach $r (@$recordsP) {
		&processRecord($r,$specP);
	}
	return $recordsP;
}

sub processRecord
{
	my $rP = shift;
	my $specP = shift;
	while (my ($k,$v) = (each %$specP)) {
		my $pairsList;
		if (ref($v) eq 'ARRAY') {
			$pairsList = $v;
		}
		else {
			$pairsList = [$v];
		}
		foreach my $pair (@$pairsList) {
			my ($pat,$r) = split(/\~/,$pair);
			$rP->{$k} =~ s/$pat/$r/g;
		}
	}
}
1;