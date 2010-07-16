//
//  SLActivityEditView.m
//  Slife
//
//  Created by Edison Thomaz on 5/19/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "SLActivityEditView.h"
#import "SLUtilities.h"
#import "MAAttachedWindow.h"
#import "ImageAndTextCell.h"

// **********************************************************************
//							Preferences
// **********************************************************************
extern NSString* k_Pref_DebugOn_Key;

// Used for (de)selection of activity items in table
static NSNumber* selectedNumber;
static NSNumber* unselectedNumber;
static NSNumber* mixedSelectionNumber;

// Syncing between side frame activities table and the activities here
static NSString* activitiesSetContext = @"activitiesSetContext";
static NSString* activitiesSelectionChangeContext = @"activitiesSelectionChangeContext";

// **********************************************************************
//                     SLActivityEditView (Private)
// **********************************************************************
@interface SLActivityEditView (Private)

- (void) loadGoalSettings;
- (void) saveGoalSettings;

@end

// **********************************************************************
//                     SLActivityEditView
// **********************************************************************
@implementation SLActivityEditView

// **********************************************************************
//                     initialize
// **********************************************************************
+ (void)initialize
{
	if ([self class] == [SLActivityEditView class])
	{
		selectedNumber = [[NSNumber alloc] initWithInt:1];
		unselectedNumber = [[NSNumber alloc] initWithInt:0];
		mixedSelectionNumber = [[NSNumber alloc] initWithInt:-1];
	}
}

// **********************************************************************
//                     initWithFrame
// **********************************************************************
- (id)initWithFrame:(NSRect)frame 
{
    self = [super initWithFrame:frame];
	
    if (self) 
	{
		// Debug
		NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
		m_debugState = [[defaults objectForKey: k_Pref_DebugOn_Key] boolValue];
		
		// Initialization
		m_selectedActivityName = @"";
        m_activityPanelCoords = [NSMutableDictionary dictionaryWithCapacity: 5];
		
		m_activityItemEditWindow = nil;
    }
	
    return self;
}

// **********************************************************************
//                     awakeFromNib
// **********************************************************************
- (void) awakeFromNib
{
	// Get managed context
	m_managedContext = [[NSApp delegate] managedObjectContext];
	
	// Listen to changes in the number of activities
	[m_activitiesArrayController addObserver: self
		forKeyPath: @"arrangedObjects"
		options:0
		context: activitiesSetContext];
	
	// Listen to changes in the selection of activities
	[m_activitiesArrayController addObserver: self
		forKeyPath: @"selectedObjects"
		options:0
		context: activitiesSelectionChangeContext];
	
    NSNotificationCenter* center = [NSNotificationCenter defaultCenter];
	
	// Views changing
	[center addObserver: self
			selector:@selector(viewChanging:)
			name: @"viewChanging" 
			object: nil];
		
	// Show Activity Edit Window
	[center addObserver: self
			selector:@selector(showActivityEditWindowForSelection:)
			name: @"showActivityEditWindowForSelection" 
			object: nil];
}

#pragma mark ---- Support ----

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
				
					NSLog(@"Slife: Error saving managed context in activity edit");
				}
			}
		}
	}
}

