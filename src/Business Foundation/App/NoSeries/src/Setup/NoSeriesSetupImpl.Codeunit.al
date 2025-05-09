// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------

namespace Microsoft.Foundation.NoSeries;

codeunit 305 "No. Series - Setup Impl."
{
    Access = Internal;
    InherentEntitlements = X;
    InherentPermissions = X;

    var
        NumberFormatErr: Label 'The number format in %1 must be the same as the number format in %2.', Comment = '%1=No. Series Code,%2=No. Series Code';
        UnIncrementableStringErr: Label 'The value in the %1 field must have a number so that we can assign the next number in the series.', Comment = '%1 = New Field Name';
        NumberLengthErr: Label 'The number %1 cannot be extended to more than 20 characters.', Comment = '%1=No.';
        CodeFieldChangedErr: Label 'The filter on %1 was altered by an event subscriber. This is a programming error. Please contact your partner to resolve the issue.\Original %1: %2\Modified Filter: %3', Comment = '%1=NoSeriesLine.FieldCaption("Series Code") %2=Original filter Value of NoSeriesLine."Series Code" %3=New filter Value of NoSeriesLine."Series Code"';

    procedure SetImplementation(var NoSeries: Record "No. Series"; Implementation: Enum "No. Series Implementation")
    var
        NoSeriesLine: Record "No. Series Line";
    begin
        NoSeriesLine.SetRange("Series Code", NoSeries.Code);
        NoSeriesLine.SetRange(Open, true);
        NoSeriesLine.ModifyAll(Implementation, Implementation, true);
    end;

    procedure DrillDown(NoSeries: Record "No. Series")
    var
        NoSeriesLine: Record "No. Series Line";
    begin
        SelectCurrentNoSeriesLine(NoSeries, NoSeriesLine, true);
        Page.RunModal(0, NoSeriesLine);
    end;

    procedure UpdateLine(var NoSeriesRec: Record "No. Series"; var StartDate: Date; var StartNo: Code[20]; var EndNo: Code[20]; var LastNoUsed: Code[20]; var WarningNo: Code[20]; var IncrementByNo: Integer; var LastDateUsed: Date; var Implementation: Enum "No. Series Implementation")
    var
        NoSeriesLine: Record "No. Series Line";
        NoSeries: Codeunit "No. Series";
    begin
        SelectCurrentNoSeriesLine(NoSeriesRec, NoSeriesLine, false);

        StartDate := NoSeriesLine."Starting Date";
        StartNo := NoSeriesLine."Starting No.";
        EndNo := NoSeriesLine."Ending No.";
        LastNoUsed := NoSeries.GetLastNoUsed(NoSeriesLine."Series Code");
        WarningNo := NoSeriesLine."Warning No.";
        IncrementByNo := NoSeriesLine."Increment-by No.";
        LastDateUsed := NoSeriesLine."Last Date Used";
        Implementation := NoSeriesLine.Implementation;
    end;

    procedure ShowNoSeriesWithWarningsOnly(var NoSeries: Record "No. Series")
    var
        NoSeriesLine: Record "No. Series Line";
        NoSeriesCodeunit: Codeunit "No. Series";
        LastNoUsedForLine: Code[20];
    begin
        if NoSeries.FindSet() then
            repeat
                NoSeriesLine.SetRange("Series Code", NoSeries.Code);
                if NoSeriesLine.FindSet() then
                    repeat
                        if (NoSeriesLine."Warning No." <> '') and NoSeriesLine.Open then begin
                            LastNoUsedForLine := NoSeriesCodeunit.GetLastNoUsed(NoSeriesLine);
                            if (LastNoUsedForLine <> '') and (LastNoUsedForLine >= NoSeriesLine."Warning No.") then begin
                                NoSeries.Mark(true);
                                break;
                            end;
                        end;
                    until NoSeriesLine.Next() = 0
                else
                    NoSeries.Mark(true);
            until NoSeries.Next() = 0;
        NoSeries.MarkedOnly(true);
    end;

    procedure SelectCurrentNoSeriesLine(NoSeriesRec: Record "No. Series"; var NoSeriesLine: Record "No. Series Line"; ResetForDrillDown: Boolean) LineFound: Boolean
    var
        NoSeries: Codeunit "No. Series";
    begin
        NoSeriesLine.Reset();
        SetNoSeriesLineFilters(NoSeriesLine, NoSeriesRec.Code, WorkDate());
        if NoSeriesLine.FindLast() then begin
            NoSeriesLine.SetRange("Starting Date", NoSeriesLine."Starting Date");
            NoSeriesLine.SetRange(Open, true);
        end;

        if not NoSeriesLine.FindLast() then begin
            NoSeriesLine.Reset();
            NoSeriesLine.SetRange("Series Code", NoSeriesRec.Code);
        end;

        if not NoSeriesLine.FindFirst() then begin
            NoSeriesLine.Init();
            NoSeriesLine."Series Code" := NoSeriesRec.Code;
            LineFound := false;
        end else
            LineFound := true;

        if ResetForDrillDown then begin
            NoSeriesLine.SetRange("Starting Date");
            NoSeriesLine.SetRange(Open);
        end;

        NoSeries.OnAfterSetNoSeriesCurrentLineFilters(NoSeriesRec, NoSeriesLine, ResetForDrillDown);
    end;

    procedure MayProduceGaps(NoSeriesLine: Record "No. Series Line"): Boolean
    var
        NoSeriesSingle: Interface "No. Series - Single";
    begin
        NoSeriesSingle := NoSeriesLine.Implementation;
        exit(NoSeriesSingle.MayProduceGaps());
    end;

    procedure SetNoSeriesLineFilters(var NoSeriesLine: Record "No. Series Line"; NoSeriesCode: Code[20]; StartingDate: Date)
    var
        NoSeriesLine2: Record "No. Series Line";
        NoSeries: Codeunit "No. Series";
        PreEventFilter, PostEventFilter : Text;
    begin
        NoSeriesLine2.SetCurrentKey("Series Code", "Starting Date");
        NoSeriesLine2.SetRange("Starting Date", 0D, StartingDate);
        NoSeriesLine2.SetRange("Series Code", NoSeriesCode);
        PreEventFilter := NoSeriesLine2.GetFilter("Series Code");
        NoSeries.OnSetNoSeriesLineFilters(NoSeriesLine2);
        PostEventFilter := NoSeriesLine2.GetFilter("Series Code");
        if PreEventFilter <> PostEventFilter then
            Error(CodeFieldChangedErr, NoSeriesLine2.FieldCaption("Series Code"), PreEventFilter, PostEventFilter);

        NoSeriesLine.SetCurrentKey("Series Code", "Starting Date");
        NoSeriesLine.CopyFilters(NoSeriesLine2);
    end;

    procedure CalculateOpen(NoSeriesLine: Record "No. Series Line"): Boolean
    var
        NoSeries: Codeunit "No. Series";
        LastNoUsed, NextNo : Code[20];
    begin
        if NoSeriesLine."Ending No." = '' then
            exit(true);

        LastNoUsed := NoSeries.GetLastNoUsed(NoSeriesLine);

        if LastNoUsed = '' then
            exit(true);

        if LastNoUsed >= NoSeriesLine."Ending No." then
            exit(false);

        if StrLen(LastNoUsed) > StrLen(NoSeriesLine."Ending No.") then
            exit(false);

        if NoSeriesLine."Increment-by No." <> 1 then begin
            NextNo := IncStr(LastNoUsed, NoSeriesLine."Increment-by No.");
            if NextNo > NoSeriesLine."Ending No." then
                exit(false);
            if StrLen(NextNo) > StrLen(NoSeriesLine."Ending No.") then
                exit(false);
        end;
        exit(true);
    end;

    procedure ValidateDefaultNos(var NoSeries: Record "No. Series"; xRecNoSeries: Record "No. Series")
    begin
            if (NoSeries."Default Nos." = false) and (xRecNoSeries."Default Nos." <> NoSeries."Default Nos.") and (NoSeries."Manual Nos." = false) then
                NoSeries.Validate("Manual Nos.", true);
    end;

    procedure ValidateManualNos(var NoSeries: Record "No. Series"; xRecNoSeries: Record "No. Series")
    begin
#pragma warning restore AL0432
            if (NoSeries."Manual Nos." = false) and (xRecNoSeries."Manual Nos." <> NoSeries."Manual Nos.") and (NoSeries."Default Nos." = false) then
                NoSeries.Validate("Default Nos.", true);
    end;

#if not CLEAN27
    procedure IncrementNoText(No: Code[20]; Increment: Integer): Code[20]
    var
        BigIntNo: BigInteger;
        BigIntIncByNo: BigInteger;
        StartPos: Integer;
        EndPos: Integer;
        NewNo: Code[20];
    begin
        GetIntegerPos(No, StartPos, EndPos);
        Evaluate(BigIntNo, CopyStr(No, StartPos, EndPos - StartPos + 1));
        BigIntIncByNo := Increment;
        NewNo := CopyStr(Format(BigIntNo + BigIntIncByNo, 0, 1), 1, MaxStrLen(NewNo));
        ReplaceNoText(No, NewNo, 0, StartPos, EndPos);
        exit(No);
    end;
#endif

    procedure UpdateNoSeriesLine(var NoSeriesLine: Record "No. Series Line"; NewNo: Code[20]; NewFieldCaption: Text[100])
    var
        NoSeriesLine2: Record "No. Series Line";
        NoSeriesErrorsImpl: Codeunit "No. Series - Errors Impl.";
        Length: Integer;
    begin
        if NewNo <> '' then begin
            if IncStr(NewNo) = '' then
                NoSeriesErrorsImpl.Throw(StrSubstNo(UnIncrementableStringErr, NewFieldCaption), NoSeriesLine, NoSeriesErrorsImpl.OpenNoSeriesLinesAction());
            NoSeriesLine2 := NoSeriesLine;
            if NewNo = GetNoText(NewNo) then
                Length := 0
            else begin
                Length := StrLen(GetNoText(NewNo));
                UpdateLength(NoSeriesLine."Starting No.", Length);
                UpdateLength(NoSeriesLine."Ending No.", Length);
                UpdateLength(NoSeriesLine."Last No. Used", Length);
                UpdateLength(NoSeriesLine."Warning No.", Length);
            end;
            UpdateNo(NoSeriesLine."Starting No.", NewNo, Length);
            UpdateNo(NoSeriesLine."Ending No.", NewNo, Length);
            UpdateNo(NoSeriesLine."Last No. Used", NewNo, Length);
            UpdateNo(NoSeriesLine."Warning No.", NewNo, Length);
            if (NewFieldCaption <> NoSeriesLine.FieldCaption("Last No. Used")) and
               (NoSeriesLine."Last No. Used" <> NoSeriesLine2."Last No. Used")
            then
                NoSeriesErrorsImpl.Throw(StrSubstNo(NumberFormatErr, NewFieldCaption, NoSeriesLine.FieldCaption("Last No. Used")), NoSeriesLine, NoSeriesErrorsImpl.OpenNoSeriesLinesAction());
        end;
    end;

    local procedure GetNoText(No: Code[20]): Code[20]
    var
        StartPos: Integer;
        EndPos: Integer;
    begin
        GetIntegerPos(No, StartPos, EndPos);
        if StartPos <> 0 then
            exit(CopyStr(CopyStr(No, StartPos, EndPos - StartPos + 1), 1, 20));
    end;

    local procedure GetIntegerPos(No: Code[20]; var StartPos: Integer; var EndPos: Integer)
    var
        IsDigit: Boolean;
        i: Integer;
    begin
        StartPos := 0;
        EndPos := 0;
        if No <> '' then begin
            i := StrLen(No);
            repeat
                IsDigit := No[i] in ['0' .. '9'];
                if IsDigit then begin
                    if EndPos = 0 then
                        EndPos := i;
                    StartPos := i;
                end;
                i := i - 1;
            until (i = 0) or (StartPos <> 0) and not IsDigit;
        end;
    end;

    local procedure UpdateLength(No: Code[20]; var MaxLength: Integer)
    var
        Length: Integer;
    begin
        if No <> '' then begin
            Length := StrLen(DelChr(GetNoText(No), '<', '0'));
            if Length > MaxLength then
                MaxLength := Length;
        end;
    end;

    local procedure UpdateNo(var No: Code[20]; NewNo: Code[20]; Length: Integer)
    var
        StartPos: Integer;
        EndPos: Integer;
        TempNo: Code[20];
    begin
        if No <> '' then
            if Length <> 0 then begin
                No := DelChr(GetNoText(No), '<', '0');
                TempNo := No;
                No := NewNo;
                NewNo := TempNo;
                GetIntegerPos(No, StartPos, EndPos);
                ReplaceNoText(No, NewNo, Length, StartPos, EndPos);
            end;
    end;

    local procedure ReplaceNoText(var No: Code[20]; NewNo: Code[20]; FixedLength: Integer; StartPos: Integer; EndPos: Integer)
    var
        StartNo: Code[20];
        EndNo: Code[20];
        ZeroNo: Code[20];
        NewLength: Integer;
        OldLength: Integer;
    begin
        if StartPos > 1 then
            StartNo := CopyStr(CopyStr(No, 1, StartPos - 1), 1, MaxStrLen(StartNo));
        if EndPos < StrLen(No) then
            EndNo := CopyStr(CopyStr(No, EndPos + 1), 1, MaxStrLen(EndNo));
        NewLength := StrLen(NewNo);
        OldLength := EndPos - StartPos + 1;
        if FixedLength > OldLength then
            OldLength := FixedLength;
        if OldLength > NewLength then
            ZeroNo := CopyStr(PadStr('', OldLength - NewLength, '0'), 1, MaxStrLen(ZeroNo));
        if StrLen(StartNo) + StrLen(ZeroNo) + StrLen(NewNo) + StrLen(EndNo) > 20 then
            Error(NumberLengthErr, No);
        No := CopyStr(StartNo + ZeroNo + NewNo + EndNo, 1, MaxStrLen(No));
    end;

    procedure DeleteNoSeries(var NoSeries: Record "No. Series")
    var
        NoSeriesLine: Record "No. Series Line";
        NoSeriesRelationship: Record "No. Series Relationship";
    begin
        NoSeriesLine.SetRange("Series Code", NoSeries.Code);
        NoSeriesLine.DeleteAll();


        NoSeriesRelationship.SetRange(Code, NoSeries.Code);
        NoSeriesRelationship.DeleteAll();
        NoSeriesRelationship.SetRange(Code);

        NoSeriesRelationship.SetRange("Series Code", NoSeries.Code);
        NoSeriesRelationship.DeleteAll();
        NoSeriesRelationship.SetRange("Series Code");
    end;

    [EventSubscriber(ObjectType::Table, Database::"No. Series Line", 'OnAfterDeleteEvent', '', false, false)]
    local procedure OnDeleteNoSeriesLine(var Rec: Record "No. Series Line"; RunTrigger: Boolean)
    begin
        if Rec.IsTemporary() then
            exit;

        if Rec."Sequence Name" <> '' then
            if NumberSequence.Exists(Rec."Sequence Name") then
                NumberSequence.Delete(Rec."Sequence Name");
    end;
}