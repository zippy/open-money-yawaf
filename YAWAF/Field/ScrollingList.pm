#-------------------------------------------------------------------------------
# Field::ScrollingList.pm
# ©2006 Harris-Braun Enterprises, LLC, All Rights Reserved
# License: This module is free software; you can redistribute it and/or modify
#          it under the terms of either the Perl Artistic License, or the GNU 
#          General Public License as published by the Free Software Foundation
# Author: Eric Harris-Braun <eric -at- harris-braun.com>
#-------------------------------------------------------------------------------

package Field::ScrollingList;

use strict;

use base 'Field::QueryField';

sub _initialize
{
	my $self = shift;
	$self->{'htmlParamList'} = [qw(name values labels default multiple size attributes onChange onFocus onMouseOver onMouseOut onBlur)];
}

sub makeHTML
{
	my $self = shift;
	my $q = shift;
	my $page = shift;
	return $q->scrolling_list(@_);
}


1;