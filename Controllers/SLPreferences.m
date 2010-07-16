
// Slife for MacOS X
// Copyright (C) 2009 Slife Labs, LLC
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see http://www.gnu.org/licenses/
//
// For comments or questions, please contact us at http://www.slifelabs.com


// **********************************************************************
//
//							SLPreferences
//
// ***********************************************************************

// Debug
NSString* k_Pref_DebugOn_Key = @"debugOn";
BOOL k_Pref_DebugOn_Default = NO;

// Login Launch
NSString* k_Pref_LaunchOnLogin_Key = @"launchOnLogin";
BOOL k_Pref_LaunchOnLogin_Default = YES;

// Menu Bar Icon
NSString* k_Pref_ShowSlifeMenubarIcon_Key = @"showSlifeMenubarIcon";
BOOL k_Pref_ShowSlifeMenubarIcon_Default = YES;

// Slife Visible
NSString* k_Pref_SlifeInvisible_Key = @"slifeVisibility";
BOOL k_Pref_SlifeInvisible_Default = NO;

// Enable Observer Scripting
NSString* k_Pref_EnableObserverScripting_Key = @"enableObserverScripting";
BOOL k_Pref_EnableObserverScripting_Default = NO;

NSString* k_Pref_ObserverIdleValue_Key = @"observerIdleValue";
int k_Pref_ObserverIdleValue_Default = 3; // We multiply this by 60

NSString* k_Pref_ObservationRate_Key = @"observationRate";
int k_Pref_ObservationRate_Default = 5;

// First Time
NSString* k_Pref_FirstTime_Key = @"firstTime";

// Event Purge
NSString* k_Pref_EventPurge_Key = @"eventPurge";
NSString* k_Pref_EventPurge_Default = @"After one month";

NSString* k_Pref_EventPurge_Never = @"Never";
NSString* k_Pref_EventPurge_OneYear = @"After one year";
NSString* k_Pref_EventPurge_SixMonths = @"After six months";
NSString* k_Pref_EventPurge_OneMonth = @"After one month";
NSString* k_Pref_EventPurge_TwoWeeks = @"After two weeks";
NSString* k_Pref_EventPurge_OneWeek = @"After one week";
NSString* k_Pref_EventPurge_OneDay = @"After one day";
