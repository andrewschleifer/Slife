
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

#import "ImageAndTextCell.h"
#import "Slife_AppDelegate.h"
#import "SLInfoWindowController.h"
#import "SLUtilities.h"

// **********************************************************************
//							Preferences
// **********************************************************************

extern NSString* k_Pref_DebugOn_Key;

// **********************************************************************
//						App + Item Settings
// **********************************************************************

// Used for (de)selection of activity items in info window
static NSNumber* selectedNumber;
static NSNumber* unselectedNumber;
static NSNumber* mixedSelectionNumber;

static NSString* activitiesSelectionChangeContext = @"activitiesSelectionChangeContext";

@interface SLInfoWindowController (Private)

- (void) loadSettings;

@end

@implementation SLInfoWindowController

// **********************************************************************
//							initialize
// **********************************************************************
+ (void) initialize
{
	if ([self class] == [SLInfoWindowController class])
	{
		selectedNumber = [[NSNumber alloc] initWithInt:1];
		unselectedNumber = [[NSNumber alloc] initWithInt:0];
		mixedSelectionNumber = [[NSNumber alloc] initWithInt:-1];
	}
}


// **********************************************************************
//								init
// **********************************************************************
- (id) initWithActivitiesArrayController: (NSArrayController*) activitiesArrayController
{
	if(self = [super initWithWindowNibName: @"Inspector"])
    {
        // Set the name of the key for the defaults database for the window
        [self setWindowFrameAutosaveName:@"InfoWindow"];
		
		// Get the managed context
		m_managedContext = [[NSApp delegate] managedObjectContext];
		
		// Set the activities controller
		m_activitiesArrayController = activitiesArrayController;
	}
    
    return self;
}

// **********************************************************************
//							awakeFromNib
// **********************************************************************
- (void) awakeFromNib
{
	// Debug
	if([[[NSUserDefaults standardUserDefaults] objectForKey: k_Pref_DebugOn_Key] boolValue]==TRUE)
		m_debugState = TRUE;
	
	// Resize window if it's too small to display applications (first tab) - It might be too small
	// because the user left it open with the goal tab open.
	
	if([[self window] frame].size.height<300)
	{
		int newWinHeight = 600;
		
		NSRect r = NSMakeRect([[self window] frame].origin.x, 
						[[self window] frame].origin.y - (newWinHeight - (int)(NSHeight([[self window] frame]))), 
						[[self window] frame].size.width, 
						newWinHeight);
							
		[[self window] setFrame:r display:YES animate:YES];
	}
	
	// Listen to changes in the selection of activities
	[m_activitiesArrayController addObserver: self
		forKeyPath: @"selectedObjects"
		options:0
		context: activitiesSelectionChangeContext];
		
	// Load settings
	[self loadSettings];
}

// **********************************************************************
//							managedObjectContext
// **********************************************************************
- (NSManagedObjectContext *) managedObjectContext
{
	return m_managedContext;
}

// **********************************************************************
//					saveChangesToManagedContext
// **********************************************************************
- (void) saveChangesToManagedContext
{
	NSError* error;
	
	if (m_managedContext != nil) 
	{
        if ([m_managedContext commitEditing]) 
		{
            if ([m_managedContext hasChanges] && ![m_managedContext save:&error]) 
			{
				if(m_debugState)
				{
					[[NSApplication sharedApplication] presentError:error];
				
					NSLog(@"Slife: Error saving managed context in info window");
				}
			}
		}
	}
}

// **********************************************************************
//					activitiesArrayController
// **********************************************************************
- (NSArrayController*) activitiesArrayController
{
	return m_activitiesArrayController;
}

