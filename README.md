*** WORK IN PROGRESS ***

# EntraID-MFA-DynamicGroup
This solution is designed for an Azure Runbook to assign users to two Entra ID (AzureAD) groups based on their MFA capability (capable / non-capable).

The initial reason for this script is to address customers who decided to exclude MFA for trusted locations on their conditional access policies, which I strongly discourage. However, I have observed this practice in multiple environments. Unfortunately, they often overlook the issue that arises when a user never connects from outside the trusted locations. In such cases, the user is never prompted to set up MFA. If the account credentials are compromised, attackers can set up MFA themselves because it is the first time MFA is required for that account. The compromised user can still access resources due to the trusted location exclusion.

To mitigate this issue, a potential solution would be to generally block external access for users without MFA (MFA non-capable) or restrict registration of security information from outside. Unfortunately, Dynamic Groups in Entra ID do not provide the possibility to create a rule based on a user's MFA state.

# Requirements
Before using the Azure Runbook, you need to set up an automation account with a managed identity.

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

# Parameters
There are a few parameters which must be set for a job run:
- $groupid_capable
  - The Object-ID of a EntraID (AzureAD) group where MFA capable uers's should be assigned
- $groupid_noncapable
  - The Object-ID of a EntraID (AzureAD) group where MFA NON-capable uers's should be assigned
- $mailMode -> This controls the mail behavior. Enter the mode you want without using '
  - 'always' - sends a mail on every run
  - 'changes' - sends a mail only if there were any changes
  - 'disabled' - never send a mail
- $mailSender
  - The mail-alias from which the mail will be send (can be a user-account or a shared-mailbox)
- $mailRecipients
  - The recipient(s) of the mail (internal or external). If you want more than one recipient, you can separate them with the character ; in between.

# Changelog
- v0.4 Email-Reporting implementation / changing from variables to parameters
  - Implemented a email reporting which requires the permission 'Mail.Send' and the Graph-Module 'Microsoft.Graph.Users.Actions'
  - Changed from variables to parameters, which makes handling within Azure Runbooks easier
- v0.3 First release
  - First release of this script
