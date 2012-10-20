
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


#import "SLGoalsView.h"
#import "SLUtilities.h"

// **********************************************************************
//							Constants
// **********************************************************************

extern int k_goalHeight;
extern int k_goalHeaderHeight;
extern int k_goalNameBarLineOffset;
extern int k_goalNameLeftOffset;
extern int k_goalNameRightOffset;
extern int k_goalViewBarLeftHorizontalOffset;
extern int k_goalViewBarRightHorizontalOffset;

extern int k_goalBarHeight;

extern int k_goalIconLeftOffset;
extern int k_goalIconHeight;
extern int k_goalIconWidth;

// **********************************************************************
//
//							SLGoalsView (Private)
//
// **********************************************************************

@interface SLGoalsView (Private)

- (void) dateChanged: (NSNotification *) notification;

- (void) drawActivities;
- (void) updateViewWidthAndHeight;

@end


// **********************************************************************
//
//								SLGoalsView
//
// **********************************************************************
@implementation SLGoalsView

#pragma mark --- Initialization ---

// **********************************************************************
//							initWithFrame
// **********************************************************************
- (id)initWithFrame:(NSRect)frame 
{
    self = [super initWithFrame:frame];
	
    if (self) 
	{
		// Initialize things
		m_activitiesGoalReachedPercentageDictionary = [NSMutableDictionary dictionaryWithCapacity: 5];
		m_activitiesGoalProgressStringDictionary = [NSMutableDictionary dictionaryWithCapacity: 5];
		m_numberOfActivities = 0;
		
		// Get the icons
		m_goalSuccessIconImage = [NSImage imageNamed: @"green-dot"];
		m_goalFailIconImage = [NSImage imageNamed: @"red-dot"];
		m_goalNoDataIconImage = [NSImage imageNamed: @"gray-dot"];
		
		// Scroll to top first time
		m_scrollToTop = NO;
    }
	
    return self;
}

// **********************************************************************
//							awakeFromNib
// **********************************************************************
- (void) awakeFromNib
{	
    // Update view width and height
    [self updateViewWidthAndHeight];
    
    // Initialize date stuff
    m_selectedDate = [NSCalendarDate date];
	
	[m_headerDateTextField setStringValue: [m_selectedDate descriptionWithCalendarFormat: @"%B %e, %Y"]];

	// Notifications for drawing optimization
    NSNotificationCenter* center = [NSNotificationCenter defaultCenter];
	
	// Date changed
	[center addObserver: self
			selector:@selector(dateChanged:)
			name: @"dateChanged" 
			object: nil];
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
	// Set new date
	m_selectedDate = [NSCalendarDate dateWithString: 
		[newDate descriptionWithCalendarFormat: @"%d %m %Y" timeZone:[NSTimeZone defaultTimeZone] locale: [[NSUserDefaults standardUserDefaults] dictionaryRepresentation]]
		calendarFormat: @"%d %m %Y"];
	
	// Set the date header
	[m_headerDateTextField setStringValue: [m_selectedDate descriptionWithCalendarFormat: @"%B %Y"]];
	
	// Refresh the view
	[self setNeedsDisplay: YES];
}

// **********************************************************************
//                        previousDayButtonClicked
// **********************************************************************
- (IBAction) previousDayButtonClicked: (id) sender
{
	// Notify date change - including this object
	[[NSNotificationCenter defaultCenter] postNotificationName: @"dateChanged" 
		object: [m_selectedDate dateByAddingYears:0 months:-1 days:0 hours:0 minutes:0 seconds:0]];
}

