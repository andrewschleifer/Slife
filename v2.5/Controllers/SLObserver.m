
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

#import "SLObserver.h"
#import "SLUtilities.h"
#import "Slife_AppDelegate.h"

// **********************************************************************
//
//							Preferences
//
// **********************************************************************

extern NSString* k_Pref_DebugOn_Key;

extern NSString* k_Pref_EnableObserverScripting_Key;
extern NSString* k_Pref_ObserverIdleValue_Key;
extern NSString* k_Pref_ObservationRate_Key;

extern NSString* k_Pref_LogGoalsToRewardsAccount_Key;
extern NSString* k_Pref_LogActivitiesToTeamsAccount_Key;
extern NSString* k_Pref_ShareAllActivitiesWithTeamsAccount_Key;

// **********************************************************************
//
//							Constants
//
// **********************************************************************

const int MAX_SECS = 3600;

@interface SLObserver (Private)

- (void) setUpInitialObserverConfiguration;
- (void) saveChangesToManagedContext;
- (void) saveLastObservedEvent;

@end

@implementation SLObserver

#pragma mark --- Initialization ---

// **********************************************************************
//								init
// **********************************************************************
- (id) init
{
	[super init];
	
	// Init members
	m_lastApplication = nil;
	m_lastWebPage = nil;
	m_lastStartDate = nil;
	m_managedContext = [[NSApp delegate] managedObjectContext];
	
	// No logged goals yet
	m_hasLoggedGoals = FALSE;
	
	// Get the defaults
    m_userDefaults = [NSUserDefaults standardUserDefaults];
	
	// Debug
	m_debugState = [[m_userDefaults objectForKey: k_Pref_DebugOn_Key] boolValue];
	
	// ------------------------ Load Scripts ---------------------
	
	// Load the script object
	NSDictionary* errorDict = nil;
	NSString* theScriptPath = nil;
	NSURL* theScriptPathURL = nil;
	
	NSString* theBundlePath = [[NSBundle mainBundle] resourcePath];
	
	// Mail
	theScriptPath = [theBundlePath stringByAppendingPathComponent: @"mail.scpt"];
	theScriptPathURL = [NSURL fileURLWithPath: theScriptPath];
	m_mailScript = [[NSAppleScript alloc] initWithContentsOfURL: theScriptPathURL error: &errorDict];
	
	// NetNewsWire
	theScriptPath = [theBundlePath stringByAppendingPathComponent: @"netnewswire.scpt"];
	theScriptPathURL = [NSURL fileURLWithPath: theScriptPath];
	m_netnewswireScript = [[NSAppleScript alloc] initWithContentsOfURL: theScriptPathURL error: &errorDict];
	
	// Safari
	theScriptPath = [theBundlePath stringByAppendingPathComponent: @"safari.scpt"];
	theScriptPathURL = [NSURL fileURLWithPath: theScriptPath];
	m_safariScript = [[NSAppleScript alloc] initWithContentsOfURL: theScriptPathURL error: &errorDict];
	
	// Firefox
	theScriptPath = [theBundlePath stringByAppendingPathComponent: @"firefox.scpt"];
	theScriptPathURL = [NSURL fileURLWithPath: theScriptPath];
	m_firefoxScript = [[NSAppleScript alloc] initWithContentsOfURL: theScriptPathURL error: &errorDict];
	
	// Opera
	theScriptPath = [theBundlePath stringByAppendingPathComponent: @"opera.scpt"];
	theScriptPathURL = [NSURL fileURLWithPath: theScriptPath];
	m_operaScript = [[NSAppleScript alloc] initWithContentsOfURL: theScriptPathURL error: &errorDict];
	
	// Init the idleness detector variables
	m_systemIdle = FALSE;
	m_lastRecordedMousePosition.x = 0;
	m_lastRecordedMousePosition.y = 0;
	m_timeLastRecordedMousePosition = [[NSCalendarDate date] retain];
	
	// Apps to ignore
	m_appsToIgnore = [NSSet setWithObjects: @"SystemUIServer", @"SecurityAgent", @"ScreenSaverEngine", 
		@"loginwindow", @"CoreServicesUIAgent", @"UserNotificationCenter", nil];
	
	// Get the system-wide UI accessibility element
	m_uiSystemWideElement = AXUIElementCreateSystemWide();	
	
	// Observation Timer
	m_observationTimer = [NSTimer scheduledTimerWithTimeInterval: [[m_userDefaults objectForKey: k_Pref_ObservationRate_Key] intValue]
		target: self selector: @selector(observationHandler:) userInfo: nil
		repeats: YES];
	
	// Notify when going to sleep and wake up
	NSNotificationCenter* notCenter = [[NSWorkspace sharedWorkspace] notificationCenter];
	[notCenter addObserver:self selector: @selector(goingToSleepNotification:) name: NSWorkspaceWillSleepNotification object:nil];
	[notCenter addObserver:self selector: @selector(wakingUpNotification:) name: NSWorkspaceDidWakeNotification object:nil];
		   
	// Observer is active
	m_observerActive = TRUE;
	
	// Private mode is off
	m_privateModeOn = FALSE;
	
	return self;
}

#pragma mark --- Accessors ---

// **********************************************************************
//							setPrivateMode
// **********************************************************************
- (void) setPrivateMode: (BOOL) privateModeActive
{
	m_privateModeOn = privateModeActive;
}

#pragma mark --- Support ---

// **********************************************************************
//					saveChangesToManagedContext
// **********************************************************************
- (void) saveChangesToManagedContext
{
	NSError* error;
	
	if (m_managedContext != nil) 
	{
        if ([m_managedContext commitEditing]) 
		{
            if ([m_managedContext hasChanges] && ![m_managedContext save:&error]) 
			{
				if(m_debugState)
				{
					[[NSApplication sharedApplication] presentError:error];
				
					NSLog(@"Slife: Error saving managed context in observer");
				}
			}
		}
	}
}

// **********************************************************************
//					saveLastEventBeforeQuitOrSleep
// **********************************************************************
- (void) saveLastEventBeforeQuitOrSleep
{
	// The observer should be off now
	m_observerActive = FALSE;

	// Save the last event observed
	[self saveLastObservedEvent];
	
	// ---------------------- Reset observations vars -----------------------
			
	m_lastStartDate = nil;
	m_lastApplication = nil;
	m_lastWebPage = nil;
	m_lastWindowTitleName = nil;
	m_lastWindowFilePath = nil;
}

