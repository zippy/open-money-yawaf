--
-- Table structure for table `bug`
--

CREATE TABLE bug (
  id int(10) unsigned NOT NULL auto_increment,
  itemname varchar(255) default NULL,
  created datetime default NULL,
  modified datetime default NULL,
  description text,
  type enum('structural','appearance','typo','broken','new-to-build','docs') default NULL,
  status enum('pending','low-priority','fixed','tested') default NULL,
  notes text,
  account_id int unsigned not null,
  created_by_id int unsigned not null,
  code varchar(50) NOT NULL default '',
  PRIMARY KEY  (id)
) TYPE=MyISAM;

