
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

#import "SLActivitiesView.h"
#import "SLUtilities.h"	

// **********************************************************************
//							Preferences
// **********************************************************************

extern NSString* k_Pref_DebugOn_Key;

// **********************************************************************
//							Constants
// **********************************************************************

extern int k_dayRange;
extern int k_monthRange;

extern int k_activityHeight;
extern int k_activityHeaderHeight;
extern int k_activityNameBarLineOffset;
extern int k_activityNameLeftOffset;
extern int k_activityNameRightOffset;
extern int k_activityViewBarLeftHorizontalOffset;
extern int k_activityViewBarRightHorizontalOffset;

extern int k_activityBarHeight;

extern int k_activityGoalIconLeftOffset;
extern int k_activityGoalIconHeight;
extern int k_activityGoalIconWidth;

static NSString* activitiesChangeContext = @"activitiesChangeContext";

// **********************************************************************
//
//						SLActivitiesView (Private)
//
// **********************************************************************

@interface SLActivitiesView (Private)

- (void) dateChanged: (NSNotification *) notification;

- (void) drawActivities;
- (void) updateViewWidthAndHeight;
- (void) setNeedsDisplayOptimized;

@end


// **********************************************************************
//
//							SLActivitiesView
//
// **********************************************************************

@implementation SLActivitiesView

#pragma mark --- Initialization & Support ---


// **********************************************************************
//							initWithFrame
// **********************************************************************
- (id)initWithFrame:(NSRect)frame 
{
    self = [super initWithFrame:frame];
	
    if (self) 
	{
		// Debug
		NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
		m_debugState = [[defaults objectForKey: k_Pref_DebugOn_Key] boolValue];
		
		// Initialize things
		m_activityDurationDictionary = [NSMutableDictionary dictionaryWithCapacity: 5];
		m_activityTeamOwnedDictionary = [NSMutableDictionary dictionaryWithCapacity: 5];
		m_activityRect = [NSMutableDictionary dictionaryWithCapacity: 5];
		m_activitySelectedID = @"";
		m_activityNameSelected = nil;
		m_numberOfActivities = 0;
		
		// Get the hour label hilite and gray backgrounds
        m_goalSuccessImage = [[NSImage alloc] initWithData:[[NSImage imageNamed: @"green-dot"] TIFFRepresentation]];
		m_goalFailImage = [[NSImage alloc] initWithData:[[NSImage imageNamed: @"red-dot"] TIFFRepresentation]];
		m_activityImage = [[NSImage alloc] initWithData:[[NSImage imageNamed: @"gray-dot"] TIFFRepresentation]];
		
		// Scroll to top first time
		m_scrollToTop = YES;
		
		// No cache
		m_useCachedEventsOnRedraw = FALSE;
    }
	
    return self;
}

