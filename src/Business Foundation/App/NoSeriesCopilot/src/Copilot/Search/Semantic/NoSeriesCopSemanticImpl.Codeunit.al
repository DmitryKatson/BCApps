// TODO: Uncomment the code below when semantic search is enabled and embedding model is available

// // ------------------------------------------------------------------------------------------------
// // Copyright (c) Microsoft Corporation. All rights reserved.
// // Licensed under the MIT License. See License.txt in the project root for license information.
// // ------------------------------------------------------------------------------------------------

// namespace Microsoft.Foundation.NoSeries;
// using System.AI;
// using System.Text;
// using System.Utilities;

// codeunit 348 "No. Series Cop. Semantic Impl."
// {
//     Access = Internal;

//     var
//         NoSeriesSemanticVocabularyBuffer: Record "No. Series Semantic Vocabulary" temporary;

//     procedure IsRelevant(FirstString: Text; SecondString: Text): Boolean
//     var
//         Score: Decimal;
//     begin
//         Score := Round(CalculateSemanticNearness(FirstString, SecondString), 0.01, '>');
//         exit(Score >= RequiredNearness());
//     end;

//     local procedure CalculateSemanticNearness(FirstString: Text; SecondString: Text): Decimal
//     var
//         FirstStringVector: List of [Decimal];
//         SecondStringVector: List of [Decimal];
//     begin
//         if (FirstString = '') or (SecondString = '') then
//             exit(0);

//         FirstStringVector := GetVectorFromText(FirstString);
//         SecondStringVector := GetVectorFromText(SecondString);
//         exit(CalculateCosineSimilarityFromNormalizedVectors(FirstStringVector, SecondStringVector));
//     end;

//     local procedure GetVectorFromText(Input: Text): List of [Decimal]
//     var
//         VectorsArray: JsonArray;
//         NoSeriesSemanticVocabulary: Record "No. Series Semantic Vocabulary";
//     begin
//         Input := PrepareTextForEmbeddings(Input);

//         if GetEmbeddingsFromVocabulary(Input, VectorsArray, NoSeriesSemanticVocabulary) then
//             exit(ConvertJsonArrayToListOfDecimals(VectorsArray));

//         if GetEmbeddingsFromVocabulary(Input, VectorsArray, NoSeriesSemanticVocabularyBuffer) then
//             exit(ConvertJsonArrayToListOfDecimals(VectorsArray));

//         VectorsArray := GetAzureOpenAIEmbeddings(Input);
//         SaveEmbeddingsToVocabulary(Input, VectorsArray, NoSeriesSemanticVocabularyBuffer);
//         exit(ConvertJsonArrayToListOfDecimals(VectorsArray));
//     end;

//     local procedure GetEmbeddingsFromVocabulary(Input: Text; var EmbeddingsArray: JsonArray; var NoSeriesSemanticVocabulary: Record "No. Series Semantic Vocabulary"): Boolean
//     begin
//         NoSeriesSemanticVocabulary.SetCurrentKey(Payload);
//         NoSeriesSemanticVocabulary.SetLoadFields(Payload);
//         NoSeriesSemanticVocabulary.SetRange(Payload, Input);
//         if not NoSeriesSemanticVocabulary.FindFirst() then
//             exit(false);

//         EmbeddingsArray.ReadFrom(NoSeriesSemanticVocabulary.LoadVectorText());
//         exit(true);
//     end;

//     local procedure PrepareTextForEmbeddings(Input: Text): Text
//     begin
//         exit(Input.ToLower().TrimStart().TrimEnd());
//     end;

//     local procedure SaveEmbeddingsToVocabulary(Input: Text; EmbeddingsArray: JsonArray; var NoSeriesSemanticVocabulary: Record "No. Series Semantic Vocabulary")
//     var
//         VectorText: Text;
//     begin
//         EmbeddingsArray.WriteTo(VectorText);

//         NoSeriesSemanticVocabulary.InsertRecord(Input);
//         NoSeriesSemanticVocabulary.SaveVectorText(VectorText);
//     end;

//     internal procedure UpdateSemanticVocabulary()
//     var
//         NoSeriesSemanticVocabulary: Record "No. Series Semantic Vocabulary";
//     begin
//         NoSeriesSemanticVocabularyBuffer.Reset();
//         if NoSeriesSemanticVocabularyBuffer.FindSet() then
//             repeat
//                 NoSeriesSemanticVocabulary.InsertRecord(NoSeriesSemanticVocabularyBuffer.Payload);
//                 NoSeriesSemanticVocabulary.SaveVectorText(NoSeriesSemanticVocabularyBuffer.LoadVectorText());
//             until NoSeriesSemanticVocabularyBuffer.Next() = 0;
//     end;

