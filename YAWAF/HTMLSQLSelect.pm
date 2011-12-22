#-------------------------------------------------------------------------------
# HTMLSQLSelect.pm
# ©2004 Harris-Braun Enterprises, LLC, All Rights Reserved
#-------------------------------------------------------------------------------

package HTMLSQLSelect;

use strict;
use SQL;
use CGI;

sub new {
	my $class = shift;	
	my $params = shift;
	
	my $self = {
		'namefield' => 'name',
		'valuefield' => 'id as value',
		'order' => 'name',
	};
	bless $self, $class;
	
	foreach (keys %$params) {
		$self->{$_} = $params->{$_};
	}

	return $self;
}


sub makeSelect
{
	my $self = shift;
	my $field = shift;
	my $sql = shift;
	my $q = shift;
	my $cur_val = shift;
	my $querySubstitutions = shift;
	my $returnValueOnly = shift;

	my $lj = $self->{'left_join'};
	my $where = $self->{'where'};
	foreach (keys %$querySubstitutions) {
		my $k = '__'.$_.'__';
		$lj =~ s/$k/$querySubstitutions->{$_}/g if ($lj ne '');
		$where =~ s/$k/$querySubstitutions->{$_}/g if ($where ne '');
	}

	
	my $cw = $self->{'cookie_where'};
	if (defined $cw) {
		foreach (keys %$cw) {
			my $v = $cw->{$_};
			my $cv = $q->cookie($_);
			$v =~ s/%/$cv/;
			$where .= ' and ' if $where ne '';
			$where .= $v;
		}
	}
	foreach (@{$self->{'querysubs'}}) {
		my $k = '__'.$_.'__';
		my $v = $q->param($_);
		$v = $sql->Quote($v) unless $self->{'querysubsdontquote'};
		$lj =~ s/$k/$v/g if ($lj ne '');
		$where =~ s/$k/$v/g if ($where ne '');
	}
	my @fields = ($self->{'namefield'},$self->{'valuefield'});
	push (@fields,@{$self->{'extrafields'}}) if exists ($self->{'extrafields'});
	
	my $recordsP = $sql->GetRecords($self->{'table'},$where,\@fields,$self->{'order'},$lj);
	if (exists $self->{'post_process'}) {
		my $func = $self->{'post_process'};
		$recordsP = &$func($recordsP);
	}
	return _makeSelect($field,$q,$recordsP,$self->{'default'},$cur_val,$self->{'null'},$self->{'nullok'},$self->{'nullval'},$returnValueOnly,$self->{'onChange'});
}

sub _makeSelect
{
	my $field = shift;
	my $q = shift;
	my $recordsP = shift;
	my $default = shift;
	my $cur_val = shift;
	my $null = shift;
	my $nullok = shift;
	my $nullval = shift;
	my $returnValueOnly = shift;
	my $onChange = shift;
	
	my $row;
	my %l;
	my @v;
	if (defined $null && $cur_val eq '') {
		push @v,'';
		$l{''} = $returnValueOnly?$null:'';
	}
	if (defined $nullok) {
		push @v,'';
		$l{''} =$nullok;
	}
	if (defined $nullval) {
		$nullval =~ /(.*)\|(.*)/;
		my ($label,$value) = ($1,$2);
		push @v,$value;
		$l{$value} = $label;
	}
	foreach $row (@$recordsP) {
		push @v,$row->{'value'};
		$l{$row->{'value'}} = $row->{'name'};
	}
	my $sel;
	if ($returnValueOnly == 0) {
		my @p = (
			-name => $field,
			-values => \@v,
			-labels => \%l,
			-default => (defined $cur_val)?$cur_val:$default
		);
		push @p,(-onChange,$onChange) if defined($onChange);
		$sel = $q->popup_menu(@p);
	}
	else {
		$sel = $l{(defined $cur_val)?$cur_val:$default};
	}
	return ($sel,scalar @$recordsP);
}
1;