// **********************************************************************
//                     observeValueForKeyPath
// **********************************************************************
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	// Observing changes in activity selection to sync activity tables/views
	
	if(context == activitiesSelectionChangeContext)
	{
		// Load setting, since activity selection changed
		[self loadSettings];
				
		return;
	}
	
	[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

#pragma mark ---- UI ----

// **********************************************************************
//					activityNameChanged
// **********************************************************************
- (IBAction) activityNameChanged: (id) sender
{
	[[NSApp delegate] refreshFrontView];
}

// **********************************************************************
//					addApplicationButtonClicked
// **********************************************************************
- (IBAction) addApplicationButtonClicked: (id) sender
{
	
	// ---------------------- User Picks Application -----------------------
	
	int result;
    NSArray* fileTypes = [NSArray arrayWithObjects:@"app", nil];
    NSOpenPanel* oPanel = [NSOpenPanel openPanel];
 
    [oPanel setAllowsMultipleSelection:NO];
    [oPanel setTitle: @"Choose Application"];
    [oPanel setMessage: @"Choose application to track with Slife"];
    [oPanel setDelegate:self];
	
	NSArray* appDirectoryArray = NSSearchPathForDirectoriesInDomains(NSApplicationDirectory, NSLocalDomainMask, YES);
	NSString* appDirectoryPath = [appDirectoryArray objectAtIndex: 0];
	
    result = [oPanel runModalForDirectory: appDirectoryPath file:nil types:fileTypes];
	
    if (result == NSOKButton) 
	{
        NSArray* chosenAppPathArray = [oPanel filenames];
        NSString* chosenAppPath = [chosenAppPathArray objectAtIndex: 0];
		
        // ---------------------- Add Application If Not Present -----------------------
					
		NSString* appFilename = [[chosenAppPath lastPathComponent] stringByDeletingPathExtension];
		
		NSFetchRequest* appFetch = [[NSFetchRequest alloc] init];

		NSEntityDescription* appEntity = [NSEntityDescription entityForName: @"Application" inManagedObjectContext: m_managedContext];
		NSPredicate* appPredicate = [NSPredicate predicateWithFormat: @"name LIKE %@", appFilename];
		
		[appFetch setEntity: appEntity];
		[appFetch setPredicate: appPredicate];
		
		NSError* error = nil;
		NSArray* appResults = [m_managedContext executeFetchRequest: appFetch error: &error];
		
		if(appResults!=nil)
		{
			if([appResults count]==0)
			{
				NSManagedObject* application = [NSEntityDescription insertNewObjectForEntityForName: @"Application" inManagedObjectContext: m_managedContext];
				[application setValue: appFilename forKey: @"name"];
				
				// Save changes to managed context
				[self saveChangesToManagedContext];
			}
		}
		else
		{
			if(m_debugState)
				NSLog(@"Slife: Error picking/inserting application in info window");
		}

	}
	
}

// **********************************************************************
//					enableGoalSettingControls
// **********************************************************************
- (void) enableGoalSettingControls
{
	[m_infoGoalValueTextField setEnabled: TRUE];
	[m_infoGoalTypePopUp setEnabled: TRUE];
	[m_infoGoalTimeUnitPopUp setEnabled: TRUE];
}

// **********************************************************************
//					disableGoalSettingControls
// **********************************************************************
- (void) disableGoalSettingControls
{
	[m_infoGoalValueTextField setEnabled: FALSE];
	[m_infoGoalTypePopUp setEnabled: FALSE];
	[m_infoGoalTimeUnitPopUp setEnabled: FALSE];
}

// **********************************************************************
//                     goalEnabledButtonClicked
// **********************************************************************
- (IBAction) goalEnabledButtonClicked: (id) sender
{
	NSButton* theSwitch = (NSButton*) sender;
	
	if([theSwitch state]==NSOffState)
		[self disableGoalSettingControls];
	else
		[self enableGoalSettingControls];
}

// **********************************************************************
//							loadSettings
// **********************************************************************
- (void) loadSettings
{	
	BOOL goalEnabled = FALSE;
	int goalValue = 0;
	NSString* goalType = nil;
	NSString* goalTimeUnit = nil;
	NSString* goalFrequency = nil;
	
	// Reload data in application and item tables - If no activity selected, all checkboxes will be unchecked
	[m_infoItemEditItemsTableView reloadData];
	[m_infoItemEditApplicationsTableView reloadData];
	
	// Check and see if there's a selection
	NSManagedObject* targetActivityObject = nil;
	if([m_activitiesArrayController selectionIndex]!=NSNotFound)
		targetActivityObject = [m_activitiesArrayController selection];
	
	if(nil==targetActivityObject)
	{
		// No selection - disable goals controls
		[self disableGoalSettingControls];
		
		return;
	}
	
	goalEnabled = [[targetActivityObject valueForKey: @"goalEnabled"] boolValue];
	goalType = [targetActivityObject valueForKey: @"goalType"];
	goalValue = [[targetActivityObject valueForKey: @"goalValue"] intValue];
	goalTimeUnit = [targetActivityObject valueForKey: @"goalTimeUnit"];
	goalFrequency = [targetActivityObject valueForKey: @"goalFrequency"];
	
	[m_infoGoalValueTextField setIntValue: goalValue];
	[m_infoGoalTypePopUp selectItemWithTitle: goalType];
	[m_infoGoalTimeUnitPopUp selectItemWithTitle: goalTimeUnit];
	
	if(goalEnabled)
	{
		[m_infoGoalEnabledButton setState: NSOnState];
		[self enableGoalSettingControls];
	}
	else
	{
		[m_infoGoalEnabledButton setState: NSOffState];
		[self disableGoalSettingControls];
	}
}

// **********************************************************************
//							saveGoalSettings
// **********************************************************************
- (void) saveGoalSettings
{
	NSManagedObject* targetActivityObject = [m_activitiesArrayController selection];
	
	if(nil==targetActivityObject)
		return;
	
	// Pick up enabled button
	NSInteger goalEnabledState = [m_infoGoalEnabledButton state];
	
	// Pick up goal values from controls and apply them to their respective activities
	int			goalValue = [m_infoGoalValueTextField intValue];
	NSString*	goalType = [m_infoGoalTypePopUp titleOfSelectedItem];
	NSString*	goalTimeUnit = [m_infoGoalTimeUnitPopUp titleOfSelectedItem];
	NSString*	goalFrequency = @"daily";
	
	if( (goalValue>0) && goalType && goalTimeUnit && goalFrequency)
	{
		[targetActivityObject setValue: goalType forKey: @"goalType"];
		[targetActivityObject setValue: [NSNumber numberWithInt: goalValue] forKey: @"goalValue"];
		[targetActivityObject setValue: goalTimeUnit forKey: @"goalTimeUnit"];
		[targetActivityObject setValue: goalFrequency forKey: @"goalFrequency"];
		
		if(goalEnabledState==NSOnState)
			[targetActivityObject setValue: [NSNumber numberWithBool: TRUE] forKey: @"goalEnabled"];
		else
			[targetActivityObject setValue: [NSNumber numberWithBool: FALSE] forKey: @"goalEnabled"];
	}
}

// **********************************************************************
//                     goalTypePopUpChanged
// **********************************************************************
- (IBAction) goalTypePopUpChanged: (id) sender
{
	[self saveGoalSettings];
}

// **********************************************************************
//                     goalTimeUnitPopUpChanged
// **********************************************************************
- (IBAction) goalTimeUnitPopUpChanged: (id) sender
{
	[self saveGoalSettings];
}

#pragma mark ---- Delegates ----

// **********************************************************************
//                     shouldSelectTabViewItem
// **********************************************************************
- (BOOL)tabView:(NSTabView *)tabView shouldSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
	NSRect r;
	int newWinHeight = 600;
		
	// If it's the goal tab, shrink the view
	if([[tabViewItem label] isEqualToString: @"Goal"])
		newWinHeight = 210;
	
	r = NSMakeRect([[self window] frame].origin.x, 
					[[self window] frame].origin.y - (newWinHeight - (int)(NSHeight([[self window] frame]))), 
					[[self window] frame].size.width, 
					newWinHeight);
						
	[[self window] setFrame:r display:YES animate:YES];
	
	return YES;
}

