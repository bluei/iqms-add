########################################################
#	IQMS ADD USER SCRIPT
#	- Created by Scott Morey
#	
#	Revisions:
#	2015.04.01 - Initial creation
########################################################
	$username = "iqms"
	$targetDbinstance = $($selection = read-host "Environment to use (iqora or [iqtrain]): "
	 if ($selection) {$selection} else {"iqtrain"})
	$password = $($selection = read-host "Target DB IQMS password: "
	 if ($selection) {$selection} else {"iqtsadmin"})
	 
	# DECLARE VARIABLES
	$fn = ""
	$ln = ""
	$un = ""
	$empno = ""
	$email = ""
	$sql = ""
	$count = 0

	
	function IsNull($objectToCheck) {
    if (!$objectToCheck) {
        return $true
    }
 
    if ($objectToCheck -is [String] -and $objectToCheck -eq [String]::Empty) {
        return $true
    }
 
    if ($objectToCheck -is [DBNull] -or $objectToCheck -is [System.Management.Automation.Language.NullString]) {
        return $true
    }
 
    return $false
}
	
	Function WriteOut ($msg){
		write-host "-------------------------------------------------------------"
		write-host $msg
		write-host "-------------------------------------------------------------"
	 }
	
	Function Prompt ($p){
		if ($p -ne "")
		{
		WriteOut $p
		read-host "Press ENTER to continue..."
		} else {
		read-host "Press ENTER to continue..."
		}
	}

	Function BuildSQL ($pSQL){
	"
		set NewPage none
		set heading off
		set feedback off
		$pSQL
		exit;
	";
	}
	
	Function EmployeeExists ($first, $last, $emp){
		$sql = "
		select count(*) c
		from pr_emp 
		where (upper(first_name) = upper('$first') and upper(last_name) = upper('$last')) or badgeno = '$emp' or empno = '$emp';
		";
		$sql = BuildSQL $sql;

        $count = 0;	#this is needed to set the count to a value if the querey returns no results.
		$count = $sql | sqlplus -silent iqms/iqtsadmin@iqtrain;

		if ([int]$count -eq 0)
		{
		return $false;
		}
		else
		{	
        return $true;
		}
	}
		
	Function UserExists ($username){
		$sql = "
		set NewPage none
		set heading off
		set feedback off
		select count(*) c
		from S_USER_GENERAL 
		where Upper(user_name) = Upper('smoooorey')
		group by Upper(user_name);
		";
		#$sql = BuildSQL $sql;
        #$count = 0;	#this is needed to set the count to a value if the querey returns no results.
		
		$count = $sql | sqlplus -silent $username/$password@$targetDbinstance;
		
		if($count -eq $null){return $false}
		if($count -gt 0){return $true}
		return $false
	}
	
if(EmployeeExists "scooott" "morey" "123")
{
	read-host "employee EXISTS";
} else {
read-host "no employee"
}

#### TESTING #####	
exit
read-host "Press enter to start...";
$sql = "
	set NewPage none
	set heading off
	set feedback off
	select count(*) c
	from S_USER_GENERAL 
	where Upper(user_name) = Upper('smoXrey')
	group by Upper(user_name);
	";
$count = $sql | sqlplus -silent iqms/iqtsadmin@iqtrain;
if($count -eq $null){write-host "Count is NULL"}
if([int]$count -gt 0){write-host "Count equals $count"}
write-host "Count: $count"
read-host "STOP"
exit
	

#----------------------------------------
#	GET ALL INFO
#----------------------------------------
$fn = 			(read-host "First Name			").ToUpper()
$ln = 			(read-host "Last Name			").ToUpper()
$un = 			(read-host "Username			").ToUpper()
$empno = 		(read-host "Employee No			")
$email = 		(read-host "Email				").ToLower()
$eplant_id =	(read-host "Eplant ID			")
$cf = 			(read-host "copy from Username	").ToUpper()




#----------------------------------------
#	ADD EMPLOYEE
#----------------------------------------

if(EmployeeExists $fn $ln $empno)
{
	# get existing employee id
	
	$sql =  "select ID from pr_emp where upper(first_name) = '$fn' and upper(last_name) = '$ln';"
	#Prompt "looking up existing with...`n $sql"
	$sql = BuildSQL $sql
	$strEmpId = $sql | sqlplus -silent $username/$password@$targetDbinstance  
		
    #read-host "Employee with ID $strEmpId has a type of..."
    #read-host $strEmpId.GetType().FullName
	$intEmpId = [int]$strEmpId
	#read-host $intEmpId.GetType().FullName
	
	Prompt "Employee $fn $ln with badge/employee no $empno already existed as ID $intEmpId"

} else 
{ 
	Prompt "Adding Employee"
    # get next employee id
	$sql = BuildSQL  "select S_PR_EMP.NextVal as NewID from DUAL;"
	$strEmpId = $sql | sqlplus -silent $username/$password@$targetDbinstance  
	$intEmpId = [int]$strEmpId
	
	# insert employee record
	$sql = BuildSQL "INSERT INTO PR_EMP (ID ,EMPNO ,FIRST_NAME ,LAST_NAME ,SSNMBR ,BADGENO ,EMAIL )  VALUES ($intEmpId, '$empno', '$fn', '$ln', '111111111', '$empno', '$email');"
	$sql | sqlplus -silent $username/$password@$targetDbinstance  
	Prompt "Added employee record for $fn $ln. ID=$intEmpId"
}

