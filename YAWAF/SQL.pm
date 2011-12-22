#-------------------------------------------------------------------------------
# SQL.pm
# ©2004 Harris-Braun Enterprises, LLC, All Rights Reserved
#-------------------------------------------------------------------------------

package SQL;

use strict;
use DBI;

sub new {
	my $class = shift;
	my $host=shift;
	my $user=shift;
	my $password=shift;
	my $database=shift;
	
	my $self = {};
	bless $self, $class;

	my $datasource = "DBI:mysql:$database";
	$datasource .= ":$host" if $host ne '';
	$self->{'dbh'} = DBI->connect($datasource,$user,$password) or
		 die qq/can't connect to database! (error: $DBI::errstr)/;

	return $self;
}

sub DESTROY {
	my $self = shift;
	
	$self->Disconnect();
}


sub GetDBH {
	my $self = shift;
	return $self->{'dbh'};
}

sub Disconnect {
	my $self = shift;
	my $dbh = $self->{'dbh'};
	if ($dbh != undef) {
		$dbh->disconnect();
		delete $self->{'dbh'};
	}
}

# return an array of arrays of all the fields from all the records
sub GetFields {
	my $self = shift;
	my $tables = shift;
	my $where = shift;
	my $fieldsP = shift;
	
	my $results = $self->_SQLquery($tables,$where,$fieldsP,@_);
	my @results;
	#initialize results to empty array refs
	foreach (@$fieldsP) {
		push @results,[];
	}
	my @row;
	while (@row = $results->fetchrow_array()) {
		my $i = @row;
		while($i > 0) {
			$i--;
			push @{$results[$i]},$row[$i];
		}
	}
	
	return @results;
}

sub GetValue {
	my $self = shift;
	my $tables = shift;
	my $where = shift;
	my $field = shift;
	my $results = $self->_SQLquery($tables,$where,[$field]);
	return scalar $results->fetchrow_array();
}

sub GetValues {
	my $self = shift;
	my $tables = shift;
	my $where = shift;
	my $results = $self->_SQLquery($tables,$where,\@_);
	return $results->fetchrow_array();
}

sub GetRecord {
	my $self = shift;
	my $tables = shift;
	my $where = shift;
	
	my $results = $self->_SQLquery($tables,$where,\@_);
	return $results->fetchrow_hashref();
}

sub GetRecords {
	my $self = shift;
	my $results = $self->_SQLquery(@_);
	return $results->fetchall_arrayref({});
}

sub _SQLquery {
	my $self = shift;
	my $tables = shift;
	my $where = shift;
	my $fieldsP = shift;
	my $order = shift;
	my $left_join = shift;
	my $distinct = shift;
	my $num_items = shift;
	my $offset = shift;

	my @fields = @$fieldsP;
	my $fields = join(',',@fields);
	$distinct = " Distinct" if $distinct;
	my $q = "SELECT$distinct $fields";
	$q .= " FROM $tables" if $tables;
	$q .= " LEFT JOIN $left_join" if $left_join;
	$q .= ' WHERE '.$where if $where;
	$q .= " ORDER BY $order" if $order;
	$q .= ' LIMIT '.int($offset).','.int($num_items) if $num_items > 0;
	
	return $self->Query($q);
}

sub GetCount
{
	my $self = shift;
	my $table = shift;
	my $where = shift;
	my $left_join = shift;
	my $distinct = shift;

	$distinct = " Distinct" if $distinct;	
	my $q = "SELECT$distinct count(*) from $table";
	$q .= " LEFT JOIN $left_join" if $left_join;
	$q .= " WHERE $where" if ($where);
	my $result = $self->Query($q);
	my ($r) = $result->fetchrow_array();
	return $r;
}

sub InsertRecord {
	my $self = shift;
	my $table = shift;
	my $pairs = shift;
	my $dontquote = shift;	# hashref of fields not to quote or scalar true false value

	my ($fieldsP,$valuesP) = $self->_getVals($pairs,$dontquote);

	my $q = "insert into $table (".join(',',@$fieldsP).') values('.join(',',@$valuesP).')';
	
	my $result = $self->Query($q);
	return $result->{'mysql_insertid'};
}

# setup the values from pairs to quote or not quote according to the dontquote hashref
sub _getVals
{
	my $self = shift;
	my $pairs = shift;
	my $dontquote = shift;	# hashref of fields not to quote or scalar true false value
	
	my $dbh = $self->{'dbh'};
	my @fields = keys(%$pairs);
	my @values;
	my $field;
	
	if (ref($dontquote) eq 'HASH') {
		foreach $field (@fields) {
			push @values, $dontquote->{$field}?$pairs->{$field}:$dbh->quote($pairs->{$field});
		}
	}
	elsif ($dontquote) {
		foreach $field (@fields) {
			push @values, $pairs->{$field};
		}
	}
	else {
		foreach $field (@fields) {
			push @values,$dbh->quote($pairs->{$field});
		}
	}
	return (\@fields,\@values)
}
sub DeleteRecords {
	my $self = shift;
	my $tables = shift;
	my $where = shift;
	my $q = "DELETE FROM $tables";
	$q .= " WHERE $where" if $where;
	return $self->Query($q);
}

sub UpdateRecords {
	my $self = shift;
	my $table = shift;
	my $pairs = shift;
	my $where = shift;
	my $dontquote = shift;	# hashref of fields not to quote or scalar true false value

	my ($fieldsP,$valuesP) = $self->_getVals($pairs,$dontquote);

	my $i;
	foreach (@$fieldsP) {
		$valuesP->[$i] = "$_=$valuesP->[$i]";
		$i++;
	}
	
	my $q = "update $table set ";
	$q .= join(',',@$valuesP);
	$q .= " WHERE $where" if $where;

	my $result = $self->Query($q);
}


sub Quote {
	my $self = shift;
	my $str = shift;
	my $dbh = $self->{'dbh'};
	return $dbh->quote($str);
}

sub Query {
	my $self = shift;
	my $query = shift;
	my $dbh = $self->{'dbh'};

	my $sth = $dbh->prepare($query);
#	print $query;
	if (!$sth->execute()){
		die  "SQLQuery error " . $sth->err() . ": " . $sth->errstr(). "\nQuery was $query\n";
	}
	return $sth;
}

sub IncreaseCounter {
	my $self = shift;
	my $table = shift;
	my $field = shift;
	my $delta = shift;
	
	$delta = 1 if not defined $delta;
	
	my $q = "update $table set $field = LAST_INSERT_ID($field+$delta)";
	my $result = $self->Query($q);
	return $result->{'insertid'};
}

1;
