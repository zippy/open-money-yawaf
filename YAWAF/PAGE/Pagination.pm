#-------------------------------------------------------------------------------
# PAGE::Pagination.pm
# ©2006 Harris-Braun Enterprises, LLC, All Rights Reserved
# License: This module is free software; you can redistribute it and/or modify
#          it under the terms of either the Perl Artistic License, or the GNU 
#          General Public License as published by the Free Software Foundation
# Author: Eric Harris-Braun <eric -at- harris-braun.com>
#-------------------------------------------------------------------------------

package PAGE::Pagination;

use strict;

sub Add
{
	my $page = shift;
	my $items_per_page = shift;
	my $offset = shift;
	my $total_count = shift;
	
	my @page_array;
	my $n;
	my $current_page_num;
	$current_page_num = $offset/$items_per_page;
	my $page_count = $total_count/$items_per_page;
	$page_count = int((int($page_count) != $page_count)?$page_count+1:$page_count);
	if ($page_count > 1) {
		foreach (0..$page_count-1){
			push @page_array,{'index_num'=> $n,'page_num'=> $_ +1,'current_page'=>($_ == $current_page_num)};
			$n += $items_per_page;
		};
		$page->addTemplatePairs(
			'_pages' => \@page_array,
			'_items_per_page'=>$items_per_page,
			'_total_pages'=>$page_count
			);
	}
}

1;