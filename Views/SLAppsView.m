
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


#import "SLAppsView.h"
#import "SLUtilities.h"

// **********************************************************************
//							Constants
// **********************************************************************

extern int k_dayRange;
extern int k_monthRange;

extern int k_appHeight;
extern int k_appHeaderHeight;
extern int k_appNameBarLineOffset;
extern int k_appNameLeftOffset;
extern int k_appNameRightOffset;
extern int k_appIconLeftOffset;
extern int k_appViewBarLeftHorizontalOffset;
extern int k_appViewBarRightHorizontalOffset;


// **********************************************************************
//
//						SLAppsView (Private)
//
// **********************************************************************

@interface SLAppsView (Private)

- (void) dateChanged: (NSNotification *) notification;

- (void) drawApps;
- (void) updateViewWidthAndHeight;

@end


// **********************************************************************
//
//							SLAppsView
//
// **********************************************************************

@implementation SLAppsView

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
		m_appObjects = [NSMutableArray arrayWithCapacity: 10];
		m_appDurationDictionary = [NSMutableDictionary dictionaryWithCapacity: 5];
		m_appRect = [NSMutableDictionary dictionaryWithCapacity: 5];
		m_appIconDictionary = [NSMutableDictionary dictionaryWithCapacity: 5];
		
		m_useCachedEventsOnRedraw = FALSE;
		
		m_appSelected = nil;
		m_numberOfApps = 0;
		
		// Scroll to top first time
		m_scrollToTop = YES;
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
	
	m_selectedDateRange = k_dayRange;
	[m_dayControlButton setState: NSOnState];
	[m_monthControlButton setState: NSOffState];
	
	[m_appDateTextField setStringValue: [m_selectedDate descriptionWithCalendarFormat: @"%B %e, %Y"]];
	[m_appSelectedNameTextField setStringValue: @""];

	// Notifications for drawing optimization
    NSNotificationCenter* center = [NSNotificationCenter defaultCenter];
	
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
    m_selectedDate = [newDate dateWithCalendarFormat:nil timeZone:[NSTimeZone defaultTimeZone]];
	
	// Set the date header
	if(m_selectedDateRange==k_dayRange)
	{
		[m_appDateTextField setStringValue: [m_selectedDate descriptionWithCalendarFormat: @"%B %e, %Y"]];
	}
	else if(m_selectedDateRange==k_monthRange)
	{
		[m_appDateTextField setStringValue: [m_selectedDate descriptionWithCalendarFormat: @"%B %Y"]];
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

#pragma mark --- App Loading ---

// **********************************************************************
//							loadApps
// **********************************************************************
- (int) loadApps
{
	// Reset the number of apps and app objects array
	//int numberOfApps = 0;
	[m_appObjects removeAllObjects];
	
	/*NSManagedObjectContext* m_managedContext = [[NSApp delegate] managedObjectContext];
	
	if(m_managedContext)
	{
		NSFetchRequest* appFetch = [[NSFetchRequest alloc] init];
		NSEntityDescription* appEntity = [NSEntityDescription entityForName: @"Application" inManagedObjectContext: m_managedContext];
		[appFetch setEntity: appEntity];
		
		NSError* error = nil;
		m_appObjects = [m_managedContext executeFetchRequest: appFetch error: &error];
		
		if(m_appObjects!=nil)
		{
			[m_appObjects retain];

			numberOfApps = [m_appObjects count];
		}
		else
		{
			NSLog(@"Slife: Error fetching app objects when drawing Apps View");
		}
	}
	else
	{
		NSLog(@"Slife: Managed Context is nil when fetching apps to draw Apps View");
	}*/
	
	NSManagedObjectContext* managedContext = [[NSApp delegate] managedObjectContext];
	
	if(managedContext)
	{
		// Get all events for this day
		NSFetchRequest* request = [[[NSFetchRequest alloc] init] autorelease];
		NSEntityDescription* entity = [NSEntityDescription entityForName: @"Event" inManagedObjectContext: managedContext];
		[request setEntity: entity];
		
		NSPredicate* predicate = predicate = [NSPredicate predicateWithFormat: 
		  @"targetDay == %@ AND targetMonth == %@ AND targetYear == %@", 
		  [NSNumber numberWithInt: [m_selectedDate dayOfMonth]], [NSNumber numberWithInt: [m_selectedDate monthOfYear]], 
		  [NSNumber numberWithInt: [m_selectedDate yearOfCommonEra]]];
		
		[request setPredicate: predicate];
		NSError* error = nil;
		
		NSArray* events = [managedContext executeFetchRequest:request error:&error];
		
		if(events)
		{
			// Go over all events and add their applications to a set
			NSMutableSet* eventApplicationsSet = [NSMutableSet set];
			for(NSManagedObject* anEvent in events)
			{
				NSManagedObject* eventApplication = [anEvent valueForKey: @"application"];
				
				[eventApplicationsSet addObject: eventApplication];
			}
			
			// Add all applications from the set (unique) to the application objects array (if the app is enabled)
			for(NSManagedObject* anApplication in eventApplicationsSet)
			{
				if([[anApplication valueForKey: @"enabled"] boolValue])
					[m_appObjects addObject: anApplication];
			}
			
		}
	}
	else
	{
		NSLog(@"Slife: Managed Context is nil when fetching applications to draw Day View");
	}
	
	// Return number
	return [m_appObjects count];
}

// **********************************************************************
//					loadAppEventsForSelectedDateRange
// **********************************************************************
- (void) loadAppEventsForSelectedDateRange
{
	NSManagedObjectContext* managedContext = [[NSApp delegate] managedObjectContext];
	for(NSManagedObject* applicationObject in m_appObjects)
	{
		// ------------------------------ Application Recorded & Duration --------------------------------
		
		NSFetchRequest* applicationRecordedRequest = [[[NSFetchRequest alloc] init] autorelease];
		NSEntityDescription* applicationRecordedEntity = [NSEntityDescription entityForName: @"ApplicationRecorded" inManagedObjectContext: managedContext];
		[applicationRecordedRequest setEntity: applicationRecordedEntity];
		
		NSPredicate* applicationRecordedPredicate = nil;
		if(m_selectedDateRange==k_dayRange)
		{
			applicationRecordedPredicate = [NSPredicate predicateWithFormat: 
				@"application.name == %@ AND targetDay == %@ AND targetMonth == %@ AND targetYear == %@", 
				[applicationObject valueForKey: @"name"], [NSNumber numberWithInt: [m_selectedDate dayOfMonth]],
				[NSNumber numberWithInt: [m_selectedDate monthOfYear]], [NSNumber numberWithInt: [m_selectedDate yearOfCommonEra]]];
		}
		else if(m_selectedDateRange==k_monthRange)
		{
			applicationRecordedPredicate = [NSPredicate predicateWithFormat: 
				@"application.name == %@ AND targetMonth == %@ AND targetYear == %@", 
				[applicationObject valueForKey: @"name"], [NSNumber numberWithInt: [m_selectedDate monthOfYear]], 
				[NSNumber numberWithInt: [m_selectedDate yearOfCommonEra]]];
		}
		
		[applicationRecordedRequest setPredicate: applicationRecordedPredicate];
		
		double totalSecondsForApplicationsRecorded = 0;
		NSError* error = nil;
		NSArray* applicationsRecordedForSelectedDate = [managedContext executeFetchRequest:applicationRecordedRequest error:&error];
		
		for(NSManagedObject* applicationRecorded in applicationsRecordedForSelectedDate)
		{
			NSNumber* applicationRecordedDuration = [applicationRecorded valueForKey: @"duration"];
			totalSecondsForApplicationsRecorded += [applicationRecordedDuration doubleValue];
		}
		
		[m_appDurationDictionary setObject: [NSNumber numberWithDouble: totalSecondsForApplicationsRecorded] forKey: [applicationObject valueForKey: @"name"]];
		
		if(totalSecondsForApplicationsRecorded>m_longestDurationAppEvents)
			m_longestDurationAppEvents = totalSecondsForApplicationsRecorded;
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
	
	// Calculate the amount of space that we need for the view. We know that about 64 is the ideal 
	// height for each event type row. So we multiply how many more scripts we have by 64. Then we 
	// add the height for the top divider line. That should give us what we need in terms of space.
	int idealHeight = m_numberOfApps*k_appHeight;
	
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
//						appsDurationCompare
// **********************************************************************
NSInteger appsDurationCompare(id obj1, id obj2, void* context)
{
	NSManagedObject* appObj1 = (NSManagedObject*) obj1;
	NSManagedObject* appObj2 = (NSManagedObject*) obj2; 
	NSDictionary* appDurationDictionary = (NSDictionary*) context;
	
	NSNumber* appObjDuration1 = [appDurationDictionary objectForKey: [appObj1 valueForKey: @"name"]];
	NSNumber* appObjDuration2 = [appDurationDictionary objectForKey: [appObj2 valueForKey: @"name"]];
	
    float v1 = [appObjDuration1 floatValue];
    float v2 = [appObjDuration2 floatValue];
	
    if (v1 < v2)
		return NSOrderedDescending;
    else if (v1 > v2)
		return NSOrderedAscending;
    else
        return NSOrderedSame;
}

#pragma mark --- Drawing ---

// **********************************************************************
//							drawApps
// **********************************************************************
- (void) drawApps
{
	if(!m_useCachedEventsOnRedraw || ([[m_appDurationDictionary allValues] count]==0))
	{
		[m_appDurationDictionary removeAllObjects];
		m_longestDurationAppEvents = 0;
		
		// ---------------------- Compute total and longest duration of events for app given time range ---------------------------
		
		[self loadAppEventsForSelectedDateRange];
	}
	
	m_useCachedEventsOnRedraw = FALSE;
	
	// Calculate how much height for each event type area
    int appDrawingAreaHeight = k_appHeight;
	
	// A counter we use to set the Y location for each event category and icon
	int yLocationIconOffset = 1;
	
	// Sanity check
	if(m_appObjects)
	{
		// Avoid during work if not needed
		if([m_appObjects count]>0)
		{
			// Sort array by total duration
			NSArray* sortedApplicationObjects = [m_appObjects sortedArrayUsingFunction: 
				appsDurationCompare context: m_appDurationDictionary];
			
			// Create a new dictionary with attribute for bar duration labels
			NSMutableDictionary* barDurationLabelStringAttribsDict = [NSMutableDictionary dictionaryWithCapacity: 5];
			[barDurationLabelStringAttribsDict setObject:[NSColor colorWithCalibratedRed:0.5 green:0.5 blue:0.5 alpha:1.0] forKey:NSForegroundColorAttributeName];
			[barDurationLabelStringAttribsDict setObject:[NSFont fontWithName: @"Lucida Grande" size: 11] forKey: NSFontAttributeName];


			// Go over every application in the store
			for(NSManagedObject* appObject in sortedApplicationObjects)
			{
				NSString* appName = [appObject valueForKey: @"name"];
				
				// -------------------------------- Bar Duration String --------------------------------
				
				NSString* barDurationString = nil;
				int totalSecondsForAppEvents = [[m_appDurationDictionary objectForKey: appName] floatValue];
				if(totalSecondsForAppEvents>0)
				{
					barDurationString = [SLUtilities convertSecondsToTimeString: totalSecondsForAppEvents withRounding: NO];
				}
				
				if(nil!=m_appSelected)
				{
					// -------------------------------------- Selection --------------------------------------

					if([m_appSelected isEqualToString: appName])
					{
						[[NSColor colorWithCalibratedRed:0.9412 green:0.9608 blue:0.9843 alpha:1.0] set];
						
						NSRect appRect;
						appRect.origin.x = 0;
						appRect.origin.y = m_viewHeight - k_appHeaderHeight - (appDrawingAreaHeight*yLocationIconOffset) + 1;
						appRect.size.height = appDrawingAreaHeight - 1;
						appRect.size.width = m_viewWidth;
						
						[NSBezierPath fillRect: appRect];
						
						if(barDurationString)
						{
							if(m_selectedDateRange==k_dayRange)
							{
								[m_appDateTextField setStringValue: [m_selectedDate descriptionWithCalendarFormat: @"%B %e, %Y"]];
							}
							else if(m_selectedDateRange==k_monthRange)
							{
								[m_appDateTextField setStringValue: [m_selectedDate descriptionWithCalendarFormat: @"%B %Y"]];
							}
					
							[m_appSelectedNameTextField setStringValue: appName];
						}
					}
				}
				else
				{
					if(m_selectedDateRange==k_dayRange)
					{
						[m_appDateTextField setStringValue: [m_selectedDate descriptionWithCalendarFormat: @"%B %e, %Y"]];
					}
					else if(m_selectedDateRange==k_monthRange)
					{
						[m_appDateTextField setStringValue: [m_selectedDate descriptionWithCalendarFormat: @"%B %Y"]];
					}
					
					[m_appSelectedNameTextField setStringValue: @""];
				}
	
				// ---------------------------------- App icon -------------------------------------------------
				
				// Get the icon image
				NSImage* appIconImage = [m_appIconDictionary objectForKey: appName];
				
				if(appIconImage==nil)
				{
					appIconImage = [SLUtilities getIconImageForApplication: appName];
					if(appIconImage!=nil)
					{
						[appIconImage setSize: NSMakeSize(16,16)];
						[m_appIconDictionary setObject: appIconImage forKey: appName];
					}
				}
				
				// Draw the icon, finally
				if(appIconImage)
				{
					[appIconImage compositeToPoint: NSMakePoint(k_appIconLeftOffset, 
						m_viewHeight - k_appHeaderHeight - (appDrawingAreaHeight*yLocationIconOffset) + (appDrawingAreaHeight/2) - 9) 
						operation: NSCompositeSourceOver];
				}
				
				// ---------------------------------- App name -------------------------------------------------
				
				// Limit to 60 chars
				NSString* appNameFormatted = [SLUtilities limitString: appName toNumberOfCharacters: 20];
				
				// Create a paragraph style
				NSMutableParagraphStyle* paragraphStyle = [[NSMutableParagraphStyle alloc] init];
				
				// Set the paragraph style
				[paragraphStyle setParagraphStyle:[NSParagraphStyle defaultParagraphStyle]];
				[paragraphStyle setAlignment:NSRightTextAlignment];
				[paragraphStyle setLineBreakMode:NSLineBreakByClipping];

				// Create a new dictionary with attribute for app names
				NSMutableDictionary* appNameStringAttribsDict = [NSMutableDictionary dictionaryWithCapacity: 5];
				[appNameStringAttribsDict setObject:[NSColor blackColor] forKey:NSForegroundColorAttributeName];
				[appNameStringAttribsDict setObject:[NSFont fontWithName: @"Lucida Grande" size: 11] forKey: NSFontAttributeName];
				[appNameStringAttribsDict setObject: paragraphStyle forKey: NSParagraphStyleAttributeName];

				[paragraphStyle release];
				
				// Create the drawing rect
				NSRect appNameRect;
				NSSize appNameStringSize = [appNameFormatted sizeWithAttributes: appNameStringAttribsDict];
				appNameRect.size = appNameStringSize;
				
				// Set the parameters for the drawing rect for the app name
				appNameRect.origin.x = k_appIconLeftOffset + 16 + k_appNameLeftOffset;
				appNameRect.origin.y = m_viewHeight - k_appHeaderHeight - 
					(appDrawingAreaHeight*yLocationIconOffset) + (appDrawingAreaHeight/2) - 8;
		
				[appNameFormatted drawInRect: appNameRect withAttributes: appNameStringAttribsDict];
				
				if(totalSecondsForAppEvents>0)
				{
					// ------------------ Draw the bar ----------------------

					int appBarHeight = 16;
					int appBarXCoordinate = k_appNameBarLineOffset + k_appViewBarLeftHorizontalOffset;
					
					int appBarYCoordinate = m_viewHeight - k_appHeaderHeight - 
						(appDrawingAreaHeight*yLocationIconOffset) + (appDrawingAreaHeight/2) - (appBarHeight/2);
						
					int longestAppBarWidth = m_viewWidth - appBarXCoordinate - k_appViewBarRightHorizontalOffset;
				
					int appBarWidth = longestAppBarWidth / m_longestDurationAppEvents * totalSecondsForAppEvents;
					
					if(appBarWidth<12)
						appBarWidth=12;
						
					NSRect theRect = NSMakeRect(appBarXCoordinate, appBarYCoordinate, appBarWidth, appBarHeight);
					
					[[NSColor colorWithCalibratedRed:0.898 green:0.898 blue:0.898 alpha:1.0] set];
					
					//[NSBezierPath fillRect: theRect];
					
					NSBezierPath* rectBezier = [NSBezierPath bezierPathWithRoundedRect: theRect xRadius: 3.0 yRadius: 3.0];
					[rectBezier fill];
		
					// ------------------ Draw the duration -----------------
					
					// Create the drawing rect
					NSRect barDurationLabelRect;
					
					// Set the parameters for the drawing rect for the bar duration label
					barDurationLabelRect.origin.x = appBarXCoordinate + appBarWidth + 10;
					
					barDurationLabelRect.origin.y = m_viewHeight - k_appHeaderHeight - 
						(appDrawingAreaHeight*yLocationIconOffset) + (appDrawingAreaHeight/2) - (appBarHeight/3);
						
					barDurationLabelRect.size.width = 200;
					barDurationLabelRect.size.height = 12;
			
					// Draw the labels
					if(barDurationString)
						[barDurationString drawInRect: barDurationLabelRect withAttributes: barDurationLabelStringAttribsDict];
					
					// ------------------ Save App Rect -----------------
					
					NSRect appRect;
					appRect.origin.x = 0;
					appRect.origin.y = m_viewHeight - k_appHeaderHeight - (appDrawingAreaHeight*yLocationIconOffset);
					appRect.size.height = appDrawingAreaHeight;
					appRect.size.width = m_viewWidth;
					
					NSString* appRectString = NSStringFromRect(appRect);
					[m_appRect setObject: appRectString forKey: appName];
				}
				
				// Decrement the Y location icon offset
				yLocationIconOffset++;
			}
		}
	}
	else
	{
		NSLog(@"Slife: Application objects are nil when trying to draw app icons");
	}
}

// **********************************************************************
//								drawRect
// **********************************************************************
- (void)drawRect:(NSRect)rect
{	
	// Initialization, cleanup and setup
	int counter = 0;
	
	[m_appRect removeAllObjects];
	
	m_numberOfApps = [self loadApps];
	[self calculateFrameSize];
    [self updateViewWidthAndHeight];
    
    // -------------------------------- Background -----------------------------------------
    
    // Draw the background of the timeline
    [[NSColor whiteColor] set];
    [NSBezierPath fillRect: [self bounds]];
			
    // --------------------- Apps Separator -----------------------------------------
     
    // Set the color of the divisor lines
    [[NSColor colorWithCalibratedRed:0.8 green:0.8 blue:0.8 alpha:1.0] set];
    
    // Calculate how much height for each event type area
    int appDrawingAreaHeight = k_appHeight;
    
	// We draw one less divisor line than the number of rows
	int totalDivisors = m_numberOfApps;
	
	// Loop and draw the divisors
	for(counter=1; counter<=totalDivisors; counter++)
	{
		[NSBezierPath strokeLineFromPoint:NSMakePoint(0, m_viewHeight - k_appHeaderHeight - (appDrawingAreaHeight*counter) + 0.5) 
			toPoint:NSMakePoint(m_viewWidth, m_viewHeight - k_appHeaderHeight - (appDrawingAreaHeight*counter) + 0.5)];
	}
    
	// ------------------------ Draw Apps ------------------------------------------
	
	// Draw the apps
	[self drawApps];
	
	// -------------------------------- Vertical Separator -----------------------------------------
	
	// Make points
    NSPoint b = NSMakePoint(0, 0);
    NSPoint e = NSMakePoint(0, 0);
    
    // Set the color for the lines
    [[NSColor colorWithCalibratedRed:0.898 green:0.898 blue:0.898 alpha:1.0] set];
    
	// Set the begining point
    b.y = 0;
    b.x = k_appNameBarLineOffset + 0.5;
    
    // Set the final point
    e.x = b.x;
    e.y = m_viewHeight;
        
    // Draw the first line segment
    [NSBezierPath strokeLineFromPoint: b toPoint: e];

	// -------------------------------- Refresh Bar Graph -------------------------------------
	
	[m_appBarGraphView setNeedsDisplay: YES];
	
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
	m_appSelected = nil;
	
    // Get the click location and convert it
    NSPoint clickPoint = [self convertPoint:[event locationInWindow] fromView: nil];
    
	NSString* anApp = nil;
	for( anApp in m_appRect)
	{
		NSString* appRectString = [m_appRect objectForKey: anApp];
		NSRect appRect = NSRectFromString(appRectString);
		
		// See if the click occurred within the rect
		if(NSMouseInRect(clickPoint, appRect, NO))
		{
			
			// If we have only one click, display it in the main window
			if([event clickCount]==1)
			{
				m_appSelected = anApp;
			}
			
			// If a double-click, display it in the main window
			else if([event clickCount]>1)
			{
				m_appSelected = anApp;
			}
			
			// We are done here
			break;
		}
	}
	
	// Request redraw
	[self setNeedsDisplay: YES];
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
	// ---------------------- Compute total and longest duration of events for app given time range ---------------------------
	
	int selectedDay = [m_selectedDate dayOfMonth];
	int selectedMonth = [m_selectedDate monthOfYear];
	int selectedYear = [m_selectedDate yearOfCommonEra];
	
	NSManagedObjectContext* managedContext = [[NSApp delegate] managedObjectContext];
	
	NSFetchRequest* applicationRecordedRequest = [[[NSFetchRequest alloc] init] autorelease];
	NSEntityDescription* applicationRecordedEntity = [NSEntityDescription entityForName: @"ApplicationRecorded" inManagedObjectContext: managedContext];
	[applicationRecordedRequest setEntity: applicationRecordedEntity];
	
	NSPredicate* applicationRecordedPredicate = nil;
	if(m_selectedDateRange==k_dayRange)
	{
		applicationRecordedPredicate = [NSPredicate predicateWithFormat: 
			@"targetHour == %@ AND targetDay == %@ AND targetMonth == %@ AND targetYear == %@", 
			[NSNumber numberWithInt: barNumber], [NSNumber numberWithInt: selectedDay],
			[NSNumber numberWithInt: selectedMonth], [NSNumber numberWithInt: selectedYear]];
	}
	else if(m_selectedDateRange==k_monthRange)
	{
		applicationRecordedPredicate = [NSPredicate predicateWithFormat: 
			@"targetDay == %@ AND targetMonth == %@ AND targetYear == %@", 
			[NSNumber numberWithInt: barNumber+1], [NSNumber numberWithInt: selectedMonth], 
			[NSNumber numberWithInt: selectedYear]];
	}
	
	[applicationRecordedRequest setPredicate: applicationRecordedPredicate];
	
	double totalSecondsForApplicationsRecorded = 0;
	NSError* error = nil;
	NSArray* applicationRecordsForSelectedDate = [managedContext executeFetchRequest: applicationRecordedRequest error:&error];
	
	for(NSManagedObject* applicationRecorded in applicationRecordsForSelectedDate)
	{
		NSNumber* applicationRecordedDuration = [applicationRecorded valueForKey: @"duration"];
		totalSecondsForApplicationsRecorded += [applicationRecordedDuration doubleValue];
	}
	
	return totalSecondsForApplicationsRecorded;
}

// **********************************************************************
//						valueForHighlightBar
// **********************************************************************
- (int) barGraph: (SLBarGraphView*) aBarGraphView valueForHighlightBar: (int) barNumber 
{	
	if(nil==m_appSelected)
		return 0;
	
	// ---------------------- Compute total and longest duration of events for app given time range ---------------------------
	
	int selectedDay = [m_selectedDate dayOfMonth];
	int selectedMonth = [m_selectedDate monthOfYear];
	int selectedYear = [m_selectedDate yearOfCommonEra];
	
	NSManagedObjectContext* managedContext = [[NSApp delegate] managedObjectContext];
	
	NSFetchRequest* applicationRecordedRequest = [[[NSFetchRequest alloc] init] autorelease];
	NSEntityDescription* applicationRecordedEntity = [NSEntityDescription entityForName: @"ApplicationRecorded" inManagedObjectContext: managedContext];
	[applicationRecordedRequest setEntity: applicationRecordedEntity];
	
	NSPredicate* applicationRecordedPredicate = nil;
	if(m_selectedDateRange==k_dayRange)
	{
		applicationRecordedPredicate = [NSPredicate predicateWithFormat: 
			@"application.name == %@ AND targetHour == %@ AND targetDay == %@ AND targetMonth == %@ AND targetYear == %@", 
			m_appSelected, [NSNumber numberWithInt: barNumber], [NSNumber numberWithInt: selectedDay],
			[NSNumber numberWithInt: selectedMonth], [NSNumber numberWithInt: selectedYear]];
	}
	else if(m_selectedDateRange==k_monthRange)
	{
		applicationRecordedPredicate = [NSPredicate predicateWithFormat: 
			@"application.name == %@ AND targetDay == %@ AND targetMonth == %@ AND targetYear == %@", 
			m_appSelected, [NSNumber numberWithInt: barNumber+1], [NSNumber numberWithInt: selectedMonth], 
			[NSNumber numberWithInt: selectedYear]];
	}
	
	[applicationRecordedRequest setPredicate: applicationRecordedPredicate];
	
	double totalSecondsForApplicationsRecorded = 0;
	NSError* error = nil;
	NSArray* applicationRecordsForSelectedDate = [managedContext executeFetchRequest: applicationRecordedRequest error:&error];
	
	for(NSManagedObject* applicationRecorded in applicationRecordsForSelectedDate)
	{
		NSNumber* applicationRecordedDuration = [applicationRecorded valueForKey: @"duration"];
		totalSecondsForApplicationsRecorded += [applicationRecordedDuration doubleValue];
	}
	
	return totalSecondsForApplicationsRecorded;
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
		
		if([m_appBarGraphView bounds].size.width>700)
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
		labelString = [m_selectedDate descriptionWithCalendarFormat: @"Application Usage For %B %e, %Y"]; 
	}
	else if(m_selectedDateRange==k_monthRange)
	{
		labelString = [m_selectedDate descriptionWithCalendarFormat: @"Application Usage For %B %Y"];
	}
		
	return labelString;

}

@end
