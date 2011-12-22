#-------------------------------------------------------------------------------
# node.pm
# ©2006 Harris-Braun Enterprises, LLC, All Rights Reserved
# This software is released under the LGPL license.
# Author: Eric Harris-Braun <eric -at- harris-braun.com>
#-------------------------------------------------------------------------------

package YAWAFmodules::node;
use strict;
use Carp;
use PAGE::Node;
use PAGE::Feed;

%YAWAFmodules::node::pages = (
	'node' => PAGE::Node->new(
		'title' => 'Road Map',
		'tmpl_params'=> {'loop_context_vars' => 1,'global_vars' => 1},
		'section'=> 'rmap',
		'head'=>q#<link rel="alternate" type="application/rss+xml" title="RSS Feed for Road Map" href="?p=node/feed" /><script src="http://wiki.script.aculo.us/javascripts/prototype.js" type="text/javascript"></script><script src="javascripts/scriptaculous.js" type="text/javascript"></script>#,
		'params' => {
			'browse_where' => "type='wiki'",
			'table' => 'node',
			'history_table' => 'history',
			'subscriptions_table' => 'subscription',
			'canCreate' => 1,
			'canDelete' => 1,
			'render_tmpl' => 'view',
			'history_tmpl' => 'history',
			'browse_tmpl' => 'browse',
			'render_fields' => ['name','contents','modified','parent_id'],
			'render_fields_wiki' => ['contents'],
			'name_of_name_field' => 'name',
			'render_querries' => {
				'table' => 'node,account',
				'where' => 'account.id=modified_by_id',
				'fields' => ['fname','lname'],
				'singleRecordQuery' => 1,
			},
			'ignore_if_undefined' => ['contents','name','parent_id'],
			'fields' => ['contents','name','parent_id'],
			'fieldsViewOnly' => ['DATE_FORMAT(modified,"%m/%d/%y %h:%m") as modified'],
			'fieldPresets' => {'modified' => 'NOW()','type'=>'"wiki"'},
			'userIDset' => ['modified_by_id'],
			'fieldspec' => \%YAWAFmodules::node::fields,
			'returnpage' => 'node/node',
			'returnmethod' => 'render',
			'querryPassThruValues' => ['parent_id','parent_id_val','level_plus_one','depth','show_contents','order','edit_contents','edit_name','edit_parent'],
			'links' => [
				{
					'table' => 'history',
					'id_field_in_link_table' => 'node_id',
				},
			]
		},
	),
	'create' => PAGE::Edit->new(
		'section' => 'node',
		'title' => 'Create node',
		'tmpl_file_name' => 'edit.html',
		'params' => {
			'table' => 'node',
			'canCreate' => 1,
			'fields' => ['contents','name','parent_id','type'],
			'fieldPresets' => {'modified' => 'NOW()'},
			'userIDset' => ['modified_by_id'],
			'fieldspec' => \%YAWAFmodules::node::fields,
			'returnpage' => 'node/list',
		},
	),


	'rename' => PAGE::Edit->new(
		'section' => 'node',
		'title' => 'Rename Node',
		'params' => {
			'table' => 'node',
			'fields' => ['name'],
			'fieldPresets' => {'modified' => 'NOW()'},
			'userIDset' => ['modified_by_id'],
			'fieldspec' => \%YAWAFmodules::node::fields,
			'returnpage' => 'node/name',
		},
	),
	
	'name' => PAGE::Edit->new(
		'section' => 'node',
		'title' => 'Edit Node',
		'params' => {
			'table' => 'node',
			'fieldsViewOnly' => ['name'],
			'fieldspec' => \%YAWAFmodules::node::fields,
			'returnpage' => 'node/list',
		},
	),


	'edit' => PAGE::Edit->new(
		'section' => 'node',
		'title' => 'Edit Node',
		'params' => {
			'table' => 'node',
			'canDelete' => 1,
			'fields' => ['contents','name','parent_id','type'],
			'fieldsViewOnly' => ['DATE_FORMAT(modified,"%m/%d/%y %h:%m") as modified'],
			'fieldPresets' => {'modified' => 'NOW()'},
			'userIDset' => ['modified_by_id'],
			'fieldspec' => \%YAWAFmodules::node::fields,
			'returnpage' => 'node/list',
			'subsearches' => [
				{
					'name' => 'modified_by',
					'singleRecordQuery' => 1,			
					'table' => 'account,node',
					'fields' => [q#concat(concat(fname,' ',lname)) modified_by_name#],
					'where' => q*node.id = _id_ and account.id=modified_by_id*,
				},
			],
		},
	),

	'list' => PAGE::Query->new(
		'tmpl_params'=> {'loop_context_vars' => 1,'global_vars' => 1},
		'section' => 'node',
		'title' => 'node',
		'params' => {
			'name' => 'nodes',
			'table' => 'node',
			'fields' => ['name','parent_id','node.id','DATE_FORMAT(node.modified,"%m/%d/%y") as modified','node.modified as m','type'],
			'order' => {
				'_default' => 'm',
				'm' => 'm',
				'r' => 'm DESC',
				'n' => 'name',
			},
		},
	),
	'feed' => PAGE::Feed->new(
		'tmpl_params'=> {'loop_context_vars' => 1,'global_vars' => 1},
		'title' => 'node',
		'params' => {
			'table' => 'node',
			'where' => "type='wiki'",
			'default_items_per_page' => 10,
			'title' => 'Road Map Feed',
			'link' => '?p=node/browse',
			'entry_link' => '?p=node/node&amp;m=render&amp;id=',
			'entryFieldMap' => {
				'entry_id' => 'id',
				'entry_title' => 'name',
				'entry_updated' => 'UNIX_TIMESTAMP(modified) as m',
				'summary' => 'contents',
				},
		},
	),
);

%YAWAFmodules::node::fields = (
	'name' => Field::Text->new(
		'validation' => ['required'],
		'name' => 'name',
		'size' => 60,
		'maxlength' => 255,
		),
	'type' => Field::Text->new(
		'name' => 'type',
		'size' => 20,
		'maxlength' => 255,
		),
	'parent_id' => Field::Text->new(
		'name' => 'parent_id',
		'sqltype' => 'int',
		),
	'contents' => Field::TextArea->new(
		'name' => 'contents',
		'sqltype' => 'text',
		'rows' => 10,
		'columns' => 70,
		),
);

sub get_page {
	my $module_name = shift;
	my $page_name = shift;
	my $page = $YAWAFmodules::node::pages{$page_name};
	return $page;
}

%YAWAFmodules::node::noLoginPages = (
	'feed' => 1
);
sub is_no_login_page {
	my $module_name = shift;
	my $page_name = shift;	
	my $page = $YAWAFmodules::node::noLoginPages{$page_name};
	return $page;
}

1;
