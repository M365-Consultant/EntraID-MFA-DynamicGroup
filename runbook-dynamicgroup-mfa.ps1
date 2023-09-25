<#PSScriptInfo
.VERSION 0.3
.GUID 21da31c8-4f69-419d-8a3f-f16168b8f3ae
.AUTHOR Dominik Gilgen
.COMPANYNAME Dominik Gilgen (Personal)
.COPYRIGHT 2023 Dominik Gilgen. All rights reserved.
.LICENSEURI https://github.com/M365-Consultant/EntraID-MFA-DynamicGroup/blob/main/LICENSE
.PROJECTURI https://github.com/M365-Consultant/EntraID-MFA-DynamicGroup
.EXTERNALMODULEDEPENDENCIES Microsoft.Graph.Authentication,Microsoft.Graph.Groups,Microsoft.Graph.Identity.SignIns,Microsoft.Graph.Users
#>

<# 

.DESCRIPTION 
 Azure Runbook - Dynamic Group - MFA State
 
This is an important change!

 This script is designed for an Azure Runbook to assign users to two Azure AD groups based on their MFA capability (capable / non-capable).
 Before running the runbook, you need to set up an automation account with a managed identity.e).
 
 IMPORTANT: Define the variables for the two necessary groups in the Automation Variables as "dynamicmfa_groupid_capable" and "dynamicmfa_groupid_noncapable", or hardcode them in this script.

 The managed identity requires the following Graph Permissions:
    - User.Read.All
    - Group.Read.All
    - Group.ReadWrite.All
    - UserAuthenticationMethod.Read.All

 The script requires the following modules:
    - Microsoft.Graph.Authentication
    - Microsoft.Graph.Groups
    - Microsoft.Graph.Identity.SignIns
    - Microsoft.Graph.Users

#> 


#variables (define them on the Automation Variables):
$groupid_capable = Get-AutomationVariable -Name 'dynamicmfa_groupid_capable'
$groupid_noncapable = Get-AutomationVariable -Name 'dynamicmfa_groupid_noncapable'


#Connect to Microsoft Graph within Azure Automation
Connect-MgGraph -Identity

# Adding users to the matching group
$users = get-mguser -All
$members_capable = Get-MgGroupMember -GroupId $groupid_capable -All
$members_noncapable = Get-MgGroupMember -GroupId $groupid_noncapable -All


foreach ($user in $users) {
    $mfa = Get-MgUserAuthenticationMethod -UserId $user.UserPrincipalName -All | Where-Object {$_.AdditionalProperties."@odata.type" -ne "#microsoft.graph.passwordAuthenticationMethod"}
    if ($mfa.Count -gt 0) {
            if ($members_capable.Id -notcontains $user.Id){ New-MgGroupMember -GroupId $groupid_capable -DirectoryObjectId $user.Id ; $output = $user.UserPrincipalName + " added to MFA capable group. User-ID: " + $user.Id ; Write-Output $output  }
            if ($members_noncapable.Id -contains $user.Id){ Remove-MgGroupMemberByRef -GroupId $groupid_noncapable -DirectoryObjectId $user.Id  ; $output = $user.UserPrincipalName + " removed from MFA non-capable group. User-ID: " + $user.Id ; Write-Output $output }
    }
    else{
            if($members_noncapable.Id -notcontains $user.Id){ New-MgGroupMember -GroupId $groupid_noncapable -DirectoryObjectId $user.Id ; $output = $user.UserPrincipalName + " added to MFA non-capable group. User-ID: " + $user.Id ; Write-Output $output }
            if($members_capable.Id -contains $user.Id){ Remove-MgGroupMemberByRef -GroupId $groupid_capable -DirectoryObjectId $user.Id ; $output = $user.UserPrincipalName + " removed from MFA capable group. User-ID: " + $user.Id ; Write-Output $output }
    }
}


#Disconnect from Microsoft Graph within Azure Automation
Disconnect-MgGraph
