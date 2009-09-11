
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

#include <Carbon/Carbon.h>
#import "ImageAndTextCell.h"
#import "DBSourceSplitView.h"

#import "Slife_AppDelegate.h"
#import "SLObserver.h"
#import "SLColorCell.h"
#import "SLUtilities.h"
#import "SLInfoWindowController.h"

// **********************************************************************
//							Preferences
// **********************************************************************

extern NSString* k_Pref_DebugOn_Key;
extern BOOL k_Pref_DebugOn_Default;

extern NSString* k_Pref_FirstTime_Key;

extern NSString* k_Pref_ShowSlifeMenubarIcon_Key;
extern BOOL k_Pref_ShowSlifeMenubarIcon_Default;

extern NSString* k_Pref_SlifeInvisible_Key;
extern BOOL k_Pref_SlifeInvisible_Default;

extern NSString* k_Pref_EnableObserverScripting_Key;
extern BOOL k_Pref_EnableObserverScripting_Default;
extern NSString* k_Pref_ObserverIdleValue_Key;
extern int k_Pref_ObserverIdleValue_Default;
extern NSString* k_Pref_ObservationRate_Key;
extern int k_Pref_ObservationRate_Default;

extern NSString* k_Pref_LaunchOnLogin_Key;
extern BOOL k_Pref_LaunchOnLogin_Default;

extern NSString* k_Pref_EventPurge_Key;
extern NSString* k_Pref_EventPurge_Default;
extern NSString* k_Pref_EventPurge_Never;
extern NSString* k_Pref_EventPurge_OneYear;
extern NSString* k_Pref_EventPurge_SixMonths;
extern NSString* k_Pref_EventPurge_OneMonth;
extern NSString* k_Pref_EventPurge_TwoWeeks;
extern NSString* k_Pref_EventPurge_OneWeek;
extern NSString* k_Pref_EventPurge_OneDay;


// **********************************************************************
//							Slife_AppDelegate
// **********************************************************************

@interface Slife_AppDelegate (Private)

- (void) setDefaults;

- (void) saveChangesToManagedContext;

- (void) purgeEvents;

- (BOOL) isFirstTimeRunning;
- (void) setUpInitialConfiguration;
- (void) showWelcomeGuide;

- (void) makeSlifeVisible;
- (void) makeSlifeInvisible;
- (void) createStatusItemInMenuBar;

@end

@implementation Slife_AppDelegate

#pragma mark --- Initialization ---

// **********************************************************************
//							awakeFromNib
// **********************************************************************
- (id) init
{
	// Init the parent class
    [super init];
		
	// Get the defaults
    m_userDefaults = [NSUserDefaults standardUserDefaults];
	
	// Check if first time running
	if([self isFirstTimeRunning])
		m_firstRun = TRUE;
	else
		m_firstRun = FALSE;
	
	// No info window yet
	m_infoWindowController = nil;
	
	return self;
}

// **********************************************************************
//							awakeFromNib
// **********************************************************************
- (void) awakeFromNib
{	
	// Set the defaults
    [self setDefaults];
	
	// Debug
	if([[m_userDefaults objectForKey: k_Pref_DebugOn_Key] boolValue]==TRUE)
		m_debugState = TRUE;
		
	// Launch on Login
	if([[m_userDefaults objectForKey: k_Pref_LaunchOnLogin_Key] boolValue]==TRUE)
		[SLUtilities addApplicationToLoginLaunchList];
	
	// The main window is visible
	m_mainWindowVisible = TRUE;
	
	// Private mode is OFF
	m_privateModeActive = NO;
	
	// Initially Slife is not visible
	m_appVisible = NO;
	
	// --------------- App settings table view settings ------------------
	
	// Color
	NSTableColumn*		colorColumn;
	SLColorCell*		colorCell;
	
	colorColumn = [m_appSettingsTableView tableColumnWithIdentifier: @"color"];
	colorCell = [[[SLColorCell alloc] init] autorelease];
	[colorCell setEditable: YES];
	[colorCell setTarget: self];
	[colorCell setAction: @selector (colorClick:)];
	[colorColumn setDataCell: colorCell];
	
	// Drag & Drop
	[m_appSettingsTableView registerForDraggedTypes: [NSArray arrayWithObject: NSFilenamesPboardType]];
	[m_appSettingsTableView setDraggingSourceOperationMask: NSDragOperationEvery forLocal: NO];
	
	// --------------- Place Views in Placeholders ------------------
	
	[m_sideFrameView setFrameSize:[m_sideFrameViewPlaceholder frame].size];
	[m_sideFrameViewPlaceholder addSubview: m_sideFrameView];

	[m_mainFrameView setFrameSize:[m_mainFrameViewPlaceholder frame].size];
	[m_mainFrameViewPlaceholder addSubview: m_mainFrameView];

	// --------------- Subscribe to Notifications -----------------

	// Request switch to view - from double click in day in Month View and side frame button view controller
	[[NSNotificationCenter defaultCenter] addObserver: self
			selector: @selector(switchToDayView:)
			name: @"dayViewChangeRequest" 
			object: nil];
	
	// Request switch to view - from side frame button view controller
	[[NSNotificationCenter defaultCenter] addObserver: self
			selector: @selector(switchToMonthView:)
			name: @"monthViewChangeRequest" 
			object: nil];
			
	// Request switch to view - from side frame button view controller
	[[NSNotificationCenter defaultCenter] addObserver: self
			selector: @selector(switchToApplicationsView:)
			name: @"applicationsViewChangeRequest" 
			object: nil];

	// Request switch to view - from side frame button view controller
	[[NSNotificationCenter defaultCenter] addObserver: self
			selector: @selector(switchToItemsView:)
			name: @"itemsViewChangeRequest" 
			object: nil];
			
	// Request switch to view - from visualize button in Activity Settings View and side frame button view controller
	[[NSNotificationCenter defaultCenter] addObserver: self
			selector: @selector(switchToActivitiesView:)
			name: @"activitiesViewChangeRequest" 
			object: nil];

	// Request switch to view - from side frame button view controller
	[[NSNotificationCenter defaultCenter] addObserver: self
			selector: @selector(switchToGoalsView:)
			name: @"goalsViewChangeRequest" 
			object: nil];

	// Show info window
	[[NSNotificationCenter defaultCenter] addObserver: self
			selector: @selector(showInfoWindowRequest:)
			name: @"showInfoWindowRequest" 
			object: nil];


	// ----- Slife Teams ----- 
	
	// Account verification
	[[NSNotificationCenter defaultCenter] addObserver: self
			selector: @selector(updateTeamAccountStatus:)
			name: @"teamAccountVerificationResult" 
			object: nil];
		
	// Fetch team activities
	[[NSNotificationCenter defaultCenter] addObserver: self
			selector: @selector(syncTeamActivities:)
			name: @"fetchTeamActivitiesResult" 
			object: nil];

	// ----- Slife Rewards ----- 
	
	// Account verification
	[[NSNotificationCenter defaultCenter] addObserver: self
			 selector: @selector(updateRewardsAccountStatus:)
				 name: @"rewardsAccountVerificationResult" 
			   object: nil];

	// ---------------------- Menu Icon ----------------------------
	
	if([[m_userDefaults objectForKey: k_Pref_ShowSlifeMenubarIcon_Key] boolValue]==TRUE)
		[self createStatusItemInMenuBar];
	
	// ---------------------- Observer -----------------------------
	
	m_observer = [[SLObserver alloc] init];

	// ----------------- Initial App Configuration And Views--------
	
	if(m_firstRun)
	{
		// Initial config
		[self setUpInitialConfiguration];
		
		// Show welcome guide after a second
		m_welcomeTimer = [NSTimer scheduledTimerWithTimeInterval: 3
        target: self selector: @selector(welcomeTimerHandler:) userInfo: nil 
        repeats: NO];
	}
	
	// Bring up day view
	[m_dayView setFrameSize:[m_mainFrameTopViewPlaceholder frame].size];
	[m_mainFrameTopViewPlaceholder addSubview: m_dayView];
	
	[m_dayControlsView setFrameSize:[m_mainFrameBottomViewPlaceholder frame].size];
	[m_mainFrameBottomViewPlaceholder addSubview: m_dayControlsView];
	
	m_frontView = m_dayView;
	
	// Restore window frame
	[[m_mainWindowSplitView window] setFrameUsingName: @"MainWindow"];
	[m_mainWindowSplitView setPositionUsingName: @"MainWindowSplit"];
	
}	

