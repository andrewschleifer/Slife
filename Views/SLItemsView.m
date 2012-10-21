
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

#import "SLItemsView.h"
#import "SLUtilities.h"
#import "SLBarGraphView.h"

// **********************************************************************
//							Constants
// **********************************************************************

extern int k_dayRange;
extern int k_monthRange;

extern int k_itemHeight;
extern int k_itemHeaderHeight;
extern int k_itemNameBarLineOffset;
extern int k_itemNameLeftOffset;
extern int k_itemNameRightOffset;
extern int k_itemIconLeftOffset;
extern int k_itemViewBarLeftHorizontalOffset;
extern int k_itemViewBarRightHorizontalOffset;


// **********************************************************************
//
//						SLItemsView (Private)
//
// **********************************************************************

@interface SLItemsView (Private)

- (void) dateChanged: (NSNotification *) notification;

- (void) drawItems;
- (void) updateViewWidthAndHeight;

@end


// **********************************************************************
//
//							SLItemsView
//
// **********************************************************************

@implementation SLItemsView

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
		m_itemDurationDictionary = [NSMutableDictionary dictionaryWithCapacity: 5];
		m_itemAppIconImageDictionary = [NSMutableDictionary dictionaryWithCapacity: 5];
		m_itemRect = [NSMutableDictionary dictionaryWithCapacity: 5];
		
		m_useCachedItemsOnRedraw = FALSE;
		
		m_itemSelected = nil;
		m_numberOfItems = 0;
		
		// Nothing for search string yet
		m_searchString = @"";
		m_searchTextFieldTimer = nil;
		
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
	
	[m_itemDateTextField setStringValue: [m_selectedDate descriptionWithCalendarFormat: @"%B %e, %Y"]];
	[m_itemSelectedNameTextField setStringValue: @""];

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
		[m_itemDateTextField setStringValue: [m_selectedDate descriptionWithCalendarFormat: @"%B %e, %Y"]];
	}
	else if(m_selectedDateRange==k_monthRange)
	{
		[m_itemDateTextField setStringValue: [m_selectedDate descriptionWithCalendarFormat: @"%B %Y"]];
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
//					loadItemRecordsForSelectedDateRange
// **********************************************************************
- (void) loadItemRecordsForSelectedDateRange
{
	NSManagedObjectContext* managedContext = [[NSApp delegate] managedObjectContext];
	
	// ------------------------------ Item Recorded & Duration --------------------------------
		
	NSFetchRequest* itemRecordedRequest = [[[NSFetchRequest alloc] init] autorelease];
	NSEntityDescription* itemRecordedEntity = [NSEntityDescription entityForName: @"ItemRecorded" inManagedObjectContext: managedContext];
	[itemRecordedRequest setEntity: itemRecordedEntity];
	
	NSPredicate* itemRecordedPredicate = nil;
	if(m_selectedDateRange==k_dayRange)
	{
		itemRecordedPredicate = [NSPredicate predicateWithFormat: 
			@"targetDay == %@ AND targetMonth == %@ AND targetYear == %@", 
			[NSNumber numberWithInt: [m_selectedDate dayOfMonth]],
			[NSNumber numberWithInt: [m_selectedDate monthOfYear]], 
			[NSNumber numberWithInt: [m_selectedDate yearOfCommonEra]]];
	}
	else if(m_selectedDateRange==k_monthRange)
	{
		itemRecordedPredicate = [NSPredicate predicateWithFormat: 
			@"targetMonth == %@ AND targetYear == %@", 
			[NSNumber numberWithInt: [m_selectedDate monthOfYear]], 
			[NSNumber numberWithInt: [m_selectedDate yearOfCommonEra]]];
	}
	
	[itemRecordedRequest setPredicate: itemRecordedPredicate];
	
	NSError* error = nil;
	NSArray* itemsRecordedForSelectedDate = [managedContext executeFetchRequest:itemRecordedRequest error:&error];
	
	// Go over all items - We have a loop because we want to calculate item duration per day, while
	// we save them per hour. So we need to go over all hours for a day.
	for(NSManagedObject* itemRecorded in itemsRecordedForSelectedDate)
	{
		NSString* itemRecordedName = [itemRecorded valueForKey: @"name"];
		NSString* itemRecordedAppName = [itemRecorded valueForKey: @"applicationName"];
		NSNumber* itemRecordedDuration = [itemRecorded valueForKey: @"duration"];
		
		// Save icon
		NSImage* itemAppIconImage = [m_itemAppIconImageDictionary objectForKey: itemRecordedName];
		if(nil==itemAppIconImage)
		{
			[m_itemAppIconImageDictionary setObject: [SLUtilities getIconImageForApplication:  itemRecordedAppName]
				forKey: itemRecordedName];
		}
		
		// See if there's a duration for item
		NSNumber* itemTotalDuration = [m_itemDurationDictionary objectForKey: itemRecordedName];
		
		if(nil==itemTotalDuration)
		{
			// No, save duration
			[m_itemDurationDictionary setObject: itemRecordedDuration forKey: itemRecordedName];
			
			itemTotalDuration = itemRecordedDuration;
		}
		else
		{
			// Yes, calculate and save new duration
			itemTotalDuration = [NSNumber numberWithDouble: 
				[itemRecordedDuration doubleValue] + [itemTotalDuration doubleValue]];
				
			[m_itemDurationDictionary setObject: itemTotalDuration forKey: itemRecordedName];
		}
		
		// We want to save the highest duration value to know how to draw the bars
		if([itemTotalDuration doubleValue]>m_longestDurationItemEvents)
			m_longestDurationItemEvents = [itemTotalDuration doubleValue];
	}	
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
	int idealHeight = m_numberOfItems*k_itemHeight;
	
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
//						itemsDurationCompare
// **********************************************************************
NSInteger itemsDurationCompare(id obj1, id obj2, void* context)
{
	NSString* itemsObj1 = (NSString*) obj1;
	NSString* itemsObj2 = (NSString*) obj2; 
	NSDictionary* itemsDurationDictionary = (NSDictionary*) context;
	
	NSNumber* itemsObjDuration1 = [itemsDurationDictionary objectForKey: itemsObj1];
	NSNumber* itemsObjDuration2 = [itemsDurationDictionary objectForKey: itemsObj2];
	
    float v1 = [itemsObjDuration1 floatValue];
    float v2 = [itemsObjDuration2 floatValue];
	
    if (v1 < v2)
		return NSOrderedDescending;
    else if (v1 > v2)
		return NSOrderedAscending;
    else
        return NSOrderedSame;
}

#pragma mark --- Drawing ---

// **********************************************************************
//							drawItems
// **********************************************************************
- (void) drawItems
{
	// Calculate how much height for each event type area
    int itemDrawingAreaHeight = k_itemHeight;
	
	// A counter we use to set the Y location for each event category and icon
	int yLocationIconOffset = 1;
	
	m_itemObjects = [m_itemDurationDictionary allKeys];
	
	// Sanity check
	if(m_itemObjects)
	{
		// Avoid during work if not needed
		if([m_itemObjects count]>0)
		{
			// Sort array by total duration
			NSArray* sortedItemsObjects = [m_itemObjects sortedArrayUsingFunction: 
				itemsDurationCompare context: m_itemDurationDictionary];
			
			// Create a new dictionary with attribute for bar duration labels
			NSMutableDictionary* barDurationLabelStringAttribsDict = [NSMutableDictionary dictionaryWithCapacity: 5];
			[barDurationLabelStringAttribsDict setObject:[NSColor colorWithCalibratedRed:0.5 green:0.5 blue:0.5 alpha:1.0] forKey:NSForegroundColorAttributeName];
			[barDurationLabelStringAttribsDict setObject:[NSFont fontWithName: @"Lucida Grande" size: 11] forKey: NSFontAttributeName];

			// Go over every item in the store
			for(NSString* itemName in sortedItemsObjects)
			{
				// Search string
				if([m_searchString length]>0)
				{
					NSString* itemNameLowercase = [itemName lowercaseString];
					
					NSRange searchStringRange = [itemNameLowercase rangeOfString: m_searchString];
					if(searchStringRange.location==NSNotFound)
						continue;
				}

				// -------------------------------- Bar Duration String --------------------------------
				
				NSString* barDurationString = nil;
				int totalSecondsForAppEvents = [[m_itemDurationDictionary objectForKey: itemName] floatValue];
				if(totalSecondsForAppEvents>0)
				{
					barDurationString = [SLUtilities convertSecondsToTimeString: totalSecondsForAppEvents withRounding: NO];
				}
				
				if(nil!=m_itemSelected)
				{
					// -------------------------------------- Selection --------------------------------------

					if([m_itemSelected isEqualToString: itemName])
					{
						[[NSColor colorWithCalibratedRed:0.9412 green:0.9608 blue:0.9843 alpha:1.0] set];
						
						NSRect itemRect;
						itemRect.origin.x = 0;
						itemRect.origin.y = m_viewHeight - k_itemHeaderHeight - (itemDrawingAreaHeight*yLocationIconOffset) + 1;
						itemRect.size.height = itemDrawingAreaHeight - 1;
						itemRect.size.width = m_viewWidth;
						
						[NSBezierPath fillRect: itemRect];
						
						if(barDurationString)
						{
							if(m_selectedDateRange==k_dayRange)
							{
								[m_itemDateTextField setStringValue: [m_selectedDate descriptionWithCalendarFormat: @"%B %e, %Y"]];
							}
							else if(m_selectedDateRange==k_monthRange)
							{
								[m_itemDateTextField setStringValue: [m_selectedDate descriptionWithCalendarFormat: @"%B %Y"]];
							}
					
							// Limit to 30 chars
							NSString* itemNameFormatted = [SLUtilities limitString: itemName toNumberOfCharacters: 40];
							[m_itemSelectedNameTextField setStringValue: itemNameFormatted];
						}
					}
				}
				else
				{
					if(m_selectedDateRange==k_dayRange)
					{
						[m_itemDateTextField setStringValue: [m_selectedDate descriptionWithCalendarFormat: @"%B %e, %Y"]];
					}
					else if(m_selectedDateRange==k_monthRange)
					{
						[m_itemDateTextField setStringValue: [m_selectedDate descriptionWithCalendarFormat: @"%B %Y"]];
					}
					
					[m_itemSelectedNameTextField setStringValue: @""];
				}
	
				// ---------------------------------- App icon -------------------------------------------------
				
				// Get the icon image
				NSImage* itemIconImage = [m_itemAppIconImageDictionary objectForKey: itemName];
				
				// Draw the icon, finally
				if(itemIconImage)
				{
					[itemIconImage setSize: NSMakeSize(16,16)];
					[itemIconImage compositeToPoint: NSMakePoint(k_itemIconLeftOffset, 
						m_viewHeight - k_itemHeaderHeight - (itemDrawingAreaHeight*yLocationIconOffset) + (itemDrawingAreaHeight/2) - 9) 
						operation: NSCompositeSourceOver];
				}
				
				// ---------------------------------- App name -------------------------------------------------
				
				// Limit to 60 chars
				NSString* itemNameFormatted = [SLUtilities limitString: itemName toNumberOfCharacters: 55];
				
				// Create a paragraph style
				NSMutableParagraphStyle* paragraphStyle = [[NSMutableParagraphStyle alloc] init];
				
				// Set the paragraph style
				[paragraphStyle setParagraphStyle:[NSParagraphStyle defaultParagraphStyle]];
				[paragraphStyle setAlignment:NSRightTextAlignment];
				[paragraphStyle setLineBreakMode:NSLineBreakByClipping];

				// Create a new dictionary with attribute for item names
				NSMutableDictionary* itemNameStringAttribsDict = [NSMutableDictionary dictionaryWithCapacity: 5];
				[itemNameStringAttribsDict setObject:[NSColor blackColor] forKey:NSForegroundColorAttributeName];
				[itemNameStringAttribsDict setObject:[NSFont fontWithName: @"Lucida Grande" size: 11] forKey: NSFontAttributeName];
				[itemNameStringAttribsDict setObject: paragraphStyle forKey: NSParagraphStyleAttributeName];

				[paragraphStyle release];
				
				// Create the drawing rect
				NSRect itemNameRect;
				NSSize itemNameStringSize = [itemNameFormatted sizeWithAttributes: itemNameStringAttribsDict];
				itemNameRect.size = itemNameStringSize;
				
				// Set the parameters for the drawing rect for the item name
				itemNameRect.origin.x = k_itemIconLeftOffset + 16 + k_itemNameLeftOffset;
				itemNameRect.origin.y = m_viewHeight - k_itemHeaderHeight - 
					(itemDrawingAreaHeight*yLocationIconOffset) + (itemDrawingAreaHeight/2) - 8;
		
				[itemNameFormatted drawInRect: itemNameRect withAttributes: itemNameStringAttribsDict];
				
				if(totalSecondsForAppEvents>0)
				{
					// ------------------ Draw the bar ----------------------

					int itemBarHeight = 16;
					int itemBarXCoordinate = k_itemNameBarLineOffset + k_itemViewBarLeftHorizontalOffset;
					
					int itemBarYCoordinate = m_viewHeight - k_itemHeaderHeight - 
						(itemDrawingAreaHeight*yLocationIconOffset) + (itemDrawingAreaHeight/2) - (itemBarHeight/2);
						
					int longestAppBarWidth = m_viewWidth - itemBarXCoordinate - k_itemViewBarRightHorizontalOffset;
				
					int itemBarWidth = longestAppBarWidth / m_longestDurationItemEvents * totalSecondsForAppEvents;
					
					if(itemBarWidth<12)
						itemBarWidth=12;
						
					NSRect theRect = NSMakeRect(itemBarXCoordinate, itemBarYCoordinate, itemBarWidth, itemBarHeight);
					
					[[NSColor colorWithCalibratedRed:0.898 green:0.898 blue:0.898 alpha:1.0] set];
					
					//[NSBezierPath fillRect: theRect];
					
					NSBezierPath* rectBezier = [NSBezierPath bezierPathWithRoundedRect: theRect xRadius: 3.0 yRadius: 3.0];
					[rectBezier fill];
		
					// ------------------ Draw the duration -----------------
					
					// Create the drawing rect
					NSRect barDurationLabelRect;
					
					// Set the parameters for the drawing rect for the bar duration label
					barDurationLabelRect.origin.x = itemBarXCoordinate + itemBarWidth + 10;
					
					barDurationLabelRect.origin.y = m_viewHeight - k_itemHeaderHeight - 
						(itemDrawingAreaHeight*yLocationIconOffset) + (itemDrawingAreaHeight/2) - (itemBarHeight/3);
						
					barDurationLabelRect.size.width = 200;
					barDurationLabelRect.size.height = 12;
			
					// Draw the labels
					if(barDurationString)
						[barDurationString drawInRect: barDurationLabelRect withAttributes: barDurationLabelStringAttribsDict];
					
					// ------------------ Save App Rect -----------------
					
					NSRect itemRect;
					itemRect.origin.x = 0;
					itemRect.origin.y = m_viewHeight - k_itemHeaderHeight - (itemDrawingAreaHeight*yLocationIconOffset);
					itemRect.size.height = itemDrawingAreaHeight;
					itemRect.size.width = m_viewWidth;
					
					NSString* itemRectString = NSStringFromRect(itemRect);
					[m_itemRect setObject: itemRectString forKey: itemName];
				}
				
				// Decrement the Y location icon offset
				yLocationIconOffset++;
			}
		}
	}
	else
	{
		NSLog(@"Slife: Application objects are nil when trying to draw item icons");
	}
}

// **********************************************************************
//								drawRect
// **********************************************************************
- (void)drawRect:(NSRect)rect
{	
	// Initialization and cleanup
	int counter = 0;
	[m_itemRect removeAllObjects];
	
	// -------------------------------- Get data from items -----------------------------------------
	
	if(!m_useCachedItemsOnRedraw || ([[m_itemDurationDictionary allValues] count]==0))
	{
		[m_itemDurationDictionary removeAllObjects];
		m_longestDurationItemEvents = 0;
		
		// ---------------------- Compute total and longest duration of events for item given time range ---------------------------
		
		[self loadItemRecordsForSelectedDateRange];
		
		// Search string
		if([m_searchString length]>0)
		{
			m_numberOfItems = 0;
			
			for(NSString* itemName in [m_itemDurationDictionary allKeys])
			{
				NSString* itemNameLowercase = [itemName lowercaseString];
				
				NSRange searchStringRange = [itemNameLowercase rangeOfString: m_searchString];
				if(searchStringRange.location!=NSNotFound)
					m_numberOfItems++;
			}
		}
		else
			m_numberOfItems = [[m_itemDurationDictionary allKeys] count];
			
		// -------------------------------- Refresh Bar Graph -------------------------------------
	
		[m_itemBarGraphView setNeedsDisplay: YES];		
	}
	else
	{
		// -------------------------------- Refresh Bar Graph With Cache --------------------------
	
		[m_itemBarGraphView setNeedsDisplayOptimized];		
	}

	// -------------------------------- Adjust view size -----------------------------------------
	
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
    int itemDrawingAreaHeight = k_itemHeight;
    
	// We draw one less divisor line than the number of rows
	int totalDivisors = m_numberOfItems;
	
	// Loop and draw the divisors
	for(counter=1; counter<=totalDivisors; counter++)
	{
		[NSBezierPath strokeLineFromPoint:NSMakePoint(0, m_viewHeight - k_itemHeaderHeight - (itemDrawingAreaHeight*counter) + 0.5) 
			toPoint:NSMakePoint(m_viewWidth, m_viewHeight - k_itemHeaderHeight - (itemDrawingAreaHeight*counter) + 0.5)];
	}
    
	// ------------------------ Draw Items ------------------------------------------
	
	// Draw the items
	[self drawItems];
	
	// -------------------------------- Vertical Separator -----------------------------------------
	
	// Make points
    NSPoint b = NSMakePoint(0, 0);
    NSPoint e = NSMakePoint(0, 0);
    
    // Set the color for the lines
    [[NSColor colorWithCalibratedRed:0.898 green:0.898 blue:0.898 alpha:1.0] set];
    
	// Set the begining point
    b.y = 0;
    b.x = k_itemNameBarLineOffset + 0.5;
    
    // Set the final point
    e.x = b.x;
    e.y = m_viewHeight;
        
    // Draw the first line segment
    [NSBezierPath strokeLineFromPoint: b toPoint: e];

	// -------------------------------- Scroll To Top -----------------------------------------
	
	// Scroll to the top if first time
	if(m_scrollToTop)
	{
		[self performSelector: @selector(scrollToTop) withObject: nil afterDelay: 0];
		m_scrollToTop = NO;
	}
		
	// -------------------------------- Disable cache  ---------------------------------------
	
	m_useCachedItemsOnRedraw = FALSE;
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
	m_itemSelected = nil;
	
    // Get the click location and convert it
    NSPoint clickPoint = [self convertPoint:[event locationInWindow] fromView: nil];
    
	NSString* anApp = nil;
	for( anApp in m_itemRect)
	{
		NSString* itemRectString = [m_itemRect objectForKey: anApp];
		NSRect itemRect = NSRectFromString(itemRectString);
		
		// See if the click occurred within the rect
		if(NSMouseInRect(clickPoint, itemRect, NO))
		{
			
			// If we have only one click, display it in the main window
			if([event clickCount]==1)
			{
				m_itemSelected = anApp;
			}
			
			// If a double-click, display it in the main window
			else if([event clickCount]>1)
			{
				m_itemSelected = anApp;
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
	m_useCachedItemsOnRedraw = TRUE;
}

// **********************************************************************
//                          windowResizeIsHappening
// **********************************************************************
- (void) windowResizeIsHappening: (NSNotification *) notification
{
	// We want to use the cached events
	m_useCachedItemsOnRedraw = TRUE;
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

#pragma mark --- BarGraph Datasource ---

// **********************************************************************
//							valueForBar
// **********************************************************************
- (int) barGraph: (SLBarGraphView*) aBarGraphView valueForBar: (int) barNumber 
{	
	// ---------------------- Compute total and longest duration of events for item given time range ---------------------------
	
	int selectedDay = [m_selectedDate dayOfMonth];
	int selectedMonth = [m_selectedDate monthOfYear];
	int selectedYear = [m_selectedDate yearOfCommonEra];
	
	NSManagedObjectContext* managedContext = [[NSApp delegate] managedObjectContext];
	
	NSFetchRequest* itemRecordedRequest = [[[NSFetchRequest alloc] init] autorelease];
	NSEntityDescription* itemRecordedEntity = [NSEntityDescription entityForName: @"ItemRecorded" inManagedObjectContext: managedContext];
	[itemRecordedRequest setEntity: itemRecordedEntity];
	
	NSPredicate* itemRecordedPredicate = nil;
	if(m_selectedDateRange==k_dayRange)
	{
		itemRecordedPredicate = [NSPredicate predicateWithFormat: 
			@"targetHour == %@ AND targetDay == %@ AND targetMonth == %@ AND targetYear == %@", 
			[NSNumber numberWithInt: barNumber], [NSNumber numberWithInt: selectedDay],
			[NSNumber numberWithInt: selectedMonth], [NSNumber numberWithInt: selectedYear]];
	}
	else if(m_selectedDateRange==k_monthRange)
	{
		itemRecordedPredicate = [NSPredicate predicateWithFormat: 
			@"targetDay == %@ AND targetMonth == %@ AND targetYear == %@", 
			[NSNumber numberWithInt: barNumber+1], [NSNumber numberWithInt: selectedMonth], 
			[NSNumber numberWithInt: selectedYear]];
	}
	
	[itemRecordedRequest setPredicate: itemRecordedPredicate];
	
	double totalSecondsForApplicationsRecorded = 0;
	NSError* error = nil;
	NSArray* itemRecordsForSelectedDate = [managedContext executeFetchRequest: itemRecordedRequest error:&error];
	
	for(NSManagedObject* itemRecorded in itemRecordsForSelectedDate)
	{
		NSNumber* itemRecordedDuration = [itemRecorded valueForKey: @"duration"];
		totalSecondsForApplicationsRecorded += [itemRecordedDuration doubleValue];
	}
	
	return totalSecondsForApplicationsRecorded;
}

// **********************************************************************
//						valueForHighlightBar
// **********************************************************************
- (int) barGraph: (SLBarGraphView*) aBarGraphView valueForHighlightBar: (int) barNumber 
{	
	if(nil==m_itemSelected)
		return 0;
	
	// ---------------------- Compute total and longest duration of events for item given time range ---------------------------
	
	int selectedDay = [m_selectedDate dayOfMonth];
	int selectedMonth = [m_selectedDate monthOfYear];
	int selectedYear = [m_selectedDate yearOfCommonEra];
	
	NSManagedObjectContext* managedContext = [[NSApp delegate] managedObjectContext];
	
	NSFetchRequest* itemRecordedRequest = [[[NSFetchRequest alloc] init] autorelease];
	NSEntityDescription* itemRecordedEntity = [NSEntityDescription entityForName: @"ItemRecorded" inManagedObjectContext: managedContext];
	[itemRecordedRequest setEntity: itemRecordedEntity];
	
	NSPredicate* itemRecordedPredicate = nil;
	if(m_selectedDateRange==k_dayRange)
	{
		itemRecordedPredicate = [NSPredicate predicateWithFormat: 
			@"name == %@ AND targetHour == %@ AND targetDay == %@ AND targetMonth == %@ AND targetYear == %@", 
			m_itemSelected, [NSNumber numberWithInt: barNumber], [NSNumber numberWithInt: selectedDay],
			[NSNumber numberWithInt: selectedMonth], [NSNumber numberWithInt: selectedYear]];
	}
	else if(m_selectedDateRange==k_monthRange)
	{
		itemRecordedPredicate = [NSPredicate predicateWithFormat: 
			@"name == %@ AND targetDay == %@ AND targetMonth == %@ AND targetYear == %@", 
			m_itemSelected, [NSNumber numberWithInt: barNumber+1], [NSNumber numberWithInt: selectedMonth], 
			[NSNumber numberWithInt: selectedYear]];
	}
	
	[itemRecordedRequest setPredicate: itemRecordedPredicate];
	
	double totalSecondsForApplicationsRecorded = 0;
	NSError* error = nil;
	NSArray* itemRecordsForSelectedDate = [managedContext executeFetchRequest: itemRecordedRequest error:&error];
	
	for(NSManagedObject* itemRecorded in itemRecordsForSelectedDate)
	{
		NSNumber* itemRecordedDuration = [itemRecorded valueForKey: @"duration"];
		totalSecondsForApplicationsRecorded += [itemRecordedDuration doubleValue];
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
		
		if([m_itemBarGraphView bounds].size.width>700)
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
		labelString = [m_selectedDate descriptionWithCalendarFormat: @"Web & Documents For %B %e, %Y"]; 
	}
	else if(m_selectedDateRange==k_monthRange)
	{
		labelString = [m_selectedDate descriptionWithCalendarFormat: @"Web & Documents For %B %Y"];
	}
		
	return labelString;

}

@end
