
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

#import <Cocoa/Cocoa.h>

@class DBSourceSplitView;
@class SLObserver;
@class SLInfoWindowController;

@interface Slife_AppDelegate : NSObject
{
	BOOL							m_debugState;
	
	IBOutlet DBSourceSplitView*		m_mainWindowSplitView;
	
	IBOutlet NSView*				m_sideFrameViewPlaceholder;
	IBOutlet NSView*				m_mainFrameViewPlaceholder;
	IBOutlet NSView*				m_mainFrameTopViewPlaceholder;
	IBOutlet NSView*				m_mainFrameBottomViewPlaceholder;
	
    IBOutlet NSView*				m_sideFrameView;
	IBOutlet NSView*				m_mainFrameView;
	
	IBOutlet NSView*				m_dayView;
	IBOutlet NSView*				m_dayControlsView;
	
	IBOutlet NSView*				m_monthView;
	IBOutlet NSView*				m_monthControlsView;
	
	IBOutlet NSView*				m_itemView;
	IBOutlet NSView*				m_itemControlsView;
	
	IBOutlet NSView*				m_applicationView;
	IBOutlet NSView*				m_applicationControlsView;
	IBOutlet NSTableView*			m_appSettingsTableView;
	int								m_targetApplicationColorRow;
	
	IBOutlet NSView*				m_activityView;
	IBOutlet NSTableView*			m_activitySettingsSideFrameTableView;
	IBOutlet NSView*				m_activityControlsView;

	IBOutlet NSView*				m_goalView;
	IBOutlet NSView*				m_goalControlsView;
	
	IBOutlet NSView*				m_preferencesView;
	IBOutlet NSView*				m_prefsControlsView;
	IBOutlet NSPopUpButton*			m_prefsEventPurgePopUpButton;
	
	NSView*							m_frontView;
	
	BOOL							m_privateModeActive;
	IBOutlet NSMenuItem*			m_privateModeMenuItem;
	NSStatusItem*					m_statusMenuItem;
	
	IBOutlet NSMenuItem*			m_removeActivityMenuItem;
	IBOutlet NSMenuItem*			m_editActivityMenuItem;
	IBOutlet NSMenuItem*			m_visualizeActivityMenuItem;
	
	NSUserDefaults*					m_userDefaults;

	BOOL							m_firstRun;
	BOOL							m_mainWindowVisible;
	BOOL							m_appVisible;
	
	NSTimer*						m_appVisibleTimer;
	NSTimer*						m_welcomeTimer;
	NSTimer*						m_newSlifeAlertTimer;
	
	IBOutlet NSArrayController*		m_applicationsArrayController;
	IBOutlet NSArrayController*		m_activitiesArrayController;
	IBOutlet NSArrayController*		m_itemsArrayController;
	
    NSPersistentStoreCoordinator*	persistentStoreCoordinator;
    NSManagedObjectModel*			managedObjectModel;
    NSManagedObjectContext*			managedObjectContext;
	
	SLObserver*						m_observer;
	SLInfoWindowController*			m_infoWindowController;
}

- (NSPersistentStoreCoordinator *)persistentStoreCoordinator;
- (NSManagedObjectModel *)managedObjectModel;
- (NSManagedObjectContext *)managedObjectContext;
- (IBAction) saveAction:sender;

// Views
- (IBAction) showDayView: (id) sender;
- (IBAction) showMonthView: (id) sender;
- (IBAction) showApplicationsView: (id) sender;
- (IBAction) showItemsView: (id) sender;
- (IBAction) showActivitiesView: (id) sender;
- (IBAction) showGoalsView: (id) sender;
- (IBAction) showPreferencesView: (id) sender;
- (IBAction) showWelcomeView: (id) sender;

- (void) refreshFrontView;

// Menus
- (IBAction) addActivity: (id) sender;
- (IBAction) editActivity: (id) sender;

// Preferences
- (IBAction) launchAtLoginSettingChanged: (id) sender;
- (IBAction) menubarIconSettingChanged: (id) sender;
- (IBAction) eventPurgePopUpClicked: (id) sender;

// Info window
- (IBAction) showInfoWindow: (id) sender;

// Support
- (IBAction) showMainWindow: (id) sender;
- (IBAction) closeMainWindow: (id) sender;

@end