// **********************************************************************
//                     observeValueForKeyPath
// **********************************************************************
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	// Observing changes in activities and selection to sync activity tables/views
	
	if (context == activitiesSetContext)
	{
		// Remove edit window
		[self removeActivityItemEditWindow: self];
		
		// Activities changed, redraw this view
		[self setNeedsDisplay: YES];
		
		return;
	}
	else if(context == activitiesSelectionChangeContext)
	{
		// Selection changed
			
		NSArray* selectedActivities = [m_activitiesArrayController selectedObjects];
		unsigned int selectionCount = [selectedActivities count];
		
		if(selectionCount==0)
		{
			// Nothing selected
			m_selectedActivityName = @"";
			
			[m_activityRemoveItemButton setEnabled: FALSE];
			[m_activityEditItemButton setEnabled: FALSE];
			[m_activityVisualizeItemButton setEnabled: FALSE];
		}
		else if(selectionCount>0)
		{
			// An item has been selected
			NSManagedObject* selectedActivity = [selectedActivities objectAtIndex: 0];
			NSString* selectedActivityID = [[[selectedActivity objectID] URIRepresentation] absoluteString];
			m_selectedActivityName = selectedActivityID;
			
			[m_activityRemoveItemButton setEnabled: TRUE];
			[m_activityEditItemButton setEnabled: TRUE];
			[m_activityVisualizeItemButton setEnabled: TRUE];
		}

		// Remove edit window
		[self removeActivityItemEditWindow: self];
		
		// Activity changed, redraw the view
		[self setNeedsDisplay: YES];
		
		return;
	}
	
	[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

// **********************************************************************
//							viewsChanging
// **********************************************************************
- (void) viewChanging: (NSNotification *) notification
{
	[self removeActivityItemEditWindow: self];
}

// **********************************************************************
//							calculateFrameSize
// **********************************************************************
- (void) calculateFrameSize
{
	// Get the view dimensions
    NSRect frame = [self frame];
	
	// Get the width and height
	int frameWidth = frame.size.width;
	
	int totalRequiredPanelHeight = 0;
	
	// Add up the height that we need for the view based on number of activities
	NSArray* allActivities = [m_activitiesArrayController arrangedObjects];
	
	int counter=0;
	for(counter=0; counter<[allActivities count]; counter++)
	{
		totalRequiredPanelHeight += 60;
	}
		
	NSScrollView* scrollView = (NSScrollView*) [[self superview] superview];
	NSClipView* clipView = [scrollView contentView];
	NSRect clipViewFrame = [clipView frame];
	
	if(totalRequiredPanelHeight>clipViewFrame.size.height)
	{
		// Resize the view
		[self setFrameSize: NSMakeSize(frameWidth, totalRequiredPanelHeight)];
	}
	else
	{
		// Resize the view
		[self setFrameSize: NSMakeSize(frameWidth, clipViewFrame.size.height)];
	}

}

// **********************************************************************
//							prepareToDraw
// **********************************************************************
- (void) prepareToDraw
{	
	[m_activityPanelCoords removeAllObjects];
	[self calculateFrameSize];
}

#pragma mark ---- Activity Edit -----

// **********************************************************************
//						showActivityItemEditWindow
// **********************************************************************
- (IBAction) showActivityItemEditWindow: (id) sender
{
	// Create new window
	m_activityItemEditWindow = [[MAAttachedWindow alloc] initWithView: m_activityItemEditView 
									attachedToPoint: m_lastClickLocation
										   inWindow: [self window] 
											 onSide: MAPositionAutomatic 
										 atDistance: 0];
	
	// Set background color and border
	[m_activityItemEditWindow setBackgroundColor: 
		[NSColor colorWithDeviceRed:0.92 green:0.92 blue:0.92 alpha:1.0]];
		
	[m_activityItemEditWindow setBorderWidth: 4];
	
	// Load settings
	[self loadGoalSettings];
	
	// Attach the window
	[[self window] addChildWindow: m_activityItemEditWindow ordered:NSWindowAbove];
	
	// Make the edit window the key window
	[m_activityItemEditWindow makeKeyAndOrderFront: self];
}

// **********************************************************************
//							removeActivityItemEditWindow
// **********************************************************************
- (IBAction) removeActivityItemEditWindow: (id) sender
{
	if(m_activityItemEditWindow)
	{
		[[self window] removeChildWindow: m_activityItemEditWindow];
		[m_activityItemEditWindow orderOut:self];
		[m_activityItemEditWindow release];
		m_activityItemEditWindow = nil;
	}
	
	// Save changes to managed context
	[self saveChangesToManagedContext];
}

// **********************************************************************
//					showActivityEditWindowForSelection
// **********************************************************************
- (void) showActivityEditWindowForSelection: (NSNotification *) notification
{
	[self showActivityItemEditWindow: self];
}

#pragma mark ---- Drawing ----

// **********************************************************************
//								drawRect
// **********************************************************************
- (void) drawRect:(NSRect)rect 
{
	// ---------------------------------- Constants ----------------------------------------
	
	int kMarginLeftX = 10;
	int kMarginRightX = 10;
	int kMarginTopY = 10;
	
	// -------------------------------- Initialization -------------------------------------
	
	[self prepareToDraw];
	
	// -------------------------------- Background -----------------------------------------
	
	[[NSColor whiteColor] set];
    [NSBezierPath fillRect: [self bounds]];
	
	// Get the view dimensions
    NSRect viewFrame = [self frame];
    NSSize viewFrameSize = viewFrame.size;
    int viewWidth = viewFrameSize.width;
	int viewHeight = viewFrameSize.height;
	
	// The coordinates for drawing the user panel
	NSRect userPanelRect;
	
	int lastYCoord = viewHeight;
	
	// -------------------------------- Activity Panels ------------------------------------
	
	NSManagedObject* anActivity = nil;
	NSArray* allActivities = [m_activitiesArrayController arrangedObjects];
	for(anActivity in allActivities)
	{
		NSString* anActivityID = [[[anActivity objectID] URIRepresentation] absoluteString];
		
		userPanelRect.size.height = 30;
		userPanelRect.size.width = viewWidth - (kMarginLeftX + kMarginRightX);
		userPanelRect.origin.x = kMarginLeftX;
		userPanelRect.origin.y = lastYCoord - kMarginTopY - userPanelRect.size.height;
		
		// Set color based on whether the item is selected or not
		if([m_selectedActivityName isEqualToString: anActivityID])
		{
			m_lastClickLocation = NSMakePoint(userPanelRect.origin.x + userPanelRect.size.width/2,
				userPanelRect.origin.y + userPanelRect.size.height/2 + 75);
				
			[[NSColor colorWithCalibratedRed:0.85 green:0.85 blue:0.85 alpha:1.0] set];
		}
		else
			[[NSColor colorWithCalibratedRed:0.90 green:0.90 blue:0.90 alpha:1.0] set];
			
		NSBezierPath* rectBezier = [NSBezierPath bezierPathWithRoundedRect: userPanelRect xRadius: 5.0 yRadius: 5.0];
		[rectBezier fill];

		// -------------------------------- Activity Name ------------------------------------
		
		NSMutableDictionary* activityNameStringAttribsDict = [NSMutableDictionary dictionaryWithCapacity: 5];
		[activityNameStringAttribsDict setObject:[NSColor colorWithCalibratedRed:0.3 green:0.3 blue:0.3 alpha:1.0] forKey:NSForegroundColorAttributeName];
		[activityNameStringAttribsDict setObject:[NSFont fontWithName: @"Lucida Grande" size: 13] forKey: NSFontAttributeName];
		
		NSPoint activityNamePoint = NSMakePoint(userPanelRect.origin.x + 13, userPanelRect.origin.y + 8);
		[[anActivity valueForKey: @"name"] drawAtPoint: activityNamePoint withAttributes: activityNameStringAttribsDict];
		
		// -------------------------------- Goal Description ------------------------------------
		
		if([[anActivity valueForKey: @"goalEnabled"] boolValue])
		{
			int			goalValue = [[anActivity valueForKey: @"goalValue"] intValue];
			NSString*	goalType = [anActivity valueForKey: @"goalType"];
			NSString*	goalTimeUnit = [anActivity valueForKey: @"goalTimeUnit"];
			NSString*	goalFrequency = [anActivity valueForKey: @"goalFrequency"];

			NSString* goalString = [NSString stringWithFormat: @"Spend %@ %d %@ %@", goalType, goalValue, goalTimeUnit, goalFrequency];
			
			// Paragraph
			NSMutableParagraphStyle* paragraphStyle = [[NSMutableParagraphStyle alloc] init];
			[paragraphStyle setParagraphStyle:[NSParagraphStyle defaultParagraphStyle]];
			[paragraphStyle setAlignment:NSRightTextAlignment];
			[paragraphStyle setLineBreakMode:NSLineBreakByClipping];
			
			// String Attributes
			NSMutableDictionary* goalStringAttribsDict = [NSMutableDictionary dictionaryWithCapacity: 5];
			[goalStringAttribsDict setObject:[NSColor colorWithCalibratedRed:0.3 green:0.3 blue:0.3 alpha:1.0] forKey:NSForegroundColorAttributeName];
			[goalStringAttribsDict setObject:[NSFont fontWithName: @"Lucida Grande" size: 10] forKey: NSFontAttributeName];
			[goalStringAttribsDict setObject: paragraphStyle forKey: NSParagraphStyleAttributeName];
			
			[paragraphStyle release];
			
			NSRect goalStringRect;
			goalStringRect.origin.y = userPanelRect.origin.y + 7;
			goalStringRect.origin.x = userPanelRect.size.width - 200;
			goalStringRect.size.height = 14;
			goalStringRect.size.width = 200;
			 
			[goalString drawInRect: goalStringRect withAttributes: goalStringAttribsDict];
		}
		
		// -------------------------------- Save Drawing State -------------------------------
		
		// Store coordinates for panel
		[m_activityPanelCoords setObject: NSStringFromRect(userPanelRect) forKey: anActivityID];
		
		// Save y coord of previously drawn panel rect
		lastYCoord = userPanelRect.origin.y;
	}
}

// **********************************************************************
//							mouseDown
// **********************************************************************
- (void) mouseDown: (NSEvent*) event
{
	// Get the click location and convert it
    NSPoint clickPoint = [self convertPoint:[event locationInWindow] fromView: nil];
	
	// Go over all activities (coordinates)
	NSManagedObject* anActivity = nil;
	NSArray* allActivities = [m_activitiesArrayController arrangedObjects];
	for(anActivity in allActivities)
	{
		NSString* anActivityID = [[[anActivity objectID] URIRepresentation] absoluteString];
		NSRect activityRect = NSRectFromString([m_activityPanelCoords objectForKey: anActivityID]);
		
		// See if the click occurred within the panel rect
		if(NSMouseInRect(clickPoint, activityRect, NO))
		{	
			// We save the last location where the mouse was clicked, 
			// so that we know where to open the edit window
			m_lastClickLocation = [event locationInWindow];
			
			// ------------------------ Single Click -------------------------------
			
			// If we have only one click, display it in the main window
            if([event clickCount]==1)
            {
				m_selectedActivityName = anActivityID;
				[m_activitiesArrayController setSelectedObjects: [NSArray arrayWithObject: anActivity]];
				
				// Remove any previous ones
				[self removeActivityItemEditWindow: self];
            }
			
			// ------------------------ Double Click -------------------------------
			
			else if([event clickCount]==2)
			{
				m_selectedActivityName = anActivityID;
				[m_activitiesArrayController setSelectedObjects: [NSArray arrayWithObject: anActivity]];
				
				// --------------- Edit Window -----------------
				
				// Remove edit window
				[self removeActivityItemEditWindow: self];
				
				// Show edit window
				[self showActivityItemEditWindow: self];

			}
			
			[self setNeedsDisplay: YES];
			
			return;
		}
	}
	
	// Remove edit window
	[self removeActivityItemEditWindow: self];
				
	// Nothing selected
	m_selectedActivityName = @"";
	[m_activitiesArrayController setSelectedObjects: [NSArray array]];
	
	[self setNeedsDisplay: YES];
}

#pragma mark ---- Visuliaze ----

// **********************************************************************
//							visualizeActivity
// **********************************************************************
- (IBAction) visualizeActivity: (id) sender
{
	// Request view change to activities view
	[[NSNotificationCenter defaultCenter] postNotificationName: @"activitiesViewChangeRequest" object: m_selectedActivityName];
}

#pragma mark ---- Application ----

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
				NSLog(@"Slife: Error picking/inserting application in activity edit view");
		}

	}
}

