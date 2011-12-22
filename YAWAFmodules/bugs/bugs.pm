#-------------------------------------------------------------------------------
# bugs.pm
# ©2006 Harris-Braun Enterprises, LLC, All Rights Reserved
# This software is released under the LGPL license.
# Author: Eric Harris-Braun <eric -at- harris-braun.com>
#-------------------------------------------------------------------------------

package YAWAFmodules::bugs;
use strict;
use Carp;

%YAWAFmodules::bugs::pages = (
	'create' => PAGE::Edit->new(
		'title' => 'Create Bug',
		'tmpl_file_name' => 'edit.html',
		'params' => {
			'table' => 'bug',
			'canCreate' => 1,
			'fields' => ['itemname','type','description','notes','status','account_id','code'],
			'fieldPresets' => {'created' => 'NOW()'},
			'userIDset' => ['created_by_id'],
			'fieldspec' => \%YAWAFmodules::bugs::fields,
			'returnpage' => 'bugs/list',
		},
	),

	'edit' => PAGE::Edit->new(
		'title' => 'Edit Bug',
		'params' => {
			'table' => 'bug',
			'canDelete' => 1,
			'fields' => ['itemname','type','description','notes','status','account_id','code'],
			'fieldsViewOnly' => ['DATE_FORMAT(created,"%m/%d/%y %h:%m") as date','DATE_FORMAT(modified,"%m/%d/%y %h:%m") as modified'],
			'fieldPresets' => {'modified' => 'NOW()'},
			'fieldspec' => \%YAWAFmodules::bugs::fields,
			'returnpage' => 'bugs/list',
			'subsearches' => [
				{
					'name' => 'created_by',
					'singleRecordQuery' => 1,			
					'table' => 'bug,account',
					'fields' => [q#concat(concat(fname,' ',lname)) created_by_name#],
					'where' => q*bug.id = _id_ and account.id=created_by_id*,
				},
			],
		},
	),
		
	'list' => PAGE::Query->new(
		'tmpl_params'=> {'loop_context_vars' => 1,'global_vars' => 1},
		'title' => 'Bugs',
		'params' => {
			'name' => 'bugs',
			'table' => 'bug',
			'left_join' => 'account on account.id = account_id',
			'fields' => ['code','itemname','type','bug.id','DATE_FORMAT(bug.created,"%m/%d/%y") as date','bug.created as d','status','fname as who'],
			'order' => {
				'_default' => 'c',
				'n' => 'itemname,status,type,d',
				'd' => 'd,status,type',
				'r' => 'd DESC,status,type',
				't' => 'status,type,d',
				'w' => 'status,who,itemname,d',
				'c' => 'status,code,itemname'
			},
		},
	),
);

$YAWAFmodules::bugs::account_id_select_spec = HTMLSQLSelect->new(
	{
	'table' => 'account',
	'where' => 'privFlags like "%dev%"',
	'namefield' => q#concat(fname,' ',lname) as name#,
	'valuefield' => 'account.id as value',
	'nullok' => 'All',
	'order' => 'lname',
	}
);


%YAWAFmodules::bugs::fields = (
	'code' => Field::Text->new(
		'name' => 'code',
		'size' => 50,
		'maxlength' => 50,
		),
	'itemname' => Field::Text->new(
		'name' => 'itemname',
		'validation' => ['required'],
		'size' => 55,
		'maxlength' => 100,
		),
	'type' => Field::Select->new(
		'name' => 'type',
		'sqltype' => 'enum',
		'values' => ['structural','appearance','typo','broken','new-to-build','docs'],
		),
	'account_id' => Field::SelectSQL->new(
		'name' => 'account_id',
		'sqltype' => 'int',
		'sqlselect' => $YAWAFmodules::bugs::account_id_select_spec,
		'sqlNullOK' => 1,
		),
	'description' => Field::TextArea->new(
		'name' => 'description',
		'sqltype' => 'text',
		'rows' => 10,
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
		'values' => ['pending','low-priority','fixed','tested','Change Log'],
		),
);

sub get_page {
	my $module_name = shift;
	my $page_name = shift;
	my $page = $YAWAFmodules::bugs::pages{$page_name};
	return $page;
}
1;
