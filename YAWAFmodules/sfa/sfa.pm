#-------------------------------------------------------------------------------
# sfa.pm
# ©2006 Harris-Braun Enterprises, LLC, All Rights Reserved
# This software is released under the LGPL license.
# Author: Eric Harris-Braun <eric -at- harris-braun.com>
#-------------------------------------------------------------------------------

package YAWAFmodules::sfa;
use strict;
use Carp;
use Review;
use PAGE::Feed;
use PAGE::Node;

%YAWAFmodules::sfa::pages = (
	'create' => PAGE::Edit->new(
		'section' => 'sfa',
		'title' => 'Create SFA',
		'tmpl_file_name' => 'edit.html',
		'params' => {
			'table' => 'sfa',
			'canCreate' => 1,
			'fields' => ['currency','project','description','notes','amount','start_date','end_date'],
			'fieldPresets' => {'created' => 'NOW()','status'=>'"pending"'},
			'userIDset' => ['created_by_id','account_id'],
			'fieldspec' => \%YAWAFmodules::sfa::fields,
			'returnpage' => 'sfa/list',
		},
	),

	'edit' => PAGE::Edit->new(
		'section' => 'sfa',
		'title' => 'Edit SFA',
		'params' => {
			'table' => 'sfa',
			'canDelete' => 1,
			'fields' => ['currency','project','description','notes','amount','start_date','end_date'],
			'fieldsViewOnly' => ['DATE_FORMAT(created,"%m/%d/%y %h:%m") as created','DATE_FORMAT(modified,"%m/%d/%y %h:%m") as modified'],
			'fieldPresets' => {'modified' => 'NOW()'},
			'fieldspec' => \%YAWAFmodules::sfa::fields,
			'returnpage' => 'sfa/list',
		},
	),
	'details' => PAGE::Edit->new(
		'section' => 'sfa',
		'title' => 'Admin edit SFA',
		'params' => {
			'table' => 'sfa',
			'canCreate' => 1,
			'canDelete' => 1,
			'fields' => ['currency','project','description','notes','account_id','status','amount','start_date','end_date'],
			'fieldsViewOnly' => ['DATE_FORMAT(created,"%m/%d/%y %h:%m") as created','DATE_FORMAT(modified,"%m/%d/%y %h:%m") as modified'],
			'fieldPresets' => {'modified' => 'NOW()'},
			'fieldspec' => \%YAWAFmodules::sfa::fields,
			'returnpage' => 'sfa/stats',
			'subsearches' => [
				{
					'name' => 'created_by',
					'singleRecordQuery' => 1,			
					'table' => 'sfa,account',
					'fields' => [q#concat(concat(fname,' ',lname)) created_by_name#],
					'where' => q*sfa.id = _id_ and account.id=created_by_id*,
				},
			],
		},
	),

	'list' => PAGE::Query->new(
		'tmpl_params'=> {'loop_context_vars' => 1,'global_vars' => 1},
		'section' => 'sfa',
		'title' => 'SFA Workspace',
		'head'=>q#	<link rel="alternate" type="application/rss+xml" title="RSS Feed for SFA" href="?p=sfa/feed" />#,
		'params' => [
			{
			'name' => 'sfa_totals',
			'table' => 'sfa',
			'thisUserIdWhere' => 'account_id = _id_',
			'singleRecordQuery' => 1,
			'fields' => [
				'sum(if(status="pending",1,0)) as pending_count',
				'sum(if(status="pending",amount,0)) as pending_amount',
				'sum(if(status="approved",1,0)) as approved_count',
				'sum(if(status="approved",amount,0)) as approved_amount',
				'sum(if(status="retired",1,0)) as retired_count',
				'sum(if(status="retired",amount,0)) as retired_amount',
				],
			},
			{
			'name' => 'sfa',
			'table' => 'sfa,node',
			'left_join' => 'account on account.id = account_id',
			'thisUserIdWhere' => 'account_id = _id_',
			'where' => 'status = "pending" and node.type="wiki" and node.id=project',
			'fields' => ['concat(left(description,40),if(length(description)>40,"...","")) as description','amount','node.name as project','currency','sfa.id','UNIX_TIMESTAMP(sfa.created) as date','DATE_FORMAT(start_date,"%m/%d/%y") as start_date','start_date as s','sfa.created as d'],
			'fieldsTimeZoneConvertDate' => ['date'],
			'order' => {
				'_default' => 's',
				's' => 's DESC,currency',
				'd' => 'd,currency',
				'r' => 'd DESC,status,currency',
				'p' => 'project,d',
				'c' => 'currency,d',
				'a' => 'amount',
				't' => 'description'
				},
			},
			{
			'name' => 'sfa_review',
			'table' => 'sfa,account,node as pnode',
			'where' => 'account.id = account_id and status = "pending" and pnode.type="wiki" and pnode.id=project',
			'thisUserIdWhere' => 'account_id != _id_ ',
			'left_join' => 'node on node.parent_id = sfa.id and node.type="sfa" and node.modified_by_id = _id_',
			'fields' => ['concat(left(description,40),if(length(description)>40,"...","")) as description','amount','pnode.name as project','currency','sfa.id','UNIX_TIMESTAMP(sfa.created) as date','DATE_FORMAT(start_date,"%m/%d/%y") as start_date','sfa.created as d','start_date as s','status','concat(fname," ",lname) as who','node.id as review_id'],
			'fieldsTimeZoneConvertDate' => ['date'],
			'order' => {
				'_default' => 's',
				's' => 's DESC,currency',
				'd' => 'd,currency',
				'r' => 'd DESC,status,currency',
				'p' => 'project,d',
				'c' => 'currency,d',
				'a' => 'amount',
				't' => 'description',
				'w' => 'who'
				}
			}
		],
	),
	'comment' => PAGE::Node->new(
		'section' => 'sfa',
		'title' => 'Review SFA:Comment',
		'params' => {
			'browse_where' => "type like 'sfa_comment'",
			'table' => 'node',
			'history_table' => 'history',
			'subscriptions_table' => 'subscription',
			'canCreate' => 1,
			'canDelete' => 1,
			'render_tmpl' => 'view',
			'history_tmpl' => 'history',
			'browse_tmpl' => 'review',
			'render_fields' => ['contents','modified'],
			'render_fields_wiki' => ['contents'],
			'name_of_name_field' => 'name',
			'render_querries' => {
				'table' => 'node,account',
				'where' => 'account.id=modified_by_id',
				'fields' => ['fname','lname'],
				'singleRecordQuery' => 1,
			},
			'fields' => ['contents','parent_id'],
			'fieldsViewOnly' => ['DATE_FORMAT(modified,"%m/%d/%y %h:%m") as modified'],
			'fieldPresets' => {'modified' => 'NOW()','type'=>'"sfa_comment"'},
			'userIDset' => ['modified_by_id'],
			'fieldspec' => \%YAWAFmodules::sfa_review::fields,
			'returnpage' => 'sfa/review',
			'querryPassThruValues' => ['order','review_id','sfa_id'],
			'links' => [
				{
					'table' => 'history',
					'id_field_in_link_table' => 'node_id',
				},
			]
		},
	),
	'review' => PAGE::Review->new(
		'section' => 'sfa',
		'title' => 'Review SFA',
		'tmpl_params'=> {'loop_context_vars' => 1,'global_vars' => 1},
		'params' => {
			'browse_where' => "type like 'sfa%'",
			'table' => 'node',
			'history_table' => 'history',
			'subscriptions_table' => 'subscription',
			'canCreate' => 1,
			'canDelete' => 1,
			'render_tmpl' => 'view',
			'history_tmpl' => 'history',
			'browse_tmpl' => 'review',
			'render_fields' => ['name','contents','modified'],
			'render_fields_wiki' => ['contents'],
			'name_of_name_field' => 'name',
			'render_querries' => {
				'table' => 'node,account',
				'where' => 'account.id=modified_by_id',
				'fields' => ['fname','lname'],
				'singleRecordQuery' => 1,
			},
			'fields' => ['contents','name','parent_id'],
			'fieldsViewOnly' => ['UNIX_TIMESTAMP(modified) as modified'],
			'fieldsTimeZoneConvertDate' => {'modified'=>1},
			'fieldPresets' => {'modified' => 'NOW()','type'=>'"sfa"'},
			'userIDset' => ['modified_by_id'],
			'fieldspec' => \%YAWAFmodules::sfa_review::fields,
			'returnpage' => 'sfa/review',
			'querryPassThruValues' => ['parent_id','order','review_id','sfa_id'],
			'links' => [
				{
					'table' => 'history',
					'id_field_in_link_table' => 'node_id',
				},
			]
		},
	),
	'stats' => PAGE::Query->new(
		'tmpl_params'=> {'loop_context_vars' => 1,'global_vars' => 1},
		'section' => 'sfa',
		'title' => 'SFA Stats',
		'params' => [
			{
			'name' => 'sfa_totals',
			'table' => 'sfa',
			'singleRecordQuery' => 1,
			'fields' => [
				'sum(if(status="pending",1,0)) as pending_count',
				'sum(if(status="pending",amount,0)) as pending_amount',
				'sum(if(status="approved",1,0)) as approved_count',
				'sum(if(status="approved",amount,0)) as approved_amount',
				'sum(if(status="retired",1,0)) as retired_count',
				'sum(if(status="retired",amount,0)) as retired_amount',
				],
			},
			{
			'name' => 'sfa',
			'table' => 'sfa,node',
			'left_join' => 'account on account.id = account_id',
			'where' => 'node.type="wiki" and node.id=project',
			'fields' => ['status','concat(left(description,40),if(length(description)>40,"...","")) as description','amount','node.name as project','currency','sfa.id','UNIX_TIMESTAMP(sfa.created) as date','sfa.created as d','concat(fname," ",lname) as who'],
			'fieldsTimeZoneConvertDate' => ['date'],
			'search_field_map' => {
				'who' => q#concat(account.fname,' ',account.lname)#,
				'status' => 'status',
				'description' => 'description',
				'project' => 'project',
				'currency' => 'currency',
			},
			'order' => {
				'_default' => 'm',
				'd' => 'd,currency',
				'r' => 'd DESC,status,currency',
				'p' => 'project,d',
				'c' => 'currency,d',
				'a' => 'amount',
				't' => 'description',
				's' => 'status',
				'w' => 'who'
				},
			},
		],
	),
	'feed' => PAGE::Feed->new(
		'tmpl_params'=> {'loop_context_vars' => 1,'global_vars' => 1},
		'title' => 'node',
		'params' => {
			'table' => 'sfa,account',
			'where' => 'account.id = account_id and status = "pending"',
			'thisUserIdWhere' => 'account_id != _id_ ',
			'left_join' => 'node on node.parent_id = sfa.id and type="sfa" and modified_by_id = _id_',
			'default_items_per_page' => 10,
			'title' => 'Open Money SFA',
			'link' => '?p=sfa/list',
			'entry_link' => '?p=sfa/review&amp;parent_id=',
			'fields' => ['node.id as review_id'],
			'entryFieldMap' => {
				'entry_id' => 'sfa.id',
				'entry_title' => q#concat("$",amount," (",currency,") by ",concat(fname," ",lname)," in ",project," for ",description)#,
				'entry_created' => 'UNIX_TIMESTAMP(sfa.modified) as c',
				'entry_updated' => 'UNIX_TIMESTAMP(sfa.created) as m',
				'summary' => 'sfa.notes'
				},
		},
	),
);

$YAWAFmodules::sfa::account_id_select_spec = HTMLSQLSelect->new(
	{
	'table' => 'account',
	'where' => 'privFlags like "%dev%"',
	'namefield' => q#concat(fname,' ',lname) as name#,
	'valuefield' => 'account.id as value',
	'nullok' => 'All',
	'order' => 'lname',
	}
);

$YAWAFmodules::sfa::project_select_spec = HTMLSQLSelect->new(
	{
	'table' => 'node',
	'where' => 'type = "wiki"',
	'valuefield' => 'node.id as value',
	'order' => 'parent_id,modified DESC',
	'extrafields' => ['parent_id','node.id'],
	'post_process' => \&PAGE::Node::_process
	}
);

%YAWAFmodules::sfa_review::fields = (
	'name' => Field::Select->new(
		'name' => 'name',
		'values' => ['Yes','No','Conditional'],
		),
	'contents' => Field::TextArea->new(
		'name' => 'contents',
		'sqltype' => 'text',
		'rows' => 5,
		'columns' => 60,
		),

	'parent_id' => Field::Hidden->new(
		'name' => 'parent_id',
		'sqltype' => 'int',
		),
);

%YAWAFmodules::sfa::fields = (
	'start_date' => Field::Date->new(
		'name' => 'start_date',
		'validation' => ['required'],
		),
	'end_date' => Field::Date->new(
		'name' => 'end_date',
		),
	'amount' => Field::Text->new(
		'name' => 'amount',
		'validation' => ['required'],
		'size' => 5,
		'maxlength' => 10,
		),
	'currency' => Field::Select->new(
		'name' => 'currency',
		'validation' => ['required'],
#		'sqltype' => 'enum',
		'values' => ['SFA:Time:General','SFA:Time:Dedicated','SFA:Time:Erics Technical','SFA:Time:JFs Technical','SFA:Time:MWL Technical','SFA:Expenses:USD','SFA:Expenses:EUR','SFA:Expenses:CAD','SFA:Quality'],
		),
#	'project' => Field::Text->new(
#		'name' => 'project',
#		'size' => 50,
#		'maxlength' => 50,
#		),
	'project' => Field::SelectSQL->new(
		'name' => 'project',
		'sqlselect' => $YAWAFmodules::sfa::project_select_spec,
		),
	'account_id' => Field::SelectSQL->new(
		'name' => 'account_id',
		'sqltype' => 'int',
		'sqlselect' => $YAWAFmodules::sfa::account_id_select_spec,
		'sqlNullOK' => 1,
		),
	'description' => Field::TextArea->new(
		'name' => 'description',
		'sqltype' => 'text',
		'rows' => 5,
		'columns' => 60,
		),
	'notes' => Field::TextArea->new(
		'name' => 'notes',
		'sqltype' => 'text',
		'rows' => 5,
		'columns' => 60,
		),
	'status' => Field::Select->new(
		'name' => 'status',
		'sqltype' => 'enum',
		'values' => ['pending','approved','retired'],
		),
);

sub get_page {
	my $module_name = shift;
	my $page_name = shift;
	my $page = $YAWAFmodules::sfa::pages{$page_name};
	return $page;
}
%YAWAFmodules::sfa::noLoginPages = (
	'feed' => 1
);
sub is_no_login_page {
	my $module_name = shift;
	my $page_name = shift;	
	my $page = $YAWAFmodules::sfa::noLoginPages{$page_name};
	return $page;
}

1;
