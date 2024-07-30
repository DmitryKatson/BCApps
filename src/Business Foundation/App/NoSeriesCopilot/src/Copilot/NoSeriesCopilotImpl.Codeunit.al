// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------

namespace Microsoft.Foundation.NoSeries;

using System.Telemetry;
using System.Globalization;
using System.Azure.KeyVault;
using System.Environment;
using System.AI;
using System.Text.Json;

codeunit 324 "No. Series Copilot Impl."
{
    Access = Internal;

    var
        Telemetry: Codeunit Telemetry;
        IncorrectCompletionErr: Label 'Incorrect completion. The property %1 is empty', Comment = '%1 = property name';
        IncorrectCompletionNumberOfGeneratedNoSeriesErr: Label 'Incorrect completion. The number of generated number series is incorrect. Expected %1, but got %2', Comment = '%1 = Expected Number, %2 = Actual Number';
        TextLengthIsOverMaxLimitErr: Label 'The property %1 exceeds the maximum length of %2', Comment = '%1 = property name, %2 = maximum length';
        DateSpecificPlaceholderLbl: Label '{current_date}', Locked = true;
        TheResponseShouldBeAFunctionCallErr: Label 'The response should be a function call.';
        ChatCompletionResponseErr: Label 'Sorry, something went wrong. Please rephrase and try again.';
        GeneratingNoSeriesForLbl: Label 'Generating number series %1', Comment = '%1 = No. Series';
        FeatureNameLbl: Label 'Number Series with AI', Locked = true;
        TelemetryToolsSelectionPromptRetrievalErr: Label 'Unable to retrieve the prompt for No. Series Copilot Tools Selection from Azure Key Vault.', Locked = true;
        ToolLoadingErr: Label 'Unable to load the No. Series Copilot Tool. Please try again later.';

    procedure GetNoSeriesSuggestions()
    var
        FeatureTelemetry: Codeunit "Feature Telemetry";
        NoSeriesCopilotRegister: Codeunit "No. Series Copilot Register";
        AzureOpenAI: Codeunit "Azure OpenAI";
    begin
        NoSeriesCopilotRegister.RegisterCapability();
        if not AzureOpenAI.IsEnabled(Enum::"Copilot Capability"::"No. Series Copilot") then
            exit;

        FeatureTelemetry.LogUptake('0000LF4', FeatureName(), Enum::"Feature Uptake Status"::Discovered); //TODO: Update signal id

        Page.Run(Page::"No. Series Proposal");
    end;

    procedure Generate(var NoSeriesProposal: Record "No. Series Proposal"; var ResponseText: Text; var GeneratedNoSeries: Record "No. Series Proposal Line"; InputText: Text)
    var
        TokenCountImpl: Codeunit "AOAI Token";
        NotificationManager: Codeunit "No. Ser. Cop. Notific. Manager";
        SystemPromptTxt: SecretText;
        CompletePromptTokenCount: Integer;
        Completion: Text;
    begin
        Clear(ResponseText);
        SystemPromptTxt := GetToolsSelectionSystemPrompt();

        CompletePromptTokenCount := TokenCountImpl.GetGPT35TokenCount(SystemPromptTxt) + TokenCountImpl.GetGPT35TokenCount(InputText);
        if CompletePromptTokenCount <= MaxInputTokens() then begin
            Completion := GenerateNoSeries(SystemPromptTxt, InputText);
            if CheckIfCompletionMeetAllRequirements(Completion) then begin
                SaveGenerationHistory(NoSeriesProposal, InputText);
                CreateNoSeries(NoSeriesProposal, GeneratedNoSeries, Completion);
            end else
                ResponseText := Completion;
        end else
            NotificationManager.SendNotification(GetChatCompletionResponseErr());
    end;

    procedure ApplyProposedNoSeries(var GeneratedNoSeries: Record "No. Series Proposal Line")
    begin
        if GeneratedNoSeries.FindSet() then
            repeat
                InsertNoSeriesWithLines(GeneratedNoSeries);
                ApplyNoSeriesToSetup(GeneratedNoSeries);
            until GeneratedNoSeries.Next() = 0;
    end;

    local procedure InsertNoSeriesWithLines(var GeneratedNoSeries: Record "No. Series Proposal Line")
    begin
        InsertNoSeries(GeneratedNoSeries);
        InsertNoSeriesLine(GeneratedNoSeries);
    end;

    local procedure InsertNoSeries(var GeneratedNoSeries: Record "No. Series Proposal Line")
    var
        NoSeries: Record "No. Series";
    begin
        NoSeries.Init();
        NoSeries.Code := GeneratedNoSeries."Series Code";
        NoSeries.Description := GeneratedNoSeries.Description;
        NoSeries."Manual Nos." := true;
        NoSeries."Default Nos." := true;
        //TODO: Check if we need to add more fields here, like "Mask", "No. Series Type", "Reverse Sales VAT No. Series" etc.
        if not NoSeries.Insert(true) then
            NoSeries.Modify(true);
    end;

    local procedure InsertNoSeriesLine(var GeneratedNoSeries: Record "No. Series Proposal Line")
    var
        NoSeriesLine: Record "No. Series Line";
        Implementation: Enum "No. Series Implementation";
    begin
        NoSeriesLine.Init();
        NoSeriesLine."Series Code" := GeneratedNoSeries."Series Code";
        NoSeriesLine."Line No." := GetNoSeriesLineNo(GeneratedNoSeries."Series Code", GeneratedNoSeries."Is Next Year");
        NoSeriesLine.Validate("Starting Date", GeneratedNoSeries."Starting Date");
        NoSeriesLine.Validate("Starting No.", GeneratedNoSeries."Starting No.");
        NoSeriesLine.Validate("Ending No.", GeneratedNoSeries."Ending No.");
        if GeneratedNoSeries."Warning No." <> '' then
            NoSeriesLine.Validate("Warning No.", GeneratedNoSeries."Warning No.");
        NoSeriesLine.Validate("Increment-by No.", GeneratedNoSeries."Increment-by No.");
        NoSeriesLine.Validate(Implementation, Implementation::Normal);
        if not NoSeriesLine.Insert(true) then
            NoSeriesLine.Modify(true);
    end;

    local procedure GetNoSeriesLineNo(SeriesCode: Code[20]; NewLineNo: Boolean): Integer
    var
        NoSeriesLine: Record "No. Series Line";
        NoSeries: Codeunit "No. Series";
    begin
        if not NoSeries.GetNoSeriesLine(NoSeriesLine, SeriesCode, 0D, true) then
            exit(10000);

        if NewLineNo then
            exit(NoSeriesLine."Line No." + 10000);

        exit(NoSeriesLine."Line No.");
    end;

    local procedure ApplyNoSeriesToSetup(var GeneratedNoSeries: Record "No. Series Proposal Line")
    var
        RecRef: RecordRef;
        FieldRef: FieldRef;
    begin
        RecRef.Open(GeneratedNoSeries."Setup Table No.");
        if not RecRef.FindFirst() then
            exit;

        FieldRef := RecRef.Field(GeneratedNoSeries."Setup Field No.");
        FieldRef.Validate(GeneratedNoSeries."Series Code");
        RecRef.Modify(true);
    end;

    [NonDebuggable]
    local procedure GetToolsSelectionSystemPrompt() ToolsSelectionSystemPrompt: SecretText
    var
        AzureKeyVault: Codeunit "Azure Key Vault";
        ToolsSelectionPrompt: Text;
    begin
        if not AzureKeyVault.GetAzureKeyVaultSecret('NoSeriesCopilotToolsSelectionPrompt', ToolsSelectionPrompt) then begin
            Telemetry.LogMessage('', TelemetryToolsSelectionPromptRetrievalErr, Verbosity::Error, DataClassification::SystemMetadata);
            Error(ToolLoadingErr);
        end;

        ToolsSelectionSystemPrompt := ToolsSelectionPrompt.Replace(DateSpecificPlaceholderLbl, Format(Today(), 0, 4));
    end;

    local procedure GenerateNoSeries(SystemPromptTxt: SecretText; InputText: Text): Text
    var
        AzureOpenAI: Codeunit "Azure OpenAI";
        AOAIChatCompletionParams: Codeunit "AOAI Chat Completion Params";
        AOAIOperationResponse: Codeunit "AOAI Operation Response";
        AOAIChatMessages: Codeunit "AOAI Chat Messages";
        AddNoSeriesIntent: Codeunit "No. Series Cop. Add Intent";
        ChangeNoSeriesIntent: Codeunit "No. Series Cop. Change Intent";
        AOAIDeployments: Codeunit "AOAI Deployments";
        NextYearNoSeriesIntent: Codeunit "No. Series Cop. Nxt Yr. Intent";
        CompletionAnswerTxt: Text;
    begin
        if not AzureOpenAI.IsEnabled(Enum::"Copilot Capability"::"No. Series Copilot") then
            exit;

        AzureOpenAI.SetAuthorization(Enum::"AOAI Model Type"::"Chat Completions", AOAIDeployments.GetGPT35TurboLatest());
        AzureOpenAI.SetCopilotCapability(Enum::"Copilot Capability"::"No. Series Copilot");
        AOAIChatCompletionParams.SetMaxTokens(MaxOutputTokens());
        AOAIChatCompletionParams.SetTemperature(0);
        AOAIChatMessages.SetPrimarySystemMessage(SystemPromptTxt);
        AOAIChatMessages.AddUserMessage(InputText);

        AOAIChatMessages.AddTool(AddNoSeriesIntent);
        AOAIChatMessages.AddTool(ChangeNoSeriesIntent);
        AOAIChatMessages.AddTool(NextYearNoSeriesIntent);

        AzureOpenAI.GenerateChatCompletion(AOAIChatMessages, AOAIChatCompletionParams, AOAIOperationResponse);
        if not AOAIOperationResponse.IsSuccess() then
            Error(AOAIOperationResponse.GetError());

        CompletionAnswerTxt := AOAIChatMessages.GetLastMessage(); // the model can answer to rephrase the question, if the user input is not clear

        if AOAIOperationResponse.IsFunctionCall() then
            CompletionAnswerTxt := GenerateNoSeriesUsingToolResult(AzureOpenAI, InputText, AOAIOperationResponse);

        exit(CompletionAnswerTxt);
    end;

    [NonDebuggable]
    local procedure GenerateNoSeriesUsingToolResult(var AzureOpenAI: Codeunit "Azure OpenAI"; InputText: Text; var AOAIOperationResponse: Codeunit "AOAI Operation Response"): Text
    var
        AOAIChatCompletionParams: Codeunit "AOAI Chat Completion Params";
        AOAIChatMessages: Codeunit "AOAI Chat Messages";
        AOAIFunctionResponse: Codeunit "AOAI Function Response";
        NoSeriesCopToolsImpl: Codeunit "No. Series Cop. Tools Impl.";
        NoSeriesGenerateTool: Codeunit "No. Series Cop. Generate";
        SystemPrompt: Text;
        ToolResponse: Dictionary of [Text, Integer]; // tool response can be a list of strings, as the response can be too long and exceed the token limit. In this case each string would be a separate message, each of them should be called separately. The integer is the number of tables used in the prompt, so we can test if the LLM answer covers all tables
        GeneratedNoSeriesArray: Text;
        FinalResults: List of [Text]; // The final response will be the concatenation of all the LLM responses (final results).
        CurrentAICallNumber, TotalAICallsRequired : Integer;
        Progress: Dialog;
    begin
        AOAIFunctionResponse := AOAIOperationResponse.GetFunctionResponse();
        if not AOAIFunctionResponse.IsSuccess() then
            Error(AOAIFunctionResponse.GetError());

        ToolResponse := AOAIFunctionResponse.GetResult();
        TotalAICallsRequired := ToolResponse.Count();

        foreach SystemPrompt in ToolResponse.Keys() do begin
            Progress.Open(StrSubstNo(GeneratingNoSeriesForLbl, NoSeriesCopToolsImpl.ExtractAreaWithPrefix(SystemPrompt)));
            CurrentAICallNumber += 1;

            AOAIChatCompletionParams.SetTemperature(0);
            AOAIChatCompletionParams.SetMaxTokens(MaxOutputTokens());
            AOAIChatMessages.SetPrimarySystemMessage(SystemPrompt);
            AOAIChatMessages.AddUserMessage(InputText);
            AOAIChatMessages.AddTool(NoSeriesGenerateTool);
            AOAIChatMessages.SetToolChoice(NoSeriesGenerateTool.GetDefaultToolChoice());

            // call the API again to get the final response from the model
            if not GenerateAndReviewToolCompletionWithRetry(AzureOpenAI, AOAIChatMessages, AOAIChatCompletionParams, GeneratedNoSeriesArray, GetExpectedNoSeriesCount(ToolResponse, SystemPrompt)) then
                Error(GetLastErrorText());

            FinalResults.Add(GeneratedNoSeriesArray);

            if CurrentAICallNumber < TotalAICallsRequired then
                Sleep(1000); // sleep for 1000ms, as the model has tokens per minute rate limit
            Clear(AOAIChatMessages);
            Progress.Close();
        end;

        exit(ConcatenateToolResponse(FinalResults));
    end;

    [NonDebuggable]
    local procedure GetExpectedNoSeriesCount(ToolResponse: Dictionary of [Text, Integer]; Message: Text) ExpectedNoSeriesCount: Integer
    begin
        ToolResponse.Get(Message, ExpectedNoSeriesCount);
    end;


    local procedure GenerateAndReviewToolCompletionWithRetry(var AzureOpenAI: Codeunit "Azure OpenAI"; var AOAIChatMessages: Codeunit "AOAI Chat Messages"; var AOAIChatCompletionParams: Codeunit "AOAI Chat Completion Params"; var GeneratedNoSeriesArrayText: Text; ExpectedNoSeriesCount: Integer): Boolean
    var
        AOAIOperationResponse: Codeunit "AOAI Operation Response";
        AOAIFunctionResponse: Codeunit "AOAI Function Response";
        MaxAttempts: Integer;
        Attempt: Integer;
    begin
        MaxAttempts := 3;
        for Attempt := 1 to MaxAttempts do begin
            AzureOpenAI.GenerateChatCompletion(AOAIChatMessages, AOAIChatCompletionParams, AOAIOperationResponse);
            if not AOAIOperationResponse.IsSuccess() then
                Error(AOAIOperationResponse.GetError());

            if not AOAIOperationResponse.IsFunctionCall() then
                Error(TheResponseShouldBeAFunctionCallErr);

            AOAIFunctionResponse := AOAIOperationResponse.GetFunctionResponse();
            if not AOAIFunctionResponse.IsSuccess() then
                Error(AOAIFunctionResponse.GetError());

            GeneratedNoSeriesArrayText := AOAIFunctionResponse.GetResult();
            if CheckIfValidResult(GeneratedNoSeriesArrayText, AOAIFunctionResponse.GetFunctionName(), ExpectedNoSeriesCount) then
                exit(true);

            AOAIChatMessages.DeleteMessage(AOAIChatMessages.GetHistory().Count); // remove the last message with wrong assistant response, as we need to regenerate the completion
            Sleep(500);
        end;

        exit(false);
    end;

    local procedure CheckIfValidResult(GeneratedNoSeriesArrayText: Text; FunctionName: Text; ExpectedNoSeriesCount: Integer): Boolean
    var
        AddNoSeriesIntent: Codeunit "No. Series Cop. Add Intent";
    begin
        if not CheckIfCompletionMeetAllRequirements(GeneratedNoSeriesArrayText) then
            exit(false);

        if FunctionName = AddNoSeriesIntent.GetName() then
            exit(CheckIfExpectedNoSeriesCount(GeneratedNoSeriesArrayText, ExpectedNoSeriesCount));

        exit(true);
    end;

    [TryFunction]
    local procedure CheckIfExpectedNoSeriesCount(GeneratedNoSeriesArrayText: Text; ExpectedNoSeriesCount: Integer)
    var
        ResultJArray: JsonArray;
        ResultedAccuracy: Decimal;
    begin
        ResultJArray := ReadGeneratedNumberSeriesJArray(GeneratedNoSeriesArrayText);
        if ResultJArray.Count = ExpectedNoSeriesCount then
            exit;
        if ExpectedNoSeriesCount = 0 then
            exit;

        ResultedAccuracy := ResultJArray.Count / ExpectedNoSeriesCount;
        if ResultedAccuracy < MinimumAccuracy() then
            Error(IncorrectCompletionNumberOfGeneratedNoSeriesErr, ExpectedNoSeriesCount, ResultJArray.Count);
    end;

    local procedure ConcatenateToolResponse(var FinalResults: List of [Text]) ConcatenatedResponse: Text
    var
        Result: Text;
        ResultJArray: JsonArray;
        JsonTok: JsonToken;
        JsonArr: JsonArray;
        i: Integer;
    begin
        foreach Result in FinalResults do begin
            ResultJArray := ReadGeneratedNumberSeriesJArray(Result);
            for i := 0 to ResultJArray.Count - 1 do begin
                ResultJArray.Get(i, JsonTok);
                JsonArr.Add(JsonTok);
            end;
        end;

        JsonArr.WriteTo(ConcatenatedResponse);
    end;

    [TryFunction]
    local procedure CheckIfCompletionMeetAllRequirements(GeneratedNoSeriesArrayText: Text)
    var
        Json: Codeunit Json;
        NoSeriesArrText: Text;
        NoSeriesObj: Text;
        i: Integer;
    begin
        ReadGeneratedNumberSeriesJArray(GeneratedNoSeriesArrayText).WriteTo(NoSeriesArrText);
        Json.InitializeCollection(NoSeriesArrText);

        for i := 0 to Json.GetCollectionCount() - 1 do begin
            Json.GetObjectFromCollectionByIndex(i, NoSeriesObj);
            Json.InitializeObject(NoSeriesObj);
            CheckTextPropertyExistAndCheckIfNotEmpty('seriesCode', Json);
            CheckMaximumLengthOfPropertyValue('seriesCode', Json, 20);
            CheckTextPropertyExistAndCheckIfNotEmpty('description', Json);
            CheckTextPropertyExistAndCheckIfNotEmpty('startingNo', Json);
            CheckMaximumLengthOfPropertyValue('startingNo', Json, 20);
            CheckTextPropertyExistAndCheckIfNotEmpty('endingNo', Json);
            CheckMaximumLengthOfPropertyValue('endingNo', Json, 20);
            CheckTextPropertyExistAndCheckIfNotEmpty('warningNo', Json);
            CheckMaximumLengthOfPropertyValue('warningNo', Json, 20);
            CheckIntegerPropertyExistAndCheckIfNotEmpty('incrementByNo', Json);
            CheckIntegerPropertyExistAndCheckIfNotEmpty('tableId', Json);
            CheckIntegerPropertyExistAndCheckIfNotEmpty('fieldId', Json);
        end;
    end;

    local procedure CheckTextPropertyExistAndCheckIfNotEmpty(propertyName: Text; var Json: Codeunit Json)
    var
        value: Text;
    begin
        Json.GetStringPropertyValueByName(propertyName, value);
        if value = '' then
            Error(IncorrectCompletionErr, propertyName);
    end;

    local procedure CheckIntegerPropertyExistAndCheckIfNotEmpty(propertyName: Text; var Json: Codeunit Json)
    var
        PropertyValue: Integer;
    begin
        Json.GetIntegerPropertyValueFromJObjectByName(propertyName, PropertyValue);
        if PropertyValue = 0 then
            Error(IncorrectCompletionErr, propertyName);
    end;

    local procedure CheckMaximumLengthOfPropertyValue(propertyName: Text; var Json: Codeunit Json; maxLength: Integer)
    var
        value: Text;
    begin
        Json.GetStringPropertyValueByName(propertyName, value);
        if StrLen(value) > maxLength then
            Error(TextLengthIsOverMaxLimitErr, propertyName, maxLength);
    end;

    local procedure ReadGeneratedNumberSeriesJArray(Completion: Text) NoSeriesJArray: JsonArray
    begin
        NoSeriesJArray.ReadFrom(Completion);
        exit(NoSeriesJArray);
    end;

    local procedure SaveGenerationHistory(var NoSeriesProposal: Record "No. Series Proposal"; InputText: Text)
    begin
        NoSeriesProposal.Init();
        NoSeriesProposal."No." := NoSeriesProposal.Count + 1;
        NoSeriesProposal.SetInputText(InputText);
        NoSeriesProposal.Insert(true);
    end;

    local procedure CreateNoSeries(var NoSeriesProposal: Record "No. Series Proposal"; var GeneratedNoSeries: Record "No. Series Proposal Line"; Completion: Text)
    var
        Json: Codeunit Json;
        NoSeriesArrText: Text;
        NoSeriesObj: Text;
        i: Integer;
    begin
        ReadGeneratedNumberSeriesJArray(Completion).WriteTo(NoSeriesArrText);
        ReAssembleDuplicates(NoSeriesArrText);

        Json.InitializeCollection(NoSeriesArrText);

        for i := 0 to Json.GetCollectionCount() - 1 do begin
            Json.GetObjectFromCollectionByIndex(i, NoSeriesObj);

            InsertGeneratedNoSeries(GeneratedNoSeries, NoSeriesObj, NoSeriesProposal."No.");
        end;
    end;

    local procedure ReAssembleDuplicates(var NoSeriesArrText: Text)
    var
        Json: Codeunit Json;
        i: Integer;
        NoSeriesObj: Text;
        NoSeriesCodes: List of [Text];
        NoSeriesCode: Text;
    begin
        Json.InitializeCollection(NoSeriesArrText);

        for i := 0 to Json.GetCollectionCount() - 1 do begin
            Json.GetObjectFromCollectionByIndex(i, NoSeriesObj);
            Json.InitializeObject(NoSeriesObj);
            Json.GetStringPropertyValueByName('seriesCode', NoSeriesCode);
            if NoSeriesCodes.Contains(NoSeriesCode) then begin
                Json.ReplaceOrAddJPropertyInJObject('seriesCode', GenerateNewSeriesCodeValue(NoSeriesCodes, NoSeriesCode));
                NoSeriesObj := Json.GetObjectAsText();
                Json.ReplaceJObjectInCollection(i, NoSeriesObj);
            end;
            NoSeriesCodes.Add(NoSeriesCode);
        end;

        NoSeriesArrText := Json.GetCollectionAsText()
    end;

    local procedure GenerateNewSeriesCodeValue(var NoSeriesCodes: List of [Text]; var NoSeriesCode: Text): Text
    var
        NewNoSeriesCode: Text;
    begin
        repeat
            NewNoSeriesCode := CopyStr(NoSeriesCode, 1, 18) + '-' + RandomCharacter();
        until not NoSeriesCodes.Contains(NewNoSeriesCode);

        NoSeriesCode := NewNoSeriesCode;
        exit(NewNoSeriesCode);
    end;

    local procedure RandomCharacter(): Char
    begin
        exit(RandIntInRange(33, 126)); // ASCII: ! (33) to ~ (126)
    end;

    local procedure RandIntInRange(MinInt: Integer; MaxInt: Integer): Integer
    begin
        exit(MinInt - 1 + Random(MaxInt - MinInt + 1));
    end;


    local procedure InsertGeneratedNoSeries(var GeneratedNoSeries: Record "No. Series Proposal Line"; NoSeriesObj: Text; ProposalNo: Integer)
    var
        Json: Codeunit Json;
        RecRef: RecordRef;
    begin
        Json.InitializeObject(NoSeriesObj);

        RecRef.GetTable(GeneratedNoSeries);
        RecRef.Init();
        SetProposalNo(RecRef, ProposalNo, GeneratedNoSeries.FieldNo("Proposal No."));
        Json.GetValueAndSetToRecFieldNo(RecRef, 'seriesCode', GeneratedNoSeries.FieldNo("Series Code"));
        Json.GetValueAndSetToRecFieldNo(RecRef, 'description', GeneratedNoSeries.FieldNo(Description));
        Json.GetValueAndSetToRecFieldNo(RecRef, 'startingNo', GeneratedNoSeries.FieldNo("Starting No."));
        Json.GetValueAndSetToRecFieldNo(RecRef, 'endingNo', GeneratedNoSeries.FieldNo("Ending No."));
        Json.GetValueAndSetToRecFieldNo(RecRef, 'warningNo', GeneratedNoSeries.FieldNo("Warning No."));
        Json.GetValueAndSetToRecFieldNo(RecRef, 'incrementByNo', GeneratedNoSeries.FieldNo("Increment-by No."));
        Json.GetValueAndSetToRecFieldNo(RecRef, 'tableId', GeneratedNoSeries.FieldNo("Setup Table No."));
        Json.GetValueAndSetToRecFieldNo(RecRef, 'fieldId', GeneratedNoSeries.FieldNo("Setup Field No."));
        Json.GetValueAndSetToRecFieldNo(RecRef, 'nextYear', GeneratedNoSeries.FieldNo("Is Next Year"));
        RecRef.Insert(true);

        ValidateGeneratedNoSeries(RecRef);
    end;

    local procedure ValidateGeneratedNoSeries(var RecRef: RecordRef)
    var
        GeneratedNoSeries: Record "No. Series Proposal Line";
    begin
        ValidateRecFieldNo(RecRef, GeneratedNoSeries.FieldNo("Is Next Year"));
        RecRef.Modify(true);
    end;

    local procedure ValidateRecFieldNo(var RecRef: RecordRef; FieldNo: Integer)
    var
        FieldRef: FieldRef;
    begin
        FieldRef := RecRef.Field(FieldNo);
        FieldRef.Validate();
    end;

    local procedure SetProposalNo(var RecRef: RecordRef; GenerationId: Integer; FieldNo: Integer)
    var
        FieldRef: FieldRef;
    begin
        FieldRef := RecRef.Field(FieldNo);
        FieldRef.Value(GenerationId);
    end;

    local procedure MinimumAccuracy(): Decimal
    begin
        exit(0.9);
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
        exit(16385); //gpt-3.5-turbo-latest
    end;

    procedure IsCopilotVisible(): Boolean
    var
        EnvironmentInformation: Codeunit "Environment Information";
    begin
        if not EnvironmentInformation.IsSaaSInfrastructure() then
            exit(false);

        if not IsSupportedLanguage() then
            exit(false);

        exit(true);
    end;

    local procedure IsSupportedLanguage(): Boolean
    var
        LanguageSelection: Record "Language Selection";
        UserSessionSettings: SessionSettings;
    begin
        UserSessionSettings.Init();
        LanguageSelection.SetLoadFields("Language Tag");
        LanguageSelection.SetRange("Language ID", UserSessionSettings.LanguageId());
        if LanguageSelection.FindFirst() then
            if LanguageSelection."Language Tag".StartsWith('pt-') then
                exit(false);
        exit(true);
    end;

    procedure GetChatCompletionResponseErr(): Text
    begin
        exit(ChatCompletionResponseErr);
    end;

    procedure FeatureName(): Text
    begin
        exit(FeatureNameLbl);
    end;
}
