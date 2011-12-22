#-------------------------------------------------------------------------------
# Field::CheckBoxGroupSQL.pm
# Copyright (C) 2004 Harris-Braun Enterprises, LLC, All Rights Reserved
# Author: Eric Harris-Braun <eric@harris-braun.com>
#-------------------------------------------------------------------------------

package Field::CheckBoxGroupSQL;

use strict;

use base 'Field::QueryField';

sub _initialize
{
	my $self = shift;
	$self->{'htmlParamList'} = ['name','linebreak','rows','columns','nolabels','rowheaders','colheaders','onClick'];
}

sub makeHTML
{
	my $self = shift;
	my $q = shift;
	my $page = shift;
		
	my ($v,$l) = $self->getLnVfromSQL($q,$page);
	
	return $q->checkbox_group(
		-values => $v,
		-labels => $l,
		@_
		);
}

sub getLnVfromSQL
{
	my $self = shift;
	my $q = shift;
	my $page = shift;

	my $row;
	my %l;
	my @v;

	my $sql = $page->param('sql');

	my $recordsP = $sql->doSQLsearch($self->{'sqlParams'},$q);
	
	my $valFieldName = $self->{'valueFieldName'};
	my $labelFieldName = $self->{'labelFieldName'};
	foreach $row (@$recordsP) {
		my $v = $row->{$valFieldName};
		push @v,$v;
		$l{$v} = $row->{$labelFieldName};
	}
	return (\@v,\%l);
}

sub buildHTMLnoEdit
{
	my $self = shift;
	my $f = shift;
	my $q = shift;
	my $page = shift;

	my ($v,$l) = $self->getLnVfromSQL($q,$page);
	
	if (defined $l) {
		my @v = $q->param($f);
		my @vals;
		foreach (@v) {
			push @vals,$l->{$_};
		}
		return join(',',@vals);
	}
	return join(',',$q->param($f));
}


sub getFieldValueFromQuery
{
	my $self = shift;
	my $field = shift;
	my $q = shift;

	my @v = $q->param($field);
	return join(',',@v);
}

sub setQueryFromFieldValue
{
	my $self = shift;
	my $field = shift;
	my $q = shift;
	my $recordP = shift;

	if (exists $recordP->{$field}) {
		my @v = split(',',$recordP->{$field});
		$q->param($field,@v);
	}
}


1;