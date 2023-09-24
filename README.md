*** WORK IN PROGRESS ***

This solution is designed for an Azure Runbook to assign users to two Entra ID (AzureAD) groups based on their MFA capability (capable / non-capable).

The initial reason for this script is to address customers who decided to exclude MFA for trusted locations on their conditional access policies, which I strongly discourage. However, I have observed this practice in multiple environments. Unfortunately, they often overlook the issue that arises when a user never connects from outside the trusted locations. In such cases, the user is never prompted to set up MFA. If the account credentials are compromised, attackers can set up MFA themselves because it is the first time MFA is required for that account. The compromised user can still access resources due to the trusted location exclusion.

To mitigate this issue, a potential solution would be to generally block external access for users without MFA (MFA non-capable) or restrict registration of security information from outside. Unfortunately, Dynamic Groups in Entra ID do not provide the possibility to create a rule based on a user's MFA state.

Before using the Azure Runbook, you need to set up an automation account with a managed identity.

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

IMPORTANT: Define the variables for the two necessary groups in the Automation Variables as "dynamicmfa_groupid_capable" and "dynamicmfa_groupid_noncapable", or hardcode them in this script.
