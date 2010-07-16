
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


#import <Cocoa/Cocoa.h>


@interface SLGoalsView : NSView 
{	
	// The images for the icon
    NSImage*							m_goalSuccessIconImage;
	NSImage*							m_goalFailIconImage;
	NSImage*							m_goalNoDataIconImage;
	
    // Date related
    NSCalendarDate*						m_selectedDate;
	
	// Custom view frame size
    float								m_viewWidth;
    float								m_viewHeight;
	
	// Number of activities
	int									m_numberOfActivities;
	
	// Activities related
	NSArray*							m_activityGoalEnabledObjects;
	NSMutableDictionary*				m_activitiesGoalReachedPercentageDictionary;
	NSMutableDictionary*				m_activitiesGoalProgressStringDictionary;
		
	// Bar Graph Top related
	IBOutlet NSTextField*				m_headerDateTextField;
	
	// Scrolling
	BOOL								m_scrollToTop;
}

// Date
- (void) setDate:(NSCalendarDate*) newDate;
- (IBAction) previousDayButtonClicked: (id) sender;
- (IBAction) nextDayButtonClicked: (id) sender;
- (IBAction) todayButtonClicked: (id) sender;

@end
