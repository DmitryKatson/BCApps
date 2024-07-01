// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------

namespace System.Tooling;

using System.PerformanceProfile;

/// <summary>
/// List for performance profiles generated by profile schedules
/// </summary>
page 1931 "Performance Profile List"
{
    Caption = 'Performance Profiles';
    PageType = List;
    ApplicationArea = All;
    UsageCategory = Administration;
    AboutTitle = 'About performance profiles';
    AboutText = 'View the profiles generated by profiler schedules. The profiler uses sampling technology, so the results may differ slightly between recordings of the same scenario.';
    Editable = false;
    SourceTable = "Performance Profiles";

    layout
    {
        area(Content)
        {
            repeater(Profiles)
            {
                field("Start Time"; Rec."Starting Date-Time")
                {
                    Caption = 'Start Time';
                    ToolTip = 'Specifies the time the profile was started.';
                }
                field("User Name"; Rec."User Name")
                {
                    Caption = 'User Name';
                    ToolTip = 'Specifies the name of the user that was profiled.';
                }
                field(Activity; ActivityType)
                {
                    Caption = 'Activity Type';
                    ToolTip = 'Specifies the type of activity for which the schedule is created.';
                    AboutText = 'The type of activity for which the schedule is created.';
                }
                field("Activity Description"; Rec."Activity Description")
                {
                    Caption = 'Activity Description';
                    ToolTip = 'Specifies a short description of the activity that was profiled.';
                }
                field("Object Display Name"; Rec."Object Display Name")
                {
                    Caption = 'Object';
                    ToolTip = 'Specifies the object that contains the entry point for this profile.';
                }
                field(Duration; Rec.Duration)
                {
                    Caption = 'Activity Duration';
                    ToolTip = 'Specifies the duration of the activity that was profiled in milliseconds.';
                }
                field("Http Call Duration"; Rec."Http Call Duration")
                {
                    Caption = 'Duration of Http Calls';
                    ToolTip = 'Specifies the duration of the http calls during the activity that was profiled in milliseconds.';
                }
                field("Http Call Number"; Rec."Http Call Number")
                {
                    Caption = 'Number of Http Calls';
                    ToolTip = 'Specifies the number of http calls during the activity that was profiled.';
                }
                field("Client Session ID"; Rec."Client Session ID")
                {
                    Caption = 'Client Session ID';
                    ToolTip = 'Specifies the ID of the client session that was profiled.';
                }
                field("Schedule ID"; Rec."Schedule ID")
                {
                    Caption = 'Schedule ID';
                    ToolTip = 'Specifies the ID of the schedule that was used to profile the activity.';
                    TableRelation = "Performance Profile Scheduler"."Schedule ID";
                    DrillDown = true;

                    trigger OnDrillDown()
                    var
                        PerfProfileSchedule: Record "Performance Profile Scheduler";
                        PerfProfileScheduleCard: Page "Perf. Profiler Schedule Card";
                    begin
                        if not PerfProfileSchedule.Get(Rec."Schedule ID") then
                            exit;

                        PerfProfileScheduleCard.SetRecord(PerfProfileSchedule);
                        PerfProfileScheduleCard.Run();
                    end;
                }
            }
        }
    }

    actions
    {
        area(Promoted)
        {
            actionref(OpenProfiles; "Open Profile")
            {
            }

            actionref(Refresh; RefreshPage)
            {
            }

            actionref(DownloadProfile; Download)
            {
            }
        }

        area(Navigation)
        {
            action("Open Profile")
            {
                ApplicationArea = All;
                Image = Setup;
                Caption = 'Open Profile';
                ToolTip = 'Open profiles for the scheduled session';
                Enabled = Rec."Activity ID" <> '';
                ShortcutKey = 'Return';

                trigger OnAction()
                var
                    ProfilerPage: Page "Performance Profiler";
                    ProfileInStream: InStream;
                begin
                    Rec.CalcFields(Profile);
                    Rec.Profile.CreateInStream(ProfileInStream);
                    ProfilerPage.SetData(ProfileInStream);
                    ProfilerPage.Run();
                end;
            }

            action(RefreshPage)
            {
                ApplicationArea = All;
                Image = Refresh;
                Caption = 'Refresh';
                ToolTip = 'Refresh the profiles for the schedule.';

                trigger OnAction()
                begin
                    Update();
                end;
            }

            action(Download)
            {
                ApplicationArea = All;
                Image = Download;
                Enabled = Rec."Activity ID" <> '';
                Caption = 'Download';
                ToolTip = 'Download the performance profile file.';

                trigger OnAction()
                var
                    SampPerfProfilerImpl: Codeunit "Sampling Perf. Profiler Impl.";
                    FileName: Text;
                    ProfileInStream: InStream;
                begin
                    FileName := StrSubstNo(ProfileFileNameTxt, Rec."Activity ID", Rec."Client Session ID") + ProfileFileExtensionTxt;
                    Rec.CalcFields(Profile);
                    Rec.Profile.CreateInStream(ProfileInStream);
                    SampPerfProfilerImpl.DownloadData(FileName, ProfileInStream);
                end;
            }
        }
    }

    trigger OnOpenPage()
    var
        RecordRef: RecordRef;
    begin
        Rec.SetAutoCalcFields("User Name", "Client Type");
        RecordRef.GetTable(Rec);
        ScheduledPerfProfilerImpl.FilterUsers(RecordRef, UserSecurityId(), false);
        RecordRef.SetTable(Rec);
    end;

    trigger OnAfterGetRecord()
    var
    begin
        this.MapClientTypeToActivityType();
    end;

    trigger OnAfterGetCurrRecord()
    begin
        this.MapClientTypeToActivityType();
    end;

    local procedure MapClientTypeToActivityType()
    begin
        Rec.CalcFields(Rec."Client Type");
        PerfProfActivityMapper.MapClientTypeToActivityType(rec."Client Type", ActivityType);
    end;

    var
        PerfProfActivityMapper: Codeunit "Perf. Prof. Activity Mapper";
        ScheduledPerfProfilerImpl: Codeunit "Scheduled Perf. Profiler Impl.";
        ActivityType: Enum "Perf. Profile Activity Type";
        ProfileFileNameTxt: Label 'PerformanceProfile_Activity%1_Session%2', Locked = true;
        ProfileFileExtensionTxt: Label '.alcpuprofile', Locked = true;
}