#Based on Tilo's GetInactive User1.ps1 mod
Param(
	[String] $domain = "",
	[int] $DaysInactive = 0,
	[String] $mailTo = "j"
	)
	
import-module activedirectory 

Function TestDomain{
	if (![adsi]::Exists($args[0])){
		$response = "The input '$domain' is not a valid LDAP path in the current domain" 
		write-output $response
		exit
	}
}

Function GetInactiveUsers{
	# Get all AD User with lastLogonTimestamp less than our time and set to enable
	Return Get-ADUser -Filter {LastLogonTimeStamp -lt $time -and enabled -EQ $true} -searchBase $domain -Properties LastLogonTimeStamp | select-object @{Name = "Inactive Users"; Expression={$_.Name}}, @{Name="Last Login"; Expression={[DateTime]::FromFileTime($_.lastLogonTimestamp)}}
}

Function GetInactiveComputers{
	# Get all AD Computers with lastLogonTimestamp less than our time and set to enable
	Return Get-ADComputer -Filter {LastLogonTimeStamp -lt $time -and enabled -EQ $true} -searchBase $domain -Properties LastLogonTimeStamp | select-object @{Name = "Inactive Computers"; Expression={$_.Name}}, @{Name="Last Login"; Expression={[DateTime]::FromFileTime($_.lastLogonTimestamp)}}
}

Function GetDisabledUsers{
	# Get all AD User with Modified less than our time and set to disabled
	Return Get-ADUser -Filter {Modified -lt $time -and enabled -EQ $false} -searchBase $domain -Properties Modified | select-object @{Name = "Disabled Users"; Expression={$_.Name}}, @{Name = "Last Modified"; Expression={$_.Modified}}
}

Function GetDisabledComputers{
	# Get all AD Computers with Modified less than our time and set to disabled
	Return Get-ADComputer -Filter {Modified -lt $time -and enabled -EQ $false} -searchBase $domain -Properties Modified | select-object @{Name = "Disabled Computers"; Expression={$_.Name}}, @{Name = "Last Modified"; Expression={$_.Modified}}
}

Function GetMailServer{
	Return Get-Content sanitizeVariables.txt
	
}

Function MailResults{
	$head = "<style>"
	$head = $head + "TABLE{border-width:1px;border-style:solid;border-color:black;border-collapse:collapse;}"
	$head = $head + "TH{border-width:1px;padding:0px;border-style:solid;border-color:black;background-color:LightSlateGray;}"
	$head = $head + "TD{border-width:1px;padding:0px;border-style:solid;border-color:black;}"
	$head = $head + "</style>"
	
	
	$body = ""
	$mailTo = ""
	$mailFrom = "DoNotReply@DoNotReply.com"
	ForEach ($arg in $args) {
		if(([array]::indexOf($args,$arg)) -NE 0){
			$temp = $arg | ConvertTo-HTML -fragment | Out-String
			$body = $body + "<br/>" + $temp
		} else{
			$mailTo = $arg
		}
	}
	
	$messageTitle = "<h2>Please Review These AD objects</h2>"
	$message = ConvertTo-HTML -Head $head -PreContent $messageTitle -PostContent $body | Out-String
	$subject = "Inactive Objects in AD"
	
	$smtpServer = GetMailServer
	#$smtp = New-Object Net.Mail.SmtpClient("$mailServer")
	#$smtp.Send("$mailFrom","$mailTo","$subject","$message")
	send-MailMessage -SmtpServer $smtpServer -To $mailTo -From $mailFrom -Subject $subject -Body $message -BodyAsHtml
}

if ($domain -EQ ""){
	$response = "The domain parameter has not been specified" 
	write-output $response
	exit
	#$OU = Get-Content sanitizeVariables.txt
	#$ofs = "," #overloading powershell preference variable, ofs
	#$domain = "$OU" #powershell automatically joins the OU array with the $ofs character above
}

if ($DaysInactive -EQ 0){
	#default timeframe to 30 days
	$DaysInactive = 30
}

$time = (Get-Date).Adddays(-($DaysInactive))

write-output "Testing '$domain'..."
TestDomain "LDAP://$domain"
write-output "domain exists"

$inactiveUsers = GetInactiveUsers
$inactiveComputers = GetInactiveComputers
$disabledUsers = GetDisabledUsers
$disabledComuters = GetDisabledComputers 

if ($mailTo -NE ""){
	MailResults $mailTo $inactiveUsers $inactiveComputers $disabledUsers $disabledComuters
}


