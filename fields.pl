#-------------------------------------------------------------------------------
# fields.pl
# ©2006 Harris-Braun Enterprises, LLC, All Rights Reserved
# This software is released under the LGPL license.
# Author: Eric Harris-Braun <eric -at- harris-braun.com>
#-------------------------------------------------------------------------------
use HTMLSQLSelect;

use Field::Password;
use Field::Radio;
use Field::CheckBox;
use Field::CheckBoxFlags;
use Field::SelectOther;
use Field::CheckBoxGroup;
use Field::CheckBoxGroupSQL;
use Field::QueryField;
use Field::Select;
use Field::SelectSQL;
use Field::Text;
use Field::Date;
use Field::TextArea;
use Field::Time;
use Field::Hidden;

use DateTime::TimeZone;

%main::wikiFields = (
	'code' => Field::Text->new(
		'name' => 'code',
		'size' => 50,
		'maxlength' => 50,
		),
	'itemname' => Field::Text->new(
		'name' => 'itemname',
		'validation' => ['required','unique'],
		'size' => 55,
		'maxlength' => 100,
		),
#	'project_id' => Field::SelectSQL->new(
#		'name' => 'project_id',
#		'validation' => ['required'],
#		'sqltype' => 'int',
#		'sqlselect' => $main::project_select_spec,
#		),

	'type_id' => Field::SelectSQL->new(
		'name' => 'type_id',
		'sqltype' => 'int',
		'sqlselect' => $main::type_select_spec,
		),
	'status_id' => Field::SelectSQL->new(
		'name' => 'status_id',
		'sqltype' => 'int',
		'sqlselect' => $main::status_select_spec,
		),
	'who' => Field::SelectSQL->new(
		'name' => 'who',
		'sqltype' => 'int',
		'sqlselect' => $main::who_select_spec,
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
	'notify' => Field::CheckBoxGroupSQL->new(
		'name' => 'notify',
		'sqltype' => 'text',
		'valueFieldName' => 'id',
		'labelFieldName' => 'fname',
		'nullok' => 'All',
		'sqlParams' => {
			'table' => 'account,account_projects',
			'where' => 'project_id = _project_id_ and account_id=account.id',
			'fieldquerysub' => {'project_id'=>'i'},
			'fieldcookiesub' => {'project_id'=>100000},
			'fields' => ['account.id','fname'],
			'order' => 'fname',
			},
		),
);

%main::loginFields = (
	'name' => Field::Text->new(
		'name' => 'name',
		'validation' => ['required'],
		'size' => 15,
		'maxlength' => 30,
		),
	'password' => Field::Password->new(
		'name' => 'password',
		'validation' => ['required'],
		'size' => 15,
		'maxlength' => 25,
		),
);
%main::namepassFields = (
	'name' => Field::Text->new(
		'name' => 'name',
		'noload' => 1,
		'validation' => ['unique'],
		'errorhtml' => {'unique_err' => '<FONT class="errortext">There is already an account by that name.  Try again.</FONT>'},
		'size' => 25,
		'maxlength' => 30,
		),
	'password' => Field::Password->new(
		'name' => 'password',
		'noload' => 1,
		'validation' => ['password'],
		'size' => 25,
		'maxlength' => 25,
		),
	'oldPass' => Field::Password->new(
		'name' => 'oldPass',
		'noload' => 1,
		'size' => 25,
		'maxlength' => 25,
		),
);
%main::accountFields = (
	'name' => Field::Text->new(
		'name' => 'name',
		'validation' => ['required','unique'],
		'errorhtml' => {'unique_err' => '<FONT class="errortext">There is already an account by that name. Try again.</FONT>'},
		'size' => 30,
		'maxlength' => 30,
		),
	'privFlags' => Field::CheckBoxFlags->new(
		'name' => 'privFlags',
		'values' => ['dev','admin','privs','createAct','act'],
		'labels' => {'dev'=>'Developer','admin'=>'Administrator','createAct'=>'Create accounts','privs'=>'Set privileges','act'=>'View/update accounts'},
		'linebreak' => 'true',
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
		'validation' => ['email'],
		'size' => 30,
		'maxlength' => 50,
		),
	'phone' => Field::Text->new(
		'name' => 'phone',
#		'validation' => ['required'],
		'size' => 19,
		'maxlength' => 50,
		),
	'phone2' => Field::Text->new(
		'name' => 'phone2',
		'size' => 19,
		'maxlength' => 50,
		),
	'address1' => Field::Text->new(
		'name' => 'address1',
#		'validation' => ['required'],
		'size' => 60,
		'maxlength' => 100,
		),
	'address2' => Field::Text->new(
		'name' => 'address2',
		'size' => 60,
		'maxlength' => 100,
		),
	'city' => Field::Text->new(
		'name' => 'city',
#		'validation' => ['required'],
		'size' => 20,
		'maxlength' => 20,
		),
	'state' => Field::Text->new(
		'name' => 'state',
#		'validation' => ['required'],
		'size' => 3,
		'maxlength' => 3,
		),
	'zip' => Field::Text->new(
		'name' => 'zip',
#		'validation' => ['required'],
		'size' => 12,
		'maxlength' => 12,
		),
	'country' => Field::Select->new(
		'name' => 'country',
#		'validation' => ['required'],
		'values' => ['US','UM','AF','AL','DZ','AS','AD','AO','AI','AQ','AG','AR','AM','AW','AU','AT','AZ','BS','BH','BD','BB','BY','BE','BZ','BJ','BM','BT','BO','BA','BW','BV','BR','IO','BN','BG','BF','BI','KH','CM','CA','CV','KY','CF','TD','CL','CN','CX','CC','CO','KM','CG','CK','CR','CI','HR','CU','CY','CZ','DK','DJ','DM','DO','TP','EC','EG','SV','GQ','ER','EE','ET','FK','FO','FJ','FI','FR','FX','GF','PF','TF','GA','GM','GE','DE','GH','GI','GR','GL','GD','GP','GU','GT','GN','GW','GY','HT','HM','HN','HK','HU','IS','IN','ID','IR','IQ','IE','IL','IT','JM','JP','JO','KZ','KE','KI','KP','KR','KW','KG','LA','LV','LB','LS','LR','LY','LI','LT','LU','MO','MK','MG','MW','MY','MV','ML','MT','MH','MQ','MR','MU','YT','MX','FM','MD','MC','MN','MS','MA','MZ','MM','NA','NR','NP','NL','AN','NC','NZ','NI','NE','NG','NU','NF','MP','NO','OM','PK','PW','PA','PG','PY','PE','PH','PN','PL','PT','PR','QA','RE','RO','RU','RW','KN','LC','VC','WS','SM','ST','SA','SN','SC','SL','SG','SK','SI','SB','SO','ZA','GS','ES','LK','SH','PM','SD','SR','SJ','SZ','SE','CH','SY','TW','TJ','TZ','TH','TG','TK','TO','TT','TN','TR','TM','TC','TV','UG','UA','AE','GB','UY','UZ','VU','VA','VE','VN','VG','VI','WF','EH','YE','ZR','ZM','ZW','ZZ'],
		'labels' => {'US'=>'United States','UM'=>'United States Minor Outlying Ils.','AF'=>'Afghanistan','AL'=>'Albania','DZ'=>'Algeria','AS'=>'American Samoa','AD'=>'Andorra','AO'=>'Angola','AI'=>'Anguilla','AQ'=>'Antarctica','AG'=>'Antigua & Barbuda','AR'=>'Argentina','AM'=>'Armenia','AW'=>'Aruba','AU'=>'Australia','AT'=>'Austria','AZ'=>'Azerbaijan','BS'=>'Bahamas','BH'=>'Bahrain','BD'=>'Bangladesh','BB'=>'Barbados','BY'=>'Belarus','BE'=>'Belgium','BZ'=>'Belize','BJ'=>'Benin','BM'=>'Bermuda','BT'=>'Bhutan','BO'=>'Bolivia','BA'=>'Bosnia & Herzegowina','BW'=>'Botswana','BV'=>'Bouvet Island','BR'=>'Brazil','IO'=>'British Indian Ocean Terr.','BN'=>'Brunei Darussalam','BG'=>'Bulgaria','BF'=>'Burkina Faso','BI'=>'Burundi','KH'=>'Cambodia','CM'=>'Cameroon','CA'=>'Canada','CV'=>'Cape Verde','KY'=>'Cayman Islands','CF'=>'Central African Republic','TD'=>'Chad','CL'=>'Chile','CN'=>'China','CX'=>'Christmas Island','CC'=>'Cocos (Keeling) Islands','CO'=>'Colombia','KM'=>'Comoros','CG'=>'Congo','CK'=>'Cook Islands','CR'=>'Costa Rica','CI'=>"Cote D'Ivoire",'HR'=>'Croatia','CU'=>'Cuba','CY'=>'Cyprus','CZ'=>'Czech Republic','DK'=>'Denmark','DJ'=>'Djibouti','DM'=>'Dominica','DO'=>'Dominican Republic','TP'=>'East Timor','EC'=>'Ecuador','EG'=>'Egypt','SV'=>'El Salvador','GQ'=>'Equatorial Guinea','ER'=>'Eritrea','EE'=>'Estonia','ET'=>'Ethiopia','FK'=>'Falkland Islands','FO'=>'Faroe Islands','FJ'=>'Fiji','FI'=>'Finland','FR'=>'France','FX'=>'France, Metropolitan','GF'=>'French Guiana','PF'=>'French Polynesia','TF'=>'French Southern Terr.','GA'=>'Gabon','GM'=>'Gambia','GE'=>'Georgia','DE'=>'Germany','GH'=>'Ghana','GI'=>'Gibraltar','GR'=>'Greece','GL'=>'Greenland','GD'=>'Grenada','GP'=>'Guadeloupe','GU'=>'Guam','GT'=>'Guatemala','GN'=>'Guinea','GW'=>'Guinea-Bissau','GY'=>'Guyana','HT'=>'Haiti','HM'=>'Heard & McDonald Ils.','HN'=>'Honduras','HK'=>'Hong Kong','HU'=>'Hungary','IS'=>'Iceland','IN'=>'India','ID'=>'Indonesia','IR'=>'Iran','IQ'=>'Iraq','IE'=>'Ireland','IL'=>'Israel','IT'=>'Italy','JM'=>'Jamaica','JP'=>'Japan','JO'=>'Jordan','KZ'=>'Kazakhstan','KE'=>'Kenya','KI'=>'Kiribati','KP'=>'North Korea','KR'=>'South Korea','KW'=>'Kuwait','KG'=>'Kyrgyzstan','LA'=>"Lao People's Republic",'LV'=>'Latvia','LB'=>'Lebanon','LS'=>'Lesotho','LR'=>'Liberia','LY'=>'Libyan Arab Jamahiriya','LI'=>'Liechtenstein','LT'=>'Lithuania','LU'=>'Luxembourg','MO'=>'Macau','MK'=>'Macedonia','MG'=>'Madagascar','MW'=>'Malawi','MY'=>'Malaysia','MV'=>'Maldives','ML'=>'Mali','MT'=>'Malta','MH'=>'Marshall Islands','MQ'=>'Martinique','MR'=>'Mauritania','MU'=>'Mauritius','YT'=>'Mayotte','MX'=>'Mexico','FM'=>'Micronesia','MD'=>'Moldova','MC'=>'Monaco','MN'=>'Mongolia','MS'=>'Montserrat','MA'=>'Morocco','MZ'=>'Mozambique','MM'=>'Myanmar','NA'=>'Namibia','NR'=>'Nauru','NP'=>'Nepal','NL'=>'Netherlands','AN'=>'Netherlands Antilles','NC'=>'New Caledonia','NZ'=>'New Zealand','NI'=>'Nicaragua','NE'=>'Niger','NG'=>'Nigeria','NU'=>'Niue','NF'=>'Norfolk Island','MP'=>'Northern Mariana Ils.','NO'=>'Norway','OM'=>'Oman','PK'=>'Pakistan','PW'=>'Palau','PA'=>'Panama','PG'=>'Papua New Guinea','PY'=>'Paraguay','PE'=>'Peru','PH'=>'Philippines','PN'=>'Pitcairn','PL'=>'Poland','PT'=>'Portugal','PR'=>'Puerto Rico','QA'=>'Qatar','RE'=>'Reunion','RO'=>'Romania','RU'=>'Russian Federation','RW'=>'Rwanda','KN'=>'Saint Kitts & Nevis','LC'=>'Saint Lucia','VC'=>'Saint Vincent  The Grenadines','WS'=>'Samoa','SM'=>'San Marino','ST'=>'Sao Tome And Principe','SA'=>'Saudi Arabia','SN'=>'Senegal','SC'=>'Seychelles','SL'=>'Sierra Leone','SG'=>'Singapore','SK'=>'Slovakia','SI'=>'Slovenia','SB'=>'Solomon Islands','SO'=>'Somalia','ZA'=>'South Africa','GS'=>'South Georgia & South Sandwich Ils.','ES'=>'Spain','LK'=>'Sri Lanka','SH'=>'St Helena','PM'=>'St Pierre & Miquelon','SD'=>'Sudan','SR'=>'Suriname','SJ'=>'Svalbard & Jan Mayen Ils.','SZ'=>'Swaziland','SE'=>'Sweden','CH'=>'Switzerland','SY'=>'Syrian Arab Republic','TW'=>'Taiwan','TJ'=>'Tajikistan','TZ'=>'Tanzania','TH'=>'Thailand','TG'=>'Togo','TK'=>'Tokelau','TO'=>'Tonga','TT'=>'Trinidad & Tobago','TN'=>'Tunisia','TR'=>'Turkey','TM'=>'Turkmenistan','TC'=>'Turks & Caicos Islands','TV'=>'Tuvalu','UG'=>'Uganda','UA'=>'Ukraine','AE'=>'United Arab Emirates','GB'=>'United Kingdom','UY'=>'Uruguay','UZ'=>'Uzbekistan','VU'=>'Vanuatu','VA'=>'Vatican City State','VE'=>'Venezuela','VN'=>'Viet Nam','VG'=>'Virgin Islands (British)','VI'=>'Virgin Islands (U.S.)','WF'=>'Wallis & Futuna Ils.','EH'=>'Western Sahara','YE'=>'Yemen','ZR'=>'Zaire','ZM'=>'Zambia','ZW'=>'Zimbabwe','ZZ'=>'Other-Not Shown'},
		),
	'notes' => Field::TextArea->new(
		'name' => 'notes',
		'sqltype' => 'text',
		'rows' => 4,
		'columns' => 80,
		),
	'prefFlags' => Field::CheckBoxFlags->new(
		'name' => 'prefFlags',
		'values' => ['terse'],  #,'validateForm'
		'labels' => {
			'terse'=>'I know how the site works now.  Hide the instructions.',
#			'validateForm'=>'Check my data form for errors/omissions as I fill it out (instead of only at the end).',
			},
		'linebreak' => 1,
		),
	'prefStartPage' => Field::Select->new(
		'name' => 'prefStartPage',
#		'validation' => ['required'],
		'values' => ['','om/account_history','om/account_trading'],
		'labels' => {''=>'Default','om/account_history'=>'Account History','om/account_trading'=>'Account Trading'},
		),
	'prefLanguage' => Field::Select->new(
		'name' => 'prefLanguage',
		'escapeHTML' => 0,
#		'validation' => ['required'],
		'values' => ['pt-br','hr','da','nl','en','en-uk','fr','de','hu','it','no','pl','pt','es','sv'],
		'labels' => {
			'pt-br'=>'Brazilian Portuguese (Portugu&ecirc;s Brasileiro, pt-br)',
			'hr'=>'Croatian (Hrvatski, hr)',
			'da'=>'Danish (Dansk, da)',
			'nl'=>'Dutch (Nederlands, nl)',
			'en'=>'English (en)',
			'en-uk'=>'English British (en-uk)',
			'fr'=>'French (Fran&ccedil;ais, fr)',
			'de'=>'German (Deutsch, de)',
			'hu'=>'Hungarian (Magyar, hu)',
			'it'=>'Italian (Italiano, it)',
			'no'=>'Norwegian (no)',
			'pl'=>'Polish (pl)',
			'pt'=>'Portuguese (Portugu&ecirc;s, pt)',
			'es'=>'Spanish (Espa&ntilde;ol, es)',
			'sv'=>'Swedish (Svenska, sv)',
		},
		),
	'timeZone' => Field::Select->new(
		'name' => 'timeZone',
##		'values' => ['','America/Boise','America/Chicago','America/Dawson','America/Dawson_Creek','America/Denver','America/Detroit','America/Glace_Bay','America/Halifax','America/Los_Angeles','America/Montreal','America/New_York','America/Phoenix','America/Toronto','America/Vancouver','America/Whitehorse','America/Winnipeg','America/Indiana/Indianapolis','America/Indiana/Knox','America/Indiana/Marengo','America/Indiana/Petersburg','America/Indiana/Vevay','America/Indiana/Vincennes','America/Kentucky/Louisville','America/Kentucky/Monticello','North_Dakota/Center','North_Dakota/New_Salem'],
		'values' => ['',@DateTime::TimeZone::ALL],
		),
);
$main::emailFieldSubject = 
	Field::Text->new(
		'name' => 'subject',
		'validation' => ['required'],
		'errorhtml' => {'required_err' => '<FONT class="errortext">Message must have a subject.</FONT><br>'},
		'size' => 65,
		'maxlength' => 70,
		);
$main::emailFieldBody = 
	Field::TextArea->new(
		'name' => 'body',
		'validation' => ['required'],
		'errorhtml' => {'required_err' => '<FONT class="errortext">Message must have a body.</FONT><br>'},
		'rows' => 17,
		'columns' => 63,
		'wrap' => 'virtual'
		);
$main::emailFieldFrom = 
	Field::Text->new(
		'name' => 'from_email',
		'validation' => ['required','email'],
		'errorhtml' => {'required_err' => '<FONT class="errortext">Message must have a "from" email address.</FONT><br>'},
		'size' => 65,
		'maxlength' => 70,
		);
$main::emailFieldTo = 
	Field::Text->new(
		'name' => 'to_email',
		'validation' => ['required','email'],
		'errorhtml' => {'required_err' => '<FONT class="errortext">Message must have a "to" email address.</FONT><br>'},
		'size' => 65,
		'maxlength' => 70,
		);
$main::emailFieldCC = 
	Field::Text->new(
		'name' => 'cc_email',
		'validation' => ['email'],
		'size' => 65,
		'maxlength' => 70,
		);


1;