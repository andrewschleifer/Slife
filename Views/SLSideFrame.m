
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

#define MIN_WIDTH 80
#define BOTTOM_BAR_HEIGHT 23
#define THUMB_RECT NSMakeRect(NSWidth([self frame]) - 17, 0, 17, BOTTOM_BAR_HEIGHT)

#import "SLSideFrame.h"
#import "SLUtilities.h"

@implementation SLSideFrame

#pragma mark --- Initialization ---

// **********************************************************************
//							initWithFrame
// **********************************************************************
- (id)initWithFrame:(NSRect)frame 
{
    self = [super initWithFrame:frame];
	
    if (self) 
	{
		
    }
	
    return self;
}

#pragma mark --- Drawing ---

// **********************************************************************
//							drawRect
// **********************************************************************
- (void)drawRect:(NSRect)rect 
{	
	if([SLUtilities areWeInFront])
		[[NSColor colorWithDeviceRed: 0.8392 green: 0.8666 blue: 0.8980 alpha:1.0] set];
	else
		[[NSColor colorWithDeviceRed: 0.9098 green: 0.9098 blue: 0.9098 alpha:1.0] set];
		
    [NSBezierPath fillRect: [self bounds]];
}

#pragma mark --- Support ---

// **********************************************************************
//						resetCursorRects
// **********************************************************************
- (void)resetCursorRects
{
		// Change the cursor to the resize cursor when it's over the resize thumb.
	[super resetCursorRects];
	NSRect resizeThumbRect = THUMB_RECT;
	[self addCursorRect:resizeThumbRect cursor:[NSCursor resizeLeftRightCursor]];
}

#pragma mark --- Event Handling ---

// **********************************************************************
//							mouseDown
// **********************************************************************
- (void) mouseDown: (NSEvent*) event
{
	float deltaX;
	NSPoint currentMouseLoc;
	NSPoint startingMouseLoc = [self convertPoint:[event locationInWindow] fromView:nil];

	NSRect startingViewRect = [self frame];
	
	NSRect resizeThumbRect = THUMB_RECT;
	
	BOOL isInside = [self mouse:startingMouseLoc inRect:resizeThumbRect];
    BOOL keepOn = isInside;
	NSRect rect;

	if (!keepOn) {
		[super mouseDown:event];
		return;
	}
	
    while (keepOn) {
        event = [[self window] nextEventMatchingMask:NSLeftMouseUpMask | NSLeftMouseDraggedMask];

		switch ([event type]) {
			case NSLeftMouseDragged:
				currentMouseLoc = [self convertPoint:[event locationInWindow] fromView:nil];
				deltaX = startingMouseLoc.x - currentMouseLoc.x;
				rect = startingViewRect;
				rect.size.width -= deltaX;
				if (rect.size.width < MIN_WIDTH)
					rect.size.width = MIN_WIDTH;
				[[self superview]setFrame:rect];
				[[[self superview]superview] display];
				break;
			case NSLeftMouseUp:
				keepOn = NO;
				break;
			default:
				[super mouseDown:event];
				break;
		}
    }
	return;
}

// **********************************************************************
//					activitiesTriangleButtonClick
// **********************************************************************
- (IBAction) activitiesTriangleButtonClick: (id) sender
{
	if([sender state]==NSOnState)
	{
		[m_activitiesTableView setHidden: false];
	}
	else
	{
		[m_activitiesTableView setHidden: true];
	}
	
	[self setNeedsDisplay: YES];
}

@end
