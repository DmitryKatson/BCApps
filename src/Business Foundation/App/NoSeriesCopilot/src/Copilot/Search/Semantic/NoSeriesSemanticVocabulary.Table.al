// TODO: Uncomment the code below when semantic search is enabled and embedding model is available

// // ------------------------------------------------------------------------------------------------
// // Copyright (c) Microsoft Corporation. All rights reserved.
// // Licensed under the MIT License. See License.txt in the project root for license information.
// // ------------------------------------------------------------------------------------------------

// namespace Microsoft.Foundation.NoSeries;
// using System.Text;

// table 393 "No. Series Semantic Vocabulary"
// {
//     Caption = 'No. Series Semantic Vocabulary';
//     Access = Internal;
//     InherentEntitlements = X;
//     InherentPermissions = X;

//     fields
//     {
//         field(1; "Entry No."; Integer)
//         {
//             Caption = 'Entry No.';
//         }
//         field(2; Payload; Text[2048])
//         {
//             Caption = 'Payload';
//         }
//         field(12; Vector; Blob)
//         {
//             Caption = 'Vector';
//             Compressed = false;
//         }
//     }

//     keys
//     {
//         key(PK; "Entry No.")
//         {
//             Clustered = true;
//         }
//         key(Payload; Payload)
//         {

//         }
//     }

//     var
//         ModifyingTheNoSeriesSemanticVocabularyTableIsNotAllowedErr: Label 'Modifying the No. Series Semantic Vocabulary table is not allowed.';

//     trigger OnModify()
//     begin
//         Error(ModifyingTheNoSeriesSemanticVocabularyTableIsNotAllowedErr);
//     end;

//     internal procedure InsertRecord(Payload: Text)
//     var
//         NextEntryNo: Integer;
//     begin
//         NextEntryNo := GetNextNo();

//         Rec.Init();
//         Rec."Entry No." := NextEntryNo;
//         Rec.Payload := Payload;
//         Rec.Insert(false);
//     end;

//     local procedure GetNextNo(): Integer
//     begin
//         Rec.Reset();
//         if Rec.FindLast() then
//             exit(Rec."Entry No." + 1);
//         exit(1);
//     end;

//     internal procedure SaveVectorText(VectorText: Text)
//     var
//         OutStream: OutStream;
//         Base64Convert: Codeunit "Base64 Convert";
//         ConvertedText: Text;
//     begin
//         ConvertedText := Base64Convert.ToBase64(VectorText);
//         Clear(Rec.Vector);
//         Rec.Vector.CreateOutStream(OutStream);
//         OutStream.WriteText(ConvertedText);
//         Rec.Modify();
//     end;

//     internal procedure LoadVectorText() VectorText: Text
//     var
//         InStream: InStream;
//         Base64Convert: Codeunit "Base64 Convert";
//         ConvertedText: Text;
//     begin
//         Rec.CalcFields(Vector);
//         Rec.Vector.CreateInStream(InStream);
//         InStream.ReadText(ConvertedText);
//         VectorText := Base64Convert.FromBase64(ConvertedText);
//     end;
// }