
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

#import "SLColorCell.h"


@implementation SLColorCell

// **********************************************************************
//							drawWithFrame
// **********************************************************************
- (void) drawWithFrame: (NSRect) cellFrame inView: (NSView*) controlView 
{
	NSRect sqare = NSInsetRect (cellFrame, 3.0, 3.0);
   
	// Use the smallest size to sqare off the box & center the box
	if (sqare.size.height < sqare.size.width) 
	{
		sqare.size.width = sqare.size.height;
		sqare.origin.x = sqare.origin.x + (cellFrame.size.width - sqare.size.width) / 2.0;
	} 
	else 
	{
		sqare.size.height = sqare.size.width;
		sqare.origin.y = sqare.origin.y + (cellFrame.size.height - sqare.size.height) / 2.0;
	}

	// Set default color
	[[NSColor lightGrayColor] set];
	[NSBezierPath strokeRect: sqare];

	[(NSColor*) [self objectValue] set];    
	[NSBezierPath fillRect: NSInsetRect (sqare, 2.0, 2.0)];
}

@end
