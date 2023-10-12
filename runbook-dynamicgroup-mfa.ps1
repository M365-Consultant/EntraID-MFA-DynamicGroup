<#PSScriptInfo
.VERSION 0.4
.GUID 21da31c8-4f69-419d-8a3f-f16168b8f3ae
.AUTHOR Dominik Gilgen
.COMPANYNAME Dominik Gilgen (Personal)
.COPYRIGHT 2023 Dominik Gilgen. All rights reserved.
.LICENSEURI https://github.com/M365-Consultant/EntraID-MFA-DynamicGroup/blob/main/LICENSE
.PROJECTURI https://github.com/M365-Consultant/EntraID-MFA-DynamicGroup
.TAGS AzureAD EntraID MFA ConditionalAccess DynamicGroup Runbook
.RELEASENOTES
This script now supports email reporting, which requires the permission 'Mail.Send' and the Graph-Module 'Microsoft.Graph.Users.Actions'.
Instead of variables it is now using parameters for the input.
#>

<# 

.DESCRIPTION 
 Azure Runbook - Dynamic Group - MFA State
 
 This script is designed for an Azure Runbook to assign users to two Azure AD groups based on their MFA capability (capable / non-capable).
 Before running the runbook, you need to set up an automation account with a managed identity.

 The managed identity requires the following Graph Permissions:
    - User.Read.All
    - Group.ReadWrite.All
    - UserAuthenticationMethod.Read.All
    - Mail.Send


 The script requires the following modules:
    - Microsoft.Graph.Authentication
    - Microsoft.Graph.Groups
    - Microsoft.Graph.Identity.SignIns
    - Microsoft.Graph.Users
    - Microsoft.Graph.Users.Actions

 There are a few parameters which must be set for a job run:
    - $groupid_capable -> The Object-ID of a EntraID (AzureAD) group where MFA capable uers's should be assigned
    - $groupid_noncapable -> The Object-ID of a EntraID (AzureAD) group where MFA NON-capable uers's should be assigned
    - $mailMode -> This controls the mail behavior. Enter the mode you want without using '
        'always' - sends a mail on every run
        'changes' - sends a mail only if there were any changes
        'disabled' - never send a mail
    - $mailSender -> The mail-alias from which the mail will be send (can be a user-account or a shared-mailbox)
    - $mailRecipients -> The recipient(s) of the mail (internal or external). If you want more than one recipient, you can separate them with the character ; in between.

#> 

Param
(
  [Parameter (Mandatory= $true)]
  [String] $groupid_capable = "Enter Group-ID for MFA capable",
  [Parameter (Mandatory= $true)]
  [String] $groupid_noncapable = "Enter Group-ID for MFA non-capable",
  [Parameter (Mandatory= $false)]
  [String] $mailMode,
  [Parameter (Mandatory= $false)]
  [String] $mailSender,
  [Parameter (Mandatory= $false)]
  [String] $mailRecipients
)

#Connect to Microsoft Graph using a Managed Identity
Connect-MgGraph -Identity

#Preparing necessary variables
$users = get-mguser -All
$members_capable = Get-MgGroupMember -GroupId $groupid_capable -All
$members_noncapable = Get-MgGroupMember -GroupId $groupid_noncapable -All
$groupname_capable = Get-MgGroup -GroupId $groupid_capable
$groupname_noncapable = Get-MgGroup -GroupId $groupid_noncapable

#Preparing mail content
$mailContentHeader = "<p>The Azure runbook for dynamic group based on the user's MFA state has been executed.</p><p>Those are the changes from this run:</p>"
$mailContentChanges = "<ul>"

