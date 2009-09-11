
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


@interface SLInfoWindowController : NSWindowController 
{
	BOOL							m_debugState;
	
	IBOutlet NSPanel*				m_infoPanel;
	IBOutlet NSTabView*				m_infoTabView;
	
	IBOutlet NSTableView*			m_infoItemEditItemsTableView;
	IBOutlet NSTableView*			m_infoItemEditApplicationsTableView;
	
	IBOutlet NSButton*				m_infoGoalEnabledButton;
	IBOutlet NSPopUpButton*			m_infoGoalTypePopUp;
	IBOutlet NSPopUpButton*			m_infoGoalTimeUnitPopUp;
	IBOutlet NSTextField*			m_infoGoalValueTextField;
	
	NSManagedObjectContext*			m_managedContext;
	
	NSArrayController*				m_activitiesArrayController;
	IBOutlet NSArrayController*		m_applicationsArrayController;
	IBOutlet NSArrayController*		m_itemsArrayController;
}

- (id) initWithActivitiesArrayController: (NSArrayController*) activitiesArrayController;

- (IBAction) activityNameChanged: (id) sender;

- (IBAction) addApplicationButtonClicked: (id) sender;
- (IBAction) goalEnabledButtonClicked: (id) sender;
- (IBAction) goalTypePopUpChanged: (id) sender;
- (IBAction) goalTimeUnitPopUpChanged: (id) sender;

@end