// **********************************************************************
//							goingToSleepNotification
// **********************************************************************
- (void) goingToSleepNotification:(NSNotification *) notification
{
	if(m_debugState)
		NSLog(@"Slife: Going to sleep...");
	
	// Save last event and reset observation vars
	[self saveLastEventBeforeQuitOrSleep];
}

// **********************************************************************
//							wakingUpNotification
// **********************************************************************
- (void) wakingUpNotification:(NSNotification *) notification
{
	if(m_debugState)
		NSLog(@"Slife: Waking up...");
		
	// The observer should be on now
	m_observerActive = TRUE;
}

// **********************************************************************
//						fetchGoalNameAndValues
// **********************************************************************
- (NSMutableArray*) fetchGoalNameAndValues
{
	NSMutableArray* goalsArray = [[NSMutableArray alloc] initWithCapacity: 5];
	
	if(m_managedContext)
	{
		// We use these to calculate percentages later
		int totalNumberOfDaysWithActivitiesRecordedInMonth = 0;
		int totalNumberOfDaysWithActivitiesRecordedInMonthWithGoalReached = 0;
		
		// --- Calculate number of days this month ---
		NSCalendarDate* todaysDate = [NSCalendarDate date];
		NSCalendarDate* firstDayOfMonth = [NSCalendarDate dateWithYear: [todaysDate yearOfCommonEra]
																 month: [todaysDate monthOfYear] day: 1 hour: 10 minute: 0 second: 0 timeZone: [NSTimeZone systemTimeZone]];
		
		NSDateComponents* dateComponents = [[NSDateComponents alloc] init];
		[dateComponents setMonth:1];
		[dateComponents setDay:-1];
		NSDate* lastDayOfMonthDate = [[NSCalendar currentCalendar] dateByAddingComponents: dateComponents toDate: firstDayOfMonth options:0];
		[dateComponents release];
		
		NSDateComponents* lastDayOfMonthComponents = [[NSCalendar currentCalendar] components: NSDayCalendarUnit fromDate: lastDayOfMonthDate];
		int numberOfDaysInMonth = [lastDayOfMonthComponents day];
		
		// Get all activities with goal enabled
		NSFetchRequest* activityFetch = [[NSFetchRequest alloc] init];
		NSEntityDescription* activityEntity = [NSEntityDescription entityForName: @"Activity" inManagedObjectContext: m_managedContext];
		[activityFetch setEntity: activityEntity];
		
		NSPredicate* activityPredicate = [NSPredicate predicateWithFormat: @"goalEnabled == YES"];
		[activityFetch setPredicate: activityPredicate];
		
		NSError* error = nil;
		NSArray* activityGoalEnabledObjects = [m_managedContext executeFetchRequest: activityFetch error: &error];
		
		if(activityGoalEnabledObjects!=nil)
		{
			// Go over every activity
			for(NSManagedObject* activityObject in activityGoalEnabledObjects)
			{
				totalNumberOfDaysWithActivitiesRecordedInMonth = 0;
				totalNumberOfDaysWithActivitiesRecordedInMonthWithGoalReached = 0;
				
				// Get goal duration for activity
				double activityGoalDuration = 0;
				BOOL activityGoalEnabled = [[activityObject valueForKey: @"goalEnabled"] boolValue];
				int activityGoalValue = [[activityObject valueForKey: @"goalValue"] intValue];
				NSString* activityGoalType = [activityObject valueForKey: @"goalType"];
				NSString* activityGoalTimeUnit = [activityObject valueForKey: @"goalTimeUnit"];
				
				if(activityGoalEnabled)
				{
					if([activityGoalTimeUnit isEqualToString: @"hours"])
						activityGoalDuration = activityGoalValue * 60 * 60;
					else if([activityGoalTimeUnit isEqualToString: @"minutes"])
						activityGoalDuration = activityGoalValue * 60;
				}
				
				// Fetch all ActivitiesRecorded for activity at given month
				NSFetchRequest* activityRecordedRequest = [[[NSFetchRequest alloc] init] autorelease];
				NSEntityDescription* activityRecordedEntity = [NSEntityDescription entityForName: @"ActivityRecorded" inManagedObjectContext: m_managedContext];
				[activityRecordedRequest setEntity: activityRecordedEntity];
				
				NSPredicate* activityRecordedPredicate = [NSPredicate predicateWithFormat: 
														  @"activity.name == %@ AND targetMonth == %@ AND targetYear == %@", 
														  [activityObject valueForKey: @"name"], [NSNumber numberWithInt: [todaysDate monthOfYear]], 
														  [NSNumber numberWithInt: [todaysDate yearOfCommonEra]]];
				
				[activityRecordedRequest setPredicate: activityRecordedPredicate];
				
				NSError* error = nil;
				NSArray* activitiesRecordedForMonth = [m_managedContext executeFetchRequest:activityRecordedRequest error:&error];
				
				// Initialize array of durations/day
				int day=0;
				double activityRecordedDurationForDays[32];
				for(day=0; day<=31; day++)
					activityRecordedDurationForDays[day]=0;
				
				// Go over all activities recorded and categorize/sum up durations by day
				for(NSManagedObject* activityRecorded in activitiesRecordedForMonth)
				{
					// Get day
					NSNumber* activityRecordedDay = [activityRecorded valueForKey: @"targetDay"];
					int activityRecordedDayInt = [activityRecordedDay intValue];
					
					// Get duration
					NSNumber* activityRecordedDuration = [activityRecorded valueForKey: @"duration"];
					double activityRecordedDurationDouble = [activityRecordedDuration doubleValue];
					
					// There's duration for the day, count it as a new day
					if(activityRecordedDurationForDays[activityRecordedDayInt]==0)
						totalNumberOfDaysWithActivitiesRecordedInMonth++;
					
					// Categorize/sum up durations
					activityRecordedDurationForDays[activityRecordedDayInt] += activityRecordedDurationDouble;
				}
				
				// Go over all activities recorded and count how many represent a goal reached
				day = 0;
				for(day=0; day<=31; day++)
				{
					double activityRecordedDurationForDay = activityRecordedDurationForDays[day];
					
					if(activityRecordedDurationForDay==0)
						continue;
					
					if([activityGoalType isEqualToString: @"more than"])
					{
						if(activityRecordedDurationForDay>=activityGoalDuration)
							totalNumberOfDaysWithActivitiesRecordedInMonthWithGoalReached++;
					}
					else if([activityGoalType isEqualToString: @"less than"])
					{
						if(activityRecordedDurationForDay<=activityGoalDuration)
							totalNumberOfDaysWithActivitiesRecordedInMonthWithGoalReached++;
					}
				}
				
				// Calculate percentage of goals reached per month
				int percentageGoalsReached = 100 * (numberOfDaysInMonth - (totalNumberOfDaysWithActivitiesRecordedInMonth - 
																		   totalNumberOfDaysWithActivitiesRecordedInMonthWithGoalReached)) / numberOfDaysInMonth;
				
				// Save goal name and percentage (value) in the array
				NSMutableDictionary* goalDictionary = [NSMutableDictionary dictionary];
				[goalDictionary setObject: [activityObject valueForKey: @"name"] forKey: @"name"];
				[goalDictionary setObject: [NSNumber numberWithInt: percentageGoalsReached] forKey: @"value"];
				[goalsArray addObject: goalDictionary];
			}
		}
		else
		{
			NSLog(@"Slife: Error fetching activity objects in fetchGoalNameAndValues");
		}
	}
	else
	{
		NSLog(@"Slife: Managed context is nil in fetchGoalNameAndValues");
	}
	
	// Return goals and values
	return [goalsArray autorelease];
}

