
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
#import "MAAttachedWindow.h"

@interface SLDayView : NSView 
{
	// The image used to give the hour labels a hilite
    NSImage*							m_hourBackHiliteImage;
    NSImage*							m_hourBackGrayImage;
	
    // The selected date
	IBOutlet NSTextField*				m_dateTextField;
    NSCalendarDate*						m_selectedDate;
	
	// Tooltip
	IBOutlet NSView*					m_tooltipView;
	MAAttachedWindow*					m_tooltipWindow;
	IBOutlet NSImageView*				m_tooltipImage;
	IBOutlet NSTextField*				m_tooltipTitle;
	IBOutlet NSTextField*				m_tooltipDate;
	IBOutlet NSButton*					m_tooltipLinkButton;
	
	// Custom view frame size
    float								m_viewWidth;
    float								m_viewHeight;
    
    // Minute-pixel ratio for the slider
    float								m_timeViewZoomSliderMinValue;
    float								m_timeViewZoomSliderMaxValue;
    
    // Value container for the sliders
    float								m_timeViewZoomFactor;
    int									m_timeScaleReference;
	
	// Variables we use to determine where to draw the event
    int									m_eventCurrentYOffset;
    NSMutableDictionary*				m_eventYOffsetDictionary;
	
	// Number of active sources
	int									m_numberOfActiveEventSources;
	
	// This is where we store the icons - for caching purposes
	NSMutableDictionary*				m_iconCacheDictionary;
	
	 // Control sliders
    IBOutlet NSSlider*					m_timeViewZoomSlider;
	
	// Events location - calculated in drawRect, used in mouseDown
    NSMutableDictionary*				m_eventsLocation;
	
	// The event selected
	NSManagedObject*					m_eventSelected;
	
	// The search string
	IBOutlet NSTextField*				m_searchTextField;
	NSString*							m_searchString;
	NSTimer*							m_searchTextFieldTimer;
	
	// Optimization
	NSMutableArray*						m_cachedApplicationObjects;
	NSMutableDictionary*				m_cachedEventsForApplications;
	NSMutableDictionary*				m_cachedApplicationEventsNumberDictionary;
	BOOL								m_useCachedEventsOnRedraw;
	
	// Scrolling
	BOOL								m_scrollToTop;
}

// Accessors
- (void) setDate:(NSCalendarDate*) newDate;

// Handlers
- (IBAction) linkButtonClicked: (id) sender;

// Date navigation
- (IBAction) timeViewZoomSliderChange:(id) sender;
- (IBAction) previousDayButtonClicked: (id) sender;
- (IBAction) nextDayButtonClicked: (id) sender;
- (IBAction) todayButtonClicked: (id) sender;


@end