// **********************************************************************
//                     applicationDidFinishLaunching
// **********************************************************************
- (void) applicationDidFinishLaunching: (NSNotification *)aNotification
{
	// ---------------------- Slife Visibility --------------------
	
	// Make Slife visible or not
	if([[m_userDefaults objectForKey: k_Pref_SlifeInvisible_Key] boolValue]==NO)
	{
		// Make app visible
		m_appVisibleTimer = [NSTimer scheduledTimerWithTimeInterval: 1
					   target: self selector: @selector(makeSlifeVisibleTimerHandler:) userInfo: nil 
					   repeats: YES];
	}
	
	// --------------------- Purge Events -----------------------------
	
	[self purgeEvents];
	
}

// **********************************************************************
//                          setDefaults
// **********************************************************************
- (void) setDefaults
{
    // Create a dictionary
    NSMutableDictionary* defaultValues = [NSMutableDictionary dictionary];

	// ------------------------ Debug --------------------------------------
	
	// Disable debug by default
	[defaultValues setObject: [NSNumber numberWithBool: k_Pref_DebugOn_Default] forKey: k_Pref_DebugOn_Key];
	
	// ------------------------ Launch On Login --------------------------------------
	
	// Enable launch mode
	[defaultValues setObject: [NSNumber numberWithBool: k_Pref_LaunchOnLogin_Default] forKey: k_Pref_LaunchOnLogin_Key];
	
	// ------------------------ Observer --------------------------------------
	
	// Enable observer scripting
	[defaultValues setObject: [NSNumber numberWithBool: k_Pref_EnableObserverScripting_Default] forKey: k_Pref_EnableObserverScripting_Key];
	
	// Idle
	[defaultValues setObject: [NSNumber numberWithInt: k_Pref_ObserverIdleValue_Default] forKey: k_Pref_ObserverIdleValue_Key];
	
	// Observation Rate
	[defaultValues setObject: [NSNumber numberWithInt: k_Pref_ObservationRate_Default] forKey: k_Pref_ObservationRate_Key];

	// ------------------------ Show Menu Bar Icon --------------------------------------
	
	// Enable menu bar icon
	[defaultValues setObject: [NSNumber numberWithBool: k_Pref_ShowSlifeMenubarIcon_Default] forKey: k_Pref_ShowSlifeMenubarIcon_Key];
	
	// ------------------------ Slife Visibility  ------------------------------------------
	
	// Keep Slife visible at first
	[defaultValues setObject: [NSNumber numberWithBool: k_Pref_SlifeInvisible_Default] forKey: k_Pref_SlifeInvisible_Key];
	
	// ------------------------ Event Purge --------------------------------------
	
	// Set purge setting to one year
	[defaultValues setObject: k_Pref_EventPurge_Default forKey: k_Pref_EventPurge_Key];
	
	// ------------------------ Register --------------------------------------
	
    // Register the dictionary of defaults
    [m_userDefaults registerDefaults: defaultValues];
}

// **********************************************************************
//					setUpInitialConfiguration
// **********************************************************************
- (void) setUpInitialConfiguration
{
	// ---------------------------- Applications -------------------------------
	
	NSManagedObject* applicationObject = nil;
	
	applicationObject = [NSEntityDescription insertNewObjectForEntityForName: @"Application" 
		inManagedObjectContext: [self managedObjectContext]];
	[applicationObject setValue: @"Safari" forKey: @"name"];
	[applicationObject setValue: [NSColor purpleColor] forKey: @"color"];
	
	applicationObject = [NSEntityDescription insertNewObjectForEntityForName: @"Application" 
		inManagedObjectContext: [self managedObjectContext]];
	[applicationObject setValue: @"Mail" forKey: @"name"];
	[applicationObject setValue: [NSColor redColor] forKey: @"color"];
	
	applicationObject = [NSEntityDescription insertNewObjectForEntityForName: @"Application" 
		inManagedObjectContext: [self managedObjectContext]];
	[applicationObject setValue: @"iChat" forKey: @"name"];
	[applicationObject setValue: [NSColor orangeColor] forKey: @"color"];
	
	applicationObject = [NSEntityDescription insertNewObjectForEntityForName: @"Application" 
		inManagedObjectContext: [self managedObjectContext]];
	[applicationObject setValue: @"iTunes" forKey: @"name"];
	[applicationObject setValue: [NSColor greenColor] forKey: @"color"];
	
	applicationObject = [NSEntityDescription insertNewObjectForEntityForName: @"Application" 
		inManagedObjectContext: [self managedObjectContext]];
	[applicationObject setValue: @"iCal" forKey: @"name"];
	[applicationObject setValue: [NSColor brownColor] forKey: @"color"];
	
	applicationObject = [NSEntityDescription insertNewObjectForEntityForName: @"Application" 
		inManagedObjectContext: [self managedObjectContext]];
	[applicationObject setValue: @"TextEdit" forKey: @"name"];
	[applicationObject setValue: [NSColor blueColor] forKey: @"color"];

	// ---------------------------- Activities -------------------------------
	
	NSManagedObject* activityObject = nil;
	
	activityObject = [NSEntityDescription insertNewObjectForEntityForName: @"Activity" 
		inManagedObjectContext: [self managedObjectContext]];
	[activityObject setValue: @"Reading news" forKey: @"name"];

	activityObject = [NSEntityDescription insertNewObjectForEntityForName: @"Activity" 
		inManagedObjectContext: [self managedObjectContext]];
	[activityObject setValue: @"Checking email" forKey: @"name"];
	
	activityObject = [NSEntityDescription insertNewObjectForEntityForName: @"Activity" 
		inManagedObjectContext: [self managedObjectContext]];
	[activityObject setValue: @"Preparing budget" forKey: @"name"];
	
	activityObject = [NSEntityDescription insertNewObjectForEntityForName: @"Activity" 
		inManagedObjectContext: [self managedObjectContext]];
	[activityObject setValue: @"Doing online research" forKey: @"name"];
	
	activityObject = [NSEntityDescription insertNewObjectForEntityForName: @"Activity" 
		inManagedObjectContext: [self managedObjectContext]];
	[activityObject setValue: @"Designing web pages" forKey: @"name"];
	
	
	[self saveChangesToManagedContext];
}

// **********************************************************************
//							purgeEvents
// **********************************************************************
- (void) purgeEvents
{	
	NSCalendarDate* purgeDate = nil;
	
	// Get the purge string
	NSString* purgeRangeString = [m_userDefaults objectForKey: k_Pref_EventPurge_Key];
	
	// Sanity check
	if(nil==purgeRangeString)
	{
		if(m_debugState)
			NSLog(@"Slife: Could not obtain purge range to purge events");
			
		return;
	}
	
	// Never
	if([purgeRangeString isEqualToString: k_Pref_EventPurge_Never])
	{
		return;
	}
	
	// One Year
	else if([purgeRangeString isEqualToString: k_Pref_EventPurge_OneYear])
	{
		purgeDate = [[NSCalendarDate date] dateByAddingYears:-1 months:0 days:0 hours:0 minutes:0 seconds:0];
	}
	
	// Six Months
	else if([purgeRangeString isEqualToString: k_Pref_EventPurge_SixMonths])
	{
		purgeDate = [[NSCalendarDate date] dateByAddingYears:0 months:-6 days:0 hours:0 minutes:0 seconds:0];
	}
	
	// One Month
	else if([purgeRangeString isEqualToString: k_Pref_EventPurge_OneMonth])
	{
		purgeDate = [[NSCalendarDate date] dateByAddingYears:0 months:-1 days:0 hours:0 minutes:0 seconds:0];
	}
	
	// Two Weeks
	else if([purgeRangeString isEqualToString: k_Pref_EventPurge_TwoWeeks])
	{
		purgeDate = [[NSCalendarDate date] dateByAddingYears:0 months:0 days:-14 hours:0 minutes:0 seconds:0];
	}
	
	// One Week
	else if([purgeRangeString isEqualToString: k_Pref_EventPurge_OneWeek])
	{
		purgeDate = [[NSCalendarDate date] dateByAddingYears:0 months:0 days:-7 hours:0 minutes:0 seconds:0];
	}
	
	// One Day
	else if([purgeRangeString isEqualToString: k_Pref_EventPurge_OneDay])
	{
		purgeDate = [[NSCalendarDate date] dateByAddingYears:0 months:0 days:-1 hours:0 minutes:0 seconds:0];
	}
	
	NSFetchRequest* request = [[[NSFetchRequest alloc] init] autorelease];
	NSEntityDescription* entity = [NSEntityDescription entityForName: @"Event" inManagedObjectContext: managedObjectContext];
	[request setEntity: entity];
	
	NSPredicate* predicate = [NSPredicate predicateWithFormat: @"startDate < %@", purgeDate];	
	[request setPredicate: predicate];

	NSError* error = nil;
	NSArray* eventsToPurgeArray = [managedObjectContext executeFetchRequest:request error:&error];
	
	for(NSManagedObject* eventObject in eventsToPurgeArray)
	{
		[managedObjectContext deleteObject: eventObject];
	}

}

