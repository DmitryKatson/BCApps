// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------

namespace System.Security.User;

using System.Security.AccessControl;

permissionset 166 "User Permissions - Objects"
{
    Access = Internal;
    Assignable = false;

    Permissions = page "Lookup Permission Set" = X,
                  page "User Subform" = X;
}
