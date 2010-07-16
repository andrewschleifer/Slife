
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

#import "SLSideFrameButtonController.h"
#import "SLSideFrameButtonView.h"

@implementation SLSideFrameButtonController

- (void) awakeFromNib
{
	// Set the title for all button views
	[m_dayButtonView setTitle: @"Day"];
	[m_monthButtonView setTitle: @"Month"];
	[m_applicationsButtonView setTitle: @"Applications"];
	[m_itemsButtonView setTitle: @"Web & Documents"];
	[m_activitiesButtonView setTitle: @"Activities"];
	[m_goalsButtonView setTitle: @"Goals"];
	
	// The day view is first, it's highlighted
	[m_dayButtonView setDrawHighlight: TRUE];
	
	// Request switch to day view - from double click in day in Month View
	[[NSNotificationCenter defaultCenter] addObserver: self
			selector: @selector(viewChanging:)
			name: @"viewChanging" 
			object: nil];
}

// **********************************************************************
//						redrawButtons
// **********************************************************************
- (void) redrawButtons
{
	[m_dayButtonView setNeedsDisplay: YES];
	[m_monthButtonView setNeedsDisplay: YES];
	[m_applicationsButtonView setNeedsDisplay: YES];
	[m_itemsButtonView setNeedsDisplay: YES];
	[m_activitiesButtonView setNeedsDisplay: YES];
	[m_goalsButtonView setNeedsDisplay: YES];
}

// **********************************************************************
//						resetHighlightForAllButtons
// **********************************************************************
- (void) resetHighlightForAllButtons
{
	[m_dayButtonView setDrawHighlight: FALSE];
	[m_monthButtonView setDrawHighlight: FALSE];
	[m_applicationsButtonView setDrawHighlight: FALSE];
	[m_itemsButtonView setDrawHighlight: FALSE];
	[m_activitiesButtonView setDrawHighlight: FALSE];
	[m_goalsButtonView setDrawHighlight: FALSE];
}

// **********************************************************************
//							viewsChanging
// **********************************************************************
- (void) viewChanging: (NSNotification *) notification
{
	NSString* viewName = [notification object];
	
	if(viewName && ([viewName length]>0))
	{
		// Reset highlights
		[self resetHighlightForAllButtons];
	
		// Day
		if([viewName isEqualToString: @"Day"])
		{
			[m_dayButtonView setDrawHighlight: TRUE];
		}
		// Month
		else if([viewName isEqualToString: @"Month"])
		{
			[m_monthButtonView setDrawHighlight: TRUE];
		}
		// Applications
		else if([viewName isEqualToString: @"Applications"])
		{
			[m_applicationsButtonView setDrawHighlight: TRUE];
		}
		// Web & Documents
		else if([viewName isEqualToString: @"Web & Documents"])
		{
			[m_itemsButtonView setDrawHighlight: TRUE];
		}
		// Activities
		else if([viewName isEqualToString: @"Activities"])
		{
			[m_activitiesButtonView setDrawHighlight: TRUE];
		}
		// Goals
		else if([viewName isEqualToString: @"Goals"])
		{
			[m_goalsButtonView setDrawHighlight: TRUE];
		}
		
		// Redraw buttons
		[self redrawButtons];
	}
}	


// **********************************************************************
//							buttonClicked
// **********************************************************************
- (void) buttonClicked: (SLSideFrameButtonView*) theButton
{
	// Request view change with app delegate
	if(theButton==m_dayButtonView)
		[[NSNotificationCenter defaultCenter] postNotificationName: @"dayViewChangeRequest" object: nil];
	else if(theButton==m_monthButtonView)
		[[NSNotificationCenter defaultCenter] postNotificationName: @"monthViewChangeRequest" object: nil];
	else if(theButton==m_applicationsButtonView)
		[[NSNotificationCenter defaultCenter] postNotificationName: @"applicationsViewChangeRequest" object: nil];
	else if(theButton==m_itemsButtonView)
		[[NSNotificationCenter defaultCenter] postNotificationName: @"itemsViewChangeRequest" object: nil];
	else if(theButton==m_activitiesButtonView)
		[[NSNotificationCenter defaultCenter] postNotificationName: @"activitiesViewChangeRequest" object: nil];
	else if(theButton==m_goalsButtonView)
		[[NSNotificationCenter defaultCenter] postNotificationName: @"goalsViewChangeRequest" object: nil];
}

@end