#pragma mark ---- Core Data ----

// **********************************************************************
//						applicationSupportFolder
// **********************************************************************

/**
    Returns the support folder for the application, used to store the Core Data
    store file.  This code uses a folder named "Slife" for
    the content, either in the NSApplicationSupportDirectory location or (if the
    former cannot be found), the system's temporary directory.
 */

- (NSString *) applicationSupportFolder 
{

    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString *basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : NSTemporaryDirectory();
    return [basePath stringByAppendingPathComponent:@"Slife"];
}


// **********************************************************************
//							managedObjectModel
// **********************************************************************

/**
    Creates, retains, and returns the managed object model for the application 
    by merging all of the models found in the application bundle.
 */
 
- (NSManagedObjectModel *)managedObjectModel {

    if (managedObjectModel != nil) {
        return managedObjectModel;
    }
	
    managedObjectModel = [[NSManagedObjectModel mergedModelFromBundles:nil] retain];    
    return managedObjectModel;
}

// **********************************************************************
//						persistentStoreCoordinator
// **********************************************************************

/**
    Returns the persistent store coordinator for the application.  This 
    implementation will create and return a coordinator, having added the 
    store for the application to it.  (The folder for the store is created, 
    if necessary.)
 */

- (NSPersistentStoreCoordinator *) persistentStoreCoordinator {

    if (persistentStoreCoordinator != nil) {
        return persistentStoreCoordinator;
    }

    NSFileManager *fileManager;
    NSString *applicationSupportFolder = nil;
    NSURL *url;
    NSError *error;
    
    fileManager = [NSFileManager defaultManager];
    applicationSupportFolder = [self applicationSupportFolder];
    if ( ![fileManager fileExistsAtPath:applicationSupportFolder isDirectory:NULL] ) {
        [fileManager createDirectoryAtPath:applicationSupportFolder attributes:nil];
    }
    
    url = [NSURL fileURLWithPath: [applicationSupportFolder stringByAppendingPathComponent: @"db20.slife"]];
    persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel: [self managedObjectModel]];
	
	NSDictionary* optionsDictionary =
    [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES]
                    forKey:NSMigratePersistentStoresAutomaticallyOption];
					
    if (![persistentStoreCoordinator addPersistentStoreWithType: NSSQLiteStoreType configuration:nil URL:url options:optionsDictionary error:&error]){
        [[NSApplication sharedApplication] presentError:error];
    }    

    return persistentStoreCoordinator;
}

// **********************************************************************
//							managedObjectContext
// **********************************************************************

/**
    Returns the managed object context for the application (which is already
    bound to the persistent store coordinator for the application.) 
 */
 
- (NSManagedObjectContext *) managedObjectContext {

    if (managedObjectContext != nil) {
        return managedObjectContext;
    }

    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
    if (coordinator != nil) {
        managedObjectContext = [[NSManagedObjectContext alloc] init];
        [managedObjectContext setPersistentStoreCoordinator: coordinator];
		
		[managedObjectContext setUndoManager: nil];
    }
    
    return managedObjectContext;
}

// **********************************************************************
//					windowWillReturnUndoManager
// **********************************************************************

/**
    Returns the NSUndoManager for the application.  In this case, the manager
    returned is that of the managed object context for the application.
 */
 
- (NSUndoManager *)windowWillReturnUndoManager:(NSWindow *)window {
    return [[self managedObjectContext] undoManager];
}


// **********************************************************************
//							saveAction
// **********************************************************************

/**
    Performs the save action for the application, which is to send the save:
    message to the application's managed object context.  Any encountered errors
    are presented to the user.
 */
 
- (IBAction) saveAction:(id)sender {

    NSError *error = nil;
    if (![[self managedObjectContext] save:&error]) {
        [[NSApplication sharedApplication] presentError:error];
    }
}


// **********************************************************************
//						applicationShouldTerminate
// **********************************************************************

/**
    Implementation of the applicationShouldTerminate: method, used here to
    handle the saving of changes in the application managed object context
    before the application terminates.
 */
 
- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender {

    NSError* error;
    int reply = NSTerminateNow;
    
	// Save last event before we quit
	[m_observer saveLastEventBeforeQuitOrSleep];
	
	// Save window frame
	[[m_mainWindowSplitView window] saveFrameUsingName: @"MainWindow"];
	[m_mainWindowSplitView savePositionUsingName: @"MainWindowSplit"];
	
    if (managedObjectContext != nil) 
	{
        if ([managedObjectContext commitEditing]) 
		{
            if ([managedObjectContext hasChanges] && ![managedObjectContext save:&error]) 
			{
				if(m_debugState)
				{
					NSLog(@"Slife: Error when saving managed context: %@", [error localizedDescription]);
				}
			}
        } 
        else 
		{
            reply = NSTerminateCancel;
        }
    }
	
    return reply;
}


// **********************************************************************
//							dealloc
// **********************************************************************

/**
    Implementation of dealloc, to release the retained variables.
 */
 
- (void) dealloc 
{	
    [managedObjectContext release], managedObjectContext = nil;
    [persistentStoreCoordinator release], persistentStoreCoordinator = nil;
    [managedObjectModel release], managedObjectModel = nil;
    [super dealloc];
}

#pragma mark ---- Support ----

// **********************************************************************
//							isFirstTimeRunning
// **********************************************************************
- (BOOL) isFirstTimeRunning
{
	NSFileManager* fileManager = [NSFileManager defaultManager];
	NSString* storePath = [[self applicationSupportFolder] stringByAppendingPathComponent: @"db20.slife"];
	
	return ![fileManager fileExistsAtPath: storePath];
}

// **********************************************************************
//							showMainWindow
// **********************************************************************
- (IBAction) showMainWindow: (id) sender
{
	// Bring the main window to the front
	[[m_mainWindowSplitView window] makeKeyAndOrderFront: sender];
	m_mainWindowVisible = TRUE;
}

// **********************************************************************
//							closeMainWindow
// **********************************************************************
- (IBAction) closeMainWindow: (id) sender
{
	if([[m_mainWindowSplitView window] isKeyWindow])
	{
		// Hide the main window
		[[m_mainWindowSplitView window] orderOut: sender];
		m_mainWindowVisible = FALSE;
	}
}

// **********************************************************************
//						 welcomeTimerHandler
// **********************************************************************
- (void) welcomeTimerHandler: (NSTimer*) theTimer
{
	// Show welcome guide 
	[self showWelcomeGuide];
}

// **********************************************************************
//					applicationDidBecomeActive
// **********************************************************************
- (void)applicationDidBecomeActive:(NSNotification *)aNotification
{		
	// Show main window if it's not visible
	if(!m_mainWindowVisible)
		[self showMainWindow: self];
	
	// Refresh the main view
	[m_frontView setNeedsDisplay: YES];
}

