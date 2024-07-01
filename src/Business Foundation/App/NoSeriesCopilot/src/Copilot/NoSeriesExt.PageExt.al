// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------

namespace Microsoft.Foundation.NoSeries;

using System.Environment.Configuration;

pageextension 324 "No. Series Ext." extends "No. Series"
{
    actions
    {
        addfirst(Prompting)
        {
            action("Generate With Copilot Prompting")
            {
                Caption = 'Generate';
                ToolTip = 'Generate No. Series using Copilot';
                Image = Sparkle;
                ApplicationArea = All;
                Visible = CopilotActionsVisible;

                trigger OnAction()
                var
                    NoSeriesCopilotImpl: Codeunit "No. Series Copilot Impl.";
                begin
                    NoSeriesCopilotImpl.GetNoSeriesSuggestions();
                end;
            }
        }

        addlast(Processing)
        {
            action("Generate With Copilot")
            {
                Caption = 'Generate';
                ToolTip = 'Generate No. Series using Copilot';
                Image = Sparkle;
                ApplicationArea = All;
                Visible = CopilotActionsVisible;

                trigger OnAction()
                var
                    NoSeriesCopilotImpl: Codeunit "No. Series Copilot Impl.";
                begin
                    NoSeriesCopilotImpl.GetNoSeriesSuggestions();
                end;
            }
        }
    }

    trigger OnOpenPage()
    var
        FeatureKey: Record "Feature Key";
        FeatureManagementFacade: Codeunit "Feature Management Facade";
    begin
        if not FeatureKey.Get(NumberSeriesWithAILbl) then
            CopilotActionsVisible := true
        else
            CopilotActionsVisible := FeatureManagementFacade.IsEnabled(NumberSeriesWithAILbl);

        // if CopilotActionsVisible then
        //     CopilotActionsVisible := EnvironmentInformation.IsSaaSInfrastructure(); //TODO: Check how to keep IsSaaSInfrastructure but be able to test in Docker Environment
    end;

    var
        CopilotActionsVisible: Boolean;
        NumberSeriesWithAILbl: Label 'NumberSeriesWithAI', Locked = true;

}