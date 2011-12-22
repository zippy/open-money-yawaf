#-------------------------------------------------------------------------------
# pages.pl
# ©2006 Harris-Braun Enterprises, LLC, All Rights Reserved
# This software is released under the LGPL license.
# Author: Eric Harris-Braun <eric -at- harris-braun.com>
#-------------------------------------------------------------------------------

use PAGE;
use PAGE::Query;
use PAGE::Edit;
use PAGE::Login;
use PAGE::Account;
use PAGE::AccountChange;
use PAGE::AccountInfoEmail;
use PAGE::Email;

require "fields.pl";

%main::pagePrivs = (
	'accountNew' => 'createAct',
	'accountActivate' => 'createAct',
	'accountPasswordReset' => 'admin',
	'eventLog' => 'admin',
	'accountPrivs' => 'privs',
	'accountList' => 'act',
	'account' => 'act',
	'exportAccounts' => 'dev',
	'l10n' => 'dev',
	'sysEmail' => ['admin'],
);

%main::noLoginPages = (
	'requestLoginInfo' => 1,
	'home' => 1,
	'about' => 1,
);

%main::pages = 
(
	'home' => PAGE::Login->new(
		'title' => 'home',
		'params' => {
			'fields' => ['name','password'],
			'fieldspec' => \%main::loginFields,
		},
	),
	'about' => PAGE->new(
		'title' => 'About',
	),
	'noPrivs' => PAGE->new(
		'title' => 'Insufficient Privileges',
	),
	'requestLoginInfo' => PAGE::AccountInfoEmail->new(
		'title' => 'Request Login Info',
		'params' => {
			'table' => 'account',
			'efields' => ['name','password'],
			'querryPassThruValues' => ['email'],
			'selfreturnpage' => 1,
		},
	),
	'sysEmail' => PAGE::Email->new(
		'title' => 'Send an email',
		'params' => {
			'from' => {
				'source' => 'curUser',
				'addToPage' => 1,
				'fields' => ['email','fname','lname']
				},
			'to' => {
				'source' => 'queryid',
				'table' => 'account',
				'addToPage' => 1,
				'addToQuery' => ['email'],
				'fields' => ['email','fname','lname']
				},
			'cc' => {
				'source' => 'curUser',
				'fields' => ['email'],
				},
			'fields' => ['to_email','subject','body'],
			'selfreturnpage' => 1,
			'fieldspec' => {
				'subject' => $main::emailFieldSubject,
				'to_email' => $main::emailFieldTo,
				'body' => $main::emailFieldBody,
				}
			},
		),
	'logout' => PAGE->new,
	'login' => PAGE::Login->new(
		'title' => 'Log in',
		'params' => {
			'fields' => ['name','password'],
			'fieldspec' => \%main::loginFields,
		},
	),
	'accountNew' => PAGE::Edit->new(
		'title' => 'New Page',
		'section' => 'users',
		'params' => {
			'table' => 'account',
			'canCreate' => 1,
			'createOnly' => 1,
			'fields' => ['name'],
			'fieldPresets' => {'created' => 'NOW()'},
			'fieldspec' => \%main::accountFields,
			'ticket' => {'badTicketPage' => 'accountNewBadticket'},
			'returnpage' => 'account',
		},
	),
	'accountPrivs' => PAGE::Edit->new(
		'title' => 'User Privileges',
		'section' => 'users',
		'params' => {
			'table' => 'account',
			'fields' => ['privFlags'],
			'fieldsViewOnly' => ['name'],
			'fieldspec' => \%main::accountFields,
			'returnpage' => 'accountList',
			'reloadAccountInfoOnReturn' => 1,
			'querryPassThruValues' => ['_search_on','_search_for','_search_on_t-is','_order'],
		},	
	),
	'accountActivated' => PAGE->new(
		'section' => 'users',
		'title' => 'User Activated',
	),
	'accountPasswordReset' => PAGE->new(
		'section' => 'users',
		'title' => 'User Password Reset',
	),
	'accountPasswordDeleted' => PAGE->new(
		'section' => 'users',
		'title' => 'User Password Deleted',
	),
	'account' => PAGE::Account->new(
		'section' => 'users',
		'tmpl_params'=> {'loop_context_vars' => 1,'global_vars' => 1},
		'title' => 'User',
		'params' => {
			'table' => 'account',
			'fields' => ['fname','lname','email','phone','phone2','address1','address2','city','state','zip','country','notes','timeZone'],
			'fieldsViewOnly' => ['name','UNIX_TIMESTAMP(created) as created','UNIX_TIMESTAMP(lastLogin) as lastLogin','lastLoginIP',q#if (password !='','x','') as password#],
			'fieldsTimeZoneConvertDate' => {'created'=>1,'lastLogin'=>1},
			'fieldspec' => \%main::accountFields,
			'querryPassThruValues' => ['_search_on','_search_for','_search_on_t-is','_order'],
			'returnpage' => 'accountList',
			'canDelete' => 1,
			'deleteConfirm' => 'accountDel',
			'deletePriv' => 'admin', # must have admin priv to be able to delete.
			'links' => [
				{
					'table' => 'user_domains',
					'id_field_in_link_table' => 'user_id',
				},
				{
					'table' => 'user_member_currencies ',
					'id_field_in_link_table' => 'user_id',
				},
				{
					'table' => 'user_om_accounts ',
					'id_field_in_link_table' => 'user_id',
				},
			]
		},
	),
	'accountList' => PAGE::Query->new(
		'section' => 'users',
		'tmpl_params'=> {'loop_context_vars' => 1,'global_vars' => 1},
		'title' => 'Users',
		'params' => {
			'name' => 'items',
			'table' => 'account',
			'queryOnSearchOnly' => 1,
			'fields' => ['name','fname','lname','notes','email','privFlags','id',
						'email','phone','phone2','address1','address2','city','state','zip','country'],
			'fieldsProcess' => {
				'notes' => '[\n\r]+~<br>&nbsp;&nbsp;&nbsp;&nbsp;'
				},
			'search_field_map' => {
				'a' => 'name','m' => q#concat(fname,' ',lname)#, 'f' => 'fname',
				'l' => 'lname', 'e' => 'email', 'n' => 'notes', 
			},
			'order' => {
				_default=> 'n',
				a=> 'name',
				n=> 'lname,fname',
				c=> 'created desc',
				l=> 'lastLogin desc',
			},
		},
	),
	'accountChange' => PAGE::AccountChange->new(
		'title' => 'Change Password',
		'section' => 'user_info',
		'params' => {
			'table' => 'account',
			'idIsUserID' => 1,
			'fields' => ['password','oldPass'],
			'fieldspec' => \%main::namepassFields,
			'selfreturnpage' => 1,
			'querryPassThruValues' => ['oldName'],
			'reloadAccountInfoOnReturn' => 1
		},	
	),
	'accountPrefs' => PAGE::Edit->new(
		'section' => 'user_info',
		'title' => 'Preferences',
		'params' => {
			'table' => 'account',
			'idIsUserID' => 1,
			'fields' => ['prefFlags','prefStartPage','prefLanguage','timeZone'],
			'fieldspec' => \%main::accountFields,
			'reloadAccountInfoOnReturn' => 1
		},
	),
	'contactInfo' => PAGE::Edit->new(
		'section' => 'user_info',
		'title' => 'Contact Info',
		'params' => {
			'table' => 'account',
			'idIsUserID' => 1,
			'fields' => ['fname','lname','email','phone','phone2','address1','address2','city','state','zip','country'],
			'fieldspec' => \%main::accountFields,
			'reloadAccountInfoOnReturn' => 1
		},
	),
	'exportAccounts' => PAGE::Query->new(
		'title' => 'Users Export',
		'params' => {
			'name' => 'items',
			'table' => 'account',
			'fields' => ['id','name','password','privFlags','created','lastLogin','lastLoginIP','lname','fname','email','address1','address2','city','state','zip','phone','phone2','fax','country','replace(Notes,"\n","\\n")','prefFlags'],
		},
	),
	'eventLog' => PAGE::Query->new(
		'tmpl_params'=> {'loop_context_vars' => 1,'global_vars' => 1},
		'title' => 'Event Log',
		'params' => {
			'queryOnSearchOnly' => 1,
			'name' => 'items',
			'table' => 'eventLog,account',
			'where' => q#account_id = account.id and (date > SUBDATE(NOW(),INTERVAL _days_ DAY)) and concat(fname,' ',lname) like "%_name_%"#,
			'fields' => ['subType','eventLog.type','concat(fname," ",lname) as user','UNIX_TIMESTAMP(date) as date','UNIX_TIMESTAMP(date) as date_sort','replace(content,"&"," & ") as content'],
			'fieldsTimeZoneConvertDate' => ['date'],
			'querryPassThruValues' => ['_search_on','_order','days'],
			'fieldquerysub' => {'days' => 'i','name'=>'nq'},
			'fieldDefaults' => {'days' => '1'},
			'order' => {
				'_default' => 'd',
				's' => 'subType,date_sort DESC',
				'd' => 'date_sort DESC',
				't' => 'type,date_sort DESC',
				'c' => 'content,date_sort DESC',
				'u' => 'lname,fname,date_sort DESC'
			},
		},
	),
);


1;