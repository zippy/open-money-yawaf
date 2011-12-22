#-------------------------------------------------------------------------------
# PAGE::Edit.pm
# Copyright (C) 2004 Harris-Braun Enterprises, LLC, All Rights Reserved
# Author: Eric Harris-Braun <eric@harris-braun.com>
#-------------------------------------------------------------------------------

package PAGE::Edit;

use strict;
use Field;

use base 'PAGE::Form';

sub _initialize
{
	my $self = shift;
	$self->SUPER::_initialize;
	
	$self->{'methods'}->{'del'} = 1;
}


sub getFieldsForValidation
{
	my $self = shift;
	my $fP = $self->SUPER::getFieldsForValidation();
	return $self->filterIgnoreFields($fP);
}

sub getFieldsToLoadFromQuery {
	my $self = shift;
	my $fP = $self->SUPER::getFieldsToLoadFromQuery();
	return $self->filterIgnoreFields($fP);
}

sub filterIgnoreFields
{
	my $self = shift;
	my $fP = shift;
	my $p = $self->{'params'};
	my $q = $self->param('app')->query();
	if ($q->param('id') != 0 && exists $p->{'ignore_if_undefined'}) {
		my @f;
		my $iP = $p->{'ignore_if_undefined'};
		foreach my $f (@$fP) {
			push (@f,$f) if defined($q->param($f)) || !grep($f,@$iP);
		}
		$fP = \@f;
	}
	return $fP;
}

sub setup
{
	my $self = shift;
	my $page_name = shift;
	my $app = shift;
	my $q = $app->query();
	my $p = $self->{'params'};

	if ($p->{'clearAllPassthrus'}) {
		my $method = $q->param('m');
		if ($method eq '' || $method eq 'show') {
			$q->delete_all();
			$self->deleteAllTemplatePairs();
		}
	}

	$self->SUPER::setup($page_name,$app);

	my $id = $self->_getID($q);
	$self->{'id'} = $id;
	
	$self->specErrorDie($page_name,'params undefined') if not defined($p);

	if ((not exists $p->{'createOnly'}) && ($id != 0) && ($self->param('m') eq 'show') && ($self->getTemplatePairValue('_errorCount')==0)) {
		$p->{'loadRecord'} = 1;
	}

	if ( (not exists $p->{'canCreate'}) && $id == 0) {
		$self->specErrorDie($page_name,'attempt to show page for record creation when canCreate not set');
	}
	
	$self->addTemplatePairs('_validate' => $q->param('_validate')) if exists ($p->{'queryFlagValidate'});
}

sub show
{
	my $self = shift;
	my $app = $self->param('app');
	my $p = $self->{'params'};
	my $q = $app->query();
	my $sql = $app->param('sql');

	my $fieldsP = $p->{'fields'};
	my $fspecP = $p->{'fieldspec'};
	
	my $id = $self->{'id'};
	
	my $recordP;


	my $voP = $p->{'fieldsViewOnly'};
	my $fP;
	$fP = $fieldsP if ($p->{'loadRecord'});
	if ((defined $voP || defined $fP) && $id > 0) {
		#[todo] what about attempts to load non-existant records, should switch to a real error page instead.
		$recordP = $self->loadRecordIntoQuery($id,$q,$sql,$p->{'table'},$fP,$fspecP,$voP);
		unless (defined $recordP) {
			return "Record not found!";
		}
	}

	if (exists $p->{'nonSQLfields'}) {
		$self->addHTMLformItems($p->{'nonSQLfields'},$fspecP,$q);
	}
	if (exists $p->{'value2flag'}) {
		foreach (@{$p->{'value2flag'}}) {
			$self->addFlagsToTemplatPairs($_.'_'.$q->param($_));
		}
	}

	$self->addTemplatePairs('id' => $id);
	my $ss = $p->{'subsearches'};
	foreach my $subp (@$ss) {
		my %sp = %$subp;
		$sp{'where'} =~ s/_id_/$id/;
		if (exists $sp{'source_fields'}) {
			my @source_fields = (@{$sp{'source_fields'}});
			foreach my $f (@source_fields) {
				my $sf = '_'.$f.'_';
				$sp{'where'} =~ s/$sf/$recordP->{$f}/;
			}
		}
		$self->addTemplatePairs($sp{'name'} => $sql->doSQLsearch(\%sp,$q));
	}
	return $self->SUPER::show();

}

sub doValidation
{
	my $self = shift;
	my $app = $self->param('app');
	my $q = $app->query();
	my $p = $self->{'params'};

	my $fieldsP = $self->getFieldsForValidation;
	my $fspecs = $self->getFieldSpecsForValidation;

	return '' if (exists $p->{'queryFlagValidate'}) && $q->param('_validate') == 0;

	my ($isDel,$isAdd,$ldef) = &isLinkAction($q,$p);
	return 0 if $isDel;
	$fieldsP = $ldef->{'fields'} if $isAdd;

	return $self->addErrorsToPage($self->_doValidation($q,$fspecs,$fieldsP));
}