// **********************************************************************
//                     objectValueForTableColumn
// **********************************************************************
- (id)tableView:(NSTableView *)aTableView 
	objectValueForTableColumn:(NSTableColumn *)aTableColumn 
	row:(int)rowIndex
{	
	// ------------------- Info - Items Table View ------------------------------
	
	if(aTableView==m_infoItemEditItemsTableView)
	{
		// Find the item at selected row
		NSArray* items = [m_itemsArrayController arrangedObjects];
		NSManagedObject* itemAtRow = [items objectAtIndex: rowIndex];
		
		NSString* identifier = [aTableColumn identifier];
		if (![identifier isEqualToString:@"checkedForActivity"])
		{
			// If not correctly identifier, just return object value
			return [itemAtRow valueForKey: identifier];
		}
		
		// Get all items for selected activity, if it contains item, check the box
		
		NSArray* selectedActivities = [m_activitiesArrayController selectedObjects];
		unsigned int selectionCount = [selectedActivities count];
		
		if (selectionCount == 0)
		{
			return unselectedNumber;
		}
		
		BOOL selected = NO;
		
		NSSet* activityItems = [[selectedActivities objectAtIndex:0] valueForKey: @"items"];
		if ([activityItems containsObject: itemAtRow])
		{
			selected = YES;
		}
		
		if(selected)
			return selectedNumber;
		else
			return unselectedNumber;
	}
	
	// ------------------- Info - Applications Table View ------------------------------
	
	else if(aTableView==m_infoItemEditApplicationsTableView)
	{
		// Find the applications at selected row
		NSArray* applications = [m_applicationsArrayController arrangedObjects];
		NSManagedObject* appAtRow = [applications objectAtIndex: rowIndex];
		
		NSString* identifier = [aTableColumn identifier];
		if (![identifier isEqualToString: @"checkedForActivity"])
		{
			// If not correctly identifier, just return object value
			return [appAtRow valueForKey: identifier];
		}
			
		// Get all applications for selected activity, if it contains item, check the box
		
		NSArray* selectedActivities = [m_activitiesArrayController selectedObjects];
		unsigned int selectionCount = [selectedActivities count];
		
		if (selectionCount == 0)
		{
			return unselectedNumber;
		}
		
		BOOL selected = NO;
		
		NSSet* activityApplications = [[selectedActivities objectAtIndex:0] valueForKey: @"applications"];
		if ([activityApplications containsObject: appAtRow])
		{
			selected = YES;
		}
		
		if(selected)
			return selectedNumber;
		else
			return unselectedNumber;

	}
	
	return FALSE;
}