// **********************************************************************
//							awakeFromNib
// **********************************************************************
- (void) awakeFromNib
{	
	// Get managed context
	m_managedContext = [[NSApp delegate] managedObjectContext];
	
    // Update view width and height
    [self updateViewWidthAndHeight];
    
    // Initialize date stuff
    m_selectedDate = [NSCalendarDate date];
	
	m_selectedDateRange = k_dayRange;
	[m_dayControlButton setState: NSOnState];
	[m_monthControlButton setState: NSOffState];
	
	[m_activityDateTextField setStringValue: [m_selectedDate descriptionWithCalendarFormat: @"%B %e, %Y"]];
	[m_activitySelectedNameTextField setStringValue: @""];

	// Listen to changes in the selection of activities
	[m_activitiesArrayController addObserver: self
		forKeyPath: @"arrangedObjects"
		options:0
		context: activitiesChangeContext];
		
	// Notifications for drawing optimization
    NSNotificationCenter* center = [NSNotificationCenter defaultCenter] ;
	
	// Scrolling
	NSScrollView* scrollView = (NSScrollView*) [[self superview] superview];
	NSClipView* clipView = [scrollView contentView];
	[clipView setPostsBoundsChangedNotifications: YES];
    [center addObserver: self
            selector: @selector(scrollingIsHappening:)
            name: NSViewBoundsDidChangeNotification
            object: clipView];
	
	// Window resize
	[center addObserver: self
            selector: @selector(windowResizeIsHappening:)
            name: NSWindowDidResizeNotification
            object: [self window]];
		
	// Date changed
	[center addObserver: self
			selector:@selector(dateChanged:)
			name: @"dateChanged" 
			object: nil];
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
	// Observing changes in activities array to sync activities with UI
	
	if(context == activitiesChangeContext)
	{
		// If the last activity on the list is unnamed, it means the user just created it,
		// so we want to select it.
		
		NSArray* allActivities = [m_activitiesArrayController arrangedObjects];
		NSManagedObject* lastActivity = [allActivities lastObject];
		
		if([[lastActivity valueForKey: @"name"] isEqualToString: @"Unnamed Activity"])
		{
			m_activitySelectedID = [[[lastActivity objectID] URIRepresentation] absoluteString];
			m_activityNameSelected = [lastActivity valueForKey: @"name"];
		}
		
		[self setNeedsDisplay: YES];
				
		return;
	}
	
	[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

#pragma mark --- Date ---

// **********************************************************************
//							dateChanged
// **********************************************************************
- (void) dateChanged: (NSNotification *) notification
{
	// Set new date
	
	NSCalendarDate* newDate = [notification object];
	
	if(nil==newDate)
		return;
	
	[self setDate: newDate];
}

// **********************************************************************
//								setDate
// **********************************************************************
- (void) setDate:(NSCalendarDate*) newDate
{	
	// Get value from date picker and make it the current date
	m_selectedDate = [NSCalendarDate dateWithString:
		[newDate descriptionWithCalendarFormat: @"%d %m %Y" timeZone: [NSTimeZone defaultTimeZone] locale: [[NSUserDefaults standardUserDefaults] dictionaryRepresentation]]
		calendarFormat: @"%d %m %Y"];
	
	// Set the date header
	if(m_selectedDateRange==k_dayRange)
	{
		[m_activityDateTextField setStringValue: [m_selectedDate descriptionWithCalendarFormat: @"%B %e, %Y"]];
	}
	else if(m_selectedDateRange==k_monthRange)
	{
		[m_activityDateTextField setStringValue: [m_selectedDate descriptionWithCalendarFormat: @"%B %Y"]];
	}

	// Refresh the view
	[self setNeedsDisplay: YES];
}

// **********************************************************************
//                        previousDayButtonClicked
// **********************************************************************
- (IBAction) previousDayButtonClicked: (id) sender
{
	if(m_selectedDateRange==k_dayRange)
	{
		// Notify date change - including this object
		[[NSNotificationCenter defaultCenter] postNotificationName: @"dateChanged" 
			object: [m_selectedDate dateByAddingYears:0 months:0 days:-1 hours:0 minutes:0 seconds:0]];
	}
	else if(m_selectedDateRange==k_monthRange)
	{
		// Notify date change - including this object
		[[NSNotificationCenter defaultCenter] postNotificationName: @"dateChanged" 
			object: [m_selectedDate dateByAddingYears:0 months:-1 days:0 hours:0 minutes:0 seconds:0]];
	}
}

// **********************************************************************
//                         nextDayButtonClicked
// **********************************************************************
- (IBAction) nextDayButtonClicked: (id) sender
{
	if(m_selectedDateRange==k_dayRange)
	{
		// Notify date change - including this object
		[[NSNotificationCenter defaultCenter] postNotificationName: @"dateChanged" 
			object: [m_selectedDate dateByAddingYears:0 months:0 days:1 hours:0 minutes:0 seconds:0]];
	}
	else if(m_selectedDateRange==k_monthRange)
	{
		// Notify date change - including this object
		[[NSNotificationCenter defaultCenter] postNotificationName: @"dateChanged" 
			object: [m_selectedDate dateByAddingYears:0 months:1 days:0 hours:0 minutes:0 seconds:0]];
	}
}

// **********************************************************************
//                          todayButtonClicked
// **********************************************************************
- (IBAction) todayButtonClicked: (id) sender
{
	// Notify date change - including this object
	[[NSNotificationCenter defaultCenter] postNotificationName: @"dateChanged" 
		object: [NSCalendarDate date]];
}

#pragma mark --- Activity Loading & Selection ---

// **********************************************************************
//							loadActivities
// **********************************************************************
- (int) loadActivities
{
	// Reset the number of activities and activity objects array
	int numberOfActivities = 0;
	[m_activityObjects release];
	
	if(m_managedContext)
	{
		NSFetchRequest* activityFetch = [[NSFetchRequest alloc] init];
		NSEntityDescription* activityEntity = [NSEntityDescription entityForName: @"Activity" inManagedObjectContext: m_managedContext];
		[activityFetch setEntity: activityEntity];
		
		NSError* error = nil;
		m_activityObjects = [m_managedContext executeFetchRequest: activityFetch error: &error];
		
		if(m_activityObjects!=nil)
		{
			[m_activityObjects retain];

			numberOfActivities = [m_activityObjects count];
		}
		else
		{
			NSLog(@"Slife: Error fetching activity objects when drawing Activities View");
		}
	}
	else
	{
		NSLog(@"Slife: Managed Context is nil when fetching activities to draw Activities View");
	}
	
	// Return number
	return numberOfActivities;
}

// **********************************************************************
//				loadActivityDurationForSelectedDateRange
// **********************************************************************
- (void) loadActivityDurationForSelectedDateRange
{
	NSManagedObjectContext* managedContext = [[NSApp delegate] managedObjectContext];
	for(NSManagedObject* activityObject in m_activityObjects)
	{
		// ------------------------------ Activity Recorded & Duration --------------------------------
		
		NSFetchRequest* activityRecordedRequest = [[[NSFetchRequest alloc] init] autorelease];
		NSEntityDescription* activityRecordedEntity = [NSEntityDescription entityForName: @"ActivityRecorded" inManagedObjectContext: managedContext];
		[activityRecordedRequest setEntity: activityRecordedEntity];
		
		NSPredicate* activityRecordedPredicate = nil;
		if(m_selectedDateRange==k_dayRange)
		{
			activityRecordedPredicate = [NSPredicate predicateWithFormat: 
				@"activity.name == %@ AND targetDay == %@ AND targetMonth == %@ AND targetYear == %@", 
				[activityObject valueForKey: @"name"], [NSNumber numberWithInt: [m_selectedDate dayOfMonth]],
				[NSNumber numberWithInt: [m_selectedDate monthOfYear]], [NSNumber numberWithInt: [m_selectedDate yearOfCommonEra]]];
		}
		else if(m_selectedDateRange==k_monthRange)
		{
			activityRecordedPredicate = [NSPredicate predicateWithFormat: 
				@"activity.name == %@ AND targetMonth == %@ AND targetYear == %@", 
				[activityObject valueForKey: @"name"], [NSNumber numberWithInt: [m_selectedDate monthOfYear]], 
				[NSNumber numberWithInt: [m_selectedDate yearOfCommonEra]]];
		}
		
		[activityRecordedRequest setPredicate: activityRecordedPredicate];
		
		double totalSecondsForActivitiesRecorded = 0;
		NSError* error = nil;
		NSArray* activitiesRecordedForSelectedDate = [managedContext executeFetchRequest:activityRecordedRequest error:&error];
		
		for(NSManagedObject* activityRecorded in activitiesRecordedForSelectedDate)
		{
			NSNumber* activityRecordedDuration = [activityRecorded valueForKey: @"duration"];
			totalSecondsForActivitiesRecorded += [activityRecordedDuration doubleValue];
		}
		
		[m_activityDurationDictionary setObject: [NSNumber numberWithDouble: totalSecondsForActivitiesRecorded] forKey: [activityObject valueForKey: @"name"]];
		
		if(totalSecondsForActivitiesRecorded>m_longestDurationActivityEvents)
			m_longestDurationActivityEvents = totalSecondsForActivitiesRecorded;
			
		// ------------------------------ Goal Status ---------------------------------------
		
		[m_activityTeamOwnedDictionary setObject: [activityObject valueForKey: @"teamOwned"] forKey: [activityObject valueForKey: @"name"]];
	}
}

#pragma mark --- Drawing Support ---

// **********************************************************************
//							scrollToTop
// **********************************************************************
- (void) scrollToTop
{
	NSScrollView* scrollView = (NSScrollView*) [[self superview] superview];
	NSPoint topPoint = NSMakePoint(0.0, [[scrollView documentView] bounds].size.height);
	[[scrollView documentView] scrollPoint: topPoint];
}

// **********************************************************************
//							setNeedsDisplayOptimized
// **********************************************************************
- (void) setNeedsDisplayOptimized
{
	// We want to use the cached events
	m_useCachedEventsOnRedraw = TRUE;
	
	// Request refresh
	[self setNeedsDisplay: YES];
}

// **********************************************************************
//						updateViewWidthAndHeight
// **********************************************************************
- (void) updateViewWidthAndHeight
{
	// Get the view dimensions
    NSRect frame = [self frame];
    NSSize frameSize = frame.size;
	
    m_viewWidth = frameSize.width;
	m_viewHeight = frameSize.height;
}

// **********************************************************************
//						calculateFrameSize
// **********************************************************************
- (void) calculateFrameSize
{
	// Get the view dimensions
    NSRect frame = [self frame];
    NSSize frameSize = frame.size;
	
	// Get the width and height
    int frameWidth = frameSize.width;
	int frameHeight = frameSize.height;
	
	// Calculate the amount of space that we need for the view. We know that about 64 is the ideal 
	// height for each event type row. So we multiply how many more scripts we have by 64. Then we 
	// add the height for the top divider line. That should give us what we need in terms of space.
	int idealHeight = m_numberOfActivities*k_activityHeight;
	
	// Check if we need to resize the view
	if(frameHeight<idealHeight)
	{
		// Calculate the delta between the current and ideal sizes
		int idealCurrentSizeDelta = idealHeight - frameHeight;
		
		// Resize the view
		[self setFrameSize: NSMakeSize(frameWidth, frameHeight + idealCurrentSizeDelta)];
	}
	else
	{
		// Resize the view
		//[self setFrameSize: NSMakeSize(frameWidth, idealHeight)];
	}
}

// **********************************************************************
//						activitiesDurationCompare
// **********************************************************************
NSInteger activitiesCompare(id obj1, id obj2, void* context)
{
	NSManagedObject* actObj1 = (NSManagedObject*) obj1;
	NSManagedObject* actObj2 = (NSManagedObject*) obj2;
	NSArray* sortDictionaries = (NSArray*) context;
	
	NSDictionary* actDurationDictionary = (NSDictionary*) [sortDictionaries objectAtIndex: 0];
	NSDictionary* actTeamOwnedDictionary = (NSDictionary*) [sortDictionaries objectAtIndex: 1];
	
	NSNumber* actObjDuration1 = [actDurationDictionary objectForKey: [actObj1 valueForKey: @"name"]];
	NSNumber* actObjDuration2 = [actDurationDictionary objectForKey: [actObj2 valueForKey: @"name"]];
	NSNumber* actObjTeamOwned1 = [actTeamOwnedDictionary objectForKey: [actObj1 valueForKey: @"name"]];
	NSNumber* actObjTeamOwned2 = [actTeamOwnedDictionary objectForKey: [actObj2 valueForKey: @"name"]];
	
    double v1 = [actObjDuration1 doubleValue];
    double v2 = [actObjDuration2 doubleValue];
	BOOL g1 = [actObjTeamOwned1 boolValue];
	BOOL g2 = [actObjTeamOwned2 boolValue];
	
	if((g1==YES) && (g2==YES))
	{
		if (v1 < v2)
			return NSOrderedDescending;
		else if (v1 > v2)	
			return NSOrderedAscending;
		else
			return NSOrderedSame;
	}
	else if((g1==YES) && (g2==NO))
	{
		return NSOrderedAscending;
	}
	else if((g1==NO) && (g2==YES))
	{
		return NSOrderedDescending;
	}
	else
	{
		if (v1 < v2)
			return NSOrderedDescending;
		else if (v1 > v2)	
			return NSOrderedAscending;
		else
			return NSOrderedSame;
	}
	
	if (v1 < v2)
		return NSOrderedDescending;
	else if (v1 > v2)	
		return NSOrderedAscending;
	else
		return NSOrderedSame;
	
}

#pragma mark --- Drawing ---

// **********************************************************************
//							drawActivities
// **********************************************************************
- (void) drawActivities
{
	if(!m_useCachedEventsOnRedraw || ([[m_activityDurationDictionary allValues] count]==0))
	{
		[m_activityDurationDictionary removeAllObjects];
		[m_activityTeamOwnedDictionary removeAllObjects];
		
		m_longestDurationActivityEvents = 0;
		
		// ---------------------- Compute total and longest duration of events for activity given time range ---------------------------
		
		[self loadActivityDurationForSelectedDateRange];
	}
	
	// Calculate how much height for each event type area
    int activityDrawingAreaHeight = k_activityHeight;
	
	// A counter we use to set the Y location for each event category and icon
	int yLocationIconOffset = 1;
	
	// Sanity check
	if(m_activityObjects)
	{
		// Avoid during work if not needed
		if([m_activityObjects count]>0)
		{
			// Store duration and team owned dictionaries in array to send to compare function
			NSArray* sortDictionaries = [NSArray arrayWithObjects: 
				m_activityDurationDictionary, m_activityTeamOwnedDictionary, nil];
			
			// Sort array by total duration
			NSArray* sortedApplicationObjects = [m_activityObjects sortedArrayUsingFunction: 
				activitiesCompare context: sortDictionaries];
			
			// Create a new dictionary with attribute for bar duration labels
			NSMutableDictionary* barDurationLabelStringAttribsDict = [NSMutableDictionary dictionaryWithCapacity: 5];
			[barDurationLabelStringAttribsDict setObject:[NSColor colorWithCalibratedRed:0.5 green:0.5 blue:0.5 alpha:1.0] forKey:NSForegroundColorAttributeName];
			[barDurationLabelStringAttribsDict setObject:[NSFont fontWithName: @"Lucida Grande" size: 11] forKey: NSFontAttributeName];
			
			// Create a new dictionary with attribute for bar duration labels
			NSMutableDictionary* goalLabelStringAttribsDict = [NSMutableDictionary dictionaryWithCapacity: 5];
			[goalLabelStringAttribsDict setObject:[NSColor colorWithCalibratedRed:0.6 green:0.6 blue:0.6 alpha:1.0] forKey:NSForegroundColorAttributeName];
			[goalLabelStringAttribsDict setObject:[NSFont fontWithName: @"Lucida Grande" size: 10] forKey: NSFontAttributeName];

			// -------------------------------- Activity Header Date --------------------------------
			
			if(m_selectedDateRange==k_dayRange)
			{
				[m_activityDateTextField setStringValue: [m_selectedDate descriptionWithCalendarFormat: @"%B %e, %Y"]];
			}
			else if(m_selectedDateRange==k_monthRange)
			{
				[m_activityDateTextField setStringValue: [m_selectedDate descriptionWithCalendarFormat: @"%B %Y"]];
			}
			
			// Go over every application in the store
			for(NSManagedObject* activityObject in sortedApplicationObjects)
			{
				NSString* activityID = [[[activityObject objectID] URIRepresentation] absoluteString];
				NSString* activityName = [activityObject valueForKey: @"name"];
				
				// ---------------------- Selected Activity ------------------------
				
				if([m_activitySelectedID isEqualToString: activityID])
				{
					// ---------------------- Draw background ------------------------
					
					[[NSColor colorWithCalibratedRed:0.9412 green:0.9608 blue:0.9843 alpha:1.0] set];
					
					NSRect activityRect;
					activityRect.origin.x = 0;
					activityRect.origin.y = m_viewHeight - k_activityHeaderHeight - (activityDrawingAreaHeight*yLocationIconOffset) + 1;
					activityRect.size.height = activityDrawingAreaHeight - 1;
					activityRect.size.width = m_viewWidth;
					
					[NSBezierPath fillRect: activityRect];
					
					// ---------------------- Set Activity Name in Header ------------------------
					
					[m_activitySelectedNameTextField setStringValue: activityName];
				}
	
				// ---------------------------- Bar and Duration Label ------------------------------------
				
				NSString* barDurationString = nil;
				double totalSecondsForActivityEvents = [[m_activityDurationDictionary objectForKey: activityName] doubleValue];
				if(totalSecondsForActivityEvents>0)
				{
					barDurationString = [SLUtilities convertSecondsToTimeString: totalSecondsForActivityEvents withRounding: NO];
				}

				if(totalSecondsForActivityEvents>0)
				{
					// ---------------------- Draw the bar ------------------------

					int activityBarXCoordinate = k_activityNameBarLineOffset + k_activityViewBarLeftHorizontalOffset;
					
					int activityBarYCoordinate = m_viewHeight - k_activityHeaderHeight - 
						(activityDrawingAreaHeight*yLocationIconOffset) + (activityDrawingAreaHeight/2) - (k_activityBarHeight/2);
						
					int longestActivityBarWidth = m_viewWidth - activityBarXCoordinate - k_activityViewBarRightHorizontalOffset;
				
					int activityBarWidth = longestActivityBarWidth / m_longestDurationActivityEvents * totalSecondsForActivityEvents;
					
					if(activityBarWidth<12)
						activityBarWidth=12;
						
					NSRect theRect = NSMakeRect(activityBarXCoordinate, activityBarYCoordinate, activityBarWidth, k_activityBarHeight);
					
					[[NSColor colorWithCalibratedRed:0.898 green:0.898 blue:0.898 alpha:1.0] set];
					
					//[NSBezierPath fillRect: theRect];
					NSBezierPath* rectBezier = [NSBezierPath bezierPathWithRoundedRect: theRect xRadius: 3.0 yRadius: 3.0];
					[rectBezier fill];
					
					// ------------------ Draw the duration label -----------------
					
					// Create the drawing rect
					NSRect barDurationLabelRect;
					
					// Set the parameters for the drawing rect for the bar duration label
					barDurationLabelRect.origin.x = activityBarXCoordinate + activityBarWidth + 10;
					
					barDurationLabelRect.origin.y = m_viewHeight - k_activityHeaderHeight - 
						(activityDrawingAreaHeight*yLocationIconOffset) + (activityDrawingAreaHeight/2) - 5;
						
					barDurationLabelRect.size.width = 200;
					barDurationLabelRect.size.height = 12;
			
					// Draw the labels
					if(barDurationString)
						[barDurationString drawInRect: barDurationLabelRect withAttributes: barDurationLabelStringAttribsDict];
				}
				
				// -------------------------------- Get Activity Goal Duration And String---------------------------
								
				int k_goalNotSpecified = 0;
				int k_goalAchieved = 1;
				int k_goalNotAchieved = 2;
				
				int goalDelta = 0;
				int goalState = k_goalNotSpecified;
				double goalSecondsForActivityEvents = 0;
				
				NSMutableString* goalLabelString = [NSMutableString stringWithCapacity: 5];
				[goalLabelString setString: @"No goal specified"];
				
				// Get goal values
				
				BOOL goalForView = FALSE;
				
				BOOL activityGoalEnabled = [[activityObject valueForKey: @"goalEnabled"] boolValue];
				int activityGoalValue = [[activityObject valueForKey: @"goalValue"] intValue];
				NSString* activityGoalType = [activityObject valueForKey: @"goalType"];
				NSString* activityGoalTimeUnit = [activityObject valueForKey: @"goalTimeUnit"];
				NSString* activityGoalFrequency = [activityObject valueForKey: @"goalFrequency"];
				
				// See the activity has a goal for this view
				if((m_selectedDateRange==k_dayRange) && ([activityGoalFrequency isEqualToString: @"daily"]))
					goalForView = TRUE;
					
				if(activityGoalEnabled && goalForView)
				{
					// Calculate goal time in seconds
					if([activityGoalTimeUnit isEqualToString: @"hours"])
						goalSecondsForActivityEvents = activityGoalValue * 60 * 60;
					else if([activityGoalTimeUnit isEqualToString: @"minutes"])
						goalSecondsForActivityEvents = activityGoalValue * 60;
				
					// If there's goal time, put together the goal label
					if(goalSecondsForActivityEvents>0)
					{
						if([activityGoalType isEqualToString: @"more than"])
						{
							if(goalSecondsForActivityEvents>totalSecondsForActivityEvents)
							{
								goalDelta = goalSecondsForActivityEvents - totalSecondsForActivityEvents;
								NSString* goalDeltaString = [SLUtilities convertSecondsToTimeString: goalDelta withRounding: NO];
								
								[goalLabelString setString: goalDeltaString];
								[goalLabelString appendString: @" until goal"];
								
								goalState = k_goalNotAchieved;
							}
							else
							{
								goalDelta = totalSecondsForActivityEvents - goalSecondsForActivityEvents;
								NSString* goalDeltaString = [SLUtilities convertSecondsToTimeString: goalDelta withRounding: NO];
								
								[goalLabelString setString: goalDeltaString];
								[goalLabelString appendString: @" over goal"];
								
								goalState = k_goalAchieved;
							}
						}
						else if([activityGoalType isEqualToString: @"less than"])
						{
							if(goalSecondsForActivityEvents>totalSecondsForActivityEvents)
							{
								goalDelta = goalSecondsForActivityEvents - totalSecondsForActivityEvents;
								NSString* goalDeltaString = [SLUtilities convertSecondsToTimeString: goalDelta withRounding: NO];
								
								[goalLabelString setString: goalDeltaString];
								[goalLabelString appendString: @" until goal"];
								
								goalState = k_goalAchieved;
							}
							else
							{
								goalDelta = totalSecondsForActivityEvents - goalSecondsForActivityEvents;
								NSString* goalDeltaString = [SLUtilities convertSecondsToTimeString: goalDelta withRounding: NO];
								
								[goalLabelString setString: goalDeltaString];
								[goalLabelString appendString: @" over goal"];
								
								goalState = k_goalNotAchieved;
							}
						}
					}
					
					// ------------------ Draw the goal label -----------------
				
					// Create the drawing rect
					NSRect goalBarDurationLabelRect;
					
					// Set the parameters for the drawing rect for the bar duration label
					goalBarDurationLabelRect.origin.x = k_activityNameLeftOffset;
					
					
					goalBarDurationLabelRect.origin.y = m_viewHeight - k_activityHeaderHeight - 
						(activityDrawingAreaHeight*yLocationIconOffset) + (5*activityDrawingAreaHeight/16) - 5;
						
					goalBarDurationLabelRect.size.width = 200;
					goalBarDurationLabelRect.size.height = 15;
			
					// Draw the labels
					if(goalLabelString)
						[goalLabelString drawInRect: goalBarDurationLabelRect withAttributes: goalLabelStringAttribsDict];	
				}
				
				// ------------------ Draw the goal indicator ----------------------
					
				int activityGoalBarXCoordinate = k_activityGoalIconLeftOffset;
				int activityGoalBarYCoordinate = 0;
				
				if(activityGoalEnabled && goalForView)
				{
					activityGoalBarYCoordinate = m_viewHeight - k_activityHeaderHeight - 
						(activityDrawingAreaHeight*yLocationIconOffset) + (2*activityDrawingAreaHeight/3) - 7;
				}
				else
				{
					activityGoalBarYCoordinate = m_viewHeight - k_activityHeaderHeight - 
						(activityDrawingAreaHeight*yLocationIconOffset) + (activityDrawingAreaHeight/2) - 7;
				}
				
				if(goalState==k_goalAchieved)
				{
					// Draw the goal success image
					[m_goalSuccessImage compositeToPoint:
						NSMakePoint(activityGoalBarXCoordinate, activityGoalBarYCoordinate) 
						operation:NSCompositeSourceOver];
				}
				else if(goalState==k_goalNotAchieved)
				{
					// Draw the goal fail image
					[m_goalFailImage compositeToPoint:
						NSMakePoint(activityGoalBarXCoordinate, activityGoalBarYCoordinate) 
						operation:NSCompositeSourceOver];
				}
				else if(goalState==k_goalNotSpecified)
				{
					// Draw the goal fail image
					[m_activityImage compositeToPoint:
						NSMakePoint(activityGoalBarXCoordinate, activityGoalBarYCoordinate) 
						operation:NSCompositeSourceOver];
				}
				
				// -------------------------- Draw Activity Name ---------------------------------
				
				NSColor* activityNameColor = [NSColor colorWithCalibratedRed:0.2 green:0.2 blue:0.2 alpha:1.0];
				if([[activityObject valueForKey: @"teamOwned"] boolValue])
					activityNameColor = [NSColor blackColor];
					
				// Limit chars
				NSString* activityNameFormatted = [SLUtilities limitString: activityName toNumberOfCharacters: 25];
				
				// Create a paragraph style
				NSMutableParagraphStyle* paragraphStyle = [[NSMutableParagraphStyle alloc] init];
				
				// Set the paragraph style
				[paragraphStyle setParagraphStyle:[NSParagraphStyle defaultParagraphStyle]];
				[paragraphStyle setAlignment:NSLeftTextAlignment];
				[paragraphStyle setLineBreakMode:NSLineBreakByClipping];

				// Create a new dictionary with attribute for activity names
				NSMutableDictionary* activityNameStringAttribsDict = [NSMutableDictionary dictionaryWithCapacity: 5];
				[activityNameStringAttribsDict setObject: activityNameColor forKey:NSForegroundColorAttributeName];
				[activityNameStringAttribsDict setObject:[NSFont fontWithName: @"Lucida Grande" size: 11] forKey: NSFontAttributeName];
				[activityNameStringAttribsDict setObject: paragraphStyle forKey: NSParagraphStyleAttributeName];

				// Create the drawing rect
				NSRect activityNameRect;
				
				// Set the parameters for the drawing rect for the activity name
				activityNameRect.origin.x = k_activityNameLeftOffset;
				
				if(activityGoalEnabled && goalForView)
				{
					activityNameRect.origin.y = m_viewHeight - k_activityHeaderHeight - 
						(activityDrawingAreaHeight*yLocationIconOffset) + (2*activityDrawingAreaHeight/3) - 12;
				}
				else
				{
					activityNameRect.origin.y = m_viewHeight - k_activityHeaderHeight - 
						(activityDrawingAreaHeight*yLocationIconOffset) + (activityDrawingAreaHeight/2) - 12;
				}
				
				activityNameRect.size.width = k_activityNameBarLineOffset - k_activityNameLeftOffset - k_activityNameRightOffset;
				activityNameRect.size.height = 18;
		
				[activityNameFormatted drawInRect: activityNameRect withAttributes: activityNameStringAttribsDict];

				
				// ------------------ Save Activity Rect -----------------
					
				NSRect activityRect;
				activityRect.origin.x = 0;
				activityRect.origin.y = m_viewHeight - k_activityHeaderHeight - (activityDrawingAreaHeight*yLocationIconOffset);
				activityRect.size.height = activityDrawingAreaHeight;
				activityRect.size.width = m_viewWidth;
				
				[m_activityRect setObject: NSStringFromRect(activityRect) forKey: activityID];
					
				// Decrement the Y location icon offset
				yLocationIconOffset++;
			}
			
			// ---------------------- No Selection, Reset Name in Activity Header ------------------------
			
			if((nil==m_activitySelectedID)||([m_activitySelectedID length]==0))
				[m_activitySelectedNameTextField setStringValue: @""];
		}
	}
	else
	{
		NSLog(@"Slife: Activity objects are nil when trying to draw app icons");
	}
}

// **********************************************************************
//								drawRect
// **********************************************************************
- (void)drawRect:(NSRect)rect
{	
	[m_activityRect removeAllObjects];
	
	m_numberOfActivities = [self loadActivities];
	[self calculateFrameSize];
    [self updateViewWidthAndHeight];
    
    // -------------------------------- Background -----------------------------------------
    
    // Draw the background of the timeline
    [[NSColor whiteColor] set];
    [NSBezierPath fillRect: [self bounds]];
			
    // --------------------- Activities Separator -----------------------------------------
     
    // Set the color of the divisor lines
    [[NSColor colorWithCalibratedRed:0.8 green:0.8 blue:0.8 alpha:1.0] set];
    
    // Calculate how much height for each event type area
    int activityDrawingAreaHeight = k_activityHeight;
    
	// We draw one less divisor line than the number of rows
	int totalDivisors = m_numberOfActivities;
	
	// Loop and draw the divisors
	int counter;
	for(counter=1; counter<=totalDivisors; counter++)
	{
		[NSBezierPath strokeLineFromPoint:NSMakePoint(0, m_viewHeight - k_activityHeaderHeight - (activityDrawingAreaHeight*counter) + 0.5) 
			toPoint:NSMakePoint(m_viewWidth, m_viewHeight - k_activityHeaderHeight - (activityDrawingAreaHeight*counter) + 0.5)];
	}
    
	// ------------------------ Draw Activities ------------------------------------------
	
	// Draw the activities
	[self drawActivities];
	
	// -------------------------------- Vertical Separator -----------------------------------------
	
	// Make points
    NSPoint b = NSMakePoint(0, 0);
    NSPoint e = NSMakePoint(0, 0);
    
    // Set the color for the lines
    [[NSColor colorWithCalibratedRed:0.898 green:0.898 blue:0.898 alpha:1.0] set];
    
	// Set the begining point
    b.y = 0;
    b.x = k_activityNameBarLineOffset + 0.5;
    
    // Set the final point
    e.x = b.x;
    e.y = m_viewHeight;
        
    // Draw the first line segment
    [NSBezierPath strokeLineFromPoint: b toPoint: e];
	
	// ---------------------------- Cache Reset --------------------------------
	
	m_useCachedEventsOnRedraw = FALSE;
	
	// ---------------------------- Refresh Bar Graph --------------------------------
	
	[m_activityBarGraphView setNeedsDisplay: YES];
	
	// -------------------------------- Scroll To Top -----------------------------------------
	
	// Scroll to the top if first time
	if(m_scrollToTop)
	{
		[self performSelector: @selector(scrollToTop) withObject: nil afterDelay: 0];
		m_scrollToTop = NO;
	}
}

#pragma mark --- Event Handling ---

// **********************************************************************
//							dateRangeChanged
// **********************************************************************
- (IBAction) dateRangeChanged: (id) sender
{
	NSButton* theButton = (NSButton*) sender;
	
	if(nil==theButton)
		return;
		
	if(theButton==m_dayControlButton)
	{
		if([theButton state]==NSOnState)
		{
			[m_monthControlButton setState: NSOffState];
		}
		else
		{
			[m_monthControlButton setState: NSOnState];
		}
		
		m_selectedDateRange = k_dayRange;
	}
	else if(theButton==m_monthControlButton)
	{
		if([theButton state]==NSOnState)
		{
			[m_dayControlButton setState: NSOffState];
		}
		else
		{
			[m_dayControlButton setState: NSOnState];
		}
		
		m_selectedDateRange = k_monthRange;
	}
	
	[self setNeedsDisplay: YES];
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
		NSRect activityRect = NSRectFromString([m_activityRect objectForKey: anActivityID]);
		
		// See if the click occurred within the rect
		if(NSMouseInRect(clickPoint, activityRect, NO))
		{
			// Mark selected object
			m_activitySelectedID = anActivityID;
			m_activityNameSelected = [anActivity valueForKey: @"name"];
			[m_activitiesArrayController setSelectedObjects: [NSArray arrayWithObject: anActivity]];
			
			// ------------------------ Double Click -------------------------------
			
			if([event clickCount]==2)
			{
				// Change date to today
				[[NSNotificationCenter defaultCenter] postNotificationName: @"showInfoWindowRequest" 
					object: [NSCalendarDate date]];
			}
			
			// Request redraw
			[self setNeedsDisplayOptimized];
			
			// We are done here
			return;
		}
	}
	
	// Nothing selected
	m_activitySelectedID = @"";
	m_activityNameSelected = nil;
	[m_activitiesArrayController setSelectedObjects: [NSArray array]];
	
	[self setNeedsDisplayOptimized];

}

// **********************************************************************
//                          scrollingIsHappening
// **********************************************************************
- (void) scrollingIsHappening: (NSNotification *) notification
{	
	// We want to use the cached events
	m_useCachedEventsOnRedraw = TRUE;
}

// **********************************************************************
//                          windowResizeIsHappening
// **********************************************************************
- (void) windowResizeIsHappening: (NSNotification *) notification
{
	// We want to use the cached events
	m_useCachedEventsOnRedraw = TRUE;
}

#pragma mark --- BarGraph Datasource ---

// **********************************************************************
//							valueForBar
// **********************************************************************
- (int) barGraph: (SLBarGraphView*) aBarGraphView valueForBar: (int) barNumber 
{	
	// ---------------------- Compute total and longest duration of events for activity given time range ---------------------------
	
	int selectedDay = [m_selectedDate dayOfMonth];
	int selectedMonth = [m_selectedDate monthOfYear];
	int selectedYear = [m_selectedDate yearOfCommonEra];
	
	NSManagedObjectContext* managedContext = [[NSApp delegate] managedObjectContext];
	
	NSFetchRequest* activityRecordedRequest = [[[NSFetchRequest alloc] init] autorelease];
	NSEntityDescription* activityRecordedEntity = [NSEntityDescription entityForName: @"ActivityRecorded" inManagedObjectContext: managedContext];
	[activityRecordedRequest setEntity: activityRecordedEntity];
	
	NSPredicate* activityRecordedPredicate = nil;
	if(m_selectedDateRange==k_dayRange)
	{
		activityRecordedPredicate = [NSPredicate predicateWithFormat: 
			@"targetHour == %@ AND targetDay == %@ AND targetMonth == %@ AND targetYear == %@", 
			[NSNumber numberWithInt: barNumber], [NSNumber numberWithInt: selectedDay],
			[NSNumber numberWithInt: selectedMonth], [NSNumber numberWithInt: selectedYear]];
	}
	else if(m_selectedDateRange==k_monthRange)
	{
		activityRecordedPredicate = [NSPredicate predicateWithFormat: 
			@"targetDay == %@ AND targetMonth == %@ AND targetYear == %@", 
			[NSNumber numberWithInt: barNumber+1], [NSNumber numberWithInt: selectedMonth], 
			[NSNumber numberWithInt: selectedYear]];
	}
	
	[activityRecordedRequest setPredicate: activityRecordedPredicate];
	
	double totalSecondsForActivitiesRecorded = 0;
	NSError* error = nil;
	NSArray* activityRecordsForSelectedDate = [managedContext executeFetchRequest: activityRecordedRequest error:&error];
	
	for(NSManagedObject* activityRecorded in activityRecordsForSelectedDate)
	{
		NSNumber* activityRecordedDuration = [activityRecorded valueForKey: @"duration"];
		totalSecondsForActivitiesRecorded += [activityRecordedDuration doubleValue];
	}
	
	return totalSecondsForActivitiesRecorded;
}

// **********************************************************************
//						valueForHighlightBar
// **********************************************************************
- (int) barGraph: (SLBarGraphView*) aBarGraphView valueForHighlightBar: (int) barNumber 
{	
	if(nil==m_activityNameSelected)
		return 0;
	
	int selectedDay = [m_selectedDate dayOfMonth];
	int selectedMonth = [m_selectedDate monthOfYear];
	int selectedYear = [m_selectedDate yearOfCommonEra];
	
	// ---------------------- Compute total and longest duration of events for activity given time range ---------------------------
		
	NSManagedObjectContext* managedContext = [[NSApp delegate] managedObjectContext];
	
	NSFetchRequest* activityRecordedRequest = [[[NSFetchRequest alloc] init] autorelease];
	NSEntityDescription* activityRecordedEntity = [NSEntityDescription entityForName: @"ActivityRecorded" inManagedObjectContext: managedContext];
	[activityRecordedRequest setEntity: activityRecordedEntity];
	
	NSPredicate* activityRecordedPredicate = nil;
	if(m_selectedDateRange==k_dayRange)
	{
		activityRecordedPredicate = [NSPredicate predicateWithFormat: 
			@"activity.name == %@ AND targetHour == %@ AND targetDay == %@ AND targetMonth == %@ AND targetYear == %@", 
			m_activityNameSelected, [NSNumber numberWithInt: barNumber], [NSNumber numberWithInt: selectedDay],
			[NSNumber numberWithInt: selectedMonth], [NSNumber numberWithInt: selectedYear]];
	}
	else if(m_selectedDateRange==k_monthRange)
	{
		activityRecordedPredicate = [NSPredicate predicateWithFormat: 
			@"activity.name == %@ AND targetDay == %@ AND targetMonth == %@ AND targetYear == %@", 
			m_activityNameSelected, [NSNumber numberWithInt: barNumber+1], [NSNumber numberWithInt: selectedMonth], 
			[NSNumber numberWithInt: selectedYear]];
	}
	
	[activityRecordedRequest setPredicate: activityRecordedPredicate];
	
	double totalSecondsForActivitiesRecorded = 0;
	NSError* error = nil;
	NSArray* eventFromAppForSelectedDate = [managedContext executeFetchRequest: activityRecordedRequest error:&error];
	
	for(NSManagedObject* activityRecorded in eventFromAppForSelectedDate)
	{
		NSNumber* activityRecordedDuration = [activityRecorded valueForKey: @"duration"];
		totalSecondsForActivitiesRecorded += [activityRecordedDuration doubleValue];
	}
	
	return totalSecondsForActivitiesRecorded;
}

// **********************************************************************
//								labelForBar
// **********************************************************************
- (NSString*) barGraph: (SLBarGraphView*) aBarGraphView labelForBar: (int) barNumber 
{
	NSString* labelString = nil;
	
	if(m_selectedDateRange==k_dayRange)
	{
		int hour;
		if(barNumber<=23)
			hour = barNumber;
		else
			hour = barNumber - 24;
		
		if([m_activityBarGraphView bounds].size.width>700)
		{
			if(hour==0)
				labelString = [NSString stringWithFormat:@"12a"];
			else if(hour<12)
				labelString = [NSString stringWithFormat:@"%da",hour];
			else if(hour==12)
				labelString = [NSString stringWithFormat:@"12p"];
			else
				labelString = [NSString stringWithFormat:@"%dp",hour-12];
		}
		else
		{
			if(hour==0)
				labelString = [NSString stringWithFormat:@"12"];
			else if(hour<12)
				labelString = [NSString stringWithFormat:@"%d",hour];
			else if(hour==12)
				labelString = [NSString stringWithFormat:@"12"];
			else
				labelString = [NSString stringWithFormat:@"%d",hour-12];
		}
	}
	else if(m_selectedDateRange==k_monthRange)
	{
		labelString = [NSString stringWithFormat: @"%d", barNumber + 1];
	}
	
	return labelString;
}

// **********************************************************************
//						numberOfBarsForBarGraph
// **********************************************************************
- (int) numberOfBarsForBarGraph: (SLBarGraphView*) aBarGraphView
{
	int numberOfBars = 0;
	
	if(m_selectedDateRange==k_dayRange)
	{
		numberOfBars = 24;
	}
	else if(m_selectedDateRange==k_monthRange)
	{
		numberOfBars = 31;
	}
	
	return numberOfBars;

}

// **********************************************************************
//						labelForBarGraph
// **********************************************************************
- (NSString*) labelForBarGraph: (SLBarGraphView*) aBarGraphView
{
	NSString* labelString = nil;
	
	if(m_selectedDateRange==k_dayRange)
	{
		labelString = [m_selectedDate descriptionWithCalendarFormat: @"Activities For %B %e, %Y"]; 
	}
	else if(m_selectedDateRange==k_monthRange)
	{
		labelString = [m_selectedDate descriptionWithCalendarFormat: @"Activities For %B %Y"];
	}
		
	return labelString;
}

@end
