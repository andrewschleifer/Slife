
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

@interface SLObserver : NSObject 
{	
	BOOL						m_debugState;
	NSUserDefaults*				m_userDefaults;
	
	BOOL						m_hasLoggedGoals;
	BOOL						m_privateModeOn;
	
	NSAppleScript*				m_mailScript;
	NSAppleScript*				m_netnewswireScript;
	NSAppleScript*				m_safariScript;
	NSAppleScript*				m_firefoxScript;
	NSAppleScript*				m_operaScript;

	NSTimer*					m_observationTimer;
	BOOL						m_observerActive;
	
	NSSet*						m_appsToIgnore;
	
	NSString*					m_lastApplication;
	NSString*					m_lastWebPage;
	NSString*					m_lastWindowTitleName;
	NSString*					m_lastWindowFilePath;
	NSCalendarDate*				m_lastStartDate;
	
	NSString*					m_uiApplicationName;
	NSString*					m_uiWindowTitleName;
	NSString*					m_uiWindowFilePath;
    AXUIElementRef				m_uiSystemWideElement;

	BOOL						m_systemIdle;
	NSPoint						m_lastRecordedMousePosition;
	NSDate*						m_timeLastRecordedMousePosition;
	
	NSManagedObjectContext*		m_managedContext;
}

- (id) init;

- (void) setPrivateMode: (BOOL) privateModeActive;
- (void) saveLastEventBeforeQuitOrSleep;

- (NSManagedObject*) createOrFetchManagedObjectForApplicationName: (NSString*) appName;

- (NSString*) getUIFrontAppName;
- (NSString*) getUIFrontWindowTitle;

@end
