
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

@interface SLMonthView : NSView
{
	
    // Custom view frame size
    float						m_viewWidth;
    float						m_viewHeight;
    float                       m_viewHeightWithWeekDaysLabels;
    
    // Day Rects
    NSRect                      m_dayRect[32];
    
    // Day Selected
    int                         m_daySelected;
	IBOutlet NSTextField*		m_dateTextField;
    
    // The date for this calendar
    NSCalendarDate*             m_date;
    int                         m_daysInMonth;
    int                         m_firstDayDateWeekDay;
    
	// Pointer to the event providers
	int							m_numberOfActiveEventSources;
	
	// The search string
	IBOutlet NSTextField*		m_searchTextField;
	NSString*					m_searchString;
	NSTimer*					m_searchTextFieldTimer;
	
	NSMutableDictionary*		m_applicationVerticalOffset;
}

// Initialization and Termination
- (id) initWithFrame:(NSRect)frameRect;
- (void) awakeFromNib;
- (BOOL) acceptsFirstResponder;
- (void) dealloc;

// Date
- (void) setDate: (NSCalendarDate*) newDate;
- (IBAction) previousDayButtonClicked: (id) sender;
- (IBAction) nextDayButtonClicked: (id) sender;
- (IBAction) todayButtonClicked: (id) sender;

// Drawing
- (void) drawRect:(NSRect)rect;
- (void) drawEvent: (NSManagedObject*) eventObject fromApplication: (NSString*) eventAppName atDay: (int) day withColor: (NSColor*) appColor;

// Utilities
- (BOOL) isOpaque;
- (BOOL) isLeapYear: (int) year;
- (BOOL) isSixRowCalendar;
- (void) clearDayRectValues;
- (int) calculateNumberOfActiveEventSources;
- (void) updateViewWidthAndHeight;

@end