// **********************************************************************
//					windowWillClose
// **********************************************************************
- (void)windowWillClose: (NSNotification *)notification
{
	NSWindow* closingWindow = [notification object];
	
	// Main window is closing, set flag
	if(closingWindow==[m_mainWindowSplitView window])
		m_mainWindowVisible = FALSE;
}

// **********************************************************************
//					saveChangesToManagedContext
// **********************************************************************
- (void) saveChangesToManagedContext
{
	NSError* error;
	
	if (managedObjectContext != nil) 
	{
        if ([managedObjectContext commitEditing]) 
		{
            if ([managedObjectContext hasChanges] && ![managedObjectContext save:&error]) 
			{
				if(m_debugState)
				{
					[[NSApplication sharedApplication] presentError:error];
				
					NSLog(@"Slife: Error saving managed context in app delegate");
				}
			}
		}
	}
}

#pragma mark ----- Menu Bar Icon -----

// **********************************************************************
//
//							Status Menu Item
//
// **********************************************************************

// **********************************************************************
//                      setPrivateModeIconToActive
// **********************************************************************
- (void) setPrivateModeIconToActive
{
	// Set the image
	[m_statusMenuItem setImage: [NSImage imageNamed: @"menubar-red"]];
}

// **********************************************************************
//                     setPrivateModeIconToInactive
// **********************************************************************
- (void) setPrivateModeIconToInactive
{
	// Set the image
	[m_statusMenuItem setImage: [NSImage imageNamed: @"menubar-black"]];
}

// **********************************************************************
//                         isPrivateModeOn
// **********************************************************************
- (BOOL) isPrivateModeOn
{	
	return m_privateModeActive;
}

// **********************************************************************
//							makeSlifeVisible
// **********************************************************************
- (void) makeSlifeVisible
{
	// Transform process from background to foreground
	ProcessSerialNumber psn = { 0, kCurrentProcess };
	OSStatus returnCode = TransformProcessType(& psn, kProcessTransformToForegroundApplication);
	
	if((returnCode != 0) && (m_debugState)) 
		NSLog(@"Could not bring Slife to front. Error %d", returnCode);
	
	// This is a hack - bring app to foreground
	[[NSApplication sharedApplication] activateIgnoringOtherApps: TRUE];
	[[m_mainWindowSplitView window] makeKeyAndOrderFront: self];
	
	// Enable menu bar
	SetSystemUIMode(kUIModeNormal, 0);
	
	// Switch to Dock.app
	[[NSWorkspace sharedWorkspace] launchAppWithBundleIdentifier:@"com.apple.dock" 
				options:NSWorkspaceLaunchDefault additionalEventParamDescriptor:nil launchIdentifier:nil];
	
	// This is a hack - bring app to foreground again
	[[NSApplication sharedApplication] activateIgnoringOtherApps: TRUE];
	[[m_mainWindowSplitView window] makeKeyAndOrderFront: self];
	
	// Slife is now visible
	m_appVisible = YES;
}

// **********************************************************************
//							makeSlifeInvisible
// **********************************************************************
- (void) makeSlifeInvisible
{	
	// ------------------------------	Alert --------------------------------------
	
	// Display alert
	NSAlert* alert = [[NSAlert alloc] init];
	[alert addButtonWithTitle:@"OK"];
	[alert setMessageText:@"Setting updated"];
	[alert setInformativeText:@"This change will take effect next time you start Slife."];
	[alert setAlertStyle:NSWarningAlertStyle];
	
	// Wait until user clicks 'ok'
	[alert runModal];
	
	// Get rid of alert
	[alert release];
	
	// ------------------------ Menu Bar Icon --------------------------------------
	
	[m_userDefaults setObject: [NSNumber numberWithBool: YES] forKey: k_Pref_ShowSlifeMenubarIcon_Key];
	
	// ------------------------ Show Slife Icon --------------------------------------
	
	[m_userDefaults setObject: [NSNumber numberWithBool: YES] forKey: k_Pref_SlifeInvisible_Key];
}

// **********************************************************************
//						 makeSlifeVisibleTimerHandler
// **********************************************************************
- (void) makeSlifeVisibleTimerHandler: (NSTimer*) theTimer
{
	[self makeSlifeVisible];
	
	[m_appVisibleTimer invalidate];
}

// **********************************************************************
//                          createStatusItemInMenuBar
// **********************************************************************
- (void) createStatusItemInMenuBar
{
	// Get the main bar
    NSStatusBar* mainBar = [NSStatusBar systemStatusBar];
 
	// Create a status item for the menu bar
    m_statusMenuItem = [mainBar statusItemWithLength:NSVariableStatusItemLength];
    [m_statusMenuItem retain];
 
	// Set the icon accordingly
	if([self isPrivateModeOn])
		[self setPrivateModeIconToActive];
	else
		[self setPrivateModeIconToInactive];
	
	// Set prefs
    [m_statusMenuItem setHighlightMode:YES];
	
	// Set the target/action
	[m_statusMenuItem setTarget: self];
	[m_statusMenuItem setAction: @selector(buildStatusMenuItems:)];
	[m_statusMenuItem sendActionOn: NSLeftMouseDownMask];
}

// **********************************************************************
//                         removeStatusItemInMenuBar
// **********************************************************************
- (void) removeStatusItemInMenuBar
{
	// Get the main bar
    NSStatusBar* mainBar = [NSStatusBar systemStatusBar];
 
	// Remove the icon
    [mainBar removeStatusItem: m_statusMenuItem];
	
	// Get rid of the menu item
	[m_statusMenuItem release];
	m_statusMenuItem = nil;
}

