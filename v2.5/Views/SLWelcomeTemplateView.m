//
//  Slife
//
//  Created by Edison Thomaz
//  Copyright 2007-2008 Slife Labs, LLC. All rights reserved.
//

#import "SLWelcomeTemplateView.h"


@implementation SLWelcomeTemplateView

- (id)initWithFrame:(NSRect)frame 
{
    self = [super initWithFrame:frame];
    
	if (self) 
	{
    }
	
    return self;
}

- (void)drawRect:(NSRect)rect 
{
	NSImage* templateImage = [NSImage imageNamed: @"welcome-template"];	
	[templateImage compositeToPoint: NSMakePoint(0, 0) operation:NSCompositeSourceOver];
}

@end
