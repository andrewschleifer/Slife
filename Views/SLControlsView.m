
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

#import "SLControlsView.h"


@implementation SLControlsView

// **********************************************************************
//								initWithFrame
// **********************************************************************
- (id)initWithFrame:(NSRect)frame 
{
    self = [super initWithFrame:frame];
    if (self) 
	{
        // Initialization code here.
    }
    return self;
}

// **********************************************************************
//								drawRect
// **********************************************************************
- (void)drawRect:(NSRect)rect 
{	
	// -------------------------- Background ----------------------------
	
    [[NSColor colorWithDeviceRed:0.878 green:0.878 blue:0.878 alpha:1.0] set];
    [NSBezierPath fillRect: [self bounds]];
	
	// -------------------------- Top Border ----------------------------
	
	[[NSColor colorWithDeviceRed:0.6 green:0.6 blue:0.6 alpha:1.0] set];
	NSPoint topBorderStartPoint = NSMakePoint(0, [self frame].size.height-1);
	NSPoint topBorderEndPoint = NSMakePoint([self frame].size.width, [self frame].size.height-1);
	[NSBezierPath strokeLineFromPoint: topBorderStartPoint toPoint: topBorderEndPoint];

}

@end
