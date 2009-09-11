
//  Slife
//
//  Created by Edison Thomaz
//  Copyright 2007-2008 Slife Labs, LLC. All rights reserved.
//


#import "SLGoalCell.h"


@implementation SLGoalCell

// **********************************************************************
//							drawWithFrame
// **********************************************************************
- (void) drawWithFrame: (NSRect) cellFrame inView: (NSView*) controlView 
{
	// Draw goal icon
	NSImage* goalIcon = [NSImage imageNamed: @"goal-small"];
	
	NSRect iconRect = cellFrame;
	iconRect.origin.x = (cellFrame.size.width / 2.0) + cellFrame.origin.x - 8;
	iconRect.origin.y = (cellFrame.size.height / 2.0) + cellFrame.origin.y + 8;
	iconRect.size.height = 16;
	iconRect.size.width = 16;
	
	[goalIcon compositeToPoint: iconRect.origin operation: NSCompositeSourceOver];
}

@end