sub loadRecordIntoQuery
{
	my $self = shift;
	my $id = shift;
	my $q = shift;
	my $sql = shift;
	my $table = shift;
	my $fieldsP = shift;
	my $fspecP = shift;
	my $fieldsViewOnlyP = shift;

	#[todo] priv system to see if user is allowed to see this record!
	if ($id > 0) {
		my @fields;
		my $field;
		foreach $field (@$fieldsP) {
			 push (@fields, $field) if not exists $fspecP->{$field}->{'noload'};
		}		
		push @fields,@$fieldsViewOnlyP if defined $fieldsViewOnlyP;

		return 1 if not @fields;
		
		my $recordP = $sql->GetRecord($table,'id='.$id,@fields);
		return 0 unless defined $recordP;

		foreach $field (@$fieldsP) {
			my $t;
			my $theField = $fspecP->{$field};
			if (defined($theField)  && ! exists $theField->{'noload'}) {
				$theField->setQueryFromFieldValue($field,$q,$recordP);
				$self->addTemplatePairs("_value_of_$field" => $recordP->{$field});
			}
		}
		if (defined $fieldsViewOnlyP) {
			@fields = @$fieldsViewOnlyP;
			grep (s/.* as (.*)/$1/,@fields);
			my $tz = (exists $self->{'params'}->{'fieldsTimeZoneConvertDate'})?$self->{'params'}->{'fieldsTimeZoneConvertDate'}:undef;
			my $app = $self->param('app');
			foreach $field (@fields) {
				my $v = $recordP->{$field};
				if (defined($tz) && $tz->{$field}) {
					$v = $app->convertUnixTimeToUserTime($v);
				}
				$q->param($field => $v);
				$self->addTemplatePairs($field => $v);
			}
		}
		return $recordP;
	}
	return undef;
}

sub isLinkAction
{
	my $q = shift;
	my $p = shift;
	
	my ($isDel,$isAdd,$ldef);
	if (exists $p->{'links'}) {
		my $l =  $p->{'links'};
		foreach my $ld (@$l) {
			my $name = $ld->{'name'};
			$isDel = int($q->param('_del_'.$name));  #the id to delete is the value of this param (set by javasscript)
			$isAdd = int($q->param('_add_'.$name));  #should be set to 1 by javascript in html
			if ($isDel || $isAdd) {
				$ldef = $ld;
				last;
			}
		}
	}
	return ($isDel,$isAdd,$ldef);
}

sub doSubmit
{
	my $self = shift;

	my $sql = $self->param('sql');
	my $app = $self->param('app');
	my $q = $app->query();
	my $p = $self->{'params'};
	my $table = $p->{'table'};

	my $id = $self->{'id'};
	
	my ($isDel,$isAdd,$ldef) = &isLinkAction($q,$p);
	if ($isDel || $isAdd) {
		if (not $self->checkSubPriv('priv',$ldef,$app)) {
			$q->delete_all();
			return $app->yawaf_get_page('noPrivs')->getBody();
		}
	}

	#[todo] make sure you are allowed to link up to the given id.
	if ($isDel) {
		return 'attempt to delete a link record when id is 0' if $id == 0;
		$sql->DeleteRecords($ldef->{'table'},"$ldef->{'id_field_in_link_table'} = $id and $ldef->{'link_value_field_in_link_table'} = ".$isDel);
		$q->param('m' => 'show');
		$self->setup($self->page_name(),$app);
#		my $t;
#		foreach ($q->param) {
#			$t .= "$_ = ".$q->param($_)."<BR>";
#			$self->addTemplatePairs($_ => $q->param($_));
#		}
#die $t;
		$self->_checkPassThrus($ldef,$q);
		$p->{'loadRecord'} = 0;
		return $self->show;				
	}

	if ($isAdd) {
		my %pairs;
		return 'attempt to create a link record when id is 0' if $id == 0;
		my $lv = int($q->param($ldef->{'link_value_field_in_querry'}));
		return 'attempt to create a link record when the link value is 0' if $lv == 0;

		if (exists $ldef->{'fieldPresets'}) {
			%pairs = %{$ldef->{'fieldPresets'}};
		}

		$pairs{$ldef->{'id_field_in_link_table'}} = $id;
		$pairs{$ldef->{'link_value_field_in_link_table'}} = $lv;

		my $querryFieldMap = $ldef->{'querry_field_map'};
		$self->queryToHash($q,$p->{'fieldspec'},\%pairs,$querryFieldMap);

		$sql->DeleteRecords($ldef->{'table'},"$ldef->{'id_field_in_link_table'} = $id and $ldef->{'link_value_field_in_link_table'} = ".$lv);
		$sql->InsertRecord($ldef->{'table'},\%pairs,1);  #dontquote=1 beacause queryToHash sets quoting properly
		$q->delete($ldef->{'link_value_field_in_querry'});
		$q->param('m' => 'show');
		$self->setup($self->page_name(),$app);
		
		$q->delete($ldef->{'link_value_field_in_querry'});
		foreach (keys %$querryFieldMap) {
			$q->delete($_);
#		die $self->getTemplatePairValue($_);
		}
#		my $t;
#		foreach ($q->param) {
#			$t .= "$_ = ".$q->param($_)."<BR>";
#			$self->addTemplatePairs($_ => $q->param($_));
#		}
#die $t;
		$self->_checkPassThrus($ldef,$q);
		$p->{'loadRecord'} = 0;
		return $self->show;				
	}


	my $pairsP = $self->param('formPairs');
	if (exists $p->{'userIDset'}) {
		my $user_id = $self->param('app')->getUserID();
		foreach my $i (@{$p->{'userIDset'}}) {
			$pairsP->{$i} = $user_id;
		}
	}
	if ($id == 0) {
		if ($p->{'canCreate'}) {
			if ($self->beforeCreate($pairsP,$q,$sql)) {
				$id = $sql->InsertRecord($table,$pairsP,1);  #dontquote=1 because queryToHash sets quoting properly
				$q->param('id'=>$id);
				$self->afterCreate($id,$pairsP,$q,$sql);
			}
		}
		else {
			$self->specErrorDie('attempt to create record when canCreate not set');
		}
	}
	else {
		if (exists $p->{'createOnly'}) {
			$self->specErrorDie('attempt to update a record when createOnly is set');
		}
		elsif (keys (%$pairsP)) {
			if ($self->beforeUpdate($id,$pairsP,$q,$sql)) {
				$self->doUpdate($table,$sql,$id,$pairsP,$q);
				$self->afterUpdate($id,$pairsP,$q,$sql);
				$self->addFlagsToTemplatPairs('_updateSuccess');
			}
			else {
				$self->addFlagsToTemplatPairs('_updateFailure');
			}
		}
	}
	return '';
}