#----------------------------------------
#	ADD USER
#----------------------------------------

if(UserExists $un)
{
	Prompt "User $un already exists and will not be re-added."	
} else 
{ 
	# get next employee id
	$sql = "
		create user $un identified by 1 default tablespace USERS temporary tablespace TEMP;
		grant connect to `"$un`";
		grant create session to `"$un`";
		grant select on iqorder2 to `"$un`";
		grant IQWEBDIRECT_ROLE to `"$un`";
		insert into s_user_general (user_name) values ('$un');
		delete from s_users where user_name = '$un';
		insert into s_users (user_name, role_name, s_group_id) select '$un', role_name, s_group_id from s_users where user_name = '$cf';
		delete from rf_profile where userid = '$un';
		insert into rf_profile (userid, module_name, topic, to_prompt, source_id, source, attribute ) 
			select '$un', module_name, topic, to_prompt, source_id, source, attribute from rf_profile where userid = '$cf';
		delete from s_user_po_type where user_name = '$un';
		insert into s_user_po_type ( po_type_id, limit, user_name, is_default ) 
			select po_type_id, limit, '$un', is_default from s_user_po_type where user_name = '$cf';
		"
	
	$sql = BuildSQL $sql
	$sql | sqlplus -silent $username/$password@$targetDbinstance  
	
	$sql = "update s_user_general 
			set 
				force_password_change = 'Y',
				pr_emp_id = $intEmpId,
				auto_shut_time = 10800,
				eplant_id = $eplant_id,
				email = '$email',
				dont_change_poap = 'Y',
				po_cant_incr_cost = 'Y',
				rma_limit = 0,
				inv_adj_limit = 0,
				ap_tolerance = 0,
				receipt_tolerance = 0,
				auto_shut_action_code = 0
			where RTrim(user_name) = '$un';"
	$sql = BuildSQL $sql
	$sql | sqlplus -silent $username/$password@$targetDbinstance 
	
	Prompt "Added user $un and copied settings from $cf"
}

#----------------------------------------
#	ADD QUALITY TEAM MEMBER
#----------------------------------------
if ((read-host "Add as Team Member (doc control, po, etc)?  Y or N ").ToUpper() -eq "Y")
{
	## Add if team member does not exist
	$sql = "select count(*) from TEAM_MEMBER where Upper(userid) = Upper('$username');"
	Prompt "looking up existing with...`n $sql"
	$sql = BuildSQL $sql
	$count = 0
	$count = $sql | sqlplus -silent $username/$password@$targetDbinstance;
	
	if ([int]$count -eq 0)
	{
	# insert team_member record...
	# get next team_member id
	$sql = BuildSQL  "Select S_TEAM_MEMBER.NextVal as NewID from DUAL;"
	$tmid = $sql | sqlplus -silent $username/$password@$targetDbinstance  
	
	$fullname = "$fn $ln"
	$sql = BuildSQL "INSERT INTO TEAM_MEMBER (ID ,USERID ,NAME ,TITLE ,EMAIL ,USED_DOC ,EPLANT_ID ,USED_PO)  
		VALUES ($tmid, '$un', '$fullname', '', '$email', 'Y', $eplant_id, 'Y');"
	$sql | sqlplus -silent $username/$password@$targetDbinstance  
	Prompt "Added team_member record for $fn $ln."
	}
	else
	{
	# get next team_member id
	Prompt "Team member with username $username already exists and will not be duplicated."
	}

}


#----------------------------------------
#	ADD Expense USER
#	- Add as Vendor if not existing
#	- Ensure approver exists
#	- Add expense user record
#----------------------------------------





########################################################
##	HOW IT WORKS
##	0) Get all information
##	1) Employee record always created if not exists
##		- create if it doesn't exist.  
##		- get employee ID
## 	2) Create the User 
##		- if exists, skip, otherwise add
##		- get user ID
##		- copy permissions: roles, WMS, Eplant Membership, Gen User, PO Limit & Accessible eplants
##	3) Add Quality Team member
##		- if exists, skip, otherwise add
##		- default DOC and PO
##	5) Create Expense User
##		- Add the Vendor record
##		- if exists, skip, otherwise add
## 		* (later) add network folder, add security group, apply permissions.
##	5) Add Expense Library
########################################################

# examples

	#$outputfile = "C:\github\iqms-add\activeusers.txt"      # this is only required for option 1
	#Prompt "The output file is $outputfile"

    # Option 1 - piping the sql output into a file. 
	#$sqlQuery | sqlplus -silent $username/$password@$targetDbinstance | Out-File $outputfile

    # Option 2 - capture the sql output into a variable. 
	
	#$sql = "
	#SELECT name FROM eplant where name = 'PLAINFIELD';"
	
	#$sql = BuildSQL $sql
	#$nextPR_EMP_ID = $sql | sqlplus -silent $username/$password@$targetDbinstance 
	#Prompt "The eplant is: $nextPR_EMP_ID"

 