#Running the MFA state check for every user and assign them to correct groups
foreach ($user in $users) {
    $mfa = Get-MgUserAuthenticationMethod -UserId $user.UserPrincipalName -All | Where-Object {$_.AdditionalProperties."@odata.type" -ne "#microsoft.graph.passwordAuthenticationMethod"}
    if ($mfa.Count -gt 0) {
            if ($members_capable.Id -notcontains $user.Id){
                New-MgGroupMember -GroupId $groupid_capable -DirectoryObjectId $user.Id
                $output = $user.UserPrincipalName + " added to '" + $groupname_capable.DisplayName + "'. User-ID: " + $user.Id
                Write-Output $output
                $outputMail = "<li>" + $user.UserPrincipalName + " <font color='green'>added</font> to '" + $groupname_capable.DisplayName + "'.  <font color='grey'>(User-ID: " + $user.Id + ")</font></li>"
                $mailContentChanges += $outputMail
            }
            if ($members_noncapable.Id -contains $user.Id){
                Remove-MgGroupMemberByRef -GroupId $groupid_noncapable -DirectoryObjectId $user.Id
                $output = $user.UserPrincipalName + " removed from '" + $groupname_noncapable.DisplayName + "'. User-ID: " + $user.Id
                $outputMail = "<li>" + $user.UserPrincipalName + " <font color='orange'>removed</font> from '" + $groupname_noncapable.DisplayName + "'. <font color='grey'>(User-ID: " + $user.Id + ")</font></li>"
                Write-Output $output
                $mailContentChanges += $outputMail
            }
    }
    else{
            if($members_noncapable.Id -notcontains $user.Id){ 
                New-MgGroupMember -GroupId $groupid_noncapable -DirectoryObjectId $user.Id
                $output = $user.UserPrincipalName + " added to '" + $groupname_noncapable.DisplayName + "'. User-ID: " + $user.Id
                $outputMail = "<li>" + $user.UserPrincipalName + " <font color='green'>added</font> to '" + $groupname_noncapable.DisplayName + "'. <font color='grey'>(User-ID: " + $user.Id + ")</font></li>"
                Write-Output $output
                $mailContentChanges += $outputMail
            }
            if($members_capable.Id -contains $user.Id){
                Remove-MgGroupMemberByRef -GroupId $groupid_capable -DirectoryObjectId $user.Id
                $output = $user.UserPrincipalName + " removed from '" + $groupname_capable.DisplayName + "' because this account has become non-capable! User-ID: " + $user.Id
                $outputMail = "<li><font color='red'><b>WARNING: </b></font>" + $user.UserPrincipalName + " <font color='orange'>removed</font> from '" + $groupname_capable.DisplayName + "' because this account has become non-capable! <font color='grey'>(User-ID: " + $user.Id + ")</font></li>"
                Write-Warning $output
                $mailContentChanges += $outputMail
            }
    }
}

if ($mailContentChanges -eq "<ul>"){
    $mailContentChanges = "<b>No changes made.</b>"
    Write-Output "No changes made."
}
else { $mailContentChanges += "</ul>" }

# Sendmail
function runbookSendMail {
    $mailRecipientsArray = $mailRecipients.Split(";")
    $mailSubject = "Azure Runbook Report: Dynamic Group MFA State"
    $mailContentFooter = "<br><br><p style='color: grey'>You can find additional details in the job history of this runbook.<br>Job finished at (UTC) " + (Get-Date).ToUniversalTime() + "<br>Job ID:"+ $PSPrivateMetadata.JobId.Guid + "</p>"
    $mailContent = $mailContentHeader + $mailContentChanges + $mailContentFooter

    $params = @{
            Message = @{
                Subject = $mailSubject
                Body = @{
                    ContentType = "html"
                    Content = $mailContent
                }
                ToRecipients = @(
                    foreach ($recipient in $mailRecipientsArray) {
                        @{
                            EmailAddress = @{
                                Address = $recipient
                            }
                        }
                    }
                )
            }
            SaveToSentItems = "false"
        }
        
    Send-MgUserMail -UserId $mailSender -BodyParameter $params
    Write-Output "Mail has been sent."
}

if ($mailMode -eq "always" -and $mailSender -and $mailRecipients) { runbookSendMail }
elseif ($mailMode -eq "changes" -and $mailSender -and $mailRecipients -and ($mailContentChanges -ne "<b>No changes made.</b>")) { runbookSendMail }
elseif ($mailMode -eq "changes" -and $mailSender -and $mailRecipients) { Write-Output "No mail sent, because there are no changes and mailmode is set to 'changes'." }
elseif ($mailMode -eq "disabled"){ Write-Output "Mail function is disabled." }
else { Write-Warning "Mail settings are missing or incorrect" }


#Disconnect from Microsoft Graph within Azure Automation
Disconnect-MgGraph