#pragma mark --- UI Observation ---

// **********************************************************************
//						valueOfExistingAttribute
// **********************************************************************
+ (id) valueOfExistingAttribute:(CFStringRef)attribute ofUIElement:(AXUIElementRef)element
{
    id result = nil;
    NSArray *attrNames;
    
    if (AXUIElementCopyAttributeNames(element, (CFArrayRef *)&attrNames) == kAXErrorSuccess) 
	{
        if ( [attrNames indexOfObject:(NSString *)attribute] != NSNotFound &&
        	AXUIElementCopyAttributeValue(element, attribute, (CFTypeRef *)&result) == kAXErrorSuccess) 
		{
            [result autorelease];
        }
		
        [attrNames release];
    }
	
    return result;
}

// **********************************************************************
//			fetchTargetApplicationAndWindowPropertiesForElement
// **********************************************************************
- (void) fetchTargetApplicationAndWindowPropertiesForElement: (CFTypeRef)theValue
{
	// Get details about this UI element and save application and window names
	// if these are the corresponding elements
	
    if (theValue) 
	{
        if (CFGetTypeID(theValue) == AXUIElementGetTypeID()) 
		{
            NSString*	uiElementRole  	= NULL;
        
            if (AXUIElementCopyAttributeValue( (AXUIElementRef)theValue, kAXRoleAttribute, (CFTypeRef *)&uiElementRole ) == kAXErrorSuccess) 
			{				
                NSString* uiElementTitle  = NULL;
                uiElementTitle = [SLObserver valueOfExistingAttribute:kAXTitleAttribute ofUIElement:(AXUIElementRef)theValue];

                if (uiElementTitle != nil) 
				{
					if([uiElementRole isEqualToString: @"AXApplication"])
					{
						m_uiApplicationName = uiElementTitle;
					}
					else if([uiElementRole isEqualToString: @"AXWindow"])
					{
						m_uiWindowTitleName = uiElementTitle;
					}
					else
					{
						m_uiApplicationName = nil;
						m_uiWindowTitleName = nil;
					}
				}
				
                [uiElementRole release];
            }
			
			if (AXUIElementCopyAttributeValue( (AXUIElementRef)theValue, kAXDocumentAttribute, (CFTypeRef *)&uiElementRole ) == kAXErrorSuccess) 
			{
				NSString* uiWindowFilePath = NULL;
				uiWindowFilePath = [SLObserver valueOfExistingAttribute:kAXDocumentAttribute ofUIElement:(AXUIElementRef)theValue];
				
				if(uiWindowFilePath != nil)
					m_uiWindowFilePath = uiWindowFilePath;
				else
					m_uiWindowFilePath = nil;
				
                [uiElementRole release];
            }
		}
    }
}

// **********************************************************************
//					lineageOfUIElement:element
// **********************************************************************
- (void) lineageOfUIElement:(AXUIElementRef)element
{
	// Check this element for app/window name and keep climbing the parent hierarchy
	
    [self fetchTargetApplicationAndWindowPropertiesForElement: element];
	
    AXUIElementRef parent = (AXUIElementRef)[SLObserver valueOfExistingAttribute:kAXParentAttribute ofUIElement:element];
	
    if (parent != NULL) 
        [self lineageOfUIElement:parent];
}

// **********************************************************************
//					getUIFrontAppName:element
// **********************************************************************
- (NSString*) getUIFrontAppName
{
	return m_uiApplicationName;
}

// **********************************************************************
//					getUIFrontWindowTitle:element
// **********************************************************************
- (NSString*) getUIFrontWindowTitle
{
	return m_uiWindowTitleName;
}

#pragma mark --- Observation Core ---

// **********************************************************************
//				createOrFetchManagedObjectForApplicationName
// **********************************************************************
- (NSManagedObject*) createOrFetchManagedObjectForApplicationName: (NSString*) appName
{
	NSManagedObject* application = nil;
	
	// Sanity check
	if((nil==appName)||([appName length]==0))
		return nil;
		
	// -------------------------- Look for Application --------------------
		
	NSFetchRequest* appFetch = [[[NSFetchRequest alloc] init] autorelease];
	
	NSEntityDescription* appEntity = [NSEntityDescription entityForName: @"Application" inManagedObjectContext: m_managedContext];
	NSPredicate* appPredicate = [NSPredicate predicateWithFormat: @"name LIKE %@", appName];
	
	[appFetch setEntity: appEntity];
	[appFetch setPredicate: appPredicate];
	
	NSError* error = nil;
	NSArray* appResults = [m_managedContext executeFetchRequest: appFetch error: &error];
	
	if(appResults!=nil)
	{
		// -------------------------- Create new Application object if necessary --------------------
		
		if([appResults count]==0)
		{
			application = [NSEntityDescription insertNewObjectForEntityForName: @"Application" inManagedObjectContext: m_managedContext];
			[application setValue: appName forKey: @"name"];
		}
		else if([appResults count]==1)
		{
			application = [appResults lastObject];
		}
		else
		{
			if(m_debugState)
				NSLog(@"Slife: More than one app with same name in object store when trying to create new app object");
		}
	}
	else
	{
		if(m_debugState)
			NSLog(@"Slife: Error fetching app objects");
	}
	
	return application;
}