// **********************************************************************
//                          buildStatusMenuItems
// **********************************************************************
- (void) buildStatusMenuItems: (id) sender
{
	// Sanity check
	if(sender==nil)
		return;

	// Trick described in Cocobuilder to build a status menu item dynamically
	// http://www.cocoabuilder.com/archive/message/cocoa/2003/2/9/74470
	
	// --------------------------------------------------------------------
	//
	//			Create some fake stuff for the popUpContextMenu call
	//
	// --------------------------------------------------------------------
	
	NSWindow  *theWindow;
    NSView    *theView;
    NSRect    contentRect = NSMakeRect( 0, 0, 100, 100 ); // x, y, w, h
    NSRect    theBoxBounds = NSMakeRect( 0, 0, 100, 100 );
    NSRect    screenRect;

    screenRect = [[NSScreen mainScreen] frame]; // get the screen height
    NSPoint mouseLocation = [NSEvent mouseLocation];
    mouseLocation.x = mouseLocation.x - 25; // move left a bit
    mouseLocation.y = screenRect.size.height - 25; // just below the bar

    theWindow = [[NSWindow alloc] initWithContentRect:contentRect
        styleMask:NSBorderlessWindowMask backing:NSBackingStoreNonretained
        defer:NO];

    theView = [[NSView alloc] initWithFrame:theBoxBounds]; // create
    [theWindow setContentView:theView]; // put into the window
    [theView setFrame:theBoxBounds]; // reposition

    NSEvent* theEvent = [NSEvent mouseEventWithType:NSLeftMouseUp
        location:mouseLocation
        modifierFlags:0
        timestamp:[NSDate timeIntervalSinceReferenceDate]
        windowNumber:[theWindow windowNumber]
        context:[NSGraphicsContext currentContext]
        eventNumber:1
        clickCount:1
        pressure:1.0];
	
	// --------------------------------------------------------------------
	
	// Create a menu
	NSMenu* statusMenu = [[[NSMenu alloc] initWithTitle: @"StatusMenu"] autorelease];
	
	// We want to handle the item selections
	[statusMenu setAutoenablesItems: NO];
	
	// --------------------------- Private Mode ----------------------------------------
	
	// Create a menu item
	NSMenuItem* privateMenuItem = [[[NSMenuItem alloc] initWithTitle: @"Private Mode" 
		action: @selector(handleStatusMenuItems:) keyEquivalent: @""] autorelease];
	
	// Settings
	[privateMenuItem setEnabled: TRUE];
	[privateMenuItem setTarget: self];
	
	// Check item if private mode is on
	if(m_privateModeActive==TRUE)
	{
		[privateMenuItem setState: NSOnState];
	}
	else
	{
		[privateMenuItem setState: NSOffState];
	}
	
	// Add it to the main menu
	[statusMenu addItem: privateMenuItem];
	
	// ---------------------------Separator ----------------------------------------
	
	// Create a menu item
	NSMenuItem* sepMenuItem = [NSMenuItem separatorItem];
	
	// Add it to the main menu
	[statusMenu addItem: sepMenuItem];
	
	// ------------------------------- Slife Visibility -----------------------------
	
	// Set the item according to whether Slife is visible or not
	NSString* visibilityItemString = nil;
	
	if(m_appVisible)
		visibilityItemString = @"Hide Slife";
	else
		visibilityItemString = @"Show Slife";
	
	// Create a menu item
	NSMenuItem*	visibilitySlifeMenuItem = [[[NSMenuItem alloc] initWithTitle: visibilityItemString 
									action: @selector(handleStatusMenuItems:) keyEquivalent: @""] autorelease];
	
	// Set target
	[visibilitySlifeMenuItem setEnabled: TRUE];
	[visibilitySlifeMenuItem setTarget: self];
	
	// Add it to the main menu
	[statusMenu addItem: visibilitySlifeMenuItem];
	
	// --------------------------- Separator ----------------------------------------
	
	// Add it to the main menu
	[statusMenu addItem: [NSMenuItem separatorItem]];

	// --------------------------- Activities ----------------------------------------
	
	NSManagedObject* anActivity = nil;
	NSArray* activities = [m_activitiesArrayController arrangedObjects];
	
	for(anActivity in activities)
	{
		NSString* activityName = [anActivity valueForKey: @"name"];
		BOOL activityActive = [[anActivity valueForKey: @"active"] boolValue];
		
		// Create a menu item
		NSMenuItem* menuItem = [[[NSMenuItem alloc] initWithTitle: activityName 
			action: @selector(handleStatusMenuItems:) keyEquivalent: @""] autorelease];
		
		// Mark it if active
		if(activityActive==TRUE)
		{
			[menuItem setState: NSOnState];
		}
		else
		{
			[menuItem setState: NSOffState];
		}
		
		// Set the target/action
		[menuItem setEnabled: TRUE];
		[menuItem setTarget: self];
		
		// Add it to the main menu
		[statusMenu addItem: menuItem];
	}
	
	// --------------------------- Separator -------------------------------------------
	
	// Add it to the main menu
	[statusMenu addItem: [NSMenuItem separatorItem]];
	
	// ------------------------------- App Activity Menu ---------------------------------
	
	// Get front most application
	NSString* frontMostApp = [SLUtilities frontMostApp];
	
	if((nil!=frontMostApp)&&([frontMostApp length]>0))
	{
		// Get activity for application object
		NSManagedObject* applicationObject = [m_observer createOrFetchManagedObjectForApplicationName: frontMostApp];
		NSString* applicationActivityName = nil;
		NSManagedObject* applicationActivityObject = [applicationObject valueForKey: @"activity"];
		if(applicationActivityObject)
		{
			applicationActivityName = [applicationActivityObject valueForKey: @"name"];
		}
		
		// Create a menu item
		NSMenuItem* setAppActivityMenuItem = [[[NSMenuItem alloc] 
			initWithTitle: [NSString stringWithFormat: @"Set Activity For %@", frontMostApp] 
			action: @selector(handleStatusMenuItems:) 
			keyEquivalent: @""] 
			autorelease];
		
		// Settings
		[setAppActivityMenuItem setEnabled: TRUE];
		[setAppActivityMenuItem setTarget: self];
		
		// Create activities submenu
		NSMenu* setAppActivitySubMenu = [[[NSMenu alloc] initWithTitle: @"AppActivitySubMenu"] autorelease];
		[setAppActivitySubMenu setAutoenablesItems: NO];
		
		for(anActivity in activities)
		{
			NSString* activityName = [anActivity valueForKey: @"name"];
			
			// Create a menu item
			NSMenuItem* menuItem = [[[NSMenuItem alloc] initWithTitle: activityName 
				action: @selector(handleStatusMenuItems:) keyEquivalent: @""] autorelease];
			
			// If there's an activity for this application, mark it as such
			if((nil!=applicationActivityName) && ([applicationActivityName length]>0) &&
				[applicationActivityName isEqualToString: activityName])
			{
				[menuItem setState: NSOnState];
			}
			else
			{
				[menuItem setState: NSOffState];
			}
					
			// Set the target/action
			[menuItem setEnabled: TRUE];
			[menuItem setTarget: self];
			
			// Add it to the main menu
			[setAppActivitySubMenu addItem: menuItem];
		}
		
		// Set submenu
		[setAppActivityMenuItem setSubmenu: setAppActivitySubMenu];
		
		// Add it to the main menu
		[statusMenu addItem: setAppActivityMenuItem];
		
		// ------------------------------- App Document Activity Menu ---------------------------------
		
		NSString* frontWindowTitle = [m_observer getUIFrontWindowTitle];
		
		// Only adding menu if the observer could get the UI of the front window title
		if((nil!=frontWindowTitle) && ([frontWindowTitle length]>0))
		{
			// Get the most important string from the window title
			NSString* frontWindowSourceString = [SLUtilities extractSourceFromString: frontWindowTitle];
			if((nil!=frontWindowSourceString) && ([frontWindowSourceString length]>0))
			{
				// Get activity for item object
				NSArray* items = [m_itemsArrayController arrangedObjects];
				NSPredicate* namePredicate = [NSPredicate predicateWithFormat: @"name like %@", frontWindowSourceString];
				NSArray* targetItemsArray = [items filteredArrayUsingPredicate: namePredicate];
				int targetItemsArrayCount = [targetItemsArray count];
				NSString* itemActivityName = nil;
				
				if(targetItemsArrayCount==1)
				{
					NSManagedObject* itemObject = [targetItemsArray lastObject];
					NSManagedObject* itemActivityObject = [itemObject valueForKey: @"activity"];
					if(itemActivityObject)
					{
						itemActivityName = [itemActivityObject valueForKey: @"name"];
					}
				}
				
				// Create a menu item
				NSMenuItem* setAppDocActivityMenuItem = [[[NSMenuItem alloc] 
					initWithTitle: [NSString stringWithFormat: @"Set Activity For '%@'", 
					[SLUtilities limitString: frontWindowSourceString toNumberOfCharacters: 50]] 
					action: @selector(handleStatusMenuItems:) 
					keyEquivalent: @""] 
					autorelease];
				
				// Settings
				[setAppDocActivityMenuItem setEnabled: TRUE];
				[setAppDocActivityMenuItem setTarget: self];
				
				// Create activities submenu
				NSMenu* setAppDocActivitySubMenu = [[[NSMenu alloc] initWithTitle: @"AppDocActivitySubMenu"] autorelease];
				[setAppDocActivitySubMenu setAutoenablesItems: NO];
				
				for(anActivity in activities)
				{
					NSString* activityName = [anActivity valueForKey: @"name"];
					
					// Create a menu item
					NSMenuItem* menuItem = [[[NSMenuItem alloc] initWithTitle: activityName 
						action: @selector(handleStatusMenuItems:) keyEquivalent: @""] autorelease];
					
					// If there's an activity for this item, mark it as such
					if((nil!=itemActivityName) && ([itemActivityName length]>0) &&
						[itemActivityName isEqualToString: activityName])
					{
						[menuItem setState: NSOnState];
					}
					else
					{
						[menuItem setState: NSOffState];
					}
							
					// Set the target/action
					[menuItem setEnabled: TRUE];
					[menuItem setTarget: self];
					
					// Add it to the main menu
					[setAppDocActivitySubMenu addItem: menuItem];
				}
				
				// Set submenu
				[setAppDocActivityMenuItem setSubmenu: setAppDocActivitySubMenu];
				
				// Add it to the main menu
				[statusMenu addItem: setAppDocActivityMenuItem];
			}
		}

		// --------------------------- Separator -------------------------------------------
		
		// Add it to the main menu
		[statusMenu addItem: [NSMenuItem separatorItem]];
	}
	
	// ------------------------------- Quit ----------------------------------------
	
	// Create a menu item
	NSMenuItem* quitMenuItem = [[[NSMenuItem alloc] initWithTitle: @"Quit Slife" 
		action: @selector(handleStatusMenuItems:) keyEquivalent: @""] autorelease];
	
	// Settings
	[quitMenuItem setEnabled: TRUE];
	[quitMenuItem setTarget: self];
	
	// Add it to the main menu
	[statusMenu addItem: quitMenuItem];

	// --------------------------- Finish Things Off ----------------------------------

	// This is the call that makes it all happen
	[NSMenu popUpContextMenu: statusMenu withEvent:theEvent forView:theView];
	
	// Delete the view and window we used in popUpContextMenu
    [theWindow autorelease];
    [theView autorelease];
}

