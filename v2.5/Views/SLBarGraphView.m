
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

#import "SLBarGraphView.h"
#import "SLUtilities.h"

@interface NSObject (SLBarGraphViewDelegateProtocol)

- (int) barGraph: (SLBarGraphView*) aBarGraphView valueForBar: (int) barNumber;
- (int) barGraph: (SLBarGraphView*) aBarGraphView valueForHighlightBar: (int) barNumber;
- (NSString*) barGraph: (SLBarGraphView*) aBarGraphView labelForBar: (int) barNumber;
- (int) numberOfBarsForBarGraph: (SLBarGraphView*) aBarGraphView;
- (NSString*) labelForBarGraph: (SLBarGraphView*) aBarGraphView;

@end

@implementation SLBarGraphView

#pragma mark --- Initialization ---

// **********************************************************************
//							initWithFrame
// **********************************************************************
- (id)initWithFrame:(NSRect)frame 
{
    self = [super initWithFrame:frame];
	
    if (self) 
	{
        m_useCachedEventsOnRedraw = FALSE;
		m_valueForBarCache = [NSMutableDictionary dictionaryWithCapacity: 5];
		m_valueForBarHighlightCache = [NSMutableDictionary dictionaryWithCapacity: 5];
    }
	
    return self;
}

// **********************************************************************
//							awakeFromNib
// **********************************************************************
- (void) awakeFromNib
{	
	// Notifications for drawing optimization
    NSNotificationCenter* center = [NSNotificationCenter defaultCenter] ;
	
	// Window resize
	[center addObserver: self
            selector: @selector(windowResizeIsHappening:)
            name: NSWindowDidResizeNotification
            object: [self window]];
}

#pragma mark --- Accessors & Mutators ---

// **********************************************************************
//							datasource
// **********************************************************************
- (id) datasource
{
	return datasource;
}

// **********************************************************************
//							setDatasource
// **********************************************************************
- (void) setDatasource: (id) newDatasource
{
	datasource = newDatasource;
}

#pragma mark --- Event Handling ---

// **********************************************************************
//                          windowResizeIsHappening
// **********************************************************************
- (void) windowResizeIsHappening: (NSNotification *) notification
{
	// We want to use the cached events
	m_useCachedEventsOnRedraw = TRUE;
}

#pragma mark --- Drawing Support ---

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

#pragma mark --- Drawing ---