// **********************************************************************
//						saveLastObservedEvent
// **********************************************************************
- (void) saveLastObservedEvent
{	
	// There must be at least a last application
	if((nil==m_lastApplication) || ([m_lastApplication length]==0))
		return;
		
	NSManagedObject* application = nil;
	
	if(m_managedContext)
	{
		// Get application object
		application = [self createOrFetchManagedObjectForApplicationName: m_lastApplication];
				
		if(application!=nil)
		{
			if([application valueForKey: @"enabled"])
			{
				// --------------------------------- Compute event duration --------------------------------------------
				
				int secondsDuration=0;
				[[NSCalendarDate date] years: NULL months: NULL days: NULL  hours:NULL minutes:NULL seconds:&secondsDuration sinceDate: m_lastStartDate];
				
				// ------------------------------ Create New Event ----------------------------------------
				
				if(m_debugState)
					NSLog(@"Slife: ----- Starting new event creation ----- ");
				
				NSManagedObject* event = [NSEntityDescription insertNewObjectForEntityForName: @"Event" inManagedObjectContext: m_managedContext];
				[event setValue: application forKey: @"application"];
				[event setValue: m_lastStartDate forKey: @"startDate"];
				[event setValue: [NSCalendarDate date] forKey: @"endDate"];
				[event setValue: [NSNumber numberWithInt: secondsDuration] forKey: @"duration"];
				[event setValue: [NSNumber numberWithInt: [m_lastStartDate secondOfMinute]] forKey: @"targetSecond"];
				[event setValue: [NSNumber numberWithInt: [m_lastStartDate minuteOfHour]] forKey: @"targetMinute"];
				[event setValue: [NSNumber numberWithInt: [m_lastStartDate hourOfDay]] forKey: @"targetHour"];
				[event setValue: [NSNumber numberWithInt: [m_lastStartDate dayOfMonth]] forKey: @"targetDay"];
				[event setValue: [NSNumber numberWithInt: [m_lastStartDate monthOfYear]] forKey: @"targetMonth"];
				[event setValue: [NSNumber numberWithInt: [m_lastStartDate yearOfCommonEra]] forKey: @"targetYear"];
				
				if(m_lastWebPage && ([m_lastWebPage length]>0))
				{
					[event setValue: m_lastWebPage forKey: @"url"];
					
					if(m_debugState)
						NSLog(@"Slife: Create new event for URL: %@", m_lastWebPage);
				}
				
				if(m_lastWindowTitleName && ([m_lastWindowTitleName length]>0))
				{
					[event setValue: m_lastWindowTitleName forKey: @"title"];
					
					if(m_debugState)
						NSLog(@"Slife: Create new event for title: %@", m_lastWindowTitleName);
				}
				
				
				// -------------------------- Add Active Activities to Event --------------------
		
				NSFetchRequest* enabledActivityFetch = [[[NSFetchRequest alloc] init] autorelease];
				
				NSEntityDescription* enabledActivityEntity = [NSEntityDescription entityForName: @"Activity" inManagedObjectContext: m_managedContext];
				NSPredicate* enabledActivityPredicate = [NSPredicate predicateWithFormat: @"active==TRUE AND enabled==TRUE"];
				
				[enabledActivityFetch setEntity: enabledActivityEntity];
				[enabledActivityFetch setPredicate: enabledActivityPredicate];
				
				NSError* error = nil;
				NSArray* enabledActivityResults = [m_managedContext executeFetchRequest: enabledActivityFetch error: &error];
				
				if(enabledActivityResults!=nil)
				{
					NSManagedObject* anEnabledActivity = nil;
					for(anEnabledActivity in enabledActivityResults)
					{
						if(m_debugState)
							NSLog(@"Slife: Activity '%@' is active, adding it to event", [anEnabledActivity valueForKey: @"name"]);
											
						NSMutableSet* eventActivities = [event mutableSetValueForKey: @"activities"];
						[eventActivities addObject: anEnabledActivity];
					}
				}

				// ------------------------------ Add Application Activity To Event ----------------------------------------
				
				NSManagedObject* appActivity = [application valueForKey: @"activity"];
				
				if(nil!=appActivity)
				{
					if([[appActivity valueForKey: @"enabled"] boolValue])
					{
						if(m_debugState)
							NSLog(@"Slife: Activity '%@' from application added to event", [appActivity valueForKey: @"name"]);
												
						NSMutableSet* eventActivities = [event mutableSetValueForKey: @"activities"];
						[eventActivities addObject: appActivity];
					}
					else
					{
						if(m_debugState)
							NSLog(@"Slife: Activity '%@' not enabled", [appActivity valueForKey: @"name"]);
					}
				}
				
				// ------------------------------ Item ----------------------------------------
				
				// Look for items that match url or title. Take their activities and add them to the event
				
				
				NSManagedObject* item = nil;
				
				if( (m_lastWebPage && ([m_lastWebPage length]>0)) || (m_lastWindowTitleName && ([m_lastWindowTitleName length]>0)) 
					|| (m_lastWindowFilePath && ([m_lastWindowFilePath length]>0)) )
				{
					NSFetchRequest* itemFetch = [[NSFetchRequest alloc] init];
					
					NSEntityDescription* itemEntity = [NSEntityDescription entityForName: @"Item" inManagedObjectContext: m_managedContext];
					NSPredicate* itemPredicate = [NSPredicate predicateWithFormat: @"enabled == YES"];
					
					[itemFetch setEntity: itemEntity];
					[itemFetch setPredicate: itemPredicate];
					
					NSError* error = nil;
					NSArray* itemResults = [m_managedContext executeFetchRequest: itemFetch error: &error];
					
					if(itemResults!=nil)
					{
						for(item in itemResults)
						{
							BOOL itemMatch = FALSE;
							
							// -------------------------- Match last web page with an item --------------------
							
							if(m_lastWebPage && ([m_lastWebPage length]>0))
							{
								NSString* itemName = [item valueForKey: @"name"];
								
								if( (itemName!=nil) && ([itemName length]>0) )
								{
									NSRange lastWebPageRange = [m_lastWebPage rangeOfString: itemName];
									
									if(lastWebPageRange.location!=NSNotFound)
										itemMatch = TRUE;
								}
							}
							
							// -------------------------- Match window title name with an item --------------------
							
							if(m_lastWindowTitleName && ([m_lastWindowTitleName length]>0))
							{
								NSString* itemName = [item valueForKey: @"name"];
								
								if( (itemName!=nil) && ([itemName length]>0) )
								{
									NSRange lastWindowTitleNameRange = [m_lastWindowTitleName rangeOfString: itemName];
									
									if(lastWindowTitleNameRange.location!=NSNotFound)
										itemMatch = TRUE;
								}
							}
							
							// -------------------------- Match file path with an item --------------------
							
							if(m_lastWindowFilePath && ([m_lastWindowFilePath length]>0))
							{
								NSString* itemName = [item valueForKey: @"name"];
								
								if( (itemName!=nil) && ([itemName length]>0) )
								{
									NSRange lastWindowFilePathRange = [m_lastWindowFilePath rangeOfString: itemName];
									
									if(lastWindowFilePathRange.location!=NSNotFound)
										itemMatch = TRUE;
								}
							}
						
							// -------------------------- Add Item Activity To Event --------------------
							
							if(itemMatch)
							{
								NSManagedObject* itemActivity = [item valueForKey: @"activity"];
								
								if(nil!=itemActivity)
								{
									if([[itemActivity valueForKey: @"enabled"] boolValue])
									{
										if(m_debugState)
											NSLog(@"Slife: Activity '%@' from item added to event", [itemActivity valueForKey: @"name"]);
									
										NSMutableSet* eventActivities = [event mutableSetValueForKey: @"activities"];
										[eventActivities addObject: itemActivity];
									}
									else
									{
										if(m_debugState)
											NSLog(@"Slife: Activity '%@' not enabled", [itemActivity valueForKey: @"name"]);
									}
								}
							}
						}
					}
				}
				
				// --------------------- Add Event Duration to Corresponding Activities (ActivitiesRecorded) ---------------------------------
				
				int dateHour = [[NSCalendarDate date] hourOfDay];
				int dateDay = [[NSCalendarDate date] dayOfMonth];
				int dateMonth = [[NSCalendarDate date] monthOfYear];
				int dateYear = [[NSCalendarDate date] yearOfCommonEra];
	
				NSManagedObject* activityRecorded = nil;
				
				NSMutableSet* eventActivities = [event mutableSetValueForKey: @"activities"];
				
				if(eventActivities && ([eventActivities count] > 0))
				{
					NSManagedObject* anActivity = nil;
					for(anActivity in eventActivities)
					{
						// -------------------------- Look for Activity --------------------
		
						NSFetchRequest* activityRecordedFetch = [[[NSFetchRequest alloc] init] autorelease];
						
						NSEntityDescription* activityRecordedEntity = [NSEntityDescription entityForName: @"ActivityRecorded" inManagedObjectContext: m_managedContext];
						NSPredicate* activityRecordedPredicate = [NSPredicate predicateWithFormat: @"activity.name LIKE %@ AND targetHour == %@ AND targetDay == %@ AND targetMonth == %@ AND targetYear == %@", 
							[anActivity valueForKey: @"name"], [NSNumber numberWithInt: dateHour], [NSNumber numberWithInt: dateDay], [NSNumber numberWithInt: dateMonth], 
							[NSNumber numberWithInt: dateYear]];
						
						[activityRecordedFetch setEntity: activityRecordedEntity];
						[activityRecordedFetch setPredicate: activityRecordedPredicate];
						
						NSError* error = nil;
						NSArray* activityRecordedResults = [m_managedContext executeFetchRequest: activityRecordedFetch error: &error];
						
						if(activityRecordedResults!=nil)
						{
							// -------------------------- Create new ActivityRecorded object if necessary --------------------
							
							if([activityRecordedResults count]==0)
							{
								if(m_debugState)
									NSLog(@"Slife: New ActivityRecorded for activity '%@' for hour %d, day %d, month %d and year %d", 
										[anActivity valueForKey: @"name"], dateHour, dateDay, dateMonth, dateYear);
									
								activityRecorded = [NSEntityDescription insertNewObjectForEntityForName: @"ActivityRecorded" inManagedObjectContext: m_managedContext];
								
								[activityRecorded setValue: [NSNumber numberWithInt: dateHour] forKey: @"targetHour"];
								[activityRecorded setValue: [NSNumber numberWithInt: dateDay] forKey: @"targetDay"];
								[activityRecorded setValue: [NSNumber numberWithInt: dateMonth] forKey: @"targetMonth"];
								[activityRecorded setValue: [NSNumber numberWithInt: dateYear] forKey: @"targetYear"];
								
								[activityRecorded setValue: anActivity forKey: @"activity"];
								[activityRecorded setValue: [NSNumber numberWithDouble: secondsDuration] forKey: @"duration"];
							}
							else if([activityRecordedResults count]==1)
							{
								if(m_debugState)
									NSLog(@"Slife: Adding duration for ActivityRecorded for activity '%@' for hour %d, day %d, month %d and year %d", 
										[anActivity valueForKey: @"name"], dateHour, dateDay, dateMonth, dateYear);
										
								activityRecorded = [activityRecordedResults lastObject];
								
								double activityRecordedDuration = [[activityRecorded valueForKey: @"duration"] doubleValue];
								activityRecordedDuration += secondsDuration;
							
								[activityRecorded setValue: [NSNumber numberWithDouble: activityRecordedDuration] forKey: @"duration"];
							
							}
							else
							{
								if(m_debugState)
									NSLog(@"Slife: More than one ActivityRecorded with same name in object store");
							}
						}
						else
						{
							if(m_debugState)
								NSLog(@"Slife: Error fetching ActivityRecorded objects");
						}

					}
				}
				
				
				// --------------------- Check Activity Goals For Day For Growl Notification (ActivitiesRecorded) ---------------------------------
				
				
				if(eventActivities && ([eventActivities count] > 0))
				{
					NSManagedObject* anActivity = nil;
					for(anActivity in eventActivities)
					{
						// -------------------------- Look for Activity --------------------
		
						NSFetchRequest* activityRecordedFetch = [[[NSFetchRequest alloc] init] autorelease];
						
						NSEntityDescription* activityRecordedEntity = [NSEntityDescription entityForName: @"ActivityRecorded" inManagedObjectContext: m_managedContext];
						NSPredicate* activityRecordedPredicate = [NSPredicate predicateWithFormat: @"activity.name LIKE %@ AND targetDay == %@ AND targetMonth == %@ AND targetYear == %@", 
							[anActivity valueForKey: @"name"], [NSNumber numberWithInt: dateDay], [NSNumber numberWithInt: dateMonth], [NSNumber numberWithInt: dateYear]];
						
						[activityRecordedFetch setEntity: activityRecordedEntity];
						[activityRecordedFetch setPredicate: activityRecordedPredicate];
						
						NSError* error = nil;
						NSArray* activityRecordedResults = [m_managedContext executeFetchRequest: activityRecordedFetch error: &error];
						
						if(activityRecordedResults!=nil)
						{
							// -------------------------- Compute total time for activity for day --------------------
							
							if([activityRecordedResults count]>0)
							{
								if(m_debugState)
									NSLog(@"Slife: %d ActivityRecorded entries for activity '%@' for day %d, month %d and year %d", 
										[activityRecordedResults count], [anActivity valueForKey: @"name"], dateDay, dateMonth, dateYear);

								NSManagedObject* anActivityRecorded = nil;
								double activityRecordedDuration = 0;
								
								for(anActivityRecorded in activityRecordedResults)
								{
									activityRecordedDuration += [[anActivityRecorded valueForKey: @"duration"] doubleValue];
								}
								
								if(m_debugState)
									NSLog(@"Slife: Total duration for ActivityRecorded entries for activity '%@' for day %d, month %d and year %d: %f", 
										[anActivity valueForKey: @"name"], dateDay, dateMonth, dateYear, activityRecordedDuration);

							}
							else
							{
								if(m_debugState)
									NSLog(@"Slife: More than one ActivityRecorded with same name in object store");
							}
						}
						else
						{
							if(m_debugState)
								NSLog(@"Slife: Error fetching ActivityRecorded objects");
						}

					}
				}
				
				// --------------------- Add Event Duration to Corresponding Application (ApplicationRecorded) ---------------------------------
				
				NSManagedObject* applicationRecorded = nil;
				
				// -------------------------- Look for Application Record --------------------

				NSFetchRequest* applicationRecordedFetch = [[[NSFetchRequest alloc] init] autorelease];
				
				NSEntityDescription* applicationRecordedEntity = [NSEntityDescription entityForName: @"ApplicationRecorded" inManagedObjectContext: m_managedContext];
				NSPredicate* applicationRecordedPredicate = [NSPredicate predicateWithFormat: @"application.name LIKE %@ AND targetHour == %@ AND targetDay == %@ AND targetMonth == %@ AND targetYear == %@", 
					[application valueForKey: @"name"], [NSNumber numberWithInt: dateHour], [NSNumber numberWithInt: dateDay], [NSNumber numberWithInt: dateMonth], 
					[NSNumber numberWithInt: dateYear]];
				
				[applicationRecordedFetch setEntity: applicationRecordedEntity];
				[applicationRecordedFetch setPredicate: applicationRecordedPredicate];
				
				error = nil;
				NSArray* applicationRecordedResults = [m_managedContext executeFetchRequest: applicationRecordedFetch error: &error];
				
				if(applicationRecordedResults!=nil)
				{
					// -------------------------- Create new ApplicationRecorded object if necessary --------------------
					
					if([applicationRecordedResults count]==0)
					{
						applicationRecorded = [NSEntityDescription insertNewObjectForEntityForName: @"ApplicationRecorded" inManagedObjectContext: m_managedContext];
						
						[applicationRecorded setValue: [NSNumber numberWithInt: dateHour] forKey: @"targetHour"];
						[applicationRecorded setValue: [NSNumber numberWithInt: dateDay] forKey: @"targetDay"];
						[applicationRecorded setValue: [NSNumber numberWithInt: dateMonth] forKey: @"targetMonth"];
						[applicationRecorded setValue: [NSNumber numberWithInt: dateYear] forKey: @"targetYear"];
						
						[applicationRecorded setValue: application forKey: @"application"];
						[applicationRecorded setValue: [NSNumber numberWithDouble: secondsDuration] forKey: @"duration"];
					}
					else if([applicationRecordedResults count]==1)
					{
						applicationRecorded = [applicationRecordedResults lastObject];
						
						double applicationRecordedDuration = [[applicationRecorded valueForKey: @"duration"] doubleValue];
						applicationRecordedDuration += secondsDuration;
					
						[applicationRecorded setValue: [NSNumber numberWithDouble: applicationRecordedDuration] forKey: @"duration"];
					
					}
					else
					{
						if(m_debugState)
							NSLog(@"Slife: More than one ApplicationRecorded with same name in object store");
					}
				}
				else
				{
					if(m_debugState)
						NSLog(@"Slife: Error fetching ApplicationRecorded objects");
				}

				// --------------------- Add Event Duration to Corresponding Item (ItemRecorded) ---------------------------------
				
				NSManagedObject* itemRecorded = nil;
				NSString* itemName = nil;
				
				// Decide which item to use, title or url
				if(m_lastWebPage && ([m_lastWebPage length]>0))
				{
					itemName = [event valueForKey: @"url"];
				}
				
				if(m_lastWindowTitleName && ([m_lastWindowTitleName length]>0))
				{
					itemName = [event valueForKey: @"title"];
				}
				
				if(itemName && ([itemName length]>0))
				{
				
					// -------------------------- Look for Item Recorded --------------------

					NSFetchRequest* itemRecordedFetch = [[[NSFetchRequest alloc] init] autorelease];
					
					NSEntityDescription* itemRecordedEntity = [NSEntityDescription entityForName: @"ItemRecorded" inManagedObjectContext: m_managedContext];
					NSPredicate* itemRecordedPredicate = [NSPredicate predicateWithFormat: @"name LIKE %@ AND targetHour == %@ AND targetDay == %@ AND targetMonth == %@ AND targetYear == %@", 
						itemName, [NSNumber numberWithInt: dateHour], [NSNumber numberWithInt: dateDay], [NSNumber numberWithInt: dateMonth], 
						[NSNumber numberWithInt: dateYear]];
					
					[itemRecordedFetch setEntity: itemRecordedEntity];
					[itemRecordedFetch setPredicate: itemRecordedPredicate];
					
					error = nil;
					NSArray* itemRecordedResults = [m_managedContext executeFetchRequest: itemRecordedFetch error: &error];
					
					if(itemRecordedResults!=nil)
					{
						// -------------------------- Create new ItemRecorded object if necessary --------------------
						
						if([itemRecordedResults count]==0)
						{
							itemRecorded = [NSEntityDescription insertNewObjectForEntityForName: @"ItemRecorded" inManagedObjectContext: m_managedContext];
							
							[itemRecorded setValue: [NSNumber numberWithInt: dateHour] forKey: @"targetHour"];
							[itemRecorded setValue: [NSNumber numberWithInt: dateDay] forKey: @"targetDay"];
							[itemRecorded setValue: [NSNumber numberWithInt: dateMonth] forKey: @"targetMonth"];
							[itemRecorded setValue: [NSNumber numberWithInt: dateYear] forKey: @"targetYear"];
							
							[itemRecorded setValue: itemName forKey: @"name"];
							[itemRecorded setValue: m_lastApplication forKey: @"applicationName"];
							[itemRecorded setValue: [NSNumber numberWithDouble: secondsDuration] forKey: @"duration"];
						}
						else if([itemRecordedResults count]==1)
						{
							itemRecorded = [itemRecordedResults lastObject];
							
							double itemRecordedDuration = [[itemRecorded valueForKey: @"duration"] doubleValue];
							itemRecordedDuration += secondsDuration;
						
							[itemRecorded setValue: [NSNumber numberWithDouble: itemRecordedDuration] forKey: @"duration"];
						
						}
						else
						{
							if(m_debugState)
								NSLog(@"Slife: More than one ItemRecorded with same name in object store");
						}
					}
					else
					{
						if(m_debugState)
							NSLog(@"Slife: Error fetching ItemRecorded objects");
					}
				}
			}
		}
		else
		{
			if(m_debugState)
				NSLog(@"Slife: Application object is nil. Can't save event object in observer");
		}
		
		[self saveChangesToManagedContext];
	}
	else
	{
		if(m_debugState)
			NSLog(@"Slife: Managed Context is nil in observer");
	}
}

