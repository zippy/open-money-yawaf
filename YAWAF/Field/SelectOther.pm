#-------------------------------------------------------------------------------
# Field::SelectOther.pm
# Copyright (C) 2004 Harris-Braun Enterprises, LLC, All Rights Reserved
# Author: Eric Harris-Braun <eric@harris-braun.com>
#-------------------------------------------------------------------------------

package Field::SelectOther;

use strict;

use base 'Field::QueryField';


sub buildHTML
{
	my $self = shift;
	my $f = shift;
	my $q = shift;
	
	my $fv;
	$fv = $q->popup_menu($self->getMyParamValues(['name','values','labels','default']));
	$fv .= " Other: ".$q->textfield(-name => "other_$f",$self->getMyParamValues(['name','size','maxlength','default']));
	return $fv;
}


1;