// **********************************************************************
//                          handleStatusMenuItems
// **********************************************************************
- (void) handleStatusMenuItems: (id) sender
{
	// Sanity check
	if(sender==nil)
		return;
		
	// Get the menu item
	NSMenuItem* menuItem = (NSMenuItem*) sender;
	
	NSManagedObject* anActivity = nil;
	NSArray* activities = [m_activitiesArrayController arrangedObjects];
	
	for(anActivity in activities)
	{
		NSString* activityName = [anActivity valueForKey: @"name"];
		BOOL activityActive = [[anActivity valueForKey: @"active"] boolValue];
		
		// Match the activity with the menuItem
		if([activityName isEqualToString: [menuItem title]])
		{
			NSString* parentMenuTitle = [[menuItem menu] title];
			
			// --------------------------- App Activity  -----------------------------------
			
			if([parentMenuTitle isEqualToString: @"AppActivitySubMenu"])
			{
				// Get front most application
				NSString* frontMostApp = [SLUtilities frontMostApp];
				
				if((nil!=frontMostApp)&&([frontMostApp length]>0))
				{
					// Get application object
					NSManagedObject* applicationObject = [m_observer createOrFetchManagedObjectForApplicationName: frontMostApp];
											
					if(nil!=applicationObject)
					{
						// Is the application already associated with this activity
						NSManagedObject* applicationActivity = [applicationObject valueForKey: @"activity"];
						if( (nil!=applicationActivity) && (applicationActivity==anActivity) )
						{
							// Yes. Remove it (associate it with nothing)
							[applicationObject setValue: nil forKey: @"activity"];
							
							if(m_debugState)
								NSLog(@"Disassociating activity '%@' with application '%@'", activityName, frontMostApp);
						}
						else
						{
							// No. Associate it with activity
							[applicationObject setValue: anActivity forKey: @"activity"];
							
							if(m_debugState)
								NSLog(@"Associating activity '%@' with application '%@'", activityName, frontMostApp);
						}
					}
					else
					{
						if(m_debugState)
							NSLog(@"Slife: More than one application object for %@, not associating app with activity", frontMostApp);
					}
				}
			}
			
			// --------------------------- App Doc Activity  -------------------------------
			
			else if([parentMenuTitle isEqualToString: @"AppDocActivitySubMenu"])
			{
				// Get item from Accessibility
				NSString* uiFrontItem = [m_observer getUIFrontWindowTitle];
				
				// Make sure all values match
				if((nil!=uiFrontItem) && ([uiFrontItem length]>0))
				{
					// Get the most important string from the window title
					NSString* frontWindowSourceString = [SLUtilities extractSourceFromString: uiFrontItem];
					if((nil!=frontWindowSourceString) && ([frontWindowSourceString length]>0))
					{	
						// See if we already have this item
						NSArray* items = [m_itemsArrayController arrangedObjects];
						NSPredicate* namePredicate = [NSPredicate predicateWithFormat: @"name like %@", frontWindowSourceString];
						NSArray* targetItemsArray = [items filteredArrayUsingPredicate: namePredicate];
						int targetItemsArrayCount = [targetItemsArray count];
						
						if(targetItemsArrayCount<=1)
						{
							NSManagedObject* itemObject = nil;
							
							if(targetItemsArrayCount==0)
							{
								// We don't - create item
								itemObject = [NSEntityDescription insertNewObjectForEntityForName: @"Item" inManagedObjectContext: [self managedObjectContext]];
								[itemObject setValue: frontWindowSourceString forKey: @"name"];
							}
							else
							{
								// We do, get it
								itemObject = [targetItemsArray lastObject];
							}
							
							// Is the item already associated with this activity
							NSManagedObject* itemActivity = [itemObject valueForKey: @"activity"];
							if( (nil!=itemActivity) && (itemActivity==anActivity) )
							{
								// Yes. Remove it (associate it with nothing)
								[itemObject setValue: nil forKey: @"activity"];
								
								if(m_debugState)
									NSLog(@"Disassociating activity '%@' with item '%@'", activityName, frontWindowSourceString);
							}
							else
							{
								// No. Associate it with activity
								[itemObject setValue: anActivity forKey: @"activity"];
								
								if(m_debugState)
									NSLog(@"Associating activity '%@' with item '%@'", activityName, frontWindowSourceString);
							}
						}
						else
						{
							if(m_debugState)
								NSLog(@"Slife: More than one item objects for %@, not associating item with activity", frontWindowSourceString);
						}
					}
				}
			}
			
			// --------------------------- Activities --------------------------------------
			
			else
			{
				// Toggle the active member
				if(activityActive==FALSE)
				{
					// Set the member
					[anActivity setValue: [NSNumber numberWithBool: TRUE] forKey: @"active"];
					[menuItem setState: NSOnState];
				}
				else
				{
					// Set the member
					[anActivity setValue: [NSNumber numberWithBool: FALSE] forKey: @"active"];
					[menuItem setState: NSOffState];
				}
			}
		}
	}
	
	// --------------------------- Private Mode -------------------------------------
	
	if([[menuItem title] isEqualToString: @"Private Mode"])
	{
		// Check item if private mode is on
		if(m_privateModeActive==YES)
		{
			m_privateModeActive = NO;
			
			// Change the setting for the "Private Mode" menu item in the Slife menu
			[m_privateModeMenuItem setState: NSOffState];
			
			// Set icon to inactive
			[self setPrivateModeIconToInactive];
			
			// Private mode is inactive
			[m_observer setPrivateMode: FALSE];
		}
		else
		{
			m_privateModeActive = YES;
			
			// Change the setting for the "Private Mode" menu item in the Slife menu
			[m_privateModeMenuItem setState: NSOnState];
			
			// Set icon to active
			[self setPrivateModeIconToActive];
			
			// Private mode is active
			[m_observer setPrivateMode: TRUE];
		}
	}
	
	// --------------------------- Show/Hide Slife --------------------------------
	
	else if([[menuItem title] isEqualToString: @"Show Slife"])
	{
		// Get Slife to the foreground
		[self makeSlifeVisible];
	}
	
	else if([[menuItem title] isEqualToString: @"Hide Slife"])
	{
		// Get Slife to the foreground
		[self makeSlifeInvisible];
	}
	
	// --------------------------- Quit -----------------------------------------
	
	else if([[menuItem title] isEqualToString: @"Quit Slife"])
	{
		// Quit the app
		[NSApp terminate:nil];
	}
}

#pragma mark ----- Preferences ------

// **********************************************************************
//						preferencesViewSetup
// **********************************************************************
- (void) preferencesViewSetup
{
	// ------------------------ Event Purge --------------------------------
	
	// Get the purge string
	NSString* purgeRangeString = [m_userDefaults objectForKey: k_Pref_EventPurge_Key];
	
	// Sanity check
	if(nil==purgeRangeString)
	{
		if(m_debugState)
			NSLog(@"Slife: Could not obtain purge range when setting up Preferences view");
			
		return;
	}
	
	// Select item
	[m_prefsEventPurgePopUpButton selectItemWithTitle: purgeRangeString];
}

// **********************************************************************
//					launchAtLoginSettingChanged
// **********************************************************************
- (IBAction) launchAtLoginSettingChanged: (id) sender
{
	// Check the state and set preferences
	if([sender state]==NSOnState)
	{
		[SLUtilities addApplicationToLoginLaunchList];
	}
	else
	{
		[SLUtilities removeApplicationFromLoginLaunchList];
	}
}

