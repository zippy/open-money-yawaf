-- MySQL dump 9.11
--
-- Host: localhost    Database: toc_om
-- ------------------------------------------------------
-- Server version	4.0.21-standard


--
-- Table structure for table `account`
--

DROP TABLE IF EXISTS  account;
CREATE TABLE account (
  id int(10) unsigned NOT NULL auto_increment,
  name varchar(30) NOT NULL default '',
  password varchar(25) NOT NULL default '',
  privFlags set('dev','admin','privs','createAct','act') default NULL,
  created datetime NOT NULL default '0000-00-00 00:00:00',
  lastLogin datetime NOT NULL default '0000-00-00 00:00:00',
  lastLoginIP varchar(16) NOT NULL default '',
  lname varchar(30) NOT NULL default '',
  fname varchar(30) NOT NULL default '',
  email varchar(50) NOT NULL default '',
  address1 varchar(100) default NULL,
  address2 varchar(100) default NULL,
  city varchar(20) default NULL,
  state char(3) default NULL,
  zip varchar(12) default NULL,
  phone varchar(50) default NULL,
  phone2 varchar(50) default NULL,
  fax varchar(50) default NULL,
  country char(2) default NULL,
  Notes text,
  prefFlags set('terse') default NULL,
  prefStartPage varchar(50) NOT NULL default '',
  prefLanguage varchar(10) NOT NULL default 'en',
  timeZone varchar(40) NOT NULL default '',
  PRIMARY KEY  (id)
) TYPE=MyISAM;

--
-- Table structure for table `accountPriv`
--

DROP TABLE IF EXISTS  accountPriv;
CREATE TABLE accountPriv (
  id int(10) unsigned NOT NULL auto_increment,
  account_id int(10) unsigned NOT NULL default '0',
  name varchar(30) NOT NULL default '',
  PRIMARY KEY  (id)
) TYPE=MyISAM;

--
-- Table structure for table `eventLog`
--

DROP TABLE IF EXISTS  eventLog;
CREATE TABLE eventLog (
  id int(10) unsigned NOT NULL auto_increment,
  type enum('access','login','email') NOT NULL default 'access',
  subType varchar(30) NOT NULL default '',
  account_id int(10) unsigned NOT NULL default '0',
  related_id int(10) unsigned NOT NULL default '0',
  content text NOT NULL,
  date datetime NOT NULL default '0000-00-00 00:00:00',
  PRIMARY KEY  (id)
) TYPE=MyISAM;

--
-- Table structure for table `sessions`
--

DROP TABLE IF EXISTS  sessions;
CREATE TABLE sessions (
  id char(32) NOT NULL default '',
  user_id int(10) unsigned NOT NULL default '0',
  time int(10) unsigned NOT NULL default '0',
  PRIMARY KEY  (id)
) TYPE=MyISAM;

