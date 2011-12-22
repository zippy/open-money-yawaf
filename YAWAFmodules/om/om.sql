-- -----------------------------------------------------------------------------------------------------------------------
-- open money SQL layer
-- -----------------------------------------------------------------------------------------------------------------------

--
-- Table structure for table `om_ledger`
--

DROP TABLE IF EXISTS om_ledger;
CREATE TABLE om_ledger (
  id int(10) unsigned NOT NULL auto_increment,
  transaction_id varchar(255) NOT NULL,
  account_id int unsigned NOT NULL,
  with_account varchar(255) NOT NULL,
  currency varchar(255) NOT NULL,
  transaction text NOT NULL default '',
  created datetime NOT NULL default '0000-00-00 00:00:00',
  PRIMARY KEY  (id)
) TYPE=MyISAM;

--
-- Table structure for table `om_summary`
--

DROP TABLE IF EXISTS  om_summary;
CREATE TABLE om_summary (
  id int(10) unsigned NOT NULL auto_increment,
  account_id int unsigned NOT NULL,
  currency varchar(255) NOT NULL,
  summary text NOT NULL default '',
  PRIMARY KEY  (id)
) TYPE=MyISAM;

--
-- Table structure for table `om_account`
--

DROP TABLE IF EXISTS  om_account;
CREATE TABLE om_account (
  id int(10) unsigned NOT NULL auto_increment,
  domain_id int unsigned NOT NULL,
  access_control text NOT NULL default '',
  created datetime NOT NULL default '0000-00-00 00:00:00',
  PRIMARY KEY  (id)
) TYPE=MyISAM;


--
-- Table structure for table `om_currency`
--

DROP TABLE IF EXISTS  om_currency;
CREATE TABLE om_currency (
  id int(10) unsigned NOT NULL auto_increment,
  domain_id int unsigned NOT NULL,
  access_control text NOT NULL default '',
  specification text NOT NULL default '',
  created datetime NOT NULL default '0000-00-00 00:00:00',
  PRIMARY KEY  (id)
) TYPE=MyISAM;

--
-- Table structure for table `om_currency_accounts`
--

DROP TABLE IF EXISTS  om_currency_accounts;
CREATE TABLE om_currency_accounts (
  id int(10) unsigned NOT NULL auto_increment,
  account varchar(255) NOT NULL,
  currency_id int unsigned NOT NULL,
  status enum('inactive','active') NOT NULL default 'inactive',
  auth_code varchar(255) NOT NULL,
  created datetime NOT NULL default '0000-00-00 00:00:00',
  PRIMARY KEY  (id)
) TYPE=MyISAM;

--
-- Table structure for table `om_domain`
--

DROP TABLE IF EXISTS  om_domain;
CREATE TABLE om_domain (
  id int(10) unsigned NOT NULL auto_increment,
  parent varchar(255) NOT NULL,
  parent_id int unsigned NOT NULL,
  name varchar(25) NOT NULL,
  specification text NOT NULL default '',
  access_control text NOT NULL default '',
  created datetime NOT NULL default '0000-00-00 00:00:00',
  PRIMARY KEY  (id)
) TYPE=MyISAM;


-- -----------------------------------------------------------------------------------------------------------------------
-- YAWAF LAYER, except that some parts of name handling is at this layer, because this YAWAF layer has to actually resolve
-- names.  This is like any particular implementation of SMTP will be resolving part of an e-mail name.
-- -----------------------------------------------------------------------------------------------------------------------

--
-- Table structure for table `user_domains`
--

DROP TABLE IF EXISTS  user_domains;
CREATE TABLE user_domains (
  id int(10) unsigned NOT NULL auto_increment,
  user_id int unsigned NOT NULL,
--  domain varchar(255) NOT NULL,
  om_domain_id int unsigned NOT NULL,
  class varchar(30) NOT NULL,
  PRIMARY KEY  (id)
) TYPE=MyISAM;


--
-- Table structure for table `user_owned_currencies`
--

DROP TABLE IF EXISTS  user_owned_currencies;
CREATE TABLE user_owned_currencies (
  id int(10) unsigned NOT NULL auto_increment,
  currency_name varchar(255) NOT NULL,
  user_id int unsigned NOT NULL,
  om_currency_id int unsigned NOT NULL,
  PRIMARY KEY  (id)
) TYPE=MyISAM;

--
-- Table structure for table `user_member_currencies`
--

DROP TABLE IF EXISTS  user_member_currencies;
CREATE TABLE user_member_currencies (
  id int(10) unsigned NOT NULL auto_increment,
  user_id int unsigned NOT NULL,
  currency varchar(255) NOT NULL,
  account varchar(255) NOT NULL,
  PRIMARY KEY  (id)
) TYPE=MyISAM;


--
-- Table structure for table `user_om_accounts`
--

DROP TABLE IF EXISTS  user_om_accounts;
CREATE TABLE user_om_accounts (
  id int(10) unsigned NOT NULL auto_increment,
  account_name varchar(255) NOT NULL,
  om_account_id int unsigned NOT NULL,
  user_id int unsigned NOT NULL,
  PRIMARY KEY  (id)
) TYPE=MyISAM;

insert into user_domains set user_id=1, om_domain_id=1, class="steward";
insert into om_domain set parent_id=0,created=now();
insert into account set name="admin",password="admin",privFlags="dev,admin,privs,createAct,act";
