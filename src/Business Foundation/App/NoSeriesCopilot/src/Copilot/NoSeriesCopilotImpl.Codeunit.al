codeunit 324 "No. Series Copilot Impl."
{
    procedure Generate(var NoSeriesProposal: Record "No. Series Proposal"; var ResponseText: text; var NoSeriesGenerated: Record "No. Series Proposal Line"; InputText: Text)
    var
        SystemPromptTxt: Text;
        ToolsTxt: Text;
        CompletePromptTokenCount: Integer;
        Completion: Text;
        TokenCountImpl: Codeunit "AOAI Token";
    begin
        SystemPromptTxt := GetSystemPrompt();
        ToolsTxt := GetToolsText();

        CompletePromptTokenCount := TokenCountImpl.GetGPT4TokenCount(SystemPromptTxt) + TokenCountImpl.GetGPT4TokenCount(ToolsTxt) + TokenCountImpl.GetGPT4TokenCount(InputText);
        if CompletePromptTokenCount <= MaxInputTokens() then begin
            Completion := GenerateNoSeries(SystemPromptTxt, InputText);
            if CheckIfValidCompletion(Completion) then begin
                SaveGenerationHistory(NoSeriesProposal, InputText);
                // CreateNoSeries(NoSeriesProposal, NoSeriesGenerated, Completion);
                ResponseText := Completion;
            end;
        end;
    end;

    [NonDebuggable]
    local procedure GetSystemPrompt(): Text
    var
        NoSeriesCopilotSetup: Record "No. Series Copilot Setup";
    begin
        // This is a temporary solution to get the system prompt. The system prompt should be retrieved from the Azure Key Vault.
        // TODO: Retrieve the system prompt from the Azure Key Vault, when passed all tests.
        NoSeriesCopilotSetup.Get();
        exit(NoSeriesCopilotSetup.GetSystemPromptFromIsolatedStorage());
    end;

    [NonDebuggable]
    local procedure GetTools() ToolsList: List of [JsonObject]
    var
        ToolsJArray: JsonArray;
        ToolJToken: JsonToken;
        i: Integer;
    begin
        ToolsJArray.ReadFrom(GetToolsText());

        for i := 0 to ToolsJArray.Count - 1 do begin
            ToolsJArray.Get(i, ToolJToken);
            ToolsList.Add(ToolJToken.AsObject());
        end;
    end;

    [NonDebuggable]
    local procedure GetToolsText(): Text
    var
        NoSeriesCopilotSetup: Record "No. Series Copilot Setup";
    begin
        // This is a temporary solution to get the tools. The tools should be retrieved from the Azure Key Vault.
        // TODO: Retrieve the tools from the Azure Key Vault, when passed all tests.
        NoSeriesCopilotSetup.Get();
        exit(NoSeriesCopilotSetup.GetFunctionsPromptFromIsolatedStorage())
    end;


    [NonDebuggable]
    internal procedure GenerateNoSeries(var SystemPromptTxt: Text; InputText: Text): Text
    var
        AzureOpenAI: Codeunit "Azure OpenAi";
        AOAIDeployments: Codeunit "AOAI Deployments";
        AOAIOperationResponse: Codeunit "AOAI Operation Response";
        AOAIChatCompletionParams: Codeunit "AOAI Chat Completion Params";
        AOAIChatMessages: Codeunit "AOAI Chat Messages";
        CompletionAnswerTxt: Text;
        ToolJson: JsonObject;
    begin
        if not AzureOpenAI.IsEnabled(Enum::"Copilot Capability"::"No. Series Copilot") then
            exit;

        AzureOpenAI.SetAuthorization(Enum::"AOAI Model Type"::"Chat Completions", GetEndpoint(), GetDeployment(), GetSecret());
        AzureOpenAI.SetCopilotCapability(Enum::"Copilot Capability"::"No. Series Copilot");
        AOAIChatCompletionParams.SetMaxTokens(MaxOutputTokens());
        AOAIChatCompletionParams.SetTemperature(0);
        AOAIChatMessages.AddSystemMessage(SystemPromptTxt);

        foreach ToolJson in GetTools() do
            AOAIChatMessages.AddTool(ToolJson);

        AOAIChatMessages.AddUserMessage(InputText);
        AzureOpenAI.GenerateChatCompletion(AOAIChatMessages, AOAIChatCompletionParams, AOAIOperationResponse);
        if AOAIOperationResponse.IsSuccess() then
            CompletionAnswerTxt := AOAIChatMessages.GetLastMessage()
        else
            Error(AOAIOperationResponse.GetError());

        if CheckIfToolShouldBeCalled(CompletionAnswerTxt) then
            CompletionAnswerTxt := CallTool(AzureOpenAI, AOAIChatMessages, AOAIChatCompletionParams, CompletionAnswerTxt);

        exit(CompletionAnswerTxt);
    end;

    local procedure CheckIfToolShouldBeCalled(var CompletionAnswerTxt: Text): Boolean
    var
        Response: JsonArray;
        TypeToken: JsonToken;
        XPathLbl: Label '$[0].type', Comment = 'For more details on response, see https://aka.ms/AAlrz36', Locked = true;
    begin
        if not Response.ReadFrom(CompletionAnswerTxt) then
            exit(false);

        if Response.SelectToken(XPathLbl, TypeToken) then
            exit(TypeToken.AsValue().AsText() = 'function');

        exit(false);
    end;

    local procedure GetToolNameAndParamsAndCallId(var CompletionAnswerTxt: Text; var FunctionName: Text; var FunctionArguments: Text; var ToolCallId: Text)
    var
        Response: JsonArray;
        FunctionNameToken: JsonToken;
        FunctionArgumentsToken: JsonToken;
        ToolCallIdToken: JsonToken;
        XPathFunctionNameLbl: Label '$[0].function.name', Comment = 'For more details on response, see https://aka.ms/AAlrz36', Locked = true;
        XPathFunctionArgumentsLbl: Label '$[0].function.arguments', Comment = 'For more details on response, see https://aka.ms/AAlrz36', Locked = true;
        XPathToolCallIdLbl: Label '$[0].id', Comment = 'For more details on response, see https://aka.ms/AAlrz36', Locked = true;
    begin
        if not Response.ReadFrom(CompletionAnswerTxt) then
            exit;

        if Response.Count > 1 then
            Error('More than one tool found'); //TODO: handle More than one tool found case

        if not Response.SelectToken(XPathFunctionNameLbl, FunctionNameToken) then
            Error('function.name not found'); //TODO: handle function.name not found case

        if not Response.SelectToken(XPathFunctionArgumentsLbl, FunctionArgumentsToken) then
            Error('function.arguments not found'); //TODO: handle function.arguments not found case

        if not Response.SelectToken(XPathToolCallIdLbl, ToolCallIdToken) then
            Error('tool_call_id not found'); //TODO: handle tool_call_id not found case

        FunctionName := FunctionNameToken.AsValue().AsText();
        FunctionArguments := FunctionArgumentsToken.AsValue().AsText();
        ToolCallId := ToolCallIdToken.AsValue().AsText();
    end;

    local procedure CallTool(var AzureOpenAI: Codeunit "Azure OpenAi"; var AOAIChatMessages: Codeunit "AOAI Chat Messages"; var AOAIChatCompletionParams: Codeunit "AOAI Chat Completion Params"; var ToolDefinition: Text): Text
    var
        ToolCallId: Text;
        FunctionName: Text;
        FunctionArguments: Text;
        ToolResponse: Text;
        ToolResponseMessageJson: JsonObject;
        ToolResponseMessage: Text;
        i: Integer;
        AOAIOperationResponse: Codeunit "AOAI Operation Response";
    begin
        GetToolNameAndParamsAndCallId(ToolDefinition, FunctionName, FunctionArguments, ToolCallId);

        case
            FunctionName of
            'generate_new_numbers_series':
                ToolResponse := BuildGenerateNewNumbersSeriesPrompt(FunctionArguments);
            'modify_existing_numbers_series':
                ToolResponse := BuildModifyExistingNumbersSeriesPrompt(FunctionArguments);
            else
                Error('Function call not supported');
        end;

        if ToolResponse = '' then
            Error('Function call failed');

        // remove the tool message from the chat messages
        for i := 1 to AOAIChatMessages.GetTools().Count do
            AOAIChatMessages.DeleteTool(1); //TODO: when the tool is removed the index of the next tool is i-1, so the next tool should be removed with index 1


        // add the assistant response and function response to the messages
        // AOAIChatMessages.AddAssistantMessage(ToolDefinition);

        // adding function response to messages
        ToolResponseMessageJson.Add('tool_call_id', ToolCallId);
        ToolResponseMessageJson.Add('role', 'tool');
        ToolResponseMessageJson.Add('name', FunctionName);
        ToolResponseMessageJson.Add('content', ToolResponse);
        ToolResponseMessageJson.WriteTo(ToolResponseMessage);
        AOAIChatMessages.AddAssistantMessage(ToolResponseMessage);

        // call the API again to get the final response from the model
        AzureOpenAI.GenerateChatCompletion(AOAIChatMessages, AOAIChatCompletionParams, AOAIOperationResponse);
        if AOAIOperationResponse.IsSuccess() then
            exit(AOAIChatMessages.GetLastMessage())
        else
            Error(AOAIOperationResponse.GetError());
    end;

    local procedure BuildGenerateNewNumbersSeriesPrompt(var FunctionArguments: Text): Text
    var
        NewNoSeriesPrompt: TextBuilder;
    begin
        NewNoSeriesPrompt.AppendLine('Your task: Generate No. Series for the next entities: ');
        if CheckIfTablesSpecified(FunctionArguments) then
            ListOnlySpecifiedTables(NewNoSeriesPrompt, GetEntities(FunctionArguments))
        else
            ListAllTablesWithNumberSeries(NewNoSeriesPrompt);

        NewNoSeriesPrompt.AppendLine('Apply next patterns: ');
        if CheckIfPatternSpecified(FunctionArguments) then
            NewNoSeriesPrompt.AppendLine(GetPattern(FunctionArguments))
        else
            ListDefaultOrExistingPattern(NewNoSeriesPrompt);

        exit(NewNoSeriesPrompt.ToText());
    end;

    local procedure CheckIfTablesSpecified(var FunctionArguments: Text): Boolean
    begin
        exit(GetEntities(FunctionArguments).Count > 0);
    end;

    local procedure GetEntities(var FunctionArguments: Text): List of [Text]
    var
        Arguments: JsonObject;
        EntitiesToken: JsonToken;
        XpathLbl: Label '$.entities', Locked = true;
    begin
        if not Arguments.ReadFrom(FunctionArguments) then
            exit;

        if not Arguments.SelectToken(XpathLbl, EntitiesToken) then
            exit;

        exit(EntitiesToken.AsValue().AsText().Split());
    end;

    local procedure ListOnlySpecifiedTables(var NewNoSeriesPrompt: TextBuilder; Entities: List of [Text])
    begin
        //TODO: implement
        Error('Not implemented');
    end;

    local procedure ListAllTablesWithNumberSeries(var NewNoSeriesPrompt: TextBuilder)
    var
        TableMetadata: Record "Table Metadata";
    begin
        // Looping trhough all Setup tables
        TableMetadata.SetFilter(Name, '* Setup');
        TableMetadata.SetRange(ObsoleteState, TableMetadata.ObsoleteState::No); //TODO: Check if 'Pending' should be included
        TableMetadata.SetRange(TableType, TableMetadata.TableType::Normal);
        if TableMetadata.FindSet() then
            repeat
                ListAllNoSeriesFields(NewNoSeriesPrompt, TableMetadata);
            until TableMetadata.Next() = 0;
    end;

    local procedure ListAllNoSeriesFields(var NewNoSeriesPrompt: TextBuilder; var TableMetadata: Record "Table Metadata")
    var
        Field: Record "Field";
    begin
        Field.SetRange(TableNo, TableMetadata.ID);
        Field.SetFilter(ObsoleteState, '<>%1', Field.ObsoleteState::Removed);
        Field.SetRange(Type, Field.Type::Code);
        Field.SetRange(Len, 20);
        Field.SetFilter(FieldName, '*Nos.'); //TODO: Check if this is the correct filter
        if Field.FindSet() then
            repeat
                NewNoSeriesPrompt.AppendLine('TableId: ' + Format(TableMetadata.ID) + ', FieldId: ' + Format(Field."No.") + ', Name: ' + Field.FieldName);
            until Field.Next() = 0;
    end;

    local procedure CheckIfPatternSpecified(var FunctionArguments: Text): Boolean
    begin
        exit(GetPattern(FunctionArguments) <> '');
    end;

    local procedure GetPattern(var FunctionArguments: Text): Text
    var
        Arguments: JsonObject;
        PatternToken: JsonToken;
        XpathLbl: Label '$.pattern', Locked = true;
    begin
        if not Arguments.ReadFrom(FunctionArguments) then
            exit;

        if not Arguments.SelectToken(XpathLbl, PatternToken) then
            exit;

        exit(PatternToken.AsValue().AsText());
    end;


    local procedure ListDefaultOrExistingPattern(var NewNoSeriesPrompt: TextBuilder): Text
    begin
        if CheckIfNumberSeriesExists() then
            ListExistingPattern(NewNoSeriesPrompt)
        else
            ListDefaultPattern(NewNoSeriesPrompt);
    end;

    local procedure CheckIfNumberSeriesExists(): Boolean
    var
        NoSeries: Record "No. Series";
    begin
        exit(not NoSeries.IsEmpty);
    end;

    local procedure ListExistingPattern(var NewNoSeriesPrompt: TextBuilder)
    var
        NoSeries: Record "No. Series";
        NoSeriesManagement: Codeunit "No. Series";
        i: Integer;
    begin
        // show first 5 existing number series as example
        // TODO: Probably there is better way to show the existing number series, maybe by showing the most used ones, or the ones that are used in the same tables as the ones that are specified in the input
        if NoSeries.FindSet() then
            repeat
                NewNoSeriesPrompt.AppendLine('Code: ' + NoSeries.Code + ', Description: ' + NoSeries.Description + ', Last No.: ' + NoSeriesManagement.GetLastNoUsed(NoSeries.Code));
                if i > 5 then
                    break;
                i += 1;
            until NoSeries.Next() = 0;
    end;

    local procedure ListDefaultPattern(var NewNoSeriesPrompt: TextBuilder)
    begin
        // TODO: Probably there are better default patterns. These are taken from CRONUS USA, Inc. demo data
        NewNoSeriesPrompt.AppendLine('Code: CUST, Description: Customer, Last No.: C00010');
        NewNoSeriesPrompt.AppendLine('Code: GJNL-GEN, Description: General Journal, Last No.: G00001');
        NewNoSeriesPrompt.AppendLine('Code: P-CR, Description: Purchase Credit Memo, Last No.: 1001');
        NewNoSeriesPrompt.AppendLine('Code: P-CR+, Description: Posted Purchase Credit Memo, Last No.: 109001');
        NewNoSeriesPrompt.AppendLine('Code: S-ORD, Description: Sales Order, Last No.: S-ORD101009');
        NewNoSeriesPrompt.AppendLine('Code: SVC-INV+, Description: Posted Service Invoices, Last No.: PSVI000001');
    end;

    local procedure BuildModifyExistingNumbersSeriesPrompt(var FunctionCallParams: Text): Text
    begin
        Error('Not implemented');
    end;

    [TryFunction]
    local procedure CheckIfValidCompletion(var Completion: Text)
    var
        JsonArray: JsonArray;
    begin
        JsonArray.ReadFrom(Completion);
    end;

    local procedure SaveGenerationHistory(var NoSeriesProposal: Record "No. Series Proposal"; InputText: Text)
    begin
        NoSeriesProposal."No." += 1;
        NoSeriesProposal.SetInputText(InputText);
        NoSeriesProposal.Insert(true);
    end;

    // local procedure CreateNoSeries(var NoSeriesProposal: Record "No. Series Proposal"; var NoSeriesGenerated: Record "No. Series Proposal Line"; Completion: Text)
    // var
    //     JSONManagement: Codeunit "JSON Management";
    //     NoSeriesObj: Text;
    //     i: Integer;
    // begin
    //     JSONManagement.InitializeCollection(Completion);

    //     for i := 0 to JSONManagement.GetCollectionCount() - 1 do begin
    //         JSONManagement.GetObjectFromCollectionByIndex(NoSeriesObj, i);

    //         InsertNoSeriesGenerated(NoSeriesGenerated, NoSeriesObj, GenerationId.ID);
    //     end;
    // end;

    /// <summary>
    /// Get the endpoint from the Azure Key Vault.
    /// This is a temporary solution to get the endpoint. The endpoint should be retrieved from the Azure Key Vault.
    /// </summary>
    /// <returns></returns>
    local procedure GetEndpoint(): Text
    var
        NoSeriesCopilotSetup: Record "No. Series Copilot Setup";
    begin
        exit(NoSeriesCopilotSetup.GetEndpoint())
    end;

    /// <summary>
    /// Get the deployment from the Azure Key Vault.
    /// This is a temporary solution to get the deployment. The deployment should be retrieved from the Azure Key Vault.
    /// </summary>
    /// <returns></returns>
    local procedure GetDeployment(): Text
    var
        NoSeriesCopilotSetup: Record "No. Series Copilot Setup";
    begin
        exit(NoSeriesCopilotSetup.GetDeployment())
    end;

    /// <summary>
    /// Get the secret from the Azure Key Vault.
    /// This is a temporary solution to get the secret. The secret should be retrieved from the Azure Key Vault.
    /// </summary>
    /// <returns></returns>
    [NonDebuggable]
    local procedure GetSecret(): Text
    var
        NoSeriesCopilotSetup: Record "No. Series Copilot Setup";
    begin
        NoSeriesCopilotSetup.Get();
        exit(NoSeriesCopilotSetup.GetSecretKeyFromIsolatedStorage())
    end;

    local procedure MaxInputTokens(): Integer
    begin
        exit(MaxModelTokens() - MaxOutputTokens());
    end;

    local procedure MaxOutputTokens(): Integer
    begin
        exit(4096);
    end;

    local procedure MaxModelTokens(): Integer
    begin
        exit(8192); //gpt-4-0613
    end;

    procedure FeatureName(): Text
    begin
        exit('Number Series with AI');
    end;

}