// **********************************************************************
//					menubarIconSettingChanged
// **********************************************************************
- (IBAction) menubarIconSettingChanged: (id) sender
{
	// Check the state and set preferences
	if([sender state]==NSOnState)
	{
		[self createStatusItemInMenuBar];
	}
	else
	{
		[self removeStatusItemInMenuBar];
	}
}

// **********************************************************************
//					eventPurgePopUpClicked
// **********************************************************************
- (IBAction) eventPurgePopUpClicked: (id) sender
{
	NSPopUpButton* popUpButton = (NSPopUpButton*) sender;
	[m_userDefaults setObject: [popUpButton titleOfSelectedItem] forKey: k_Pref_EventPurge_Key];
}

// **********************************************************************
//							colorClick
// **********************************************************************
- (void) colorClick: (id) sender 
{    
	// sender is the table view
	NSColorPanel* panel;
   
	// Color has been clicked. Find out target row, get color from app object and show it in color panel
	m_targetApplicationColorRow = [sender clickedRow];
	NSColor* appRowColor = [[[m_applicationsArrayController arrangedObjects] objectAtIndex: m_targetApplicationColorRow] valueForKey: @"color"];

	panel = [NSColorPanel sharedColorPanel];
	[panel setTarget: self];
	[panel setAction: @selector (colorChanged:)];
	[panel setColor: appRowColor];
	[panel makeKeyAndOrderFront: self];
}

// **********************************************************************
//							colorChanged
// **********************************************************************
- (void) colorChanged: (id) sender 
{    
	// sender is the NSColorPanel

	// Color has been changed in color panel. Re-set the color of app object
	NSColorPanel* panel = (NSColorPanel*) sender;
	[[[m_applicationsArrayController arrangedObjects] objectAtIndex: m_targetApplicationColorRow] setValue: [panel color] forKey: @"color"];
	
	[m_appSettingsTableView reloadData];
}

// **********************************************************************
//								validateDrop
// **********************************************************************
- (NSDragOperation)tableView:(NSTableView*)aTableView validateDrop:(id <NSDraggingInfo>)info proposedRow:(int)row proposedDropOperation:(NSTableViewDropOperation)op
{	
	if(aTableView==m_appSettingsTableView)
	{
		// Set the whole table as the focus
		[m_appSettingsTableView setDropRow: -1 dropOperation: NSTableViewDropOn];
		
		// ---------------------- Get the pasteboard -----------------------
		
		NSPasteboard* pboard = [info draggingPasteboard];
		if( [[pboard types] containsObject: NSFilenamesPboardType] ) 
		{
			NSArray* files = [pboard propertyListForType: NSFilenamesPboardType];
			
			NSString* filePath = nil;
			for(filePath in files)
			{
				// If any of the items is not an app, we don't validate the drop
				if(![[filePath pathExtension] isEqualToString: @"app"])
					return NSDragOperationNone;
			}
				
			return NSDragOperationEvery;
		}
		else
			return NSDragOperationNone;
	}
	else
		return NSDragOperationNone;
}

// **********************************************************************
//								acceptDrop
// **********************************************************************
- (BOOL)tableView:(NSTableView *)aTableView acceptDrop:(id <NSDraggingInfo>)info
            row:(int)row dropOperation:(NSTableViewDropOperation)operation
{	
	if(aTableView==m_appSettingsTableView)
	{
		// Set the whole table as the focus
		[m_appSettingsTableView setDropRow: -1 dropOperation: NSTableViewDropOn];
		
		// ---------------------- Get the pasteboard -----------------------
		
		NSPasteboard* pboard = [info draggingPasteboard];
		if( [[pboard types] containsObject: NSFilenamesPboardType] ) 
		{
			NSArray* files = [pboard propertyListForType: NSFilenamesPboardType];
			
			NSString* filePath = nil;
			for(filePath in files)
			{
				if([[filePath pathExtension] isEqualToString: @"app"])
				{
					// ---------------------- Add Application If Not Present -----------------------
					
					NSString* appFilename = [[filePath lastPathComponent] stringByDeletingPathExtension];
					
					NSFetchRequest* appFetch = [[NSFetchRequest alloc] init];
		
					NSEntityDescription* appEntity = [NSEntityDescription entityForName: @"Application" inManagedObjectContext: managedObjectContext];
					NSPredicate* appPredicate = [NSPredicate predicateWithFormat: @"name LIKE %@", appFilename];
					
					[appFetch setEntity: appEntity];
					[appFetch setPredicate: appPredicate];
					
					NSError* error = nil;
					NSArray* appResults = [managedObjectContext executeFetchRequest: appFetch error: &error];
					
					if(appResults!=nil)
					{
						if([appResults count]==0)
						{
							NSManagedObject* application = [NSEntityDescription insertNewObjectForEntityForName: @"Application" inManagedObjectContext: managedObjectContext];
							[application setValue: appFilename forKey: @"name"];
							
							// Save changes to managed context
							[self saveChangesToManagedContext];
							
							// Reload table
							[m_appSettingsTableView reloadData];
						}
					}
					else
					{
						if(m_debugState)
							NSLog(@"Slife: Error fetching application objects in drag");
					}
				}
			}
				
			return YES;
		}
		else
			return NO;
	}
	else
		return NO;

}


// **********************************************************************
//							tableView:willDisplayCell
// **********************************************************************
- (void)tableView:(NSTableView *)aTableView willDisplayCell:(id)aCell forTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex 
{
	if(aTableView==m_appSettingsTableView)
	{
		// Set color for application color cell in app settings view
		if([[aTableColumn identifier] isEqualToString: @"color"])
		{
			NSColor* appRowColor = [[[m_applicationsArrayController arrangedObjects] objectAtIndex: rowIndex] valueForKey: @"color"];
			[aCell setObjectValue: appRowColor];
		}
		
		// Set app name and icon in app settings view
		else if([[aTableColumn identifier] isEqualToString: @"appName"])
		{
			NSString* appRowName = [[[m_applicationsArrayController arrangedObjects] objectAtIndex: rowIndex] valueForKey: @"name"];
			
			if(appRowName && ([appRowName length]>0))
			{
				// Get the icon image
				NSImage* appIconImage = nil;
				
				appIconImage = [SLUtilities getIconImageForApplication: appRowName];
				if(appIconImage!=nil)
					[appIconImage setSize: NSMakeSize(16,16)];
				
				// Draw the icon, finally
				if(appIconImage)
				{
					ImageAndTextCell* imageAndTextCell = (ImageAndTextCell *) aCell;
					[imageAndTextCell setImage: appIconImage];
				}
			}
		}
	}
}

#pragma mark ----- Views ------

// **********************************************************************
//							showDayView
// **********************************************************************
- (IBAction) showDayView: (id) sender
{
	// Notify observers
	[[NSNotificationCenter defaultCenter] postNotificationName: @"viewChanging" object: @"Day"];
	
	// Change view
	[m_dayView setFrameSize:[m_mainFrameTopViewPlaceholder frame].size];
	[m_mainFrameTopViewPlaceholder replaceSubview: [[m_mainFrameTopViewPlaceholder subviews] objectAtIndex: 0] with: m_dayView];
	
	[m_dayControlsView setFrameSize:[m_mainFrameBottomViewPlaceholder frame].size];
	[m_mainFrameBottomViewPlaceholder replaceSubview: [[m_mainFrameBottomViewPlaceholder subviews] objectAtIndex: 0] with: m_dayControlsView];
	
	m_frontView = m_dayView;
}

// **********************************************************************
//							showMonthView
// **********************************************************************
- (IBAction) showMonthView: (id) sender
{
	// Notify observers
	[[NSNotificationCenter defaultCenter] postNotificationName: @"viewChanging" object: @"Month"];
	
	// Change view
	[m_monthView setFrameSize:[m_mainFrameTopViewPlaceholder frame].size];
	[m_mainFrameTopViewPlaceholder replaceSubview: [[m_mainFrameTopViewPlaceholder subviews] objectAtIndex: 0] with: m_monthView];
	
	[m_monthControlsView setFrameSize:[m_mainFrameBottomViewPlaceholder frame].size];
	[m_mainFrameBottomViewPlaceholder replaceSubview: [[m_mainFrameBottomViewPlaceholder subviews] objectAtIndex: 0] with: m_monthControlsView];

	m_frontView = m_monthView;
}

