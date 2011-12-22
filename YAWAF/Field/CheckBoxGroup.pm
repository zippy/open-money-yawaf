#-------------------------------------------------------------------------------
# Field::CheckBoxGroup.pm
# Copyright (C) 2004 Harris-Braun Enterprises, LLC, All Rights Reserved
# Author: Eric Harris-Braun <eric@harris-braun.com>
#-------------------------------------------------------------------------------

package Field::CheckBoxGroup;

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



1;