// **********************************************************************
//							drawRect
// **********************************************************************
- (void)drawRect:(NSRect)rect 
{
	// ---------------------- Constants -------------------------
	
	int kTopHeightOffset = 15;
	int kHorizontalAxisHeightOffset = 50;
	int kTimeLabelOffset = 73;
	int kTimeLabelVerticalOffset = 4;
	
	// ------------------- Graph Labels Style-------------------------
	
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
    [stringAttribsDict setObject: [NSColor blackColor] forKey:NSForegroundColorAttributeName];
    [stringAttribsDict setObject: [NSFont fontWithName: @"Lucida Grande" size: 9] forKey: NSFontAttributeName];
    [stringAttribsDict setObject: paragraphStyle forKey: NSParagraphStyleAttributeName];
	
	// ----------------- Initialization -------------------------
	
    NSRect frame = [self frame];
	frame.origin.x = 0;
	frame.origin.y = 0;
	int frameHeight = frame.size.height;
	int frameWidth = frame.size.width;
	
	// ---------------------- Background ------------------------

	NSRect backgroundRect = frame;
	backgroundRect.origin.x = kTimeLabelOffset;
	backgroundRect.origin.y = kHorizontalAxisHeightOffset;
	backgroundRect.size.height -= kHorizontalAxisHeightOffset;
	
	NSGradient* theGradient = [[[NSGradient alloc] initWithColorsAndLocations: 
		[NSColor colorWithCalibratedRed: 0.940 green: 0.940 blue: 0.940 alpha: 1.0], 
		(CGFloat) 0.0, 
		[NSColor whiteColor], 
		(CGFloat) 1.0, 
		nil] autorelease];
 
    [theGradient drawInRect: backgroundRect angle: 90.0];
	
	// ---------------------- X Line ----------------------------
	
	int maximumBarHeight = frameHeight - kTopHeightOffset - kHorizontalAxisHeightOffset;
	
	[[NSColor colorWithCalibratedRed:0.698 green:0.698 blue:0.698 alpha:1.0] set];
	 
    NSPoint lineStartPoint = NSMakePoint(0, 0);
    NSPoint lineEndPoint = NSMakePoint(0, 0);
    
    lineStartPoint.y = kHorizontalAxisHeightOffset + 0.5;
    lineStartPoint.x = kTimeLabelOffset;
    
    lineEndPoint.x = frameWidth;
    lineEndPoint.y = kHorizontalAxisHeightOffset + 0.5;
        
    [NSBezierPath strokeLineFromPoint: lineStartPoint toPoint: lineEndPoint];
	
	// -------------------------- Bars Values --------------------------
	
	int numberOfBars = 0;
	
	if ( [datasource respondsToSelector: @selector(numberOfBarsForBarGraph:)] ) 
	{
		numberOfBars = [datasource numberOfBarsForBarGraph: self];
	}
		
	float barGapWidth = (frameWidth - kTimeLabelOffset) / numberOfBars;
	
	[[NSColor colorWithCalibratedRed:0.798 green:0.798 blue:0.798 alpha:1.0] set];
	
	int counter=0;
	float barValue[numberOfBars];
	float highestBarValue=1;
	
	if( (!m_useCachedEventsOnRedraw) || ([[m_valueForBarCache allValues] count]==0) )
	{
		// Remove cache
		[m_valueForBarCache removeAllObjects];
		
		// Get all the bar values
		for(counter=0; counter<numberOfBars; counter++)
		{
			if([datasource respondsToSelector: @selector(barGraph:valueForBar:)]) 
			{
				barValue[counter] = [datasource barGraph: self valueForBar: counter];
				
				if(barValue[counter] > highestBarValue)
					highestBarValue = barValue[counter];
					
				// Save value for cache
				[m_valueForBarCache setObject: [NSNumber numberWithFloat: barValue[counter]] 
					forKey: [NSNumber numberWithInt: counter]];
			}
		}
	}
	else
	{	
		// Get all the bar values
		for(counter=0; counter<numberOfBars; counter++)
		{
			barValue[counter] = [[m_valueForBarCache objectForKey: [NSNumber numberWithInt: counter]] floatValue];
					
			if(barValue[counter] > highestBarValue)
					highestBarValue = barValue[counter];
		}
	}
	
	// ---------------------- X Graph Lines ----------------------------
	
	int graphLineHeight = maximumBarHeight / 3;
	
	for(counter=1; counter <= 3; counter++)
	{
		// Draw line
		[[NSColor colorWithCalibratedRed:0.85 green:0.85 blue:0.85 alpha:1.0] set];
		
		lineStartPoint.y = lineEndPoint.y = kHorizontalAxisHeightOffset + (graphLineHeight*counter) + 0.5 - 1;
		[NSBezierPath strokeLineFromPoint: lineStartPoint toPoint: lineEndPoint];
		
		// Calculate label
		int graphLineSeconds = graphLineHeight*counter*highestBarValue/maximumBarHeight;
		
		NSString* timeLabelString = [SLUtilities convertSecondsToTimeString: graphLineSeconds withRounding: YES];
	
		// Draw the labels
		NSRect timeLabelRect;
		timeLabelRect.origin.x = 0;
		timeLabelRect.origin.y = lineStartPoint.y - kTimeLabelVerticalOffset;
		timeLabelRect.size.height = 15;
		timeLabelRect.size.width = kTimeLabelOffset;
		
		if(nil!=timeLabelString)
			[timeLabelString drawInRect: timeLabelRect withAttributes: stringAttribsDict];
	}
	
	// -------------------------- Bars Drawing --------------------------
	
	[[NSColor colorWithCalibratedRed:0.8 green:0.8 blue:0.8 alpha:1.0] set];
	
	// Plot the bar, with normalized bar value/height
	for(counter=0; counter<numberOfBars; counter++)
	{
		barValue[counter] = (barValue[counter] * maximumBarHeight) / highestBarValue;
		
		NSRect barRect;
		barRect.origin.x = barGapWidth * (counter) + kTimeLabelOffset;
		barRect.origin.y = kHorizontalAxisHeightOffset + 0.5;
		barRect.size.height = barValue[counter];
		barRect.size.width = 2 * barGapWidth / 3 ;
		
		NSBezierPath* rectBezier = [NSBezierPath bezierPathWithRoundedRect: barRect xRadius: 3.0 yRadius: 3.0];
		[rectBezier fill];
	}
	
	// -------------------------- Highlight Bars --------------------------
	
	[[NSColor colorWithCalibratedRed:0.866 green:0.376 blue:0.376 alpha:1.0] set];
	
	float highlightBarValue[numberOfBars];
		
	if( (!m_useCachedEventsOnRedraw) || ([[m_valueForBarHighlightCache allValues] count]==0) )
	{
		// Remove cache
		[m_valueForBarHighlightCache removeAllObjects];
		
		// Get all the bar values
		for(counter=0; counter<numberOfBars; counter++)
		{
			if([datasource respondsToSelector: @selector(barGraph:valueForHighlightBar:)]) 
			{
				highlightBarValue[counter] = [datasource barGraph: self valueForHighlightBar: counter];
				
				// Save value for cache
				[m_valueForBarHighlightCache setObject: [NSNumber numberWithFloat: highlightBarValue[counter]]
					forKey: [NSNumber numberWithInt: counter]];

			}
		}
	}
	else
	{
		// Get all the bar values
		for(counter=0; counter<numberOfBars; counter++)
		{
			highlightBarValue[counter] = [[m_valueForBarHighlightCache objectForKey: [NSNumber numberWithInt: counter]] floatValue];
		}
	}
	
	// Plot the bar, with normalized bar value/height
	for(counter=0; counter<numberOfBars; counter++)
	{
		highlightBarValue[counter] = (highlightBarValue[counter] * maximumBarHeight) / highestBarValue;

		NSRect barRect;
		barRect.origin.x = barGapWidth * (counter) + kTimeLabelOffset;
		barRect.origin.y = kHorizontalAxisHeightOffset + 0.5;
		barRect.size.height = highlightBarValue[counter];
		barRect.size.width = 2 * barGapWidth / 3;
		
		NSBezierPath* rectBezier = [NSBezierPath bezierPathWithRoundedRect: barRect xRadius: 3.0 yRadius: 3.0];
		[rectBezier fill];
	}

	// -------------------------- Hour/Day Labels --------------------------
	
	NSString* labelString = nil;
	
	// Draw the labels
	for(counter=0; counter<numberOfBars; counter++)
	{
		NSRect labelRect;
		labelRect.origin.x = barGapWidth * (counter) + kTimeLabelOffset;
		labelRect.origin.y = kHorizontalAxisHeightOffset - 17;
		labelRect.size.height = 15;
		labelRect.size.width = 2 * barGapWidth/3;
		
		if( [datasource respondsToSelector: @selector(barGraph:labelForBar:)] ) 
		{
			labelString = [datasource barGraph: self labelForBar: counter];
		}
		
		if(nil!=labelString)
			[labelString drawInRect: labelRect withAttributes: stringAttribsDict];
	}
	
	// Release the dict
    [stringAttribsDict release];
    
    // Release the paragraph style
    [paragraphStyle release];
	
	// -------------------------- Graph Label --------------------------
	
	if ( [datasource respondsToSelector: @selector(labelForBarGraph:)] ) 
	{
		NSString* barGraphLabelString = [datasource labelForBarGraph: self];
		
		NSMutableDictionary* barGraphLabelStringAttribsDict = [[NSMutableDictionary alloc] init];
		[barGraphLabelStringAttribsDict setObject: [NSColor grayColor] forKey:NSForegroundColorAttributeName];
		[barGraphLabelStringAttribsDict setObject: [NSFont fontWithName: @"Lucida Grande" size: 12] forKey: NSFontAttributeName];


		NSSize barGraphLabelStringSize = [barGraphLabelString sizeWithAttributes: barGraphLabelStringAttribsDict];
		
		NSRect barGraphLabelRect;
		barGraphLabelRect.origin.x = (frameWidth/2) - (barGraphLabelStringSize.width/2);
		barGraphLabelRect.origin.y = 0;
		barGraphLabelRect.size = barGraphLabelStringSize;
		
		if(nil!=labelString)
			[barGraphLabelString drawInRect: barGraphLabelRect withAttributes: barGraphLabelStringAttribsDict];
	}
	
	// -------------------------- Cache Reset -----------------------------
	
	// Reset cache flag
	m_useCachedEventsOnRedraw = FALSE;
}

@end