sub beforeCreate
{
	my $self = shift;
	my $pairsP = shift;
	
	return 1;
}

sub beforeUpdate
{
	my $self = shift;
	my $id = shift;
	my $pairsP = shift;
	
	return 1;
}

sub doUpdate
{
	my $self = shift;
	my $table = shift;
	my $sql = shift;
	my $id = shift;
	my $pairsP = shift;
	$sql->UpdateRecords($table,$pairsP,"id=$id",1);
}


sub afterCreate
{
	my $self = shift;
	my $id = shift;
	my $pairsP = shift;
}
sub afterUpdate
{
	my $self = shift;
}

sub del
{
	my $self = shift;
	my $sql = $self->param('sql');
	my $app = $self->param('app');
	my $q = $app->query();
	my $p = $self->{'params'};
	my $table = $p->{'table'};

	my $badPrivs;
	
	if ((not exists $p->{'canDelete'})) {
		$self->specErrorDie('attempt to delete a record when canDelete not set');
	}
	
	$badPrivs = not $self->checkSubPriv('deletePriv',$p,$app);

	my $confirmPage = $p->{'deleteConfirm'};
	if ($confirmPage ne '' && not $app->checkPrivs($confirmPage)) {
		$badPrivs = 1;
	}
	
	if ($badPrivs) {
		$q->delete_all();
		return $app->yawaf_get_page('noPrivs')->getBody();
	}
	
	my $confirmed = ($confirmPage eq '') || ($q->param('confirm') eq 'Yes');
	if ($confirmed) {
		#[todo] check privilages to see if user is allowed to delete this particular record.
		my $id = $self->{'id'};
		if ($id > 0) {
			$sql->DeleteRecords($table,"id=$id");

			#delete any linked records too
			my $l =  $p->{'links'};
			foreach my $ldef (@$l) {
				my $ltable = $ldef->{'table'};
				$sql->DeleteRecords($ltable,"$ldef->{'id_field_in_link_table'}=$id");
			}
		}

		return $self->showReturnPage();
	}
	elsif (defined $q->param('cancel')) {
		return $self->showReturnPage();
	}
	else {
		my $return_page = $q->param('r');
		$return_page = $p->{'returnpage'} if $return_page eq '';
		$self->addTemplatePairs('r' => $return_page);
		$self->page_name($p->{'deleteConfirm'});
		return $self->show;
	}
}

sub _getID
{
	my $self = shift;
	my $q = shift;
	my $id;
	
	if (exists $self->{'params'}->{'idIsUserID'}) {
		return $self->param('app')->getUserID();
	}
	else {
		return int($q->param('id'));
	}
	
}

sub getTicketSpec
{
	my $self = shift;
	return undef if $self->{'params'}->{'ticketForCreateOnly'} && (exists $self->{'params'}->{'idIsUserID'} || int($self->param('app')->query()->param('id')) > 0);
	return $self->SUPER::getTicketSpec;
}

sub checkSubPriv
{
	my $self = shift;
	my $pKey = shift;
	my $p = shift;
	my $app = shift;

	if (exists $p->{$pKey}) {
		my @privs = @{$app->param('user_privs')};
		if (not grep(/$p->{$pKey}/,@privs)) {
			return 0;
		}
	}
	return 1;
}


1;