// **********************************************************************
//                         nextDayButtonClicked
// **********************************************************************
- (IBAction) nextDayButtonClicked: (id) sender
{
	// Notify date change - including this object
	[[NSNotificationCenter defaultCenter] postNotificationName: @"dateChanged" 
		object: [m_selectedDate dateByAddingYears:0 months:1 days:0 hours:0 minutes:0 seconds:0]];
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

#pragma mark --- Activity Loading ---

// **********************************************************************
//							loadActivities
// **********************************************************************
- (int) loadActivities
{
	// Reset the number of activities and activity objects array
	int numberOfActivities = 0;
	[m_activityGoalEnabledObjects release];
	
	NSManagedObjectContext* m_managedContext = [[NSApp delegate] managedObjectContext];
	
	if(m_managedContext)
	{
		NSFetchRequest* activityFetch = [[NSFetchRequest alloc] init];
		NSEntityDescription* activityEntity = [NSEntityDescription entityForName: @"Activity" inManagedObjectContext: m_managedContext];
		[activityFetch setEntity: activityEntity];
		
		NSPredicate* activityPredicate = [NSPredicate predicateWithFormat: @"goalEnabled == YES"];
		[activityFetch setPredicate: activityPredicate];
		
		NSError* error = nil;
		m_activityGoalEnabledObjects = [m_managedContext executeFetchRequest: activityFetch error: &error];
		
		if(m_activityGoalEnabledObjects!=nil)
		{
			[m_activityGoalEnabledObjects retain];

			numberOfActivities = [m_activityGoalEnabledObjects count];
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
//				loadActivityGoalReachedPercentageInMonth
// **********************************************************************
- (void) loadActivityGoalReachedPercentageInMonth
{
	int totalNumberOfDaysWithActivitiesRecordedInMonth = 0;
	int totalNumberOfDaysWithActivitiesRecordedInMonthWithGoalReached = 0;
	
	// Calculate number of days in month
	NSCalendarDate* firstDayOfMonth = [NSCalendarDate dateWithYear: [m_selectedDate yearOfCommonEra]
		month: [m_selectedDate monthOfYear] day: 1 hour: 10 minute: 0 second: 0 timeZone: [NSTimeZone systemTimeZone]];
	
	NSDateComponents* dateComponents = [[NSDateComponents alloc] init];
	[dateComponents setMonth:1];
	[dateComponents setDay:-1];
	NSDate* lastDayOfMonthDate = [[NSCalendar currentCalendar] dateByAddingComponents: dateComponents toDate: firstDayOfMonth options:0];
	[dateComponents release];
	
	NSDateComponents* lastDayOfMonthComponents = [[NSCalendar currentCalendar] components: NSDayCalendarUnit fromDate: lastDayOfMonthDate];
	int numberOfDaysInMonth = [lastDayOfMonthComponents day];
	
	// Go over all goal-enabled activities
	NSManagedObjectContext* managedContext = [[NSApp delegate] managedObjectContext];
	for(NSManagedObject* activityObject in m_activityGoalEnabledObjects)
	{
		totalNumberOfDaysWithActivitiesRecordedInMonth = 0;
		totalNumberOfDaysWithActivitiesRecordedInMonthWithGoalReached = 0;
	
		// Get goal duration for activity
		double activityGoalDuration = 0;
		BOOL activityGoalEnabled = [[activityObject valueForKey: @"goalEnabled"] boolValue];
		int activityGoalValue = [[activityObject valueForKey: @"goalValue"] intValue];
		NSString* activityGoalType = [activityObject valueForKey: @"goalType"];
		NSString* activityGoalTimeUnit = [activityObject valueForKey: @"goalTimeUnit"];
			
		if(activityGoalEnabled)
		{
			if([activityGoalTimeUnit isEqualToString: @"hours"])
				activityGoalDuration = activityGoalValue * 60 * 60;
			else if([activityGoalTimeUnit isEqualToString: @"minutes"])
				activityGoalDuration = activityGoalValue * 60;
		}
		
		// Fetch all ActivitiesRecorded for activity at given month
		NSFetchRequest* activityRecordedRequest = [[[NSFetchRequest alloc] init] autorelease];
		NSEntityDescription* activityRecordedEntity = [NSEntityDescription entityForName: @"ActivityRecorded" inManagedObjectContext: managedContext];
		[activityRecordedRequest setEntity: activityRecordedEntity];
		
		NSPredicate* activityRecordedPredicate = [NSPredicate predicateWithFormat: 
				@"activity.name == %@ AND targetMonth == %@ AND targetYear == %@", 
				[activityObject valueForKey: @"name"], [NSNumber numberWithInt: [m_selectedDate monthOfYear]], 
				[NSNumber numberWithInt: [m_selectedDate yearOfCommonEra]]];

		[activityRecordedRequest setPredicate: activityRecordedPredicate];
		
		NSError* error = nil;
		NSArray* activitiesRecordedForMonth = [managedContext executeFetchRequest:activityRecordedRequest error:&error];
		
		// Initialize array of durations/day
		int day=0;
		double activityRecordedDurationForDays[32];
		for(day=0; day<=31; day++)
			activityRecordedDurationForDays[day]=0;
		
		// Go over all activities recorded and categorize/sum up durations by day
		for(NSManagedObject* activityRecorded in activitiesRecordedForMonth)
		{
			// Get day
			NSNumber* activityRecordedDay = [activityRecorded valueForKey: @"targetDay"];
			int activityRecordedDayInt = [activityRecordedDay intValue];
			
			// Get duration
			NSNumber* activityRecordedDuration = [activityRecorded valueForKey: @"duration"];
			double activityRecordedDurationDouble = [activityRecordedDuration doubleValue];
			
			// There's duration for the day, count it as a new day
			if(activityRecordedDurationForDays[activityRecordedDayInt]==0)
				totalNumberOfDaysWithActivitiesRecordedInMonth++;
			
			// Categorize/sum up durations
			activityRecordedDurationForDays[activityRecordedDayInt] += activityRecordedDurationDouble;
		}
		
		// Go over all activities recorded and count how many represent a goal reached
		
		day = 0;
		for(day=0; day<=31; day++)
		{
			double activityRecordedDurationForDay = activityRecordedDurationForDays[day];
			
			if(activityRecordedDurationForDay==0)
				continue;
				
			if([activityGoalType isEqualToString: @"more than"])
			{
				if(activityRecordedDurationForDay>=activityGoalDuration)
					totalNumberOfDaysWithActivitiesRecordedInMonthWithGoalReached++;
			}
			else if([activityGoalType isEqualToString: @"less than"])
			{
				if(activityRecordedDurationForDay<=activityGoalDuration)
					totalNumberOfDaysWithActivitiesRecordedInMonthWithGoalReached++;
			}
		}
		
		// Calculate percentage of goals reached per month
		int percentageGoalsReached = 100 * (numberOfDaysInMonth - (totalNumberOfDaysWithActivitiesRecordedInMonth - 
				totalNumberOfDaysWithActivitiesRecordedInMonthWithGoalReached)) / numberOfDaysInMonth;
		
		// Save percentage in cache
		[m_activitiesGoalReachedPercentageDictionary setObject: [NSNumber numberWithInt: percentageGoalsReached] 
			forKey: [activityObject valueForKey: @"name"]];
		
		// Save goal progress string in cache
		NSString* activityGoalProgressString = [NSString stringWithFormat: @"Goal completed in %d of %d days this month", 
				(numberOfDaysInMonth - (totalNumberOfDaysWithActivitiesRecordedInMonth - totalNumberOfDaysWithActivitiesRecordedInMonthWithGoalReached)), numberOfDaysInMonth];
			
		[m_activitiesGoalProgressStringDictionary setObject: activityGoalProgressString
			forKey: [activityObject valueForKey: @"name"]];
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
	
	// Calculate the amount of space that we need for the view.
	int idealHeight = m_numberOfActivities*k_goalHeight;
	
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
//					activitiesGoalPercentageCompare
// **********************************************************************
NSInteger activitiesGoalPercentageCompare(id obj1, id obj2, void* context)
{
	NSManagedObject* actObj1 = (NSManagedObject*) obj1;
	NSManagedObject* actObj2 = (NSManagedObject*) obj2; 
	NSDictionary* actGoalReachedPercentageDictionary = (NSDictionary*) context;
	
	NSNumber* actObjGoalReachedPercentage1 = [actGoalReachedPercentageDictionary objectForKey: [actObj1 valueForKey: @"name"]];
	NSNumber* actObjGoalReachedPercentage2 = [actGoalReachedPercentageDictionary objectForKey: [actObj2 valueForKey: @"name"]];
	
    int v1 = [actObjGoalReachedPercentage1 intValue];
    int v2 = [actObjGoalReachedPercentage2 intValue];
	
    if (v1 < v2)
		return NSOrderedDescending;
    else if (v1 > v2)
		return NSOrderedAscending;
    else
        return NSOrderedSame;
}

#pragma mark --- Drawing ---

// **********************************************************************
//							drawActivityGoals
// **********************************************************************
- (void) drawActivityGoals
{
	[m_activitiesGoalReachedPercentageDictionary removeAllObjects];
	[m_activitiesGoalProgressStringDictionary removeAllObjects];
		
	// ---------------------- Compute activity goals reached percentage in month ---------------------------
	
	[self loadActivityGoalReachedPercentageInMonth];
	
	// Calculate how much height for each area
    int goalDrawingAreaHeight = k_goalHeight;
	
	// A counter we use to set the Y location for each event category and icon
	int yRowOffset = 1;
	
	// Sanity check
	if(m_activityGoalEnabledObjects)
	{
		// Avoid doing work if not needed
		if([m_activityGoalEnabledObjects count]>0)
		{
			// Create a new dictionary with attribute for percentage labels
			NSMutableDictionary* percentageLabelStringAttribsDict = [NSMutableDictionary dictionaryWithCapacity: 5];
			[percentageLabelStringAttribsDict setObject:[NSColor colorWithCalibratedRed:0.3 green:0.3 blue:0.3 alpha:1.0] forKey:NSForegroundColorAttributeName];
			[percentageLabelStringAttribsDict setObject:[NSFont fontWithName: @"Lucida Grande" size: 14] forKey: NSFontAttributeName];
			
			// Create a new dictionary with attribute for bar duration labels
			NSMutableDictionary* goalProgressStringAttribsDict = [NSMutableDictionary dictionaryWithCapacity: 5];
			[goalProgressStringAttribsDict setObject:[NSColor colorWithCalibratedRed:0.6 green:0.6 blue:0.6 alpha:1.0] forKey:NSForegroundColorAttributeName];
			[goalProgressStringAttribsDict setObject:[NSFont fontWithName: @"Lucida Grande" size: 10] forKey: NSFontAttributeName];

			// -------------------------------- Activity Header Date --------------------------------
			
			[m_headerDateTextField setStringValue: [m_selectedDate descriptionWithCalendarFormat: @"%B %Y"]];
			
			// -------------------------------- Go Over All Activities --------------------------------
			
			// Sort array by total duration
			NSArray* sortedApplicationObjects = [m_activityGoalEnabledObjects sortedArrayUsingFunction: 
				activitiesGoalPercentageCompare context: m_activitiesGoalReachedPercentageDictionary];
			
			// Go over every application in the store
			for(NSManagedObject* activityObject in sortedApplicationObjects)
			{
				NSString* activityName = [activityObject valueForKey: @"name"];
	
				// -------------------------- Draw Activity Name ---------------------------------
				
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
				[activityNameStringAttribsDict setObject:[NSColor blackColor] forKey:NSForegroundColorAttributeName];
				[activityNameStringAttribsDict setObject:[NSFont fontWithName: @"Lucida Grande" size: 11] forKey: NSFontAttributeName];
				[activityNameStringAttribsDict setObject: paragraphStyle forKey: NSParagraphStyleAttributeName];

				// Create the drawing rect
				NSRect activityNameRect;
				
				// Set the parameters for the drawing rect for the activity name
				activityNameRect.origin.x = k_goalNameLeftOffset;
				
				activityNameRect.origin.y = m_viewHeight - k_goalHeaderHeight - 
					(goalDrawingAreaHeight*yRowOffset) + (goalDrawingAreaHeight/2) - 12;
					
				activityNameRect.size.width = k_goalNameBarLineOffset - k_goalNameLeftOffset - k_goalNameRightOffset;
				activityNameRect.size.height = 18;
		
				[activityNameFormatted drawInRect: activityNameRect withAttributes: activityNameStringAttribsDict];
				
				// ---------------------- Draw the bar ------------------------
				
				// Goal reached bar first
				int goalReachedPercentage = [[m_activitiesGoalReachedPercentageDictionary objectForKey: activityName] intValue];
				int goalNotReachedPercentage = 100 - goalReachedPercentage;
				
				int goalReachedBarXCoordinate = k_goalNameBarLineOffset + k_goalViewBarLeftHorizontalOffset;
				
				int goalReachedBarYCoordinate = m_viewHeight - k_goalHeaderHeight - 
					(goalDrawingAreaHeight*yRowOffset) + (2*goalDrawingAreaHeight/3) - (k_goalBarHeight/2);
			
				int goalReachedBarWidth = (m_viewWidth - goalReachedBarXCoordinate - k_goalViewBarRightHorizontalOffset) * goalReachedPercentage / 100;
				
				NSRect goalReachedRect = NSMakeRect(goalReachedBarXCoordinate, goalReachedBarYCoordinate, goalReachedBarWidth, k_goalBarHeight);
				
				[[NSColor colorWithCalibratedRed:0.454 green:0.705 blue:0.478 alpha:1.0] set];
				
				//[NSBezierPath fillRect: goalReachedRect];
				
				NSBezierPath* rectBezier = [NSBezierPath bezierPathWithRoundedRect: goalReachedRect xRadius: 3.0 yRadius: 3.0];
				[rectBezier fill];
				
				// Now the goal non-reached bar
				int goalNotReachedBarXCoordinate = k_goalNameBarLineOffset + k_goalViewBarLeftHorizontalOffset + goalReachedBarWidth;
				
				int goalNotReachedBarYCoordinate = m_viewHeight - k_goalHeaderHeight - 
					(goalDrawingAreaHeight*yRowOffset) + (2*goalDrawingAreaHeight/3) - (k_goalBarHeight/2);
			
				int goalNotReachedBarWidth = (m_viewWidth - goalReachedBarXCoordinate - k_goalViewBarRightHorizontalOffset) * goalNotReachedPercentage / 100;
					
				NSRect goalNotReachedRect = NSMakeRect(goalNotReachedBarXCoordinate, goalNotReachedBarYCoordinate, goalNotReachedBarWidth, k_goalBarHeight);
				
				[[NSColor colorWithCalibratedRed: 0.898 green: 0.898 blue: 0.898 alpha:1.0] set];
				
				//[NSBezierPath fillRect: goalNotReachedRect];
				
				rectBezier = [NSBezierPath bezierPathWithRoundedRect: goalNotReachedRect xRadius: 3.0 yRadius: 3.0];
				[rectBezier fill];

				// ------------------ Draw the goal label -----------------
				
				// Get the goal progress string
				NSString* goalProgressString = [m_activitiesGoalProgressStringDictionary objectForKey: activityName];
				
				// Create the drawing rect
				NSRect goalProgressLabelRect;
				
				// Set the parameters for the drawing rect for the bar duration label
				goalProgressLabelRect.origin.x = k_goalNameBarLineOffset + k_goalViewBarLeftHorizontalOffset;
				
				
				goalProgressLabelRect.origin.y = m_viewHeight - k_goalHeaderHeight - 
					(goalDrawingAreaHeight*yRowOffset) + 8;
					
				goalProgressLabelRect.size.width = 300;
				goalProgressLabelRect.size.height = 15;
		
				// Draw the labels
				if(goalProgressString)
					[goalProgressString drawInRect: goalProgressLabelRect withAttributes: goalProgressStringAttribsDict];	

	
				// ------------------ Draw the percentange label -----------------
				
				// Create the drawing rect
				NSRect percentageLabelRect;
				
				// Set the parameters for the drawing rect for the bar duration label
				percentageLabelRect.origin.x = goalReachedBarXCoordinate + goalReachedBarWidth + goalNotReachedBarWidth + 10;
				
				percentageLabelRect.origin.y = m_viewHeight - k_goalHeaderHeight - 
					(goalDrawingAreaHeight*yRowOffset) + (2*goalDrawingAreaHeight/3) - 5;
					
				percentageLabelRect.size.width = 200;
				percentageLabelRect.size.height = 16;
		
		
				NSString* percentageStringValue = [[m_activitiesGoalReachedPercentageDictionary objectForKey: activityName] stringValue];
				NSString* percentageString = [NSString stringWithFormat: @"%@%%", percentageStringValue];
				
				// Draw the labels
				if(percentageString)
					[percentageString drawInRect: percentageLabelRect withAttributes: percentageLabelStringAttribsDict];
				
				// -------------------------- Draw Activity Icon ---------------------------------
				
				int goalIconXCoordinate = k_goalIconLeftOffset;
				
				int goalIconYCoordinate = m_viewHeight - k_goalHeaderHeight - 
					(goalDrawingAreaHeight*yRowOffset) + (goalDrawingAreaHeight/2) - 6;
				
				int percentageIntValue = [[m_activitiesGoalReachedPercentageDictionary objectForKey: activityName] intValue];
				NSImage* iconImage = nil;
				
				if(percentageIntValue>=50)
					iconImage = m_goalSuccessIconImage;
				else if(percentageIntValue>0)
					iconImage = m_goalFailIconImage;
				else
					iconImage = m_goalNoDataIconImage;
				
				[iconImage compositeToPoint:
					NSMakePoint(goalIconXCoordinate, goalIconYCoordinate) 
					operation:NSCompositeSourceOver];

				// Decrement the Y location icon offset
				yRowOffset++;
			}
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
	// Load activities
	m_numberOfActivities = [self loadActivities];
	
	// -------------------------------- Frame & Size -----------------------------------------
	
	[self calculateFrameSize];
    [self updateViewWidthAndHeight];
    
    // -------------------------------- Background -----------------------------------------
    
    // Draw the background of the timeline
    [[NSColor whiteColor] set];
    [NSBezierPath fillRect: [self bounds]];
	
	if(m_numberOfActivities==0)
	{
		NSString* title = @"There Are No Goals";
		NSString* subtitle = @"You can define goals for each one of your Activities";
		
		// Create a new dictionary with attribute for title label
		NSMutableDictionary* titleLabelStringAttribsDict = [NSMutableDictionary dictionaryWithCapacity: 5];
		[titleLabelStringAttribsDict setObject:[NSColor colorWithCalibratedRed:0.3 green:0.3 blue:0.3 alpha:1.0] forKey:NSForegroundColorAttributeName];
		[titleLabelStringAttribsDict setObject:[NSFont fontWithName: @"Lucida Grande" size: 14] forKey: NSFontAttributeName];
		
		// Create a new dictionary with attribute for subtitle label
		NSMutableDictionary* subtitleLabelStringAttribsDict = [NSMutableDictionary dictionaryWithCapacity: 5];
		[subtitleLabelStringAttribsDict setObject:[NSColor colorWithCalibratedRed:0.5 green:0.5 blue:0.5 alpha:1.0] forKey:NSForegroundColorAttributeName];
		[subtitleLabelStringAttribsDict setObject:[NSFont fontWithName: @"Lucida Grande" size: 12] forKey: NSFontAttributeName];
		
		// Coords for the title and subtitle
		NSPoint titleMessagePoint = NSMakePoint(([self bounds].size.width/2) - 90, ([self bounds].size.height/2));
		NSPoint subtitleMessagePoint = NSMakePoint(([self bounds].size.width/2) - 165, ([self bounds].size.height/2) - 20);
		
		[title drawAtPoint: titleMessagePoint withAttributes: titleLabelStringAttribsDict];
		[subtitle drawAtPoint: subtitleMessagePoint withAttributes: subtitleLabelStringAttribsDict];
		
		return;
	}
	
    // --------------------- Activities Separator -----------------------------------------
     
    // Set the color of the divisor lines
    [[NSColor colorWithCalibratedRed:0.8 green:0.8 blue:0.8 alpha:1.0] set];
    
    // Calculate how much height for each event type area
    int goalDrawingAreaHeight = k_goalHeight;
    
	// We draw one less divisor line than the number of rows
	int totalDivisors = m_numberOfActivities;
	
	// Loop and draw the divisors
	int counter;
	for(counter=1; counter<=totalDivisors; counter++)
	{
		[NSBezierPath strokeLineFromPoint:NSMakePoint(0, m_viewHeight - k_goalHeaderHeight - (goalDrawingAreaHeight*counter) + 0.5) 
			toPoint:NSMakePoint(m_viewWidth, m_viewHeight - k_goalHeaderHeight - (goalDrawingAreaHeight*counter) + 0.5)];
	}
    
	// ------------------------ Draw Activities ------------------------------------------
	
	// Draw the activities
	[self drawActivityGoals];
	
	// -------------------------------- Vertical Separator -----------------------------------------
	
	// Make points
    NSPoint b = NSMakePoint(0, 0);
    NSPoint e = NSMakePoint(0, 0);
    
    // Set the color for the lines
    [[NSColor colorWithCalibratedRed:0.898 green:0.898 blue:0.898 alpha:1.0] set];
    
	// Set the begining point
    b.y = 0;
    b.x = k_goalNameBarLineOffset + 0.5;
    
    // Set the final point
    e.x = b.x;
    e.y = m_viewHeight;
        
    // Draw the first line segment
    [NSBezierPath strokeLineFromPoint: b toPoint: e];
	
	// -------------------------------- Scroll To Top -----------------------------------------
	
	// Scroll to the top if first time
	if(m_scrollToTop)
	{
		[self scrollToTop];
		m_scrollToTop = NO;
	}
}

@end
