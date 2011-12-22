--
-- Table structure for table `sfa`
--

CREATE TABLE sfa (
  id int(10) unsigned NOT NULL auto_increment,
  created datetime default NULL,
  modified datetime default NULL,
  start_date datetime default NULL,
  end_date datetime default NULL,
  description text,
  currency varchar(255) default NULL,
  status enum('pending','approved','retired') default NULL,
  notes text,
  account_id int unsigned not null,
  created_by_id int unsigned not null,
  amount varchar(10) NOT NULL default '',
  project varchar(50) NOT NULL default '',
  PRIMARY KEY  (id)
) TYPE=MyISAM;

