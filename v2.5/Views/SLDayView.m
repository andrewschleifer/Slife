
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

#import "SLDayView.h"
#import "SLUtilities.h"

// **********************************************************************
//							Constants
// **********************************************************************

// Minutes for view and event size
extern int k_minutesInHourView;
extern int k_minutesInDayView;

// Hour label distances
extern int k_hourLabelWidth;
extern int k_hourLabelHeight;
extern int k_hourLabelYDist;
extern int k_hourLabelDividerYDist;

// Height for each event type - we use this for the day view resize
extern int k_eventTypeHeight;

// Offset to icon offset in day view
extern int k_viewIconOffset;


@interface SLDayView (Private)

- (void) dateChanged: (NSNotification *) notification;
- (void) updatemViewWidthAndHeight;
- (void) removeTooltipWindow;

@end


@implementation SLDayView

#pragma mark --- Initialization ---

// **********************************************************************
//							initWithFrame
// **********************************************************************
- (id)initWithFrame:(NSRect)frame 
{
    self = [super initWithFrame:frame];
    if (self) 
	{
        // Init the table and control variable we use to determine where to draw the event
        m_eventCurrentYOffset = 0;
        m_eventYOffsetDictionary = [NSMutableDictionary dictionaryWithCapacity: 5];

        // Get the hour label hilite and gray backgrounds
        m_hourBackHiliteImage = [[NSImage alloc] initWithData:[[NSImage imageNamed: @"aquablue"] TIFFRepresentation]];
		m_hourBackGrayImage = [[NSImage alloc] initWithData:[[NSImage imageNamed: @"aquagray"] TIFFRepresentation]];
        
        // Create a dictionary to hold the event locations used in mouseDown:
        m_eventsLocation = [NSMutableDictionary dictionaryWithCapacity: 5];
		
		// The icon cache that we use to speed things up in drawing
		m_iconCacheDictionary = [NSMutableDictionary dictionaryWithCapacity: 5];
		
		// Array of applications we need to draw
		m_cachedApplicationObjects = [NSMutableArray arrayWithCapacity: 0];
		
		// Create cache array of application events
		m_cachedEventsForApplications = [NSMutableDictionary dictionaryWithCapacity: 5];
		
		// Dictionary of number of events for each application - used for sorting
		m_cachedApplicationEventsNumberDictionary = [NSMutableDictionary dictionaryWithCapacity: 5];
		
		// The number of event rows we have right now is zero
		m_numberOfActiveEventSources = 0;
		
		// No events selected
		m_eventSelected = nil;
		m_tooltipWindow = nil;
		
		// Scroll to top first time
		m_scrollToTop = YES;
		
		// Nothing for search string yet
		m_searchString = @"";
		m_searchTextFieldTimer = nil;
		
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
    // Update view width and height
    [self updatemViewWidthAndHeight];
    
    // Initialize the date to the current date
    m_selectedDate = [NSCalendarDate date];
	
	[m_dateTextField setStringValue: [m_selectedDate descriptionWithCalendarFormat: @"%B %e, %Y"]];
	
    // Calculate min and max values based on frame size and minutes we display per view
    m_timeViewZoomSliderMinValue = (m_viewWidth-k_viewIconOffset) / k_minutesInDayView;
    m_timeViewZoomSliderMaxValue = (m_viewWidth-k_viewIconOffset) / k_minutesInHourView;
    
    // Reset the slider
    m_timeViewZoomFactor = m_timeViewZoomSliderMinValue;
    m_timeScaleReference = 0;

    // Set the min-max values for the time zoom slider based on calculations on initWithFrame
    [m_timeViewZoomSlider setMinValue:m_timeViewZoomSliderMinValue];
    [m_timeViewZoomSlider setMaxValue:m_timeViewZoomSliderMaxValue];
    [m_timeViewZoomSlider setFloatValue:m_timeViewZoomFactor];
	
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
	
	// Always draw everything on scrolling
	[[[self enclosingScrollView] contentView] setCopiesOnScroll:NO];
	
	// Date changed
	[center addObserver: self
			selector:@selector(dateChanged:)
			name: @"dateChanged" 
			object: nil];
			
	// Views changing
	[center addObserver: self
			selector:@selector(viewChanging:)
			name: @"viewChanging" 
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
//							setDate
// **********************************************************************
- (void) setDate:(NSCalendarDate*) newDate
{
	// Remove tooltip window if there's one up
	[self removeTooltipWindow];
	
	// Set new date
	m_selectedDate = [NSCalendarDate dateWithString: 
		[newDate descriptionWithCalendarFormat: @"%d %m %Y" timeZone: nil locale: [[NSUserDefaults standardUserDefaults] dictionaryRepresentation]] 
		calendarFormat: @"%d %m %Y"];
	
	// Change the date in the header
	[m_dateTextField setStringValue: [m_selectedDate descriptionWithCalendarFormat: @"%B %e, %Y"]];
	
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
		object: [m_selectedDate dateByAddingYears:0 months:0 days:-1 hours:0 minutes:0 seconds:0]];
}

// **********************************************************************
//                         nextDayButtonClicked
// **********************************************************************
- (IBAction) nextDayButtonClicked: (id) sender
{
	// Notify date change - including this object
	[[NSNotificationCenter defaultCenter] postNotificationName: @"dateChanged" 
		object: [m_selectedDate dateByAddingYears:0 months:0 days:1 hours:0 minutes:0 seconds:0]];
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

#pragma mark --- Event Handling ---

// **********************************************************************
//                          acceptsFirstResponder
// **********************************************************************
- (BOOL) acceptsFirstResponder 
{ 
    return YES;
}

// **********************************************************************
//					m_timeViewZoomSliderChange
// **********************************************************************
- (IBAction) timeViewZoomSliderChange:(id) sender
{
	// Remove tooltip window if there's one up
	[self removeTooltipWindow];
	
    // There is a change in the time zoom slider
    m_timeViewZoomFactor = [sender floatValue];
	
	// We want to use the cached events
	m_useCachedEventsOnRedraw = TRUE;
	
	// Optimized redraw
	[self setNeedsDisplay: YES];
}

// **********************************************************************
//							linkButtonClicked
// **********************************************************************
- (IBAction) linkButtonClicked: (id) sender
{
	if(nil!=m_eventSelected)
	{
		NSString* eventURLString = [m_eventSelected valueForKey: @"url"];
					
		if( (nil!=eventURLString) && ([eventURLString length]>0) )
		{
			[[NSWorkspace sharedWorkspace] openURL: [NSURL URLWithString: eventURLString]];
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
//							scrollToTop
// **********************************************************************
- (void) scrollToTop
{
	NSScrollView* scrollView = (NSScrollView*) [[self superview] superview];
	NSPoint topPoint = NSMakePoint(0.0, [[scrollView documentView] bounds].size.height);
	[[scrollView documentView] scrollPoint: topPoint];
}

// **********************************************************************
//				updatemViewWidthAndHeight
// **********************************************************************
- (void) updatemViewWidthAndHeight
{
	// Get the view dimensions
    NSRect frame = [self frame];
    NSSize frameSize = frame.size;
	
    m_viewWidth = frameSize.width;
	m_viewHeight = frameSize.height;
}

// **********************************************************************
//							calculateFrameSize
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
	int idealHeight = (m_numberOfActiveEventSources*k_eventTypeHeight)+k_hourLabelDividerYDist;
	
	// Check if we need to resize the view
	if(frameHeight<idealHeight)
	{
		// Calculate the delta between the current and ideal sizes
		int idealCurrentSizeDelta = idealHeight - frameHeight;
		
		// Resize the view
		[self setFrameSize: NSMakeSize(frameWidth, frameHeight + idealCurrentSizeDelta)];
	}
}

// **********************************************************************
//					loadEventsAndApplications
// **********************************************************************
- (int) loadEventsAndApplications
{	
	// If not using cached events, purge cache
	if(!m_useCachedEventsOnRedraw)
	{
		[m_cachedApplicationObjects removeAllObjects];
		[m_cachedEventsForApplications removeAllObjects];
		[m_cachedApplicationEventsNumberDictionary removeAllObjects];
		
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
					NSString* eventApplicationName = [eventApplication valueForKey: @"name"];
					
					[eventApplicationsSet addObject: eventApplication];
					
					// Cache application events
					NSMutableArray* eventsForApplication = [m_cachedEventsForApplications objectForKey: eventApplicationName];
					
					if(eventsForApplication==nil)
						eventsForApplication = [NSMutableArray arrayWithCapacity: 5];
					
					[eventsForApplication addObject: anEvent];
					[m_cachedEventsForApplications setObject: eventsForApplication forKey: eventApplicationName];
					
					// Cache number of events for application, for sorting
					[m_cachedApplicationEventsNumberDictionary setObject: 
					 [NSNumber numberWithInt: [eventsForApplication count]] forKey: eventApplicationName];
				}
				
				// Add all applications from the set (unique) to the application objects array (if the app is enabled)
				for(NSManagedObject* anApplication in eventApplicationsSet)
				{
					if([[anApplication valueForKey: @"enabled"] boolValue])
						[m_cachedApplicationObjects addObject: anApplication];
				}
			
			}
		}
		else
		{
			NSLog(@"Slife: Managed Context is nil when fetching applications to draw Day View");
		}
		
	}
		
	// Return number
	return [m_cachedApplicationObjects count];
}

// **********************************************************************
//							removeTooltipWindow
// **********************************************************************
- (void) removeTooltipWindow
{
	if(m_tooltipWindow)
	{
		[[self window] removeChildWindow: m_tooltipWindow];
		[m_tooltipWindow orderOut:self];
		[m_tooltipWindow release];
		m_tooltipWindow = nil;
	}
}

// **********************************************************************
//							viewsChanging
// **********************************************************************
- (void) viewChanging: (NSNotification *) notification
{
	[self removeTooltipWindow];
}

// **********************************************************************
//							mouseDown
// **********************************************************************
- (void) mouseDown: (NSEvent*) event
{
    // Update view width and height
    [self updatemViewWidthAndHeight];
    
    // Calculate min and max values based on frame size and minutes we display per view
	m_timeViewZoomSliderMinValue = (m_viewWidth-k_viewIconOffset) / k_minutesInDayView;
    m_timeViewZoomSliderMaxValue = (m_viewWidth-k_viewIconOffset) / k_minutesInHourView;

    // Set the min-max values for the time zoom slider based on calculations on initWithFrame
    [m_timeViewZoomSlider setMinValue:m_timeViewZoomSliderMinValue];
    [m_timeViewZoomSlider setMaxValue:m_timeViewZoomSliderMaxValue];
    m_timeViewZoomFactor = [m_timeViewZoomSlider floatValue];
    
    // Get the click location and convert it
    NSPoint clickPoint = [self convertPoint:[event locationInWindow] fromView: nil];
    
    // Set the m_timeScaleReference. It's much easier when we are not zoomed in somewhere
    if(m_timeViewZoomFactor==m_timeViewZoomSliderMinValue)
        m_timeScaleReference = (clickPoint.x-k_viewIconOffset) / (60*m_timeViewZoomFactor);
    else
    {
        // If we are zoomed in somewhere, then we need to make a few calculations first to figure out
        // where the click happened.
        
        // First, calculate the x coord of the hour line corresponding to the current m_timeScaleReference
        // and call it refLineXCoord
        int refLineXCoord = 60*m_timeViewZoomFactor*m_timeScaleReference - 
                ( ( (m_timeScaleReference*(m_viewWidth-k_viewIconOffset)) / (m_timeViewZoomSliderMaxValue-m_timeViewZoomSliderMinValue) ) * 
                    (m_timeViewZoomFactor- m_timeViewZoomSliderMinValue) ) + k_viewIconOffset;
                    
        // If the click happened after refLineXCoord...
        if(clickPoint.x > refLineXCoord)
        {
            // Use this formula to calculate the new m_timeScaleReference. It's not too complicated. First we calculate
            // how many x pixels away from the current m_timeScaleReference hour line the click happened. Then, we divide
            // that by an hour in pixels. The result is how many hours ahead the shift represents. We just add that to the
            // m_timeScaleReference and are done!
            m_timeScaleReference = ( (clickPoint.x-refLineXCoord) / (60*m_timeViewZoomFactor) ) + m_timeScaleReference;
        }
        // If the click happened before refLineXCoord...
        else
        {
            // Use this formula to calculate the new m_timeScaleReference. It's not too complicated. First we calculate
            // how many x pixels away from the current m_timeScaleReference hour line the click happened. Then, we divide
            // that by an hour in pixels. The result is how many hours behind the shift represents. We just subtract that from 
            // the m_timeScaleReference and are done!
            m_timeScaleReference = m_timeScaleReference - ( (refLineXCoord-clickPoint.x) / (60*m_timeViewZoomFactor) );
        }
    }
    
    // Create an enumerator of all event location keys
    NSEnumerator* eventKeyEnumerator = [m_eventsLocation keyEnumerator];
    NSString* eventKey;
	
	// Flag if we've found an event selected
	BOOL anyEventSelected = FALSE;
	
    // Iterate over the all the elements in m_eventsLocation's keys
    while ((eventKey = [eventKeyEnumerator nextObject]) && (!anyEventSelected))
    {
        // Convert the string key to a rect

        NSRect eventRect = NSRectFromString(eventKey);
        
        // Relax the rect a bit so that it's easier to click on the event

        NSRect relaxedSelectionRect = eventRect;
        relaxedSelectionRect.origin.x -= 2;
        relaxedSelectionRect.origin.y -= 2;
        relaxedSelectionRect.size.width += 4;
        relaxedSelectionRect.size.height += 4;
        
        // See if the click occurred within the rect
        if(NSMouseInRect(clickPoint, relaxedSelectionRect, NO))
        {
            // It did. Get the event header
            m_eventSelected = [m_eventsLocation objectForKey: eventKey];
            
			// An event has been selected
			anyEventSelected = TRUE;
            
            // If we have only one click, display it in the main window
            if([event clickCount]==1)
            {
				// --------------- Tooltip Window -----------------
				
				[self removeTooltipWindow];
				
				m_tooltipWindow = [[MAAttachedWindow alloc] initWithView: m_tooltipView 
                                                attachedToPoint: [event locationInWindow]
                                                       inWindow: [self window] 
                                                         onSide: MAPositionAutomatic 
                                                     atDistance: 0];
				
				// Set background color and border
				[m_tooltipWindow setBackgroundColor: 
					[NSColor colorWithDeviceRed:0.92 green:0.92 blue:0.92 alpha:1.0]];
					
				[m_tooltipWindow setBorderWidth: 4];
			
				// ------------------ Tooltip Values ----------------------
				
				// Icon
				NSImage* appImage = [m_iconCacheDictionary objectForKey: [m_eventSelected valueForKeyPath: @"application.name"]];
				if(nil!=appImage)
				[m_tooltipImage setImage: appImage];
				
				// Title
				NSString* eventTitle = [m_eventSelected valueForKey: @"title"];
				
				if(nil!=eventTitle)
					[m_tooltipTitle setStringValue: [SLUtilities limitString: eventTitle toNumberOfCharacters: 40]];
				
				
				// Duration + Date
				NSDate* eventDate_Date = [m_eventSelected valueForKey: @"startDate"];
				NSCalendarDate* eventDate = [NSCalendarDate dateWithString: [eventDate_Date description] calendarFormat: @"%Y-%m-%d %H:%M:%S"];
				
				NSDate* eventEndDate_Date = [m_eventSelected valueForKey: @"endDate"];
				NSCalendarDate* eventEndDate = [NSCalendarDate dateWithString: [eventEndDate_Date description] calendarFormat: @"%Y-%m-%d %H:%M:%S"];
				
				int seconds=0;
				[eventEndDate years: NULL months: NULL days: NULL  hours:NULL minutes:NULL seconds:&seconds sinceDate: eventDate];
				
				NSMutableString* dateString = [NSMutableString stringWithCapacity: 5];
				[dateString appendString: [SLUtilities convertSecondsToTimeString: seconds withRounding: NO]];
				[dateString appendString: @" at "];
				[dateString appendString: [eventDate descriptionWithCalendarFormat: @"%I:%M %p"]];
				
				[m_tooltipDate setStringValue: dateString];
				
				
				// Link
				NSString* eventLink = [m_eventSelected valueForKey: @"url"];
				
				if( (nil!=eventLink) && ([eventLink length]>0) )
					[m_tooltipLinkButton setTransparent: NO];
				else
					[m_tooltipLinkButton setTransparent: YES];

					
				// Attach the window
				[[self window] addChildWindow: m_tooltipWindow ordered:NSWindowAbove];
            }
            
            // If a double-click, display it in the main window
            else if([event clickCount]>1)
            {
				[self removeTooltipWindow];
				
				// --------------- Open in browser -----------------
				
				if(nil!=m_eventSelected)
				{
					NSString* eventURLString = [m_eventSelected valueForKey: @"url"];
					
					if(nil!=eventURLString)
					{
						[[NSWorkspace sharedWorkspace] openURL: [NSURL URLWithString: eventURLString]];
					}
				}
            }
            
            // We are done here
            break;
        }
    }

	// ----------------- No Events ------------------
	
	if(!anyEventSelected)
	{
		[self removeTooltipWindow];
		m_eventSelected = nil;
		
		// Draw if no events selected. Otherwise, we just bring up the tooltip
		[self setNeedsDisplay: YES];
		
		// We want to use the cached events
		m_useCachedEventsOnRedraw = TRUE;
	}
}

// **********************************************************************
//                          scrollingIsHappening
// **********************************************************************
- (void) scrollingIsHappening: (NSNotification *) notification
{	
	// Scrolling. Remove tooltip if there's one
	[self removeTooltipWindow];
	
	// We want to use the cached events
	m_useCachedEventsOnRedraw = TRUE;
}

// **********************************************************************
//                          windowResizeIsHappening
// **********************************************************************
- (void) windowResizeIsHappening: (NSNotification *) notification
{
	// Scrolling. Remove tooltip if there's one
	[self removeTooltipWindow];
	
	// We want to use the cached events
	m_useCachedEventsOnRedraw = TRUE;
}

// **********************************************************************
//						appsNumberOfEventsCompare
// **********************************************************************
NSInteger appsNumberOfEventsCompare(id obj1, id obj2, void* context)
{
	NSManagedObject* appObj1 = (NSManagedObject*) obj1;
	NSManagedObject* appObj2 = (NSManagedObject*) obj2; 
	NSDictionary* appDurationDictionary = (NSDictionary*) context;
	
	NSNumber* appObjDuration1 = [appDurationDictionary objectForKey: [appObj1 valueForKey: @"name"]];
	NSNumber* appObjDuration2 = [appDurationDictionary objectForKey: [appObj2 valueForKey: @"name"]];
	
    float v1 = [appObjDuration1 intValue];
    float v2 = [appObjDuration2 intValue];
	
    if (v1 < v2)
		return NSOrderedDescending;
    else if (v1 > v2)
		return NSOrderedAscending;
    else
        return NSOrderedSame;
}

#pragma mark --- Drawing ---

// **********************************************************************
//							drawEvents
// **********************************************************************
- (void) drawEvent: (NSManagedObject*) eventObject atOffset: (int) appOffset withColor: (NSColor*) appColor
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
	
    // Get the event time
    NSDate* eventDate_Date = [eventObject valueForKey: @"startDate"];
	NSCalendarDate* eventDate = [NSCalendarDate dateWithString: [eventDate_Date description] calendarFormat: @"%Y-%m-%d %H:%M:%S"];
	
	int event_day = [eventDate dayOfMonth];
    int event_hour = [eventDate hourOfDay];
    int event_minute = [eventDate minuteOfHour];
    
    // Calculate event timestamp using minute as reference
    event_total_minutes = (event_hour*60) + event_minute;

    // ------------------ End Date ------------------------
	
	int eventEnd_day = event_day;
	int eventEnd_hour = event_hour;
	int eventEnd_minute = event_minute + ([[eventObject valueForKey: @"duration"] intValue]/60);
	
	// Calculate end event timestamp using hour as reference
	event_end_total_minutes = (eventEnd_hour*60) + eventEnd_minute + ((eventEnd_day - event_day) * 24 * 60);


    // ************************** X Drawing Starts **************************************
    
    // Set the event x point. Calculate x dot coordinate: multiply event minutes by m_timeViewZoomFactor and adjust
    // for the time scale. Note that the m_timeViewZoomFactor is a variable that indicates how long is a minute in 
    // pixels in our representation. So multiplying event minutes by m_timeViewZoomFactor gives the location of the 
    // event in the view. Whenever m_timeViewZoomFactor is not at its minimum value, then shift the pixels for the 
    // hour selected by m_timeScaleReference to the origin proportionally to the value of m_timeViewZoomFactor.

    float eventXCoord;
    float eventEndXCoord = 0;
    
    if(m_timeViewZoomFactor==m_timeViewZoomSliderMinValue)
        eventXCoord = (event_total_minutes * m_timeViewZoomFactor) + k_viewIconOffset;
    else
        eventXCoord = (event_total_minutes * m_timeViewZoomFactor) - 
            ( ( (m_timeScaleReference*(m_viewWidth-k_viewIconOffset)) / (m_timeViewZoomSliderMaxValue-m_timeViewZoomSliderMinValue) ) * 
                (m_timeViewZoomFactor- m_timeViewZoomSliderMinValue) ) + k_viewIconOffset;

    // Set x coordinate
    NSRect dotRect;
    dotRect.origin.x = eventXCoord;

    // Now calculate the x coordinate for the end date if there is one
    if(event_end_total_minutes>0)
    {
        if(m_timeViewZoomFactor==m_timeViewZoomSliderMinValue)
            eventEndXCoord = (event_end_total_minutes * m_timeViewZoomFactor) + k_viewIconOffset;
        else
            eventEndXCoord = (event_end_total_minutes * m_timeViewZoomFactor) - 
                ( ( (m_timeScaleReference*(m_viewWidth-k_viewIconOffset)) / (m_timeViewZoomSliderMaxValue-m_timeViewZoomSliderMinValue) ) * 
                    (m_timeViewZoomFactor- m_timeViewZoomSliderMinValue) ) + k_viewIconOffset;
					                    
        // Set the dot width
        dotRect.size.width = eventEndXCoord - eventXCoord;
        
        // It has to be at least 1 pixel long, otherwise it won't be displayed
        if(dotRect.size.width < (eventSize-1))
            dotRect.size.width = (eventSize-1);
    }
    else
    {
        // Set the dot width
        dotRect.size.width = (eventSize-1);
    }

    // ************************** Y Drawing Starts **************************************
     
    // Set the dot height
    dotRect.size.height = eventSize;
    
	// The total number of event rows that we have
	int totalEventRows = m_numberOfActiveEventSources;
	
    // Calculate how much height for each event type area
    int eventTypeDrawingAreaHeight = (m_viewHeight - k_hourLabelDividerYDist) / totalEventRows;

	// The Y offset location
    int YOffSet = 0;
    
	// Retrieve an ID for the event - as a string
	NSString* eventTimeID = [eventDate descriptionWithCalendarFormat: @"%m%d%y%H%M%S"];
						
    // Check to see if the event already has a YOffset location
    NSNumber* eventYOffset = [m_eventYOffsetDictionary objectForKey: eventTimeID];
    
    if(eventYOffset==nil)
    {
        // It does not, assign it a new location
        [m_eventYOffsetDictionary setObject: [NSNumber numberWithInt: m_eventCurrentYOffset] forKey: eventTimeID];
        
        // Make the run time assignment here
        YOffSet = m_eventCurrentYOffset;
        
        // Get the next y offset location
        m_eventCurrentYOffset++;
    
        // Keep the new y offset within boundary
        if(m_eventCurrentYOffset == 3)
            m_eventCurrentYOffset = -2;
    }
    else
    {
        // it does, so use it!
        YOffSet = [eventYOffset intValue];
    }

    // Calculate y coordinate
    float eventYCoord = (eventTypeDrawingAreaHeight*(totalEventRows-appOffset)) + 
		(eventTypeDrawingAreaHeight/2) + (YOffSet*(eventTypeDrawingAreaHeight/7)) - 2;
	
    // Set y dot coordinate
    dotRect.origin.y = eventYCoord;
    
	// ********************************** Bezier ***************************************
	
	// Find out what is the location of the top of the visible screen
	float visibleRectY = [self visibleRect].size.height + [self visibleRect].origin.y;
	
	// Do the drawing only if we are not drawing over the icons
	if( (dotRect.origin.x >= k_viewIconOffset) && 
		(dotRect.origin.y < (visibleRectY-k_hourLabelDividerYDist-dotRect.size.height)) )
	{
		//[NSGraphicsContext saveGraphicsState];
		
		// Setting the shadow
		NSShadow* theShadow = [[NSShadow alloc] init];
		[theShadow setShadowOffset:NSMakeSize(3.0, -3.0)];
		[theShadow setShadowBlurRadius:5];
		[theShadow setShadowColor: [NSColor colorWithCalibratedWhite:0.0 alpha:0.6]];
		[theShadow set];
		
		// Getg a CGRect from the NSRect
		CGRect cgDotRect;
		CGPoint cgDotRectPoint;
		CGSize cgDotRectSize;
		
		cgDotRectPoint.x = dotRect.origin.x;
		cgDotRectPoint.y = dotRect.origin.y;
		
		cgDotRectSize.width = dotRect.size.width;
		cgDotRectSize.height = dotRect.size.height;
		
		cgDotRect.origin = cgDotRectPoint;
		cgDotRect.size = cgDotRectSize;
		
		// Draw the rect with round edges
		[SLUtilities fillRoundedRect: [NSGraphicsContext currentContext] andRect: cgDotRect 
			andOvalWidth: (dotRect.size.height/2) andOvalHeight: (dotRect.size.height/2)];
		
		// Release the shadow
		[theShadow release];
		
		// ------------------------ Save Event Location -------------------------------
		
		// Adds the event to the dictionary of events that we drew - used in mouseDown:
		[m_eventsLocation setObject: eventObject forKey: NSStringFromRect(dotRect)];
	}
}


// **********************************************************************
//								drawIconsAndEvents
// **********************************************************************
- (void) drawIconsAndEvents
{
	// Remove all event locations
	[m_eventsLocation removeAllObjects];
	
	// Find out what is the location of the top of the visible screen
	float visibleRectY = [self visibleRect].size.height + [self visibleRect].origin.y;
	
	// The total number of icons that we have
	int totalIcons = m_numberOfActiveEventSources;
	
	// Calculate how much height for each event type area
    int eventTypeDrawingAreaHeight = (m_viewHeight - k_hourLabelDividerYDist) / totalIcons;
	
	// A counter we use to set the Y location for each event category and icon
	int yLocationIconOffset = 1;
	
	if(m_cachedApplicationObjects)
	{
		if([m_cachedApplicationObjects count]>0)
		{
			// Sort array by total duration
			NSArray* sortedApplicationObjects = [m_cachedApplicationObjects sortedArrayUsingFunction: 
				appsNumberOfEventsCompare context: m_cachedApplicationEventsNumberDictionary];
				
			// ------------------------------- Go over all apps -------------------------------
			
			for(NSManagedObject* appObject in sortedApplicationObjects)
			{
				// ------------------------------- Draw icons -------------------------------
				
				// Get the icon image in the icon cache
				NSImage* appIconImage = [m_iconCacheDictionary objectForKey: [appObject valueForKey: @"name"]];
				
				// See if it was in the cache
				if(appIconImage==nil)
				{
					// Get the icon
					appIconImage = [SLUtilities getIconImageForApplication: [appObject valueForKey: @"name"]];
					
					// If it's valid
					if(appIconImage!=nil)
					{	
						// Store it in the cache
						[m_iconCacheDictionary setObject: appIconImage forKey: [appObject valueForKey: @"name"]];
					}
				}
				
				// Condition the drawing based on the location of the icon. If it's under the hour row, it's ok to draw
				if(((eventTypeDrawingAreaHeight*(totalIcons-yLocationIconOffset)) + 
					(eventTypeDrawingAreaHeight/2) + 16) < (visibleRectY-k_hourLabelDividerYDist))
				{
					// Setting the shadow
					NSShadow* theShadow = [[NSShadow alloc] init];
					[theShadow setShadowOffset:NSMakeSize(3.0, -3.0)];
					[theShadow setShadowBlurRadius:5];
					[theShadow setShadowColor: [NSColor colorWithCalibratedWhite:0.0 alpha:0.6]];
					[theShadow set];

					// Draw the icon, finally
					[appIconImage compositeToPoint: NSMakePoint((k_viewIconOffset/2) - 16, 
						(eventTypeDrawingAreaHeight*(totalIcons-yLocationIconOffset)) + 
							(eventTypeDrawingAreaHeight/2) - 16) operation: NSCompositeSourceOver];
					
					// Release shadow
					[theShadow release];
				}
				
				// ------------------------------- Draw events -------------------------------
				
				NSArray* eventsForApplication = [m_cachedEventsForApplications objectForKey: [appObject valueForKey: @"name"]];
				for(NSManagedObject* eventObject in eventsForApplication)
				{
					// Search string
					if([m_searchString length]>0)
					{
						NSString* eventTitleLowercase = [[eventObject valueForKey: @"title"] lowercaseString];
						
						NSRange searchStringRange = [eventTitleLowercase rangeOfString: m_searchString];
						if(searchStringRange.location!=NSNotFound)
							[self drawEvent: eventObject atOffset: yLocationIconOffset withColor: [appObject valueForKey: @"color"]];
					}
					else
						[self drawEvent: eventObject atOffset: yLocationIconOffset withColor: [appObject valueForKey: @"color"]];
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
//								drawRectCore
// **********************************************************************
- (void)drawRect:(NSRect)rect
{	
	// Figure out how many event sources are active
	m_numberOfActiveEventSources = [self loadEventsAndApplications];
	
	// Set the frame size based on how many event providers are active
	[self calculateFrameSize];
	
    // Counter variable for the loops
    int counter = 0;
    
    // A couple of floats that store the boundary x coords for the hour backcolor rectangle
    float initialXCoordHourBackColorRect = 0;
    float finalXCoordHourBackColorRect = 0;

	// A couple of floats that store the boundary x coords for the current hour backcolor rectangle
    float initialXCoordCurrentHourBackColorRect = 0;
    float finalXCoordCurrentHourBackColorRect = 0;
	
	// The hour of day
	int hourOfDay = [[NSCalendarDate date] hourOfDay];
    
    // Update view width and height
    [self updatemViewWidthAndHeight];
    
	// Find out what is the location of the top of the visible screen
	float visibleRectY = [self visibleRect].size.height + [self visibleRect].origin.y;
	
    // Calculate min and max values based on frame size and minutes we display per view
	m_timeViewZoomSliderMinValue = (m_viewWidth-k_viewIconOffset) / k_minutesInDayView;
    m_timeViewZoomSliderMaxValue = (m_viewWidth-k_viewIconOffset) / k_minutesInHourView;
    
    // Set the min-max values for the time zoom slider based on calculations on initWithFrame
    [m_timeViewZoomSlider setMinValue:m_timeViewZoomSliderMinValue];
    [m_timeViewZoomSlider setMaxValue:m_timeViewZoomSliderMaxValue];
    m_timeViewZoomFactor = [m_timeViewZoomSlider floatValue];
    
    // *************************** View Background *****************************************
    
    // Draw the background of the timeline
    [[NSColor whiteColor] set];
    [NSBezierPath fillRect: [self bounds]];
    
	// ****************************** Hour Back Gray Image *****************************************
	
	for(counter=0; counter<m_viewWidth; counter++)
	{
		// Draw the hour back gray checkbox image
		[m_hourBackGrayImage compositeToPoint:
			NSMakePoint(counter, visibleRectY-(k_hourLabelDividerYDist)-1) operation:NSCompositeSourceOver];
	}
	
    // ****************************** Hour Lines *****************************************
     
    // Make more points
    NSPoint b = NSMakePoint(0, 0);
    NSPoint e = NSMakePoint(0, 0);
    
    // Set the color for the lines
    [[NSColor colorWithCalibratedRed:0.898 green:0.898 blue:0.898 alpha:1.0] set];
    
	// Set the begining point
    b.y = 0;
    b.x = k_viewIconOffset + 0.5;
    
    // Set the final point
    e.x = b.x;
    e.y = m_viewHeight;
        
    // Draw the first line segment
    [NSBezierPath strokeLineFromPoint: b toPoint: e];
	
    // Draw the timeline hour lines
    for(counter = 1; counter < 24; counter++)
    {
        // Set the starting point. Note that the m_timeViewZoomFactor is a variable that indicates how long
        // is a minute in pixels in our representation. In this case, for each iteration of the loop, b.x is increased 
        // by an hour (60*) in pixels, based on the value of m_timeViewZoomFactor. Whenever m_timeViewZoomFactor is not at its
        // minimum value, then shift the pixels for the hour selected by m_timeScaleReference to the origin proportionally to
        // the value of m_timeViewZoomFactor.
        
        if(m_timeViewZoomFactor==m_timeViewZoomSliderMinValue)
            b.x = (60*m_timeViewZoomFactor*counter) + k_viewIconOffset;
        else
            b.x = 60*m_timeViewZoomFactor*counter - 
                ( ( (m_timeScaleReference*(m_viewWidth-k_viewIconOffset)) / (m_timeViewZoomSliderMaxValue-m_timeViewZoomSliderMinValue) ) * 
                    (m_timeViewZoomFactor- m_timeViewZoomSliderMinValue) ) + k_viewIconOffset;
        
        // Set the y coordinate
        b.y = 0;
        
        // Adjust the value of x to hit the pixels in the head
        int t = b.x;
        
        // If t is zero, we will draw on top of the border of the frame. No good.
        if(t==0)
            t++;
            
        // Here we hit the head
        b.x = t + 0.5;
        
        // Don't go over the frame width boundary
        if(b.x>=m_viewWidth)
            b.x = m_viewWidth-1.5;
            
        // Set the final point
        e.x = b.x;
        e.y = m_viewHeight;
        
        // Draw the line segment only if it's not going to overdraw the icons area
		if(b.x>=(k_viewIconOffset + 0.5))
			[NSBezierPath strokeLineFromPoint: b toPoint: e];
        
        // Set the initial and final coords based on m_timeScaleReference
        if(m_timeScaleReference==0)
            initialXCoordHourBackColorRect = k_viewIconOffset + 1;
        else if(m_timeScaleReference==counter)
            initialXCoordHourBackColorRect = b.x;
        
        if((m_timeScaleReference+1)==counter)
            finalXCoordHourBackColorRect = b.x;
        else if(finalXCoordHourBackColorRect==0)
            finalXCoordHourBackColorRect = m_viewWidth-1;
		
		// Coordinates for the hour of day color background
		if(hourOfDay==0)
            initialXCoordCurrentHourBackColorRect = k_viewIconOffset + 1;
        else if(hourOfDay==counter)
            initialXCoordCurrentHourBackColorRect = b.x;
        
        if((hourOfDay+1)==counter)
            finalXCoordCurrentHourBackColorRect = b.x;
        else if(finalXCoordCurrentHourBackColorRect==0)
            finalXCoordCurrentHourBackColorRect = m_viewWidth-1;

    }
	
	// ************************ Current Hour BackColor Rectangle **********************************
	
	NSCalendarDate* nowDate = [NSCalendarDate date];
	
	// Get the date day, month and year
	int dateYear, dateMonth, dateDay;
	
	dateYear = [m_selectedDate yearOfCommonEra];
	dateMonth = [m_selectedDate monthOfYear];
	dateDay = [m_selectedDate dayOfMonth];
	
	// Get the current day, month and year
	int nowYear, nowMonth, nowDay;
	
	nowYear = [nowDate yearOfCommonEra];
	nowMonth = [nowDate monthOfYear];
	nowDay = [nowDate dayOfMonth];
	
	// Make sure the view is showing today. If it is, draw the current hour backcolor
	if((dateYear==nowYear) && (dateMonth==nowMonth) && (dateDay==nowDay))
	{
		// A rect for the hour backcolor
		NSRect backColorRect;
		
		// Calculate the origin for the current hour backcolor rectangle. It's the hour in pixels
		// multiplied by the timescale reference. The y coord is just 1, to exclude the border.
		backColorRect.origin.x = initialXCoordCurrentHourBackColorRect;
		backColorRect.origin.y = 0;
		
		// The width is going to be the width of an hour in pixels. Note that the m_timeViewZoomFactor is a 
		// variable that indicates how long is a minute in pixels in our representation.
		backColorRect.size.width = finalXCoordCurrentHourBackColorRect - initialXCoordCurrentHourBackColorRect;
		
		// The height will be the height of the m_viewHeight minus the distance of the hour labels divisor line minus 1
		backColorRect.size.height = visibleRectY - k_hourLabelDividerYDist;
		
		// Set the color of the hour backcolor rectangle
		[[NSColor colorWithCalibratedRed:0.9725 green:0.9725 blue:0.9725 alpha:1.0] set];
		
		// Draw the hour backcolor rectangle
		[NSBezierPath fillRect: backColorRect];
	}
	
    // ************************ Hour BackColor Rectangle **********************************
    
    // A rect for the hour backcolor
    NSRect backColorRect;
    
    // Calculate the origin for the hour backcolor rectangle. It's the hour in pixels
    // multiplied by the timescale reference. The y coord is just 1, to exclude the border.
    backColorRect.origin.x = initialXCoordHourBackColorRect;
    backColorRect.origin.y = 0;
    
    // The width is going to be the width of an hour in pixels. Note that the m_timeViewZoomFactor is a 
    // variable that indicates how long is a minute in pixels in our representation.
    backColorRect.size.width = finalXCoordHourBackColorRect - initialXCoordHourBackColorRect;
    
    // The height will be the height of the m_viewHeight minus the distance of the hour labels divisor line minus 1
    backColorRect.size.height = m_viewHeight-(k_hourLabelDividerYDist+0.5)-1;
    
    // Set the color of the hour backcolor rectangle
    [[NSColor colorWithCalibratedRed:0.9412 green:0.9608 blue:0.9843 alpha:1.0] set];
    
    // Draw the hour backcolor rectangle
    [NSBezierPath fillRect: backColorRect];
	
    // ****************************** Divisors *****************************************
     
    // Set the color of the divisor lines
    [[NSColor colorWithCalibratedRed:0.8 green:0.8 blue:0.8 alpha:1.0] set];
	
    // Draw the divisor line between hour labels and rest of view
    [NSBezierPath strokeLineFromPoint:NSMakePoint(0, (visibleRectY-(k_hourLabelDividerYDist + 0.5))) 
        toPoint:NSMakePoint(m_viewWidth, (visibleRectY-(k_hourLabelDividerYDist + 0.5)))];
    
    // Calculate how much height for each event type area
    int eventTypeDrawingAreaHeight = (m_viewHeight - k_hourLabelDividerYDist) / m_numberOfActiveEventSources;
    
	// We draw one less divisor line than the number of rows... One is alredy done (above)
	int totalDivisors = m_numberOfActiveEventSources - 1;
	
	// Loop and draw the divisors
	for(counter=1; counter<=totalDivisors; counter++)
	{
		// Condition the drawing based on the location of the divisor. If it's under the hour row, it's ok to draw
		if((eventTypeDrawingAreaHeight*counter) < (visibleRectY-k_hourLabelDividerYDist))
		{
			[NSBezierPath strokeLineFromPoint:NSMakePoint(0, (eventTypeDrawingAreaHeight*counter) + 0.5) 
				toPoint:NSMakePoint(m_viewWidth, (eventTypeDrawingAreaHeight*counter) + 0.5)];
		}
	}
	
    // ****************************** Hour Back Hilite Image *****************************************
    
    // Here we do something fun. We calculate how wide the area to be filled is. Then we draw our image from
    // the initial hour line an x number of times and from the final hour line an x number of time as well.
    // The many images overlap in the middle of the target area and we cover the entire region.
    
    // Calculate the distance between hour lines
    int distBetweenHourLines = finalXCoordHourBackColorRect - initialXCoordHourBackColorRect;
    
    // Set the initial hour line
    int xCoordm_hourBackHiliteImage = initialXCoordHourBackColorRect;
    
    // Draw the image a number of times
    for(counter= 0; counter <= distBetweenHourLines; counter++)
    {
        // Draw the hour back hilite checkbox image
        [m_hourBackHiliteImage compositeToPoint:
            NSMakePoint(xCoordm_hourBackHiliteImage+counter, visibleRectY-(k_hourLabelDividerYDist)-1) operation:NSCompositeSourceOver];
	}
    
    // Set the color for the vertical lines
    [[NSColor colorWithCalibratedRed:0.3137 green:0.4549 blue:0.7490 alpha:1.0] set];
    
    // Draw the left vertical line bordering the hilite image
    [NSBezierPath strokeLineFromPoint:NSMakePoint(initialXCoordHourBackColorRect, (visibleRectY-(k_hourLabelDividerYDist))) 
        toPoint:NSMakePoint(initialXCoordHourBackColorRect, (visibleRectY))];

    // Draw the right vertical line bordering the hilite image
    [NSBezierPath strokeLineFromPoint:NSMakePoint(finalXCoordHourBackColorRect, (visibleRectY-(k_hourLabelDividerYDist))) 
        toPoint:NSMakePoint(finalXCoordHourBackColorRect, (visibleRectY))];

    // ****************************** Hour Labels *****************************************
    
    // A reference point
    NSPoint p = NSMakePoint(0, 0);
    
	// Create a paragraph style
    NSMutableParagraphStyle* paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    
    // Set the paragraph style
    [paragraphStyle setParagraphStyle:[NSParagraphStyle defaultParagraphStyle]];
    [paragraphStyle setAlignment:NSCenterTextAlignment];
    [paragraphStyle setLineBreakMode:NSLineBreakByClipping];
    [paragraphStyle setMaximumLineHeight:15];
    [paragraphStyle setMinimumLineHeight:15];

    // Create a new dictionary as attribute to the line labels
    NSMutableDictionary* stringAttribsDict = [[NSMutableDictionary alloc] init];
    [stringAttribsDict setObject:[NSColor blackColor] forKey:NSForegroundColorAttributeName];
    [stringAttribsDict setObject:[NSFont fontWithName: @"Helvetica" size: 9] forKey: NSFontAttributeName];
    [stringAttribsDict setObject:[[paragraphStyle copy] autorelease] forKey: NSParagraphStyleAttributeName];
		
    // Draw the timeline labels
    for(counter = 0; counter < 24; counter++)
    {
        // Set the starting point. Note that the m_timeViewZoomFactor is a variable that indicates how long
        // is a minute in pixels in our representation. In this case, for each iteration of the loop, p.x is increased 
        // by an hour (60*) in pixels, based on the value of m_timeViewZoomFactor. Whenever m_timeViewZoomFactor is not at its
        // minimum value, then shift the pixels for the hour selected by m_timeScaleReference to the origin proportionally to
        // the value of m_timeViewZoomFactor.
        
        if(m_timeViewZoomFactor==m_timeViewZoomSliderMinValue)
            p.x = (60*m_timeViewZoomFactor*counter) + k_viewIconOffset;
        else
            p.x = 60*m_timeViewZoomFactor*counter - 
                ( ( (m_timeScaleReference*(m_viewWidth-k_viewIconOffset)) / (m_timeViewZoomSliderMaxValue-m_timeViewZoomSliderMinValue) ) * 
                    (m_timeViewZoomFactor- m_timeViewZoomSliderMinValue) ) + k_viewIconOffset;

        // Set the y coord here
        p.y = visibleRectY;
		
		// The hour label
		NSString* hourLabel;
		
		// Translate the counter into an actual hour, if necessary
		int hour;
		if(counter<=23)
			hour = counter;
		else
			hour = counter - 24;
		
		// Include am/pm only if there's room
		if(distBetweenHourLines>24)
		{
			// Decide which labels to use
		
			if(hour==0)
				hourLabel = [NSString stringWithFormat:@"12am"];
			else if(hour<12)
				hourLabel = [NSString stringWithFormat:@"%dam",hour];
			else if(hour==12)
				hourLabel = [NSString stringWithFormat:@"12pm"];
			else
				hourLabel = [NSString stringWithFormat:@"%dpm",hour-12];
		}
		else if( (distBetweenHourLines>20) && (distBetweenHourLines<=24))
		{
			// Decide which labels to use
		
			if(hour==0)
				hourLabel = [NSString stringWithFormat:@"12"];
			else if(hour<12)
				hourLabel = [NSString stringWithFormat:@"%d",hour];
			else if(hour==12)
				hourLabel = [NSString stringWithFormat:@"12"];
			else
				hourLabel = [NSString stringWithFormat:@"%d",hour-12];
		}
		else
			hourLabel = @"";
			
		// Draw the label only if it's not going to overdraw the icons area
		if(p.x>=(k_viewIconOffset - 3))
		{
			// Create the drawing rect
			NSRect hourLabelRect;
			
			// Set the parameters for the drawing rect
			hourLabelRect.origin.x = p.x + 3;
			hourLabelRect.origin.y = p.y - k_hourLabelYDist;
			hourLabelRect.size.width = k_hourLabelWidth;
			hourLabelRect.size.height = k_hourLabelHeight;
		
			// Draw the labels
			[hourLabel drawInRect: hourLabelRect withAttributes: stringAttribsDict];
		}
    }

    // Release the dict
    [stringAttribsDict release];
    
    // Release the paragraph style
    [paragraphStyle release];
    
    
	// ---------------------------- Icons --------------------------------
	
	// Draw the icons
	[self drawIconsAndEvents];
	
	// -------------------------------- Scroll To Top -----------------------------------------
	
	// Scroll to the top if first time
	if(m_scrollToTop)
	{
		[self scrollToTop];
		m_scrollToTop = NO;
	}
	
	// ---------------------------- Cache Reset --------------------------------
	
	m_useCachedEventsOnRedraw = FALSE;
    
}

@end
