<#
Azure Runbook - Dynamic Group - MFA State

This script is designed for an Azure Runbook to assign users to two Azure AD groups based on their MFA capability (capable / non-capable).
Before running the runbook, you need to set up an automation account with a managed identity.

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

!!! Important: Define the variables for the two necessary groups in the Automation Variables as "dynamicmfa_groupid_capable" and "dynamicmfa_groupid_noncapable", or hardcode them in this script. !!!

Version: 0.2
Creator: Dominik Gilgen (https://github.com/M365-Consultant)
Date of creation: 2023-09-22
License: CC BY-SA 4.0 (Attribution-ShareAlike 4.0 International)
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
    $mfa = Get-MgUserAuthenticationMethod -UserId $user.UserPrincipalName -All | where {$_.AdditionalProperties."@odata.type" -ne "#microsoft.graph.passwordAuthenticationMethod"}
    if ($mfa.Count -gt 0) {
            if ($members_capable.Id -notcontains $user.Id){ New-MgGroupMember -GroupId $groupid_capable -DirectoryObjectId $user.Id ; Write-Output $user.UserPrincipalName "added to MFA capable group. User-ID:" $user.Id  }
            if ($members_noncapable.Id -contains $user.Id){ Remove-MgGroupMemberByRef -GroupId $groupid_noncapable -DirectoryObjectId $user.Id  ; Write-Output $user.UserPrincipalName "removed from MFA non-capable group. User-ID:" $user.Id }
    }
    else{
            if($members_noncapable.Id -notcontains $user.Id){ New-MgGroupMember -GroupId $groupid_noncapable -DirectoryObjectId $user.Id ; Write-Output $user.UserPrincipalName "added to MFA non-capable group. User-ID:" $user.Id }
            if($members_capable.Id -contains $user.Id){ Remove-MgGroupMemberByRef -GroupId $groupid_capable -DirectoryObjectId $user.Id ; Write-Output $user.UserPrincipalName "removed from MFA capable group. User-ID:" $user.Id }
    }
}


#Disconnect from Microsoft Graph within Azure Automation
Disconnect-MgGraph
