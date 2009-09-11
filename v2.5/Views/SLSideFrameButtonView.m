
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

#import "SLSideFrameButtonView.h"
#import "SLUtilities.h"

@interface NSObject (SLSideFrameButtonViewDelegateProtocol)

- (void) buttonClicked: (SLSideFrameButtonView*) theButton;

@end

@implementation SLSideFrameButtonView

// **********************************************************************
//							initWithFrame
// **********************************************************************
- (id)initWithFrame:(NSRect)frame 
{
    self = [super initWithFrame:frame];
    
	if (self) 
	{
		m_drawHighlight = FALSE;
		m_title = @"Activities";
    }
	
    return self;
}

// **********************************************************************
//							setDrawHighlight
// **********************************************************************
- (void) setDrawHighlight: (BOOL) drawHighlight
{
	m_drawHighlight = drawHighlight;
}

// **********************************************************************
//							setTitle
// **********************************************************************
- (void) setTitle: (NSString*) newTitle
{
	if((nil==newTitle) || ([newTitle length]==0))
		return;
		
	m_title = newTitle;
}

// **********************************************************************
//							drawTitle
// **********************************************************************
- (void) drawTitle
{		
	if((nil==m_title) || ([m_title length]==0))
		return;
	
	NSColor* titleColor = [NSColor blackColor];
	
	if(m_drawHighlight)
		titleColor = [NSColor whiteColor];
		
	NSMutableDictionary* itemTitleStringAttribsDict = [NSMutableDictionary dictionaryWithCapacity: 5];
	[itemTitleStringAttribsDict setObject: titleColor forKey:NSForegroundColorAttributeName];
	[itemTitleStringAttribsDict setObject: [NSFont fontWithName: @"Lucida Grande" size: 11] forKey: NSFontAttributeName];
	
	NSShadow* theShadow = nil;
	if(m_drawHighlight)
	{
		// Setting the shadow
		theShadow = [[NSShadow alloc] init];
		[theShadow setShadowOffset:NSMakeSize(1.0, -1.0)];
		[theShadow setShadowBlurRadius:3];
		[theShadow setShadowColor: [NSColor colorWithCalibratedWhite:0.0 alpha:0.6]];
		[theShadow set];
	}
	
	[m_title drawAtPoint: NSMakePoint(53, 5) withAttributes: itemTitleStringAttribsDict];
	
	if(m_drawHighlight)
	{
		// Release the shadow
		[theShadow release];
	}
}

// **********************************************************************
//							drawIcon
// **********************************************************************
- (void) drawIcon
{
	NSImage* image = nil;
	
	if([m_title isEqualToString: @"Activities"])
		image = [NSImage imageNamed: @"activity-small"];
	else if([m_title isEqualToString: @"Applications"])
		image = [NSImage imageNamed: @"application-small"];
	else if([m_title isEqualToString: @"Day"])
		image = [NSImage imageNamed: @"day-small"];
	else if([m_title isEqualToString: @"Month"])
		image = [NSImage imageNamed: @"month-small"];
	else if([m_title isEqualToString: @"Goals"])
		image = [NSImage imageNamed: @"goal-small"];
	else if([m_title isEqualToString: @"Web & Documents"])
		image = [NSImage imageNamed: @"item-small"];
	
	[image compositeToPoint: NSMakePoint(29, 5) operation: NSCompositeSourceOver];
}

// **********************************************************************
//							drawRect
// **********************************************************************
- (void)drawRect:(NSRect)rect 
{	
	if(m_drawHighlight)
	{
		NSGradient* theGradient = nil;
		
		// App in front
		if([SLUtilities areWeInFront])
		{
			// Window is key
			if([[self window] isKeyWindow])
			{
				// Create gradient
				theGradient = [[[NSGradient alloc] initWithColorsAndLocations:
					[NSColor colorWithCalibratedRed: 0.082 green: 0.325 blue: 0.666 alpha: 1.0],
					(CGFloat) 0.0, 
					[NSColor colorWithCalibratedRed: 0.36 green: 0.576 blue: 0.835 alpha: 1.0],
					(CGFloat) 1.0, 
					nil] autorelease];
				
				// Draw background
				[theGradient drawInRect: [self bounds] angle: 90];
			
				// Draw the top of the gradient
				[[NSColor colorWithCalibratedRed: 0.270 green: 0.501 blue: 0.8 alpha: 1.0] set];
				NSPoint startPoint = NSMakePoint(0, [self frame].size.height);
				NSPoint endPoint = NSMakePoint([self frame].size.width, [self frame].size.height);
				[NSBezierPath strokeLineFromPoint: startPoint toPoint: endPoint];
			}
			
			// Window is not key
			else
			{
				// Create gradient
				theGradient = [[[NSGradient alloc] initWithColorsAndLocations:
					[NSColor colorWithCalibratedRed: 0.435 green: 0.509 blue: 0.666 alpha: 1.0],
					(CGFloat) 0.0, 
					[NSColor colorWithCalibratedRed: 0.639 green: 0.698 blue: 0.815 alpha: 1.0],
					(CGFloat) 1.0, 
					nil] autorelease];
				
				// Draw background
				[theGradient drawInRect: [self bounds] angle: 90];
			
				// Draw the top of the gradient
				[[NSColor colorWithCalibratedRed: 0.568 green: 0.627 blue: 0.752 alpha: 1.0] set];
				NSPoint startPoint = NSMakePoint(0, [self frame].size.height);
				NSPoint endPoint = NSMakePoint([self frame].size.width, [self frame].size.height);
				[NSBezierPath strokeLineFromPoint: startPoint toPoint: endPoint];
			}
			
		}
		
		// App not in front
		else
		{
			// Create gradient
			theGradient = [[[NSGradient alloc] initWithColorsAndLocations:
				[NSColor colorWithCalibratedRed: 0.541 green: 0.541 blue: 0.541 alpha: 1.0],
				(CGFloat) 0.0, 
				[NSColor colorWithCalibratedRed: 0.709 green: 0.709 blue: 0.709 alpha: 1.0],
				(CGFloat) 1.0, 
				nil] autorelease];
				
			// Draw background
			[theGradient drawInRect: [self bounds] angle: 90];
			
			// Draw the top of the gradient
			[[NSColor colorWithCalibratedRed: 0.592 green: 0.592 blue: 0.592 alpha: 1.0] set];
			NSPoint startPoint = NSMakePoint(0, [self frame].size.height);
			NSPoint endPoint = NSMakePoint([self frame].size.width, [self frame].size.height);
			[NSBezierPath strokeLineFromPoint: startPoint toPoint: endPoint];
		}
	}
	
	[self drawIcon];
	[self drawTitle];
}

// **********************************************************************
//							mouseDown
// **********************************************************************
- (void) mouseDown: (NSEvent*) event
{
	if([m_actionTarget respondsToSelector: @selector(buttonClicked:)]) 
		[m_actionTarget buttonClicked: self];
}

@end
