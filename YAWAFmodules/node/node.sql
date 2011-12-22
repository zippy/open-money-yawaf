--
-- Table structure for table `node`
--

CREATE TABLE node (
  id int unsigned NOT NULL auto_increment,
  modified datetime default NULL,
  modified_by_id int unsigned NOT NULL,
  parent_id int unsigned NOT NULL,
  name varchar(255) NOT NULL default '',
  contents text,
  type varchar(255) NOT NULL default '',
  PRIMARY KEY  (id)
) TYPE=MyISAM;


CREATE TABLE history (
  id int unsigned NOT NULL auto_increment,
  node_id int unsigned NOT NULL,
  modified datetime default NULL,
  modified_by_id int unsigned NOT NULL,
  contents text,
  PRIMARY KEY  (id)
) TYPE=MyISAM;

CREATE TABLE subscription (
  id int unsigned NOT NULL auto_increment,
  node_id int unsigned NOT NULL,
  account_id int unsigned NOT NULL,
  type varchar(255) NOT NULL default '',
  PRIMARY KEY  (id)
) TYPE=MyISAM;
