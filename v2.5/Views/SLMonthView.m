
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

#import "SLMonthView.h"
#import "SLUtilities.h"

// **********************************************************************
//							Constants
// **********************************************************************

// Number of days for each month - one for leap year and one for no leap year
static int kMonthDaysArray[ 2 ][ 13 ] = 
{
	{ 0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }, 
	{ 0, 31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
};

// Week day labels
static NSString* kWeekDayLabelsArray[ 2 ][ 7 ] = 
{
	{ @"Sunday", @"Monday", @"Tuesday", @"Wednesday", @"Thursday", @"Friday", @"Saturday" }, 
	{ @"Sun", @"Mon", @"Tue", @"Wed", @"Thu", @"Fri", @"Sat" }
};

@interface SLMonthView (Private)

- (void) dateChanged: (NSNotification *) notification;

@end

@implementation SLMonthView

#pragma mark --- Initialization ---

// **********************************************************************
//						initWithFrame
// **********************************************************************
- (id)initWithFrame:(NSRect)frameRect
{
    if ((self = [super initWithFrame:frameRect]) != nil) 
    {
        // Initialize the member variables
		
		m_applicationVerticalOffset = [NSMutableDictionary dictionaryWithCapacity: 10];
		
        m_daySelected = 0;
        m_daysInMonth = 0;
        m_firstDayDateWeekDay = 0;
		
		// The number of event rows we have right now is zero
		m_numberOfActiveEventSources = 0;
		
		// Nothing for search string yet
		m_searchString = @"";
		m_searchTextFieldTimer = nil;
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
    
    // Set the date to the current date for now
    [self setDate: [NSCalendarDate date]];
	
	// Date changed observation
	NSNotificationCenter* center = [NSNotificationCenter defaultCenter];
	
	[center addObserver: self
			selector:@selector(dateChanged:)
			name: @"dateChanged" 
			object: nil];
}

// **********************************************************************
// 		 		dealloc
// **********************************************************************
- (void) dealloc
{
    // Get rid of the date
    [m_date release];
    
    // Call super dealloc
    [super dealloc];
}

#pragma mark --- Event Handling ---

// **********************************************************************
//                          acceptsFirstResponder
// **********************************************************************
- (BOOL) acceptsFirstResponder 
{ 
    return YES;
}

// **********************************************************************
//							mouseDown
// **********************************************************************
- (void) mouseDown: (NSEvent*) event
{
    // The counter for the loop
    int counter=0;
        
    // Let's assume that a day was not selected
    m_daySelected = 0;
    
    // Get the click location and convert it
    NSPoint clickPoint = [self convertPoint:[event locationInWindow] fromView: nil];
    
    // Iterate and check if the mouse down ocurred in any of the selected month's day
    for(counter=1; counter<32; counter++)
    {
        // See if the click happened inside any of the days
        if(NSMouseInRect(clickPoint, m_dayRect[counter], NO))
        {
			// Notify date change - including this object
			[[NSNotificationCenter defaultCenter] postNotificationName: @"dateChanged" 
				object: [NSCalendarDate dateWithYear:[m_date yearOfCommonEra] month:[m_date monthOfYear] 
					day:counter hour:0 minute:0 second:0 timeZone:[NSTimeZone defaultTimeZone]]];
			
			// Ask for a screen refresh
			[self setNeedsDisplay: YES];
	
			// Check for double-click
			if([event clickCount]>1)
            {
				// Request view change to day view
				[[NSNotificationCenter defaultCenter] postNotificationName: @"dayViewChangeRequest" object: nil];
            }

            break;
        } 
    }
}

// **********************************************************************
//                     controlTextDidChange
// **********************************************************************
- (void)controlTextDidChange: (NSNotification *)aNotification
{
	m_searchString = [[m_searchTextField stringValue] lowercaseString];
	
	// Make sure that there is a timer
    if(m_searchTextFieldTimer)
    {
        // kill the timer
        [m_searchTextFieldTimer invalidate];
        [m_searchTextFieldTimer release];
        m_searchTextFieldTimer = nil;
    }
    
    // Create and start the searchField timer
    m_searchTextFieldTimer = [[NSTimer scheduledTimerWithTimeInterval: 0.3
        target: self selector: @selector(redrawAfterSearchKeystrokeDelay:) userInfo: nil 
        repeats: NO] retain];

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
- (void) setDate: (NSCalendarDate*) newDate
{
    // Check if we need to do this work
    if( newDate && (![m_date isEqual: newDate]) )
    {
        // Store the new date
        [m_date release];
        m_date = [newDate copy];
        
        // See how many days there are in the month
        m_daysInMonth = kMonthDaysArray[ [self isLeapYear: [m_date yearOfCommonEra]]][ [m_date monthOfYear] ];
        
        // Get a date for the first of the month
        NSCalendarDate* firstDayDate = [NSCalendarDate dateWithYear:[m_date yearOfCommonEra] 
            month:[m_date monthOfYear] day:1 hour:0 minute:0 second:0 timeZone:[NSTimeZone defaultTimeZone]];
        
        // Get the weekday of the first of the month
        m_firstDayDateWeekDay = [firstDayDate dayOfWeek];
		
		// Set the date in the header
		[m_dateTextField setStringValue: [m_date descriptionWithCalendarFormat: @"%B %Y"]];
    }
    
    // Set the selected day
    m_daySelected = [m_date dayOfMonth];
	
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
		object: [m_date dateByAddingYears:0 months:-1 days:0 hours:0 minutes:0 seconds:0]];
}

// **********************************************************************
//                         nextDayButtonClicked
// **********************************************************************
- (IBAction) nextDayButtonClicked: (id) sender
{		
	// Notify date change - including this object
	[[NSNotificationCenter defaultCenter] postNotificationName: @"dateChanged" 
		object: [m_date dateByAddingYears:0 months:1 days:0 hours:0 minutes:0 seconds:0]];
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

#pragma mark --- Drawing Support ---

// **********************************************************************
//                  redrawAfterSearchKeystrokeDelay
// **********************************************************************
- (void) redrawAfterSearchKeystrokeDelay: (NSTimer*) theTimer
{
    // kill the searchField timer
    [m_searchTextFieldTimer invalidate];
    [m_searchTextFieldTimer release];
    m_searchTextFieldTimer = nil;
    
    // Update the current view
    [self setNeedsDisplay: YES];
}

// **********************************************************************
//								isOpaque
// **********************************************************************
- (BOOL) isOpaque
{
    // Drawing optimization
    return YES;
}

// **********************************************************************
//                              isLeapYear
// **********************************************************************
- (BOOL) isLeapYear: (int) year
{
    // The leap year bool we return with the result
    BOOL leapYear = FALSE;
    
    // Check to see if it's divisible by 4
    if((year%4)==0)
    {
        // Ok, we assume it's a leap year then
        leapYear = TRUE;
        
        // Check if it's divisible by 100
        if((year%100)==0)
        {
            // Check if it's divisible by 400
            if(year%400)
            {
                // Not, so it's not a leap year
                leapYear = FALSE;
            }
        }
    }
    
    return leapYear;
}

// **********************************************************************
//                          isSixRowCalendar
// **********************************************************************
- (BOOL) isSixRowCalendar
{
    // Based on the day of the week for the first day of the month, calculate
    // how many days fall in the first row of the calendar
    int daysTillEndOfWeek = 7 - m_firstDayDateWeekDay;
    
    // Three rows in the calendar are always filled - That's 21 days. If all days in
    // the month minus those three rows minus the number of the days that fall in the
    // first rows equals a number that is more than 7, then we need a sixth row.
    if( (m_daysInMonth - 21 - daysTillEndOfWeek) > 7 )
        return YES;
    else
        return NO;
}

// **********************************************************************
//                          clearDayRectValues
// **********************************************************************
- (void) clearDayRectValues
{
    // the counter for the loop
    int counter=0;
    
    // Iterate and clear all day rect values
    for(counter=0; counter<32; counter++)
    {
        m_dayRect[counter].origin.x = 0.0;
        m_dayRect[counter].origin.y = 0.0;
        m_dayRect[counter].size.width = 0.0;
        m_dayRect[counter].size.height = 0.0;
    }
}

// **********************************************************************
//					calculateNumberOfActiveEventSources
// **********************************************************************
- (int) calculateNumberOfActiveEventSources
{
	// Reset the number of event sources
	int numberOfSources = 0;
	
	NSManagedObjectContext* m_managedContext = [[NSApp delegate] managedObjectContext];
	
	if(m_managedContext)
	{
		NSFetchRequest* appFetch = [[NSFetchRequest alloc] init];
				
		NSEntityDescription* appEntity = [NSEntityDescription entityForName: @"Application" inManagedObjectContext: m_managedContext];
		NSPredicate* appPredicate = [NSPredicate predicateWithFormat: @"enabled == YES"];
		
		[appFetch setEntity: appEntity];
		[appFetch setPredicate: appPredicate];
		
		NSError* error = nil;
		NSArray* applicationObjects = [m_managedContext executeFetchRequest: appFetch error: &error];
		
		if(applicationObjects!=nil)
		{
			numberOfSources = [applicationObjects count];
		}
		else
		{
			NSLog(@"Slife: Error fetching application objects when drawing Day View");
		}
	}
	else
	{
		NSLog(@"Slife: Managed Context is nil when fetching applications to draw Day View");
	}
	
	// Return number
	return numberOfSources;
}


// **********************************************************************
// 		      updateViewWidthAndHeight
// **********************************************************************
- (void) updateViewWidthAndHeight
{
     // Get the view dimensions
    NSRect bounds = [self bounds];
    NSSize viewSize = bounds.size;
    m_viewWidth = viewSize.width;
    m_viewHeight = viewSize.height;
    
    // Set the view height with the week day labels
    m_viewHeightWithWeekDaysLabels = m_viewHeight - 30;
}

#pragma mark --- Drawing ---

// **********************************************************************
//								drawRect
// **********************************************************************
- (void)drawRect:(NSRect)rect
{	
	// Figure out how many event sources are active
	m_numberOfActiveEventSources = [self calculateNumberOfActiveEventSources];
    
    // Update view width and height
    [self updateViewWidthAndHeight];
    
    // Clear all the day rect values
    [self clearDayRectValues];
    
    // The number of rows that this calendar needs
    int numberOfRowsNeeded = 5;
    
    // Check if a six row is needed for this calendar
    if([self isSixRowCalendar])
        numberOfRowsNeeded = 6;

    // Make some bezier points
    NSPoint master = NSMakePoint(0, 0);
    NSPoint slave = NSMakePoint(0, 0);
    
    // Calculate the offset for the lines
    int widthOffSet = m_viewWidth / 7;
    int heightOffSet = m_viewHeightWithWeekDaysLabels / numberOfRowsNeeded;
    
    // A counter for the outer and inner loops
    int counter = 0;
    int icounter = 0;

    // We store the key coordinates of the horizontal and vertical lines here
    // For the hor lines, we need the number of rows + 1 because we don't use
    // the zero position in the array
    float vertLines[7];
    float horLines[numberOfRowsNeeded+1];
    
    // The first hoz and vert lines are at zero
    vertLines[0] = 0.0;
    horLines[0] = 0.0;
    
    // ---------------------------- Background --------------------------------
    
    // Draw the view background
    [[NSColor whiteColor] set];
    [NSBezierPath fillRect: [self bounds]];
    
    // ---------------------------- Vertical Lines --------------------------------
    
    // Set the color for the lines
    [[NSColor colorWithCalibratedRed:0.898 green:0.898 blue:0.898 alpha:1.0] set];
    
    // Set the y position for the master point. It never changes
    master.y = 1;
    
    // Set the end of the line (we go from 0 to view height)
    slave.y = m_viewHeightWithWeekDaysLabels - 1;
    
    // Draw the vertical lines
    for(counter = 1; counter < 7; counter++)
    {
        // Set the x position for the line
        master.x = (widthOffSet * counter) + 0.5;
        slave.x = master.x;
        
        // Store the key coordinate for this line
        vertLines[counter] = master.x;
        
        // Draw the line segment
        [NSBezierPath strokeLineFromPoint: master toPoint: slave];
    }

    // ---------------------------- Horizontal Lines --------------------------------
    
    // Set the color for the lines
    [[NSColor colorWithCalibratedRed:0.898 green:0.898 blue:0.898 alpha:1.0] set];
    
    // Set the x position for the master point. It never changes
    master.x = 1;
    
    // Set the end of the line (we go from 0 to view width)
    slave.x = m_viewWidth - 1;
    
    // Draw the horizontal lines - We use the number of rows + 1 here because we don't use the
    // zero position in the array.
    for(counter = 1; counter < (numberOfRowsNeeded+1) ; counter++)
    {
        // Set the y position for the line
        master.y = (heightOffSet * counter) + 0.5;
        slave.y = master.y;
        
        // Store the key coordinate for this line
        horLines[counter] = master.y;
        
        // Draw the line segment
        [NSBezierPath strokeLineFromPoint: master toPoint: slave];
    }
    
    // ---------------------------- Day Rects --------------------------------
    
    // Start from the beginning of the month
    int dayStringToDraw = 1;
    
    // And the beginning of the grid - We use zero here to make things easier
    int gridElement = 0;
    
    // Row by row - We user the number of rows - 1 because we are going all the way to zero
    // with this counter. We go to zero because we are use dealing with graphic coordinates
    // here and it makes things easier.
    for(counter = (numberOfRowsNeeded - 1); counter >= 0; counter--)
    {
        // Column by column
        for(icounter = 0; icounter < 7; icounter++)
        {
            // Check if more strings need to be drawn
            if(dayStringToDraw<=m_daysInMonth)
            {
                if(m_firstDayDateWeekDay<=gridElement)
                {
                    // Store the rect for this day
                    m_dayRect[dayStringToDraw].origin.x = vertLines[icounter] + 1;
                    m_dayRect[dayStringToDraw].origin.y = horLines[counter] + 1;
                    m_dayRect[dayStringToDraw].size.width = widthOffSet - 1;
                    m_dayRect[dayStringToDraw].size.height = heightOffSet - 1;

                    // Increment the day string to draw
                    dayStringToDraw++;
                }
            }
            
            // Increment the grid element
            gridElement++;
        }
    }
	
    // ---------------------------- Back Color Rectangle --------------------------------
    
    if(m_daySelected)
    {
        // A rect for the hour backcolor
        NSRect backColorRect;
        
        // Set the selection rectangle to the selected day
        backColorRect = m_dayRect[m_daySelected];
        
        // Set the color of the hour backcolor rectangle
        [[NSColor colorWithCalibratedRed:0.9412 green:0.9608 blue:0.9843 alpha:1.0] set];
        
        // Draw the hour backcolor rectangle
        [NSBezierPath fillRect: backColorRect];
    }
    
    // ---------------------------- Day String --------------------------------
    
    // Create a new dictionary as attribute to the day strings
    NSMutableDictionary* stringAttribsDict = [[NSMutableDictionary alloc] init];
    [stringAttribsDict setObject:[NSColor blackColor] forKey:NSForegroundColorAttributeName];
    [stringAttribsDict setObject:[NSFont fontWithName: @"Lucida Grande" size: 11] forKey: NSFontAttributeName];
    
    // Start from the beginning of the month
    dayStringToDraw = 1;
    
    // And the beginning of the grid - We use zero here to make things easier
    gridElement = 0;
    
    // Row by row
    for(counter = 0; counter <= 5; counter++)
    {
        // Column by column
        for(icounter = 1; icounter <= 7; icounter++)
        {
            // Check if more strings need to be drawn
            if(dayStringToDraw<=m_daysInMonth)
            {
                if(m_firstDayDateWeekDay<=gridElement)
                {
                    // Set the x position for the string
                    master.x = (widthOffSet * icounter) - 20;
                    
                    // Set the y position for the string
                    master.y = m_viewHeightWithWeekDaysLabels - (heightOffSet * counter) - 20;
                    
                    // Set the string to draw
                    NSString* dayString = [NSString stringWithFormat:@"%d", dayStringToDraw];

                    // Draw the string
                    [dayString drawAtPoint: master withAttributes:stringAttribsDict];
                    
                    // Increment the day string to draw
                    dayStringToDraw++;
                }
            }
            
            // Increment the grid element
            gridElement++;
        }
    }
    
    // Release the string attributes
    [stringAttribsDict release];
	
    // ---------------------------- Day Labels --------------------------------
    
    // Create a new dictionary as attribute to the day strings
    stringAttribsDict = [[NSMutableDictionary alloc] init];
    
    // Create a paragraph style
    NSMutableParagraphStyle* paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    
    // Set the paragraph style
    [paragraphStyle setParagraphStyle:[NSParagraphStyle defaultParagraphStyle]];
    [paragraphStyle setAlignment:NSCenterTextAlignment];
    [paragraphStyle setLineBreakMode:NSLineBreakByClipping];
    [paragraphStyle setMaximumLineHeight:15];
    [paragraphStyle setMinimumLineHeight:15];

    // Add the attributes to the string style dictionary
    [stringAttribsDict setObject:[NSColor blackColor] forKey:NSForegroundColorAttributeName];
    [stringAttribsDict setObject:[NSFont fontWithName: @"Lucida Grande" size: 11] forKey: NSFontAttributeName];
    [stringAttribsDict setObject:[[paragraphStyle copy] autorelease] forKey: NSParagraphStyleAttributeName];
    
    // Create the drawing rect
    NSRect weekDayLabelRect;
    
    // Set the parameters for the drawing rect that never change
    weekDayLabelRect.size.width = widthOffSet;
    weekDayLabelRect.size.height = 15.0;
    weekDayLabelRect.origin.y = m_viewHeightWithWeekDaysLabels + 3;
    
    // Draw the labels
    for(counter = 0; counter < 7; counter++)
    {
        // Set the x origin for the drawing rect
        weekDayLabelRect.origin.x = (widthOffSet * counter);
        
        if(m_viewWidth>500)
        {
            // Draw the label
            [kWeekDayLabelsArray[0][counter] drawInRect: weekDayLabelRect withAttributes:stringAttribsDict];
        }
        else
        {
            // Draw the label
            [kWeekDayLabelsArray[1][counter] drawInRect: weekDayLabelRect withAttributes:stringAttribsDict];
        }
    }

    // Release the string attributes
    [stringAttribsDict release];
    
    // Release the paragraph style
    [paragraphStyle release];
    
	// ---------------------------- Events --------------------------------
	
	int currentApplicationVerticalOffset = 1;
	
	NSManagedObjectContext* managedContext = [[NSApp delegate] managedObjectContext];
				
	NSFetchRequest* request = [[[NSFetchRequest alloc] init] autorelease];
	NSEntityDescription* entity = [NSEntityDescription entityForName: @"Event" inManagedObjectContext: managedContext];
	[request setEntity: entity];
	
	NSPredicate* predicate = [NSPredicate predicateWithFormat: 
		@"targetMonth == %@ AND targetYear == %@", 
		[NSNumber numberWithInt: [m_date monthOfYear]], 
		[NSNumber numberWithInt: [m_date yearOfCommonEra]]];
	
	[request setPredicate: predicate];
	
	NSSortDescriptor* sortDescriptor = [[NSSortDescriptor alloc] initWithKey: @"application.name" ascending: YES];
	[request setSortDescriptors:[NSArray arrayWithObject:sortDescriptor]];
	[sortDescriptor release];

	NSError* error = nil;
	NSArray* eventsArray = [managedContext executeFetchRequest:request error:&error];
	
	for(NSManagedObject* eventObject in eventsArray)
	{
		NSManagedObject* appObject = [eventObject valueForKey: @"application"];
		
		// There might not be an application any more, since those can be deleted now
		if(nil==appObject)
			continue;
			
		if(nil==[m_applicationVerticalOffset objectForKey: [appObject valueForKey: @"name"]])
		{
			[m_applicationVerticalOffset setObject: [NSNumber numberWithInteger: currentApplicationVerticalOffset] forKey: [appObject valueForKey: @"name"]];
			currentApplicationVerticalOffset++;
		}
		
		// Search string
		if([m_searchString length]>0)
		{
			NSString* eventTitleLowercase = [[eventObject valueForKey: @"title"] lowercaseString];
			
			NSRange searchStringRange = [eventTitleLowercase rangeOfString: m_searchString];
			
			if(searchStringRange.location!=NSNotFound)
				[self drawEvent: eventObject fromApplication: [appObject valueForKey: @"name"] 
					atDay: [[eventObject valueForKey: @"targetDay"] intValue] withColor: [appObject valueForKey: @"color"]];
		}
		else
		{
			[self drawEvent: eventObject fromApplication: [appObject valueForKey: @"name"] 
					atDay: [[eventObject valueForKey: @"targetDay"] intValue] withColor: [appObject valueForKey: @"color"]];
		}
	}
}

// **********************************************************************
//							drawEvent
// **********************************************************************
- (void) drawEvent: (NSManagedObject*) eventObject fromApplication: (NSString*) eventAppName 
	atDay: (int) day withColor: (NSColor*) appColor
{	
	// Sanity check
	if(eventObject==nil)
		return;
	
	// Get the event size
	int eventSize = 4;
    
    // Set the color of the event
	if(appColor!=nil)
		[appColor set];
	else
		[[NSColor purpleColor] set];
	    
    // Get event time
    float event_total_minutes = 0;
    float event_end_total_minutes = 0;
    
	// ------------------ Start Date ----------------------
	
	int event_day = [[eventObject valueForKey: @"targetDay"] intValue];
    int event_hour = [[eventObject valueForKey: @"targetHour"] intValue];
    int event_minute = 0;
    
    // Calculate event timestamp using minute as reference
    event_total_minutes = (event_hour*60) + event_minute;

    // ------------------ End Date ------------------------
	
	int eventEnd_day = event_day;
	int eventEnd_hour = event_hour;
	int eventEnd_minute = 0;
	
	// Calculate end event timestamp using hour as reference
	event_end_total_minutes = (eventEnd_hour*60) + eventEnd_minute + ((eventEnd_day - event_day) * 24 * 60);

    // ************************** X Drawing Starts **************************************
    
    NSRect eventRect;
    double eventXCoord = 0;
    double eventEndXCoord = 0;
    
    // Calculate how many pixels there are per minute
    double pixelsPerMinute = m_dayRect[day].size.width / 1440;
    
    // Set the event x point.
    eventXCoord = event_total_minutes * pixelsPerMinute;
    
    // Set x coordinate
    eventRect.origin.x = eventXCoord + m_dayRect[day].origin.x;

    // Now calculate the x coordinate for the end date if there is one
    if(event_end_total_minutes>0)
    {
        eventEndXCoord = event_end_total_minutes * pixelsPerMinute;
        
        // Set the event width
        eventRect.size.width = eventEndXCoord - eventXCoord;
        
        // It has to be at least 1 pixel long, otherwise it won't be displayed
        if(eventRect.size.width < (eventSize-1))
            eventRect.size.width = (eventSize-1);
    }
    else
    {
        // Set the event width
        eventRect.size.width = (eventSize-1);
    }
    
        
    // ************************** Y Drawing Starts **************************************
       
    // Calculate how much height for each event area.
    int eventAreaHeight = (m_dayRect[day].size.height - (3*m_dayRect[day].size.height/4)) / 15;

    // Calculate y coordinate
    double eventYCoord = eventAreaHeight * [[m_applicationVerticalOffset objectForKey: eventAppName] intValue];
	
    // Set y dot coordinate, and limit y so that it doesn't get drawn out of bounds
    eventRect.origin.y = eventYCoord + m_dayRect[day].origin.y;
    if(eventRect.origin.y>(m_dayRect[day].size.height + m_dayRect[day].origin.y))
		return;
		
    // Set the event height
    eventRect.size.height = eventSize;
    
    // ********************************** Bezier ***************************************
	
	// Getg a CGRect from the NSRect
	CGRect cgDotRect;
	CGPoint cgDotRectPoint;
	CGSize cgDotRectSize;
	
	cgDotRectPoint.x = eventRect.origin.x;
	cgDotRectPoint.y = eventRect.origin.y;
	
	cgDotRectSize.width = eventRect.size.width;
	cgDotRectSize.height = eventRect.size.height;
	
	cgDotRect.origin = cgDotRectPoint;
	cgDotRect.size = cgDotRectSize;
	
	// Draw the rect with round edges
	[SLUtilities fillRoundedRect: [NSGraphicsContext currentContext] andRect: cgDotRect 
		andOvalWidth: (eventRect.size.height/2) andOvalHeight: (eventRect.size.height/2)];

}

@end
