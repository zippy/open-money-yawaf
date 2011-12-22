#-------------------------------------------------------------------------------
# PAGE::Review.pm
# Copyright (C) 2006 Harris-Braun Enterprises, LLC, All Rights Reserved
# This software is released under the LGPL license.
# Author: Eric Harris-Braun <eric -at- harris-braun.com>
#-------------------------------------------------------------------------------

package PAGE::Review;

use strict;

use base 'PAGE::Node';
use sendmail;

sub _initialize
{
	my $self = shift;
	$self->SUPER::_initialize;

	$self->{'default_method'} = 'show';

}

sub setup {
	my $self = shift;
	my $page_name = shift;
	my $app = shift;

	my $sql = $app->param('sql');
	my $q = $app->query();

	if ($self->param('m') eq 'show' || $self->param('m') eq '') {
		$q->param('id',$q->param('review_id')) if $q->param('review_id');
	}

	$self->SUPER::setup($page_name,$app);
	
	if ($self->param('m') eq 'show') {
		my $table = 'sfa';
		my $account_table = 'account';
		
		$q->param('parent_id',$q->param('sfa_id')) if $q->param('sfa_id');

		my $id = $q->param('parent_id');
		$self->addTemplatePairs('sfa_id',$id) if $id;	
		$self->addTemplatePairs('review_id',$q->param('id'));	
		
		my @fields = ('account_id','currency','node.name as project','description','sfa.notes','amount',"UNIX_TIMESTAMP($table.modified) as modified",'UNIX_TIMESTAMP(sfa.created) as created','concat(fname," ",lname) as who');	
		my $recordP = $sql->GetRecord("$table,$account_table,node","$account_table.id = account_id and $table.id=$id and node.type='wiki' and sfa.project = node.id",@fields);
		$recordP->{'modified'} = $app->convertUnixTimeToUserTime($recordP->{'modified'});
		$recordP->{'created'} = $app->convertUnixTimeToUserTime($recordP->{'created'});
		$recordP->{'notes'} =~ s/\n/<br \/>/g;
		$self->addTemplatePairs(%$recordP);	

		my $user_id = $app->getUserID();
		$self->addTemplatePairs('is_my_sfa',1) if $user_id == $recordP->{'account_id'};	

	
		my $recordsP = $self->_browse($sql,'node',$account_table,qq#type = 'sfa' and parent_id=$id#,$q->param('order'));

		my @r;
		foreach my $r (@$recordsP) {
			$r->{'parent_id'} = 0;
			$r->{'is_review'} = 1;
			my $rP = $self->_browse($sql,'node',$account_table,qq#type = 'sfa_comment' and parent_id=$r->{'id'}#,$q->param('order'));
			push (@r, @$rP) if scalar @$rP;
		}
		push @$recordsP,@r;
		$recordsP = &PAGE::Node::_process($recordsP,undef,'');
		$self->addTemplatePairs('reviews' => $recordsP);
	}

}

			'subsearches' => [
				{
					'name' => 'project_name',
					'singleRecordQuery' => 1,			
					'table' => 'sfa,node',
					'fields' => [q#node.name as name#],
					'source_fields' => ['project'],
					'where' => q*sfa.type="wiki" and sfa.project = _project_ *,
				},
			],

1;