// **********************************************************************
//							showApplicationsView
// **********************************************************************
- (IBAction) showApplicationsView: (id) sender
{
	// Notify observers
	[[NSNotificationCenter defaultCenter] postNotificationName: @"viewChanging" object: @"Applications"];
	
	// Change view
	[m_applicationView setFrameSize:[m_mainFrameTopViewPlaceholder frame].size];
	[m_mainFrameTopViewPlaceholder replaceSubview: [[m_mainFrameTopViewPlaceholder subviews] objectAtIndex: 0] with: m_applicationView];
	
	[m_applicationControlsView setFrameSize:[m_mainFrameBottomViewPlaceholder frame].size];
	[m_mainFrameBottomViewPlaceholder replaceSubview: [[m_mainFrameBottomViewPlaceholder subviews] objectAtIndex: 0] with: m_applicationControlsView];
	
	m_frontView = m_applicationView;	
}

// **********************************************************************
//							showItemsView
// **********************************************************************
- (IBAction) showItemsView: (id) sender
{
	// Notify observers
	[[NSNotificationCenter defaultCenter] postNotificationName: @"viewChanging" object: @"Web & Documents"];
	
	// Change view
	[m_itemView setFrameSize:[m_mainFrameTopViewPlaceholder frame].size];
	[m_mainFrameTopViewPlaceholder replaceSubview: [[m_mainFrameTopViewPlaceholder subviews] objectAtIndex: 0] with: m_itemView];
	
	[m_itemControlsView setFrameSize:[m_mainFrameBottomViewPlaceholder frame].size];
	[m_mainFrameBottomViewPlaceholder replaceSubview: [[m_mainFrameBottomViewPlaceholder subviews] objectAtIndex: 0] with: m_itemControlsView];
	
	m_frontView = m_itemView;
}

// **********************************************************************
//							showActivitiesView
// **********************************************************************
- (IBAction) showActivitiesView: (id) sender
{
	// Notify observers
	[[NSNotificationCenter defaultCenter] postNotificationName: @"viewChanging" object: @"Activities"];
	
	// Change view
	[m_activityView setFrameSize:[m_mainFrameTopViewPlaceholder frame].size];
	[m_mainFrameTopViewPlaceholder replaceSubview: [[m_mainFrameTopViewPlaceholder subviews] objectAtIndex: 0] with: m_activityView];
	
	[m_activityControlsView setFrameSize:[m_mainFrameBottomViewPlaceholder frame].size];
	[m_mainFrameBottomViewPlaceholder replaceSubview: [[m_mainFrameBottomViewPlaceholder subviews] objectAtIndex: 0] with: m_activityControlsView];
	
	m_frontView = m_activityView;
}

// **********************************************************************
//							showGoalsView
// **********************************************************************
- (IBAction) showGoalsView: (id) sender
{
	// Notify observers
	[[NSNotificationCenter defaultCenter] postNotificationName: @"viewChanging" object: @"Goals"];
	
	// Change view
	[m_goalView setFrameSize:[m_mainFrameTopViewPlaceholder frame].size];
	[m_mainFrameTopViewPlaceholder replaceSubview: [[m_mainFrameTopViewPlaceholder subviews] objectAtIndex: 0] with: m_goalView];
	
	[m_goalControlsView setFrameSize:[m_mainFrameBottomViewPlaceholder frame].size];
	[m_mainFrameBottomViewPlaceholder replaceSubview: [[m_mainFrameBottomViewPlaceholder subviews] objectAtIndex: 0] with: m_goalControlsView];
	
	m_frontView = m_goalView;
}

// **********************************************************************
//						showPreferencesView
// **********************************************************************
- (IBAction) showPreferencesView: (id) sender
{
	// Notify observers
	[[NSNotificationCenter defaultCenter] postNotificationName: @"viewChanging" object: @"Preferences"];
	
	// Change view
	[m_preferencesView setFrameSize:[m_mainFrameTopViewPlaceholder frame].size];
	[m_mainFrameTopViewPlaceholder replaceSubview: [[m_mainFrameTopViewPlaceholder subviews] objectAtIndex: 0] with: m_preferencesView];
	
	[m_prefsControlsView setFrameSize:[m_mainFrameBottomViewPlaceholder frame].size];
	[m_mainFrameBottomViewPlaceholder replaceSubview: [[m_mainFrameBottomViewPlaceholder subviews] objectAtIndex: 0] with: m_prefsControlsView];
	
	// Set up preferences view
	[self preferencesViewSetup];
	
	m_frontView = m_preferencesView;
}

// **********************************************************************
//							showWelcomeView
// **********************************************************************
- (IBAction) showWelcomeView: (id) sender
{
	[self showWelcomeGuide];
}

// **********************************************************************
//						switchToDayView
// **********************************************************************
- (void) switchToDayView: (NSNotification *) notification
{
	[self showDayView: self];
}

// **********************************************************************
//						switchToMonthView
// **********************************************************************
- (void) switchToMonthView: (NSNotification *) notification
{
	[self showMonthView: self];
}

// **********************************************************************
//						switchToApplicationsView
// **********************************************************************
- (void) switchToApplicationsView: (NSNotification *) notification
{
	[self showApplicationsView: self];
}

// **********************************************************************
//						switchToItemsView
// **********************************************************************
- (void) switchToItemsView: (NSNotification *) notification
{
	[self showItemsView: self];
}

// **********************************************************************
//						switchToActivitiesView
// **********************************************************************
- (void) switchToActivitiesView: (NSNotification *) notification
{	
	[self showActivitiesView: self];
}

// **********************************************************************
//						switchToGoalsView
// **********************************************************************
- (void) switchToGoalsView: (NSNotification *) notification
{
	[self showGoalsView: self];
}

// **********************************************************************
//							refreshFrontView
// **********************************************************************
- (void) refreshFrontView
{
	if(nil!=m_frontView)
		[m_frontView setNeedsDisplay: YES];
}

#pragma mark ----- Info Window ------

// **********************************************************************
//							showInfoWindow
// **********************************************************************
- (IBAction) showInfoWindow: (id) sender
{
	// If we still don't have a welcome controller instance
    if(!m_infoWindowController)
    {
        // Create one
        m_infoWindowController = [[SLInfoWindowController alloc] initWithActivitiesArrayController: m_activitiesArrayController];
    }
	 
	// Show it
    [m_infoWindowController showWindow: self];
}

// **********************************************************************
//					showInfoWindowRequest
// **********************************************************************
- (void) showInfoWindowRequest: (NSNotification*) notification
{
	[self showInfoWindow: self];
}

#pragma mark ----- Menu ------

// **********************************************************************
//						addActivity
// **********************************************************************
- (IBAction) addActivity: (id) sender
{
	// Bring up activities view
	[self showActivitiesView: self];
	
	// Add activity and show info window
	[m_activitiesArrayController add: self];
	[self showInfoWindow: self];
}

// **********************************************************************
//                     editActivity
// **********************************************************************
- (IBAction) editActivity: (id) sender
{
	// Bring up activities view and show info view
	[self showActivitiesView: self];
	[self showInfoWindow: self];
}

// **********************************************************************
//                       validateMenuItem
// **********************************************************************
- (BOOL) validateMenuItem:(NSMenuItem*)anItem
{
	NSArray* selectedActivities = [m_activitiesArrayController selectedObjects];
	unsigned int selectionCount = [selectedActivities count];
	BOOL activitySelected = (selectionCount>0) ? TRUE : FALSE;
	
	NSMenu* menuParent = [anItem menu];
	
	// ------------------- Activity ---------------------
	
	if([[menuParent title] isEqualToString: @"File"])
	{
		if([[anItem title] isEqualToString:  @"Edit Activity"])
		{
			if(!activitySelected)
				return NO;
		}
		
		else if([[anItem title] isEqualToString:  @"Delete Activity"])
		{
			if(!activitySelected)
				return NO;
		}
	}
	
	return YES;
}

@end