//     local procedure GetAzureOpenAIEmbeddings(Input: Text): JsonArray
//     var
//         AzureOpenAI: Codeunit "Azure OpenAI";
//         AOAIOperationResponse: Codeunit "AOAI Operation Response";
//         AOAIDeployments: Codeunit "AOAI Deployments";
//         NoSeriesCopilotSetup: Record "No. Series Copilot Setup"; //TODO: Remove this line, when Microsoft Deployment is used
//     begin
//         if not AzureOpenAI.IsEnabled(Enum::"Copilot Capability"::"No. Series Copilot") then
//             exit;

//         NoSeriesCopilotSetup.Get(); //TODO: Remove this line, when Microsoft Deployment is used
//         AzureOpenAI.SetAuthorization(Enum::"AOAI Model Type"::Embeddings, NoSeriesCopilotSetup.GetEndpoint(), NoSeriesCopilotSetup.GetEmbeddingsDeployment(), NoSeriesCopilotSetup.GetSecretKeyFromIsolatedStorage()); //TODO: Remove this line, when Microsoft Deployment is used
//         // AzureOpenAI.SetAuthorization(Enum::"AOAI Model Type"::Embeddings, AOAIDeployments.GetEmbeddingAda002()); //TODO: Add text-embedding-ada-002 deployment and uncomment this line when Microsoft Deployment is used
//         AzureOpenAI.SetCopilotCapability(Enum::"Copilot Capability"::"No. Series Copilot");
//         AzureOpenAI.GenerateEmbeddings(Input, AOAIOperationResponse);

//         if AOAIOperationResponse.IsSuccess() then
//             exit(GetVectorArray(AOAIOperationResponse.GetResult()))
//         else
//             Error(AOAIOperationResponse.GetError());
//     end;

//     local procedure CalculateCosineSimilarity(FirstVector: List of [Decimal]; SecondVector: List of [Decimal]): Decimal
//     var
//         DotProduct: Decimal;
//         MagnitudeFirstVector: Decimal;
//         MagnitudeSecondVector: Decimal;
//         i: Integer;
//         Math: Codeunit Math;
//     begin
//         DotProduct := 0;
//         MagnitudeFirstVector := 0;
//         MagnitudeSecondVector := 0;

//         for i := 1 to FirstVector.Count() do begin
//             DotProduct += FirstVector.Get(i) * SecondVector.Get(i);
//             MagnitudeFirstVector += Math.Pow(FirstVector.Get(i), 2);
//             MagnitudeSecondVector += Math.Pow(SecondVector.Get(i), 2);
//         end;

//         MagnitudeFirstVector := Math.Sqrt(MagnitudeFirstVector);
//         MagnitudeSecondVector := Math.Sqrt(MagnitudeSecondVector);

//         if (MagnitudeFirstVector = 0) or (MagnitudeSecondVector = 0) then
//             exit(0);

//         exit(DotProduct / (MagnitudeFirstVector * MagnitudeSecondVector));
//     end;

//     local procedure CalculateCosineSimilarityFromNormalizedVectors(FirstVector: List of [Decimal]; SecondVector: List of [Decimal]): Decimal
//     var
//         DotProduct: Decimal;
//         i: Integer;
//     begin
//         DotProduct := 0;

//         for i := 1 to FirstVector.Count() do
//             DotProduct += FirstVector.Get(i) * SecondVector.Get(i);

//         exit(DotProduct);
//     end;

//     local procedure GetVectorArray(Response: Text) Result: JsonArray
//     var
//         Vector: JsonObject;
//         Tok: JsonToken;
//     begin
//         Vector.ReadFrom(Response);
//         Vector.Get('vector', Tok);
//         exit(Tok.AsArray());
//     end;

//     local procedure ConvertJsonArrayToListOfDecimals(EmbeddingArray: JsonArray) Result: List of [Decimal]
//     var
//         i: Integer;
//         EmbeddingValue: JsonToken;
//     begin
//         for i := 0 to EmbeddingArray.Count() - 1 do begin
//             EmbeddingArray.Get(i, EmbeddingValue);
//             Result.Add(EmbeddingValue.AsValue().AsDecimal());
//         end;
//     end;

//     local procedure RequiredNearness(): Decimal
//     begin
//         exit(0.8)
//     end;

// }