// **********************************************************************
//							setObjectValue
// **********************************************************************
- (void)tableView:(NSTableView *) aTableView 
	setObjectValue:(id) anObject 
	forTableColumn:(NSTableColumn *) aTableColumn 
	row:(int) rowIndex
{
	// ------------------- Info - Items Table View ------------------------------
	
	if(aTableView==m_infoItemEditItemsTableView)
	{
		// Find the item at selected row
		
		NSArray* items = [m_itemsArrayController arrangedObjects];
		NSManagedObject* itemAtRow = [items objectAtIndex:rowIndex];
		
		NSString* identifier = [aTableColumn identifier];
		if (![identifier isEqualToString:@"checkedForActivity"])
		{
			// If not correctly identifier, just return object value
			[itemAtRow setValue:anObject forKey:identifier];
			return;
		}
		
		// Add/remove item from activity based on click and selection
		
		NSArray* selectedActivities = [m_activitiesArrayController selectedObjects];	
		BOOL shouldBeInDestination = [anObject boolValue];
		
		if (shouldBeInDestination)
		{
			for (id activity in selectedActivities)
			{
				NSMutableSet* activityItems = [activity mutableSetValueForKey: @"items"];
				if (![activityItems containsObject: itemAtRow])
				{
					[activityItems addObject: itemAtRow];
				}
			}
		}
		else // !shouldBeInDestination
		{
			for (id activity in selectedActivities)
			{
				NSMutableSet* activityItems = [activity mutableSetValueForKey: @"items"];
				if ([activityItems containsObject: itemAtRow])
				{
					[activityItems removeObject: itemAtRow];
				}
			}
		}
	}
	
	// ------------------- Info - Applications Table View ------------------------------
	
	else if(aTableView==m_infoItemEditApplicationsTableView)
	{
		// Find the item at selected row
		
		NSArray* applications = [m_applicationsArrayController arrangedObjects];
		NSManagedObject* appAtRow = [applications objectAtIndex:rowIndex];
		
		NSString* identifier = [aTableColumn identifier];
		if (![identifier isEqualToString:@"checkedForActivity"])
		{
			// If not correctly identifier, just return object value
			[appAtRow setValue:anObject forKey: identifier];
			return;
		}
		
		// Add/remove application from activity based on click and selection
		
		NSArray* selectedActivities = [m_activitiesArrayController selectedObjects];	
		BOOL shouldBeInDestination = [anObject boolValue];
		
		if (shouldBeInDestination)
		{
			for (id activity in selectedActivities)
			{
				NSMutableSet* activityApplications = [activity mutableSetValueForKey: @"applications"];
				if (![activityApplications containsObject: appAtRow])
				{
					[activityApplications addObject: appAtRow];
				}
			}
		}
		else // !shouldBeInDestination
		{
			for (id activity in selectedActivities)
			{
				NSMutableSet* activityApplications = [activity mutableSetValueForKey: @"applications"];
				if ([activityApplications containsObject: appAtRow])
				{
					[activityApplications removeObject: appAtRow];
				}
			}
		}
	}

}

// **********************************************************************
//							tableView:willDisplayCell
// **********************************************************************
- (void)tableView:(NSTableView *)aTableView willDisplayCell:(id)aCell forTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex 
{
	
	// ------------------- Info - Applications Table View ------------------------------
	
	if(aTableView==m_infoItemEditApplicationsTableView)
	{
		// Set app name and icon in app settings view
		if([[aTableColumn identifier] isEqualToString: @"name"])
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

// **********************************************************************
//                     controlTextDidChange
// **********************************************************************
- (void)controlTextDidChange:(NSNotification *)aNotification
{
	// Info Window
	if([aNotification object]==m_infoGoalValueTextField)
	{
		[self saveGoalSettings];
	}	
}

@end
