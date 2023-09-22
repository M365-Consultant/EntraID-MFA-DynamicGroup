<#
Dynamic Group Runbook - MFA State

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

Important: Define the variables for the two necessary groups at the beginning of the script.

Version: 0.1
Creator: Dominik Gilgen (https://github.com/M365-Consultant)
Date of creation: 2023-09-22
License: CC BY-SA 4.0 (Attribution-ShareAlike 4.0 International)
#>


#Define variables (e.g. 3edd8134-e624-451e-abb2-ec82cae1900e):
$groupid_capable = 'xxx'
$groupid_noncapable = 'xxx'



#Connect to Microsoft Graph within Azure Automation
Connect-AzAccount -Identity
$token = Get-AzAccessToken -ResourceUrl "https://graph.microsoft.com"
$securetoken = ConvertTo-SecureString -String $token.Token -AsPlainText -Force
Connect-MgGraph -AccessToken $securetoken


# Remove all members from exisiting Group
$members_mfatrue = Get-MgGroupMember -GroupId $groupid_capable
$members_mfafalse = Get-MgGroupMember -GroupId $groupid_noncapable

foreach ($user in $members_mfatrue) {
    Remove-MgGroupMemberByRef -GroupId $groupid_capable -DirectoryObjectId $user.Id
    }

foreach ($user in $members_mfafalse) {
    Remove-MgGroupMemberByRef -GroupId $groupid_noncapable -DirectoryObjectId $user.Id
    }


# Adding users to the matching group
$users = get-mguser -All

foreach ($user in $users) {
    $mfa = Get-MgUserAuthenticationMethod -UserId $user.UserPrincipalName -All | where {$_.AdditionalProperties."@odata.type" -ne "#microsoft.graph.passwordAuthenticationMethod"}
    if ($mfa.Count -gt 0) {
    New-MgGroupMember -GroupId $groupid_capable -DirectoryObjectId $user.Id
    }
}

foreach ($user in $users) {
    $mfa = Get-MgUserAuthenticationMethod -UserId $user.UserPrincipalName -All | where {$_.AdditionalProperties."@odata.type" -ne "#microsoft.graph.passwordAuthenticationMethod"}
    if ($mfa.Count -eq 0) {
    New-MgGroupMember -GroupId $groupid_noncapable -DirectoryObjectId $user.Id
    }
}

#Disconnect from Microsoft Graph within Azure Automation
Disconnect-MgGraph
