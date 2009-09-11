//
//  SLActivityEditView.h
//  Slife
//
//  Created by Edison Thomaz on 5/19/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class MAAttachedWindow;

@interface SLActivityEditView : NSView 
{
	BOOL							m_debugState;
	
	NSMutableDictionary*			m_activityPanelCoords;
	NSString*						m_selectedActivityName;
	NSPoint							m_lastClickLocation;
	
	MAAttachedWindow*				m_activityItemEditWindow;
	IBOutlet NSView*				m_activityItemEditView;
	IBOutlet NSTableView*			m_activityItemEditItemsTableView;
	IBOutlet NSTableView*			m_activityItemEditApplicationsTableView;
	
	IBOutlet NSButton*				m_activityRemoveItemButton;
	IBOutlet NSButton*				m_activityEditItemButton;
	IBOutlet NSButton*				m_activityVisualizeItemButton;
	
	IBOutlet NSButton*				m_activityGoalEnabledButton;
	IBOutlet NSPopUpButton*			m_activityGoalTypePopUp;
	IBOutlet NSPopUpButton*			m_activityGoalTimeUnitPopUp;
	IBOutlet NSTextField*			m_activityGoalValueTextField;

	IBOutlet NSArrayController*		m_applicationsArrayController;
	IBOutlet NSArrayController*		m_activitiesArrayController;
	IBOutlet NSArrayController*		m_itemsArrayController;
	
	NSManagedObjectContext*			m_managedContext;
}

// Application
- (IBAction) addApplicationButtonClicked: (id) sender;

// Edit Window
- (IBAction) showActivityItemEditWindow: (id) sender;
- (IBAction) removeActivityItemEditWindow: (id) sender;

// Goal Settings
- (IBAction) goalEnabledButtonClicked: (id) sender;
- (IBAction) goalTypePopUpChanged: (id) sender;
- (IBAction) goalTimeUnitPopUpChanged: (id) sender;

// Visualization
- (IBAction) visualizeActivity: (id) sender;

@end
