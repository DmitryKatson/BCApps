/// <summary>
/// This is temporary table to store the endpoint and secret key for the number series copilot.
/// Should be removed once the number series copilot is fully integrated with the system.
/// Shoulbe replaced with the Azure Key Vault storage.
/// </summary>
table 9200 "No. Series Copilot Setup"
{
    Description = 'Number Series Copilot Setup';

    fields
    {
        field(1; "Code"; Code[20])
        {
            DataClassification = CustomerContent;
            Caption = 'Code';

        }

        field(2; Endpoint; Text[250])
        {
            DataClassification = CustomerContent;
            Caption = 'Endpoint';
        }

        field(3; Deployment; Text[250])
        {
            Caption = 'Deployment';
        }

        field(4; "Secret Key"; Guid)
        {
            DataClassification = CustomerContent;
            Caption = 'Secret';
        }

        field(5; "System Prompt"; Guid)
        {
            DataClassification = CustomerContent;
            Caption = 'System Prompt';
        }
        field(6; "Tools Definition"; Guid)
        {
            DataClassification = CustomerContent;
            Caption = 'Tools Definition';
        }

        field(10; "Tool 1 General Instr. Prompt"; Guid)
        {
            DataClassification = CustomerContent;
            Caption = 'Tool 1 General Instructions Prompt';
        }
        field(11; "Tool 1 Limitations Prompt"; Guid)
        {
            DataClassification = CustomerContent;
            Caption = 'Tool 1 Limitations Prompt';
        }
        field(12; "Tool 1 Code Guideline Prompt"; Guid)
        {
            DataClassification = CustomerContent;
            Caption = 'Tool 1 Series Code Guideline Prompt';
        }

        field(13; "Tool 1 Descr. Guideline Prompt"; Guid)
        {
            DataClassification = CustomerContent;
            Caption = 'Tool 1 Series Description Guideline Prompt';
        }

        field(14; "Tool 1 Number Guideline Prompt"; Guid)
        {
            DataClassification = CustomerContent;
            Caption = 'Tool 1 Series Numbering Guideline Prompt';
        }
        field(15; "Tool 1 Output Examples Prompt"; Guid)
        {
            DataClassification = CustomerContent;
            Caption = 'Tool 1 Output Examples Prompt';
        }

        field(16; "Tool 1 Output Format Prompt"; Guid)
        {
            DataClassification = CustomerContent;
            Caption = 'Tool 1 Output Format Prompt';
        }
    }

    keys
    {
        key(PK; Code)
        {
            Clustered = true;
        }
    }

    procedure GetEndpoint() Endpoint: Text[250]
    var
        Rec: Record "No. Series Copilot Setup";
    begin
        Rec.Get();
        Rec.TestField(Rec.Endpoint);
        exit(Rec.Endpoint);
    end;

    procedure GetDeployment() Deployment: Text[250]
    var
        Rec: Record "No. Series Copilot Setup";
    begin
        Rec.Get();
        Rec.TestField(Rec.Deployment);
        exit(Rec.Deployment);
    end;


    [NonDebuggable]
    procedure GetSecretKeyFromIsolatedStorage() SecretKey: Text
    begin
        if not IsNullGuid(Rec."Secret Key") then
            if not IsolatedStorage.Get(Rec."Secret Key", DataScope::Module, SecretKey) then;

        exit(SecretKey);
    end;

    [NonDebuggable]
    procedure SetSecretKeyToIsolatedStorage(SecretKey: Text)
    var
        NewSecretGuid: Guid;
    begin
        if not IsNullGuid(Rec."Secret Key") then
            if not IsolatedStorage.Delete(Rec."Secret Key", DataScope::Module) then;

        NewSecretGuid := CreateGuid();

        IsolatedStorage.Set(NewSecretGuid, SecretKey, DataScope::Module);

        Rec."Secret Key" := NewSecretGuid;
    end;

    [NonDebuggable]
    procedure GetSystemPromptFromIsolatedStorage() SystemPrompt: Text
    begin
        if not IsNullGuid(Rec."System Prompt") then
            if not IsolatedStorage.Get(Rec."System Prompt", DataScope::Module, SystemPrompt) then;

        exit(SystemPrompt);
    end;

    [NonDebuggable]
    procedure SetSystemPromptToIsolatedStorage(SystemPrompt: Text)
    var
        NewSystemPromptGuid: Guid;
    begin
        if not IsNullGuid(Rec."System Prompt") then
            if not IsolatedStorage.Delete(Rec."System Prompt", DataScope::Module) then;

        NewSystemPromptGuid := CreateGuid();

        IsolatedStorage.Set(NewSystemPromptGuid, SystemPrompt, DataScope::Module);

        Rec."System Prompt" := NewSystemPromptGuid;
    end;

    [NonDebuggable]
    procedure GetToolsDefinitionFromIsolatedStorage() FunctionsPrompt: Text
    begin
        if not IsNullGuid(Rec."Tools Definition") then
            if not IsolatedStorage.Get(Rec."Tools Definition", DataScope::Module, FunctionsPrompt) then;

        exit(FunctionsPrompt);
    end;

    [NonDebuggable]
    procedure SetToolsDefinitionToIsolatedStorage(FunctionsPrompt: Text)
    var
        NewFunctionsPromptGuid: Guid;
    begin
        if not IsNullGuid(Rec."Tools Definition") then
            if not IsolatedStorage.Delete(Rec."Tools Definition", DataScope::Module) then;

        NewFunctionsPromptGuid := CreateGuid();

        IsolatedStorage.Set(NewFunctionsPromptGuid, FunctionsPrompt, DataScope::Module);

        Rec."Tools Definition" := NewFunctionsPromptGuid;
    end;

    [NonDebuggable]
    procedure GetTool1GeneralInstructionsPromptFromIsolatedStorage() Tool1GeneralInstrPrompt: Text
    begin
        if not IsNullGuid(Rec."Tool 1 General Instr. Prompt") then
            if not IsolatedStorage.Get(Rec."Tool 1 General Instr. Prompt", DataScope::Module, Tool1GeneralInstrPrompt) then;

        exit(Tool1GeneralInstrPrompt);
    end;

    [NonDebuggable]
    procedure SetTool1GeneralInstructionsPromptToIsolatedStorage(Tool1GeneralInstrPrompt: Text)
    var
        NewTool1GeneralInstrPromptGuid: Guid;
    begin
        if not IsNullGuid(Rec."Tool 1 General Instr. Prompt") then
            if not IsolatedStorage.Delete(Rec."Tool 1 General Instr. Prompt", DataScope::Module) then;

        NewTool1GeneralInstrPromptGuid := CreateGuid();

        IsolatedStorage.Set(NewTool1GeneralInstrPromptGuid, Tool1GeneralInstrPrompt, DataScope::Module);

        Rec."Tool 1 General Instr. Prompt" := NewTool1GeneralInstrPromptGuid;
    end;

    [NonDebuggable]
    procedure GetTool1LimitationsPromptFromIsolatedStorage() Tool1LimitationsPrompt: Text
    begin
        if not IsNullGuid(Rec."Tool 1 Limitations Prompt") then
            if not IsolatedStorage.Get(Rec."Tool 1 Limitations Prompt", DataScope::Module, Tool1LimitationsPrompt) then;

        exit(Tool1LimitationsPrompt);
    end;

    [NonDebuggable]
    procedure SetTool1LimitationsPromptToIsolatedStorage(Tool1LimitationsPrompt: Text)
    var
        NewTool1LimitationsPromptGuid: Guid;
    begin
        if not IsNullGuid(Rec."Tool 1 Limitations Prompt") then
            if not IsolatedStorage.Delete(Rec."Tool 1 Limitations Prompt", DataScope::Module) then;

        NewTool1LimitationsPromptGuid := CreateGuid();

        IsolatedStorage.Set(NewTool1LimitationsPromptGuid, Tool1LimitationsPrompt, DataScope::Module);

        Rec."Tool 1 Limitations Prompt" := NewTool1LimitationsPromptGuid;
    end;

    [NonDebuggable]
    procedure GetTool1CodeGuidelinePromptFromIsolatedStorage() Tool1CodeGuidelinePrompt: Text
    begin
        if not IsNullGuid(Rec."Tool 1 Code Guideline Prompt") then
            if not IsolatedStorage.Get(Rec."Tool 1 Code Guideline Prompt", DataScope::Module, Tool1CodeGuidelinePrompt) then;

        exit(Tool1CodeGuidelinePrompt);
    end;

    [NonDebuggable]
    procedure SetTool1CodeGuidelinePromptToIsolatedStorage(Tool1CodeGuidelinePrompt: Text)
    var
        NewTool1CodeGuidelinePromptGuid: Guid;
    begin
        if not IsNullGuid(Rec."Tool 1 Code Guideline Prompt") then
            if not IsolatedStorage.Delete(Rec."Tool 1 Code Guideline Prompt", DataScope::Module) then;

        NewTool1CodeGuidelinePromptGuid := CreateGuid();

        IsolatedStorage.Set(NewTool1CodeGuidelinePromptGuid, Tool1CodeGuidelinePrompt, DataScope::Module);

        Rec."Tool 1 Code Guideline Prompt" := NewTool1CodeGuidelinePromptGuid;
    end;

    [NonDebuggable]
    procedure GetTool1DescrGuidelinePromptFromIsolatedStorage() Tool1DescrGuidelinePrompt: Text
    begin
        if not IsNullGuid(Rec."Tool 1 Descr. Guideline Prompt") then
            if not IsolatedStorage.Get(Rec."Tool 1 Descr. Guideline Prompt", DataScope::Module, Tool1DescrGuidelinePrompt) then;

        exit(Tool1DescrGuidelinePrompt);
    end;

    [NonDebuggable]
    procedure SetTool1DescrGuidelinePromptToIsolatedStorage(Tool1DescrGuidelinePrompt: Text)
    var
        NewTool1DescrGuidelinePromptGuid: Guid;
    begin
        if not IsNullGuid(Rec."Tool 1 Descr. Guideline Prompt") then
            if not IsolatedStorage.Delete(Rec."Tool 1 Descr. Guideline Prompt", DataScope::Module) then;

        NewTool1DescrGuidelinePromptGuid := CreateGuid();

        IsolatedStorage.Set(NewTool1DescrGuidelinePromptGuid, Tool1DescrGuidelinePrompt, DataScope::Module);

        Rec."Tool 1 Descr. Guideline Prompt" := NewTool1DescrGuidelinePromptGuid;
    end;

    [NonDebuggable]
    procedure GetTool1NumberGuidelinePromptFromIsolatedStorage() Tool1NumberGuidelinePrompt: Text
    begin
        if not IsNullGuid(Rec."Tool 1 Number Guideline Prompt") then
            if not IsolatedStorage.Get(Rec."Tool 1 Number Guideline Prompt", DataScope::Module, Tool1NumberGuidelinePrompt) then;

        exit(Tool1NumberGuidelinePrompt);
    end;

    [NonDebuggable]
    procedure SetTool1NumberGuidelinePromptToIsolatedStorage(Tool1NumberGuidelinePrompt: Text)
    var
        NewTool1NumberGuidelinePromptGuid: Guid;
    begin
        if not IsNullGuid(Rec."Tool 1 Number Guideline Prompt") then
            if not IsolatedStorage.Delete(Rec."Tool 1 Number Guideline Prompt", DataScope::Module) then;

        NewTool1NumberGuidelinePromptGuid := CreateGuid();

        IsolatedStorage.Set(NewTool1NumberGuidelinePromptGuid, Tool1NumberGuidelinePrompt, DataScope::Module);

        Rec."Tool 1 Number Guideline Prompt" := NewTool1NumberGuidelinePromptGuid;
    end;

    [NonDebuggable]
    procedure GetTool1OutputExamplesPromptFromIsolatedStorage() Tool1OutputExamplesPrompt: Text
    begin
        if not IsNullGuid(Rec."Tool 1 Output Examples Prompt") then
            if not IsolatedStorage.Get(Rec."Tool 1 Output Examples Prompt", DataScope::Module, Tool1OutputExamplesPrompt) then;

        exit(Tool1OutputExamplesPrompt);
    end;

    [NonDebuggable]
    procedure SetTool1OutputExamplesPromptToIsolatedStorage(Tool1OutputExamplesPrompt: Text)
    var
        NewTool1OutputExamplesPromptGuid: Guid;
    begin
        if not IsNullGuid(Rec."Tool 1 Output Examples Prompt") then
            if not IsolatedStorage.Delete(Rec."Tool 1 Output Examples Prompt", DataScope::Module) then;

        NewTool1OutputExamplesPromptGuid := CreateGuid();

        IsolatedStorage.Set(NewTool1OutputExamplesPromptGuid, Tool1OutputExamplesPrompt, DataScope::Module);

        Rec."Tool 1 Output Examples Prompt" := NewTool1OutputExamplesPromptGuid;
    end;

    [NonDebuggable]
    procedure GetTool1OutputFormatPromptFromIsolatedStorage() Tool1OutputFormatPrompt: Text
    begin
        if not IsNullGuid(Rec."Tool 1 Output Format Prompt") then
            if not IsolatedStorage.Get(Rec."Tool 1 Output Format Prompt", DataScope::Module, Tool1OutputFormatPrompt) then;

        exit(Tool1OutputFormatPrompt);
    end;

    [NonDebuggable]
    procedure SetTool1OutputFormatPromptToIsolatedStorage(Tool1OutputFormatPrompt: Text)
    var
        NewTool1OutputFormatPromptGuid: Guid;
    begin
        if not IsNullGuid(Rec."Tool 1 Output Format Prompt") then
            if not IsolatedStorage.Delete(Rec."Tool 1 Output Format Prompt", DataScope::Module) then;

        NewTool1OutputFormatPromptGuid := CreateGuid();

        IsolatedStorage.Set(NewTool1OutputFormatPromptGuid, Tool1OutputFormatPrompt, DataScope::Module);

        Rec."Tool 1 Output Format Prompt" := NewTool1OutputFormatPromptGuid;
    end;
}