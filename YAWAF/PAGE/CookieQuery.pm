#-------------------------------------------------------------------------------
# CookieQuery.pm
# ©2006 Harris-Braun Enterprises, LLC, All Rights Reserved
# License: This module is free software; you can redistribute it and/or modify
#          it under the terms of either the Perl Artistic License, or the GNU 
#          General Public License as published by the Free Software Foundation
# Author: Eric Harris-Braun <eric -at- harris-braun.com>
#-------------------------------------------------------------------------------

package PAGE::CookieQuery;

use strict;
use base 'PAGE::Query';


sub setup
{
	my $self = shift;
	my $page_name = shift;
	my $app = shift;

	my $q = $app->query();
	my $p = $self->{'params'};
	if (exists $p->{'cookie_values'}) {
		foreach my $c (@{$p->{'cookie_values'}}) {
			my $cookie_name = $c->{'name'};
			my $value = $q->cookie($cookie_name);
			if (!defined $value) {
				my $d = $c->{'default'};
				if (ref($d) eq 'CODE') {
					$value = &$d($app,$self,$q);
				}
				else {
					$value = $d;
				}
			}
			if ($c->{'type'} eq 'i') {
				$value = int($value);
			}
			if (exists $c->{'field'}) {
				my $f = $c->{'field'};
				my $field_name = $f->{'name'};
				$f->setQueryFromFieldValue($field_name,$q,{$field_name => $value});
				$self->addTemplatePairs($field_name,$f->buildHTML($field_name,$q,$self));	
			}
		}
	}

	$self->SUPER::setup($page_name,$app);
}

1;