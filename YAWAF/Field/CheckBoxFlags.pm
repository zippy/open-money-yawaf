#-------------------------------------------------------------------------------
# Field::CheckBoxFlags.pm
# Copyright (C) 2004 Harris-Braun Enterprises, LLC, All Rights Reserved
# Author: Eric Harris-Braun <eric@harris-braun.com>
#-------------------------------------------------------------------------------

package Field::CheckBoxFlags;

use strict;

use base 'Field::QueryField';

sub _initialize
{
	my $self = shift;
	$self->{'htmlParamList'} = ['name','values','default','labels','linebreak','rows','columns','nolabels','rowheaders','colheaders','onClick'];
}

sub makeHTML
{
	my $self = shift;
	my $q = shift;
	my $page = shift;
	return $q->checkbox_group(@_);
}

sub buildHTMLnoEdit
{
	my $self = shift;
	my $f = shift;
	my $q = shift;
	my $page = shift;
	my $fv;
	
	if (exists $self->{'labels'}) {
		my @v = $q->param($f);
		my @vals;
		foreach (@v) {
			push @vals,$self->{'labels'}->{$_};
		}
		return join(',',@vals);
	}
	return join(',',$q->param($f));
}

sub getFieldValueFromQuery
{
	my $self = shift;
	my $f = shift;
	my $q = shift;
	
	my $sc = $self->{'splitchar'};
	$sc = (defined $sc)?'':',';
	return join($sc,$q->param($f));
}

sub setQueryFromFieldValue
{
	my $self = shift;
	my $field = shift;
	my $q = shift;
	my $recordP = shift;
	
	my $flag;
	my $v = $recordP->{$field};
	my $sc = $self->{'splitchar'};
	$sc = (defined $sc)?'':',';
	$q->param($field => ($v eq '')?'':split(/$sc/,$v));
}

1;