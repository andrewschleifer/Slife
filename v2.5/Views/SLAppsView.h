
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

@class SLBarGraphView;

@interface SLAppsView : NSView 
{
    // Date related
    NSCalendarDate*						m_selectedDate;
	int									m_selectedDateRange;
	
	IBOutlet NSButton*					m_dayControlButton;
	IBOutlet NSButton*					m_monthControlButton;
	
	// Custom view frame size
    float								m_viewWidth;
    float								m_viewHeight;
	
	// Number of activities
	int									m_numberOfApps;
	
	// Activities related
	NSString*							m_appSelected;
	NSMutableArray*						m_appObjects;
	NSMutableDictionary*				m_appDurationDictionary;
	NSMutableDictionary*				m_appRect;
	float								m_longestDurationAppEvents;
	
	// Bar Graph Top related
	IBOutlet SLBarGraphView*			m_appBarGraphView;
	IBOutlet NSTextField*				m_appDateTextField;
	IBOutlet NSTextField*				m_appSelectedNameTextField;
	
	// Optimization
	NSMutableDictionary*				m_appIconDictionary;
	BOOL								m_useCachedEventsOnRedraw;
	
	// Scrolling
	BOOL								m_scrollToTop;
}

// Accessors
- (void) setDate:(NSCalendarDate*) newDate;

// Date
- (IBAction) dateRangeChanged: (id) sender;
- (IBAction) previousDayButtonClicked: (id) sender;
- (IBAction) nextDayButtonClicked: (id) sender;
- (IBAction) todayButtonClicked: (id) sender;

@end
