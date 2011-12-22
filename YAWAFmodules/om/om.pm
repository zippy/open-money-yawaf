#-------------------------------------------------------------------------------
# om.pm
# ©2006 Harris-Braun Enterprises, LLC, All Rights Reserved
# This software is released under the LGPL license.
# Author: Eric Harris-Braun <eric -at- harris-braun.com>
#-------------------------------------------------------------------------------

package YAWAFmodules::om;
use strict;
use Carp;
use OMTrading;
use OMHistory;
use OMActNew;
use OMCurrency;
use OMCurrencyJoin;
use OMCurrencyAdmin;
use OMDomains;
use OMDomainNew;
use OMDomainAdmin;
use OMDomainUserPerms;
use NewUser;
use OMImportAccounts;
use OMImportTransactions;

%YAWAFmodules::om::noLoginPages = (
	'new_user' => 1
);

%YAWAFmodules::om::pages = (
	'new_user' => NewUser->new(
		'params' => {
			'table' => 'account',
			'om_act_table' => 'user_om_accounts',
			'canCreate' => 1,
			'createOnly' => 1,
			'fields' => ['name','fname','lname','email'],
			'fieldPresets' => {'created' => 'NOW()'},
			'fieldspec' => {
				'name' => Field::Text->new(
					'name' => 'name',
					'validation' => ['required','unique'],
					'errorhtml' => {'unique_err' => '<span class="errortext">There is already an user with that name. Please choose a different name.</span>'},
					'size' => 30,
					'maxlength' => 30,
					),
				'fname' => Field::Text->new(
					'name' => 'fname',
					'validation' => ['required'],
					'size' => 30,
					'maxlength' => 30,
					),
				'lname' => Field::Text->new(
					'name' => 'lname',
					'validation' => ['required'],
					'size' => 30,
					'maxlength' => 30,
					),
				'email' => Field::Text->new(
					'name' => 'email',
					'validation' => ['email','required'],
					'size' => 30,
					'maxlength' => 50,
					),
				},
#			'ticket' => {'badTicketPage' => 'accountNewBadticket'},
			'selfreturnpage' => 1,
		},
	),
	'account_trading' => OMTrading->new(
		'section' => 'accounts',
		'tmpl_params'=> {'loop_context_vars' => 1,'global_vars' => 1},
		'title' => 'Account Trading',
		'params' => {
			'fields' => ['trade_for','trade_with','trade_amount','trade_currency','trade_tax_status'],
			'fieldspec' => {
				'trade_for' => Field::Text->new(
					'name' => 'trade_for',
					'validation' => ['required'],
					'size' => 20,
					'maxlength' => 1000,
					),
				'trade_with' => Field::Text->new(
					'name' => 'trade_with',
					'validation' => ['required'],
					'size' => 10,
					'maxlength' => 255,
					),
				'trade_amount' => Field::Text->new(
					'name' => 'trade_amount',
					'validation' => ['required'],
					'size' => 6,
					'maxlength' => 20,
					),
				'trade_tax_status' => Field::Select->new(
					'name' => 'trade_tax_status',
					'validation' => ['required'],
					'values' => ['no','yes'],
#					'values' => ['non-taxable','IRS-barter','CA-VAT','EC-VAT'],
#					'labels' => {'non-taxable'=>'non-taxable','IRS-barter'=>'IRS Barter Rules','CA-VAT' =>'Canada VAT','EU-VAT'=>'European Union VAT'},
					),
			},
		}
	),
	'account_history' => OMHistory->new(
		'section' => 'accounts',
		'title' => 'Account History',
		'tmpl_params'=> {'loop_context_vars' => 1,'global_vars' => 1},
		'params' => {
		},
	),
	'import_accounts' => OMImportAccounts->new(
		'section' => 'import',
		'title' => 'Import Accounts',
		'tmpl_params'=> {'loop_context_vars' => 1,'global_vars' => 1},
		'params' => {
		},
	),
	'import_transactions' => OMImportTransactions->new(
		'section' => 'import',
		'title' => 'Import Transactions',
		'tmpl_params'=> {'loop_context_vars' => 1,'global_vars' => 1},
		'params' => {
		},
	),
	'account_prefs' => PAGE->new(
		'section' => 'accounts',
		'title' => 'Account Settings',
	),
	'account_new' => OMActNew->new(
		'section' => 'accounts',
		'title' => 'New Account',
		'params' => {
			'fields' => ['account_name'],
			'table' => 'user_om_accounts',
			'fieldspec' => {
				'account_name' => Field::Text->new(
					'name' => 'account_name',
					'validation' => ['required'],
					'size' => 20,
					'maxlength' => 255,
					),
			},
			'returnpage' => 'om/account_trading',
		}
	),
	'currency_join' => OMCurrencyJoin->new(
		'section' => 'currencies',
		'title' => 'Join Currency',
		'tmpl_params'=> {'loop_context_vars' => 1,'global_vars' => 1},
		'params' => {
			'returnpage' => 'om/currency_join',
		},
	),
	'currency_create' => OMCurrency->new(
		'section' => 'currencies',
		'title' => 'Create Currency',
		'params' => {
			'fields' => ['currency_name','currency_spec','name','description','type','unit'],
			'table' => 'user_owned_currencies',
			'querryPassThruValues' => ['currency_name'],
			'fieldspec' => {
				'currency_name' => Field::Text->new(
					'name' => 'currency_name',
					'validation' => ['required'],
#					'errorhtml' => {'unique_err' => '<span class="errortext">Sorry, there is already a currency with that name.</span>'},
					'size' => 20,
					'maxlength' => 255,
					),
				'name' => Field::Text->new(
					'name' => 'name',
					'size' => 60,
					'maxlength' => 255,
					),
				'description' => Field::TextArea->new(
					'name' => 'description',
					'sqltype' => 'text',
					'rows' => 3,
					'columns' => 60,
					),
				'type' => Field::Select->new(
					'name' => 'type',
					'validation' => ['required'],
					'values' => ['Transaction','Transaction:Mutual Credit','Transaction:Mutual Credit w/ Limits','Transaction:Issuer Credit','Reputation']
					),
				'unit' => Field::Select->new(
					'name' => 'unit',
					'escapeHTML' => 0,
					'validation' => ['required'],
					'values' => ['USD','EUR','CAD','AUD','NZD','S','MXP','YEN','CHY','T-h','T-m','kwh','other'],
					'labels' => {
						'USD'=>'US Dollar ($)','EUR'=>'Euro (&euro;)','CAD'=>'Canadian Dollar ($)','AUD'=>'Australian Dollar ($)','NZD'=>'New Zeland Dollar ($)',
						'S'=>'Sterling Pound (&pound;)','MXP'=>'Mexican Peso (p)','YEN'=>'Yen (&yen;)','CHY'=>'Yuan',
						'T-h'=>'Time:hours (h)','T-m'=>'Time:minutes (h)','kwh'=>'Kilowatt Hours (kwh)',
						'other'=>'other--see description (&curren;)'
						},
					),
				'currency_spec' => Field::TextArea->new(
					'name' => 'currency_spec',
					'validation' => ['required'],
					'sqltype' => 'text',
					'rows' => 5,
					'columns' => 60,
					'default' => <<END
name:
description:
type:
unit:
END
					),
			},
			'returnpage' => 'om/currency_join',
		}
	),
	'currency_admin' => OMCurrencyAdmin->new(
		'section' => 'currencies',
		'title' => 'Manage Currencies',
		'tmpl_params'=> {'loop_context_vars' => 1,'global_vars' => 1},
		'params' => {
			'fields' => ['reverse_tx_id','reverse_tx_comment','trade_for','trade_from','trade_to','trade_amount','trade_tax_status'],
			'fieldspec' => {
				'reverse_tx_id' => Field::Text->new(
					'name' => 'reverse_tx_id',
					'size' => 20,
					'maxlength' => 255,
					),
				'reverse_tx_comment' => Field::Text->new(
					'name' => 'reverse_tx_comment',
					'size' => 60,
					'maxlength' => 255,
					),
				'trade_from' => Field::Text->new(
					'name' => 'trade_from',
					'size' => 10,
					'maxlength' => 255,
					),
				'trade_to' => Field::Text->new(
					'name' => 'trade_to',
					'size' => 10,
					'maxlength' => 255,
					),
				'trade_for' => Field::Text->new(
					'name' => 'trade_for',
					'size' => 20,
					'maxlength' => 1000,
					),
				'trade_amount' => Field::Text->new(
					'name' => 'trade_amount',
					'size' => 6,
					'maxlength' => 20,
					),
				'trade_tax_status' => Field::Select->new(
					'name' => 'trade_tax_status',
					'values' => ['yes','no'],
#					'values' => ['non-taxable','IRS-barter','CA-VAT','EC-VAT'],
#					'labels' => {'non-taxable'=>'non-taxable','IRS-barter'=>'IRS Barter Rules','CA-VAT' =>'Canada VAT','EU-VAT'=>'European Union VAT'},
					),
				},
			'selfreturnpage' => 1,
		}
	),
	'domains' => OMDomains->new(
		'title' => 'Namespace Administration',
		'params' => {
		}
	),
	'domain_admin' => OMDomainAdmin->new(
		'section' => 'domains',
		'title' => 'My Domains',
		'params' => {
		}
	),
	'domain_new' => OMDomainNew->new(
		'section' => 'domains',
		'title' => 'New Domain',
		'params' => {
			'fields' => ['domain_name','description'],
			'table' => 'user_domains',
			'fieldspec' => {
				'domain_name' => Field::Text->new(
					'name' => 'domain_name',
					'validation' => ['required'],
					'size' => 20,
					'maxlength' => 255,
					),
				'description' => Field::TextArea->new(
					'name' => 'description',
					'sqltype' => 'text',
					'rows' => 3,
					'columns' => 60,
					),
			},
			'returnpage' => 'om/domain_admin',
		}
	),
	'domain_user_perms' => OMDomainUserPerms->new(
		'section' => 'domains',
		'title' => 'User Domain Permissions',
		'tmpl_params'=> {'loop_context_vars' => 1,'global_vars' => 1},
		'params' => {
			'table' => 'account',
			'left_join' => q*user_domains on user_domains.user_id = account.id and om_domain_id = _domain_id_*,
			'fieldquerysub' => {'domain_id' => 'i'},
			'fields' => ['name','fname','lname','email','class','account.id as user_id'],
			'queryOnSearchOnly' => 1,
			'name' => 'users',
			'search_field_map' => {
				'a' => 'name','m' => q#concat(fname,' ',lname)#, 'f' => 'fname',
				'l' => 'lname', 'e' => 'email' 
			},
			'order' => {
				_default=> 'n',
				a=> 'name',
				n=> 'lname,fname',
				c=> 'created desc',
			},
		}
	),
);

sub get_page {
	my $module_name = shift;
	my $page_name = shift;
	my $page = $YAWAFmodules::om::pages{$page_name};
	return $page;
}
sub is_no_login_page {
	my $module_name = shift;
	my $page_name = shift;
	my $page = $YAWAFmodules::om::noLoginPages{$page_name};
	return $page;
}
1;