// **********************************************************************
//						observationHandler
// **********************************************************************
- (void) observationHandler: (NSTimer*) timer
{	
	// Check private mode
	if(m_privateModeOn)
		return;
	
	// Master switch for the observer
	if(!m_observerActive)
		return;
	
	// ---------------------- Idle Check ------------------------------------
	
	// Determine the current mouse location
	NSPoint currentMouseLocation = [NSEvent mouseLocation];
	
	// See if the mouse location has changed since last time
	if( (currentMouseLocation.x!=m_lastRecordedMousePosition.x) || 
		(currentMouseLocation.y!=m_lastRecordedMousePosition.y) )
	{	
		// Mark the system as non-idle
		m_systemIdle = FALSE;
		
		// Get the mouse location and record the time
		m_lastRecordedMousePosition = currentMouseLocation;
		m_timeLastRecordedMousePosition = [NSDate date];
	}
	else
	{
		// Get the current timestamp
		NSCalendarDate* nowDate = [NSDate date];
		
		// Check the interval the mouse has been idle
		NSTimeInterval timeIdle = [nowDate timeIntervalSinceDate: m_timeLastRecordedMousePosition];
		
		if(timeIdle>([[m_userDefaults objectForKey: k_Pref_ObserverIdleValue_Key] intValue]*60))
		{
			// If we are going idle, save event first
			if(m_systemIdle==FALSE)
			{
				if(m_debugState)
					NSLog(@"Slife: Saving last event and going idle");

				// ---------------------- Reset observations vars ----------------------
				
				m_lastStartDate = nil;
				m_lastApplication = nil;
				m_lastWebPage = nil;
				m_lastWindowTitleName = nil;
				m_lastWindowFilePath = nil;
				
				// -------------------------- Go Idle ------------------------------
				
				// Mark the system as idle
				m_systemIdle = TRUE;

			}
			else
			{
				if(m_debugState)
					NSLog(@"Slife: Still idle");
			}
		}
		else
		{
			if(m_debugState)
				NSLog(@"Slife: Waiting to go idle");
					
			// Mark the system as non-idle
			m_systemIdle = FALSE;
		}
	}
	
	// If the system is idle, save last event and reset everything
	if(m_systemIdle==TRUE)
	{
		if(m_debugState)
			NSLog(@"Slife: --------------- Observer is idle, just return --------------------");
			
		return;
	}

	// ---------------------- Max Duration Check ------------------------------------
	
	if(m_lastStartDate!=nil)
	{
		if(m_debugState)
			NSLog(@"Slife: Maximum duration check...");
				
		int secondsDuration=0;
		[[NSCalendarDate date] years: NULL months: NULL days: NULL  hours:NULL minutes:NULL seconds:&secondsDuration sinceDate: m_lastStartDate];

		if(secondsDuration>MAX_SECS)
		{
			if(m_debugState)
				NSLog(@"Slife: Discarding event - too long");
				
			// ---------------------- Reset event info -----------------------
					
			m_lastStartDate = nil;
			m_lastApplication = nil;
			m_lastWebPage = nil;
			m_lastWindowTitleName = nil;
			m_lastWindowFilePath = nil;
			
			return;
		}
	}
	
	// ---------------------- Observe ------------------------------------
	
	m_uiApplicationName = nil;
	m_uiWindowTitleName = nil;
	m_uiWindowFilePath = nil;
	
	NSString* frontAppName = [SLUtilities frontMostApp];
	NSString* frontWebPage = nil;
	NSString* frontWindowTitleName = nil;
	NSString* frontWindowFilePath = nil;
	
	//NSLog(frontAppName);
	
	
	// ---- Ask Accessibility API for UI Element under the mouse -------
	
	Point		pointAsCarbonPoint;

	GetGlobalMouse( &pointAsCarbonPoint );
	
	CGPoint				pointAsCGPoint;
	AXUIElementRef 		newElement = NULL;

	pointAsCGPoint.x = pointAsCarbonPoint.h;
	pointAsCGPoint.y = pointAsCarbonPoint.v;

	if (AXUIElementCopyElementAtPosition( m_uiSystemWideElement, pointAsCGPoint.x, pointAsCGPoint.y, &newElement ) == kAXErrorSuccess && newElement)
	{
		[self lineageOfUIElement:newElement];
	}
		
	//NSLog(m_uiApplicationName);
	//NSLog(m_uiWindowTitleName);
	//NSLog(m_uiWindowFilePath);
	
	if(frontAppName && ([frontAppName length]>0))
	{
		// ---- Apps To Ignore -------
		
		if([m_appsToIgnore member: frontAppName])
			return;
		
		// ---- Get window title name -------

		if (m_uiApplicationName && ([m_uiApplicationName length]>0))
		{
			// Make sure that frontmost app name and ui app name match to get window title and file path
			NSRange frontAppNameAndUIAppNameMatchRange = [frontAppName rangeOfString: m_uiApplicationName];
			if(frontAppNameAndUIAppNameMatchRange.location!=NSNotFound)
			{
				if(m_uiWindowTitleName && ([m_uiWindowTitleName length]>0))
				{
					frontWindowTitleName = [SLUtilities removeLoadingPrefixFromWebPageTitle: m_uiWindowTitleName];
				}
				
				if(m_uiWindowFilePath && ([m_uiWindowFilePath length]>0))
				{
					frontWindowFilePath = m_uiWindowFilePath;
				}
				
				if(m_debugState)
				{
					NSLog(@"Slife: Window title: %@", frontWindowTitleName);
					NSLog(@"Slife: Window file path: %@", frontWindowFilePath);
				}
			}
			else
			{
				if(m_debugState)
					NSLog(@"Slife: Front app name '%@' and UI app name '%@' don't match", frontAppName, m_uiApplicationName);
			}
		}
		
		// ---- Observer Scripting -------

		if([[m_userDefaults objectForKey: k_Pref_EnableObserverScripting_Key] boolValue])
		{
			// Mail
			if([frontAppName isEqualToString: @"Mail"])
			{
				NSArray* scriptResultArray = [SLUtilities executeApplescript: m_mailScript];
			
				if( (nil != scriptResultArray) && ([scriptResultArray count]>0) )
				{
					frontWindowTitleName = [scriptResultArray objectAtIndex: 0];
				}
					
				if(m_debugState)
					NSLog(@"Slife: Title observed with scripting: %@", frontWebPage);
			}
			
			// Netnewswire
			if([frontAppName isEqualToString: @"NetNewsWire"])
			{
				NSArray* scriptResultArray = [SLUtilities executeApplescript: m_netnewswireScript];
			
				if( (nil != scriptResultArray) && ([scriptResultArray count]>0) )
				{
					frontWindowTitleName = [scriptResultArray objectAtIndex: 0];
				}
					
				if(m_debugState)
					NSLog(@"Slife: Title observed with scripting: %@", frontWebPage);
			}
			
			// Safari
			else if([frontAppName isEqualToString: @"Safari"])
			{
				NSArray* scriptResultArray = [SLUtilities executeApplescript: m_safariScript];
			
				if( (nil != scriptResultArray) && ([scriptResultArray count]>0) )
				{
					frontWebPage = [scriptResultArray objectAtIndex: 1];
					frontWebPage = [SLUtilities removeLoadingPrefixFromWebPageTitle: frontWebPage];
				}
					
				if(m_debugState)
					NSLog(@"Slife: Page observed with scripting: %@", frontWebPage);
			}
			
			// Firefox
			else if([frontAppName isEqualToString: @"Firefox"])
			{
				NSArray* scriptResultArray = [SLUtilities executeApplescript: m_firefoxScript];
			
				if( (nil != scriptResultArray) && ([scriptResultArray count]>0) )
				{
					frontWebPage = [scriptResultArray objectAtIndex: 1];
					frontWebPage = [SLUtilities removeLoadingPrefixFromWebPageTitle: frontWebPage];
				}
					
				if(m_debugState)
					NSLog(@"Slife: Page observed with scripting: %@", frontWebPage);
			}
			
			// Opera
			if([frontAppName isEqualToString: @"Opera"])
			{
				NSArray* scriptResultArray = [SLUtilities executeApplescript: m_operaScript];
			
				if( (nil != scriptResultArray) && ([scriptResultArray count]>0) )
				{
					frontWebPage = [scriptResultArray objectAtIndex: 1];
					frontWebPage = [SLUtilities removeLoadingPrefixFromWebPageTitle: frontWebPage];
				}
					
				if(m_debugState)
					NSLog(@"Slife: Page observed with scripting: %@", frontWebPage);
			}
		}
		
		// ---------------------- Track event boundaries and save them  ------------------------------------
		
		if(m_lastApplication==nil && m_lastStartDate==nil)
		{
			if(m_debugState)
				NSLog(@"Slife: Setting last application and last date");
				
			m_lastApplication = frontAppName;
			m_lastStartDate = [NSCalendarDate date];
			
			if(frontWebPage && ([frontWebPage length]>0))
				m_lastWebPage = frontWebPage;
				
			if(frontWindowTitleName && ([frontWindowTitleName length]>0))
				m_lastWindowTitleName = frontWindowTitleName;
			
			if(frontWindowFilePath && ([frontWindowFilePath length]>0))
				m_lastWindowFilePath = frontWindowFilePath;
		}
		else if( 
		(![m_lastApplication isEqualToString: frontAppName]) ||
		(m_lastWebPage && ([m_lastWebPage length]>0) && ![m_lastWebPage isEqualToString: frontWebPage]) ||
		(m_lastWindowTitleName && ([m_lastWindowTitleName length]>0) && ![m_lastWindowTitleName isEqualToString: frontWindowTitleName])
		)
		{
			// ---------------------- Reset application -----------------------
			
			[self saveLastObservedEvent];
			
			// ---------------------- Refresh front view -----------------------
			
			[[NSApp delegate] refreshFrontView];
			
			// ---------------------- Reset and set event info -----------------------
			
			m_lastStartDate = nil;
			m_lastApplication = nil;
			m_lastWebPage = nil;
			m_lastWindowTitleName = nil;
			m_lastWindowFilePath = nil;
			
			m_lastStartDate = [NSCalendarDate date];
			m_lastApplication = frontAppName;
			m_lastWebPage = frontWebPage;
			m_lastWindowTitleName = frontWindowTitleName;
			m_lastWindowFilePath = frontWindowFilePath;
		}
		
	}
}

@end