// **********************************************************************
//							tableView:willDisplayCell
// **********************************************************************
- (void)tableView:(NSTableView *)aTableView willDisplayCell:(id)aCell forTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex 
{
	// ------------------- Applications Table View ------------------------------
	
	if(aTableView==m_activityItemEditApplicationsTableView)
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

#pragma mark ---- Goal ----

// **********************************************************************
//					enableGoalSettingControls
// **********************************************************************
- (void) enableGoalSettingControls
{
	[m_activityGoalValueTextField setEnabled: TRUE];
	[m_activityGoalTypePopUp setEnabled: TRUE];
	[m_activityGoalTimeUnitPopUp setEnabled: TRUE];
}

// **********************************************************************
//					disableGoalSettingControls
// **********************************************************************
- (void) disableGoalSettingControls
{
	[m_activityGoalValueTextField setEnabled: FALSE];
	[m_activityGoalTypePopUp setEnabled: FALSE];
	[m_activityGoalTimeUnitPopUp setEnabled: FALSE];
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
//							loadGoalSettings
// **********************************************************************
- (void) loadGoalSettings
{
	BOOL goalEnabled = FALSE;
	int goalValue = 0;
	NSString* goalType = nil;
	NSString* goalTimeUnit = nil;
	NSString* goalFrequency = nil;
	
	NSManagedObject* targetActivityObject = [m_activitiesArrayController selection];
	
	if(nil==targetActivityObject)
		return;
		
	goalEnabled = [[targetActivityObject valueForKey: @"goalEnabled"] boolValue];
	goalType = [targetActivityObject valueForKey: @"goalType"];
	goalValue = [[targetActivityObject valueForKey: @"goalValue"] intValue];
	goalTimeUnit = [targetActivityObject valueForKey: @"goalTimeUnit"];
	goalFrequency = [targetActivityObject valueForKey: @"goalFrequency"];
	
	[m_activityGoalValueTextField setIntValue: goalValue];
	[m_activityGoalTypePopUp selectItemWithTitle: goalType];
	[m_activityGoalTimeUnitPopUp selectItemWithTitle: goalTimeUnit];
	
	if(goalEnabled)
	{
		[m_activityGoalEnabledButton setState: NSOnState];
		[self enableGoalSettingControls];
	}
	else
	{
		[m_activityGoalEnabledButton setState: NSOffState];
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
	NSInteger goalEnabledState = [m_activityGoalEnabledButton state];
	
	// Pick up goal values from controls and apply them to their respective activities
	int			goalValue = [m_activityGoalValueTextField intValue];
	NSString*	goalType = [m_activityGoalTypePopUp titleOfSelectedItem];
	NSString*	goalTimeUnit = [m_activityGoalTimeUnitPopUp titleOfSelectedItem];
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

// **********************************************************************
//                     controlTextDidChange
// **********************************************************************
- (void) controlTextDidChange: (NSNotification *) aNotification
{
	[self saveGoalSettings];
}

#pragma mark ---- Item/Application To-Many Selection ----

// **********************************************************************
//                     objectValueForTableColumn
// **********************************************************************
- (id)tableView:(NSTableView *)aTableView 
	objectValueForTableColumn:(NSTableColumn *)aTableColumn 
	row:(int)rowIndex
{
	// ------------------- Items Table View ------------------------------
	
	if(aTableView==m_activityItemEditItemsTableView)
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
			return mixedSelectionNumber;
		}
		
		BOOL selected = NO;
		
		NSSet* activityItems = [[selectedActivities objectAtIndex:0] valueForKey: @"items"];
		if ([activityItems containsObject: itemAtRow])
		{
			selected = YES;
		}
		
		if (selected)
		{
			return selectedNumber;	
		}
	}
	
	// ------------------- Applications Table View ------------------------------
	
	else if(aTableView==m_activityItemEditApplicationsTableView)
	{
		// Find the applications at selected row
		NSArray* applications = [m_applicationsArrayController arrangedObjects];
		NSManagedObject* appAtRow = [applications objectAtIndex: rowIndex];
		
		NSString* identifier = [aTableColumn identifier];
		if (![identifier isEqualToString:@"checkedForActivity"])
		{
			// If not correctly identifier, just return object value
			return [appAtRow valueForKey: identifier];
		}
		
		// Get all applications for selected activity, if it contains item, check the box
		
		NSArray* selectedActivities = [m_activitiesArrayController selectedObjects];
		unsigned int selectionCount = [selectedActivities count];
		
		if (selectionCount == 0)
		{
			return mixedSelectionNumber;
		}
		
		BOOL selected = NO;
		
		NSSet* activityApplications = [[selectedActivities objectAtIndex:0] valueForKey: @"applications"];
		if ([activityApplications containsObject: appAtRow])
		{
			selected = YES;
		}
		
		if (selected)
		{
			return selectedNumber;	
		}

	}
	
	return unselectedNumber;
}

// **********************************************************************
//							setObjectValue
// **********************************************************************
- (void)tableView:(NSTableView *) aTableView 
	setObjectValue:(id) anObject 
	forTableColumn:(NSTableColumn *) aTableColumn 
	row:(int) rowIndex
{
	// ------------------- Items Table View ------------------------------
	
	if(aTableView==m_activityItemEditItemsTableView)
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
	
	// ------------------- Applications Table View ------------------------------
	
	else if(aTableView==m_activityItemEditApplicationsTableView)
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

@end
