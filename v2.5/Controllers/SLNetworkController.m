
//  Slife
//
//  Created by Edison Thomaz
//  Copyright 2007-2008 Slife Labs, LLC. All rights reserved.
//

#include <openssl/md5.h>
#import "XMLRPCCall.h"
#import "SLNetworkController.h"

// **********************************************************************
//
//							Preferences
//
// **********************************************************************

extern NSString* k_Pref_DebugOn_Key;

extern NSString* k_Pref_RewardsUsername_Key;
extern NSString* k_Pref_RewardsPassword_Key;

extern NSString* k_Pref_TeamsTeamName_Key;
extern NSString* k_Pref_TeamsTeamKey_Key;
extern NSString* k_Pref_TeamsUserName_Key;

// **********************************************************************
//
//								Constants
//
// **********************************************************************

extern NSString* SLIFETEAMS_XMLRPC_URL;
extern NSString* SLIFEREWARDS_XMLRPC_URL;

extern NSString* SLIFETEAMS_LOGACTIVITY_METHODNAME;
extern NSString* SLIFETEAMS_LOGNOTE_METHODNAME;
extern NSString* SLIFETEAMS_FETCHTEAMACTIVITIES_METHODNAME;
extern NSString* SLIFETEAMS_VALIDATEACCOUNT_METHODNAME;

extern NSString* SLIFEREWARDS_LOGGOALS_METHODNAME;
extern NSString* SLIFEREWARDS_VALIDATEACCOUNT_METHODNAME;

// **********************************************************************
//
//                    NetworkController (Private)
//
// **********************************************************************

@interface SLNetworkController (Private)

// Utilities
- (NSString*) getCallError: (id) rpcCall;

@end


@implementation SLNetworkController

// **********************************************************************
//
//							 Initialization
//
// **********************************************************************

// **********************************************************************
//							init
// **********************************************************************
- (id) init
{
	// Init the parent class
    [super init];
	
	// Debug
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
	m_debugState = [[defaults objectForKey: k_Pref_DebugOn_Key] boolValue];
		
    return self;
}

// **********************************************************************
//							dealloc
// **********************************************************************
- (void) dealloc
{	
	[super dealloc];
}

#pragma mark -

// **********************************************************************
//
//							Utilities
//
// **********************************************************************

// **********************************************************************
//					replaceDoubleWithSingleQuotesForString
// **********************************************************************
+ (NSString*) replaceDoubleWithSingleQuotesForString: (NSString*) inString
{
	// Sanity check
	if(inString==nil)
		return nil;
		
	// See if there's a double quote in the first place
	NSRange doubleQuoteRange = [inString rangeOfString: @"\""];
	
	// There is, replace it
	if(doubleQuoteRange.location!=NSNotFound)
	{
		NSArray* stringDoubleQuoteItemsArray = [inString componentsSeparatedByString: @"\""];
		return [stringDoubleQuoteItemsArray componentsJoinedByString: @"'"];
	}
	else
		return inString;
}

// **********************************************************************
//						getMD5ForString
// **********************************************************************
+ (NSString*) getMD5ForString: (NSString*) inString
{
	// Sanity checks
	if(nil==inString)
		return nil;
	
	if([inString length]==0)
		return inString;
	
	NSData* toHash = [inString dataUsingEncoding:NSUTF8StringEncoding];
	
	unsigned char* digest = MD5([toHash bytes], [toHash length], NULL);
	
	if (digest) 
	{
		NSMutableString* ms = [NSMutableString string];
		
		int i = 0;
		for (i = 0; i < MD5_DIGEST_LENGTH; i++) 
		{
			[ms appendFormat: @"%02x", (int)(digest[i])];
		}
		
		NSString* s = [[ms copy] autorelease];
		
		return s;
	} 
	else 
	{
		return nil;
	}
}

#pragma mark -

// **********************************************************************
//					logEventActionWithParameters
// **********************************************************************
- (void) logEventActionWithParameters: (NSDictionary*) eventParameters
{
	// Sanity check
	if(nil==eventParameters)
		return;
	
	// The properties containers
	NSString* name = @"";
	NSString* url = @"";
	NSString* source = @"";
	NSString* application = nil;
	NSString* applicationIcon = nil;
	NSArray* activities = nil;
	int duration = 0;
	int hour = 0;
	int day = 0;
	int month = 0;
	int year = 0;
	
	name = [eventParameters objectForKey: @"name"];
	url = [eventParameters objectForKey: @"url"];
	source = [eventParameters objectForKey: @"source"];
	application = [eventParameters objectForKey: @"application"];
	applicationIcon = [eventParameters objectForKey: @"applicationIcon"];
	activities = [eventParameters objectForKey: @"activities"];
	duration = [[eventParameters objectForKey: @"duration"] intValue];
	hour = [[eventParameters objectForKey: @"hour"] intValue];
	day = [[eventParameters objectForKey: @"day"] intValue];
	month = [[eventParameters objectForKey: @"month"] intValue];
	year = [[eventParameters objectForKey: @"year"] intValue];
	
	// Sanity checks
		
	if(hour>23)
		return;
		
	if( (day==0) || (day>31) )
		return;
	
	if( (month==0) || (month>12) )
		return;
		
	if( (year==0) || (year<2008) )
		return;
	
	// Get the account
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
	
	NSString* team = [defaults objectForKey: k_Pref_TeamsTeamName_Key];
	NSString* datakey = [defaults objectForKey: k_Pref_TeamsTeamKey_Key];
	NSString* user = [defaults objectForKey: k_Pref_TeamsUserName_Key];
	
	if( (nil==team) || (nil==datakey) || (nil==user) || ([team length]==0) ||
		([datakey length]==0) || ([user length]==0) )
		return;
		
	NS_DURING
	
	// The call and its params
	XMLRPCCall* rpcCall = [[XMLRPCCall alloc] initWithURLString: SLIFETEAMS_XMLRPC_URL];
	NSArray* params = nil;
	
	// Set the method name
	[rpcCall setMethodName: SLIFETEAMS_LOGACTIVITY_METHODNAME];
	
	// -------------------------- Set parameters ---------------------------------
	
	// Set the parameters. It's an array. Order matters.
	params = [NSArray arrayWithObjects: 
		team, 
		datakey, 
		user,
		name,
		url,
		source,
		application,
		applicationIcon,
		activities, 
		[NSString stringWithFormat:@"%d", hour],
		[NSString stringWithFormat:@"%d", day],
		[NSString stringWithFormat:@"%d", month],
		[NSString stringWithFormat:@"%d", year], 
		[NSString stringWithFormat:@"%d", duration],
		@"mac", 
		nil];
		
	[rpcCall setParameters: params];
	
	// Make the XML-RPC Call
	[rpcCall invokeInNewThread: self callbackSelector: @selector (logEventActionCallback:)];
	
	// ----------------------------- Debug ------------------------------------------
	
	if(m_debugState)
	{
		NSLog(@"Slife: Logging activity to Teams");
	}
	
	// -------------------------------------------------------------------------------
	
	NS_HANDLER
	
	NSLog(@"Slife: Exception in logActivity: %@", localException);
	
	NS_ENDHANDLER
}

// **********************************************************************
//						logNoteWithParameters
// **********************************************************************
- (void) logNoteWithParameters: (NSDictionary*) eventParameters
{
	// Sanity check
	if(nil==eventParameters)
		return;
	
	// The properties containers
	NSString* note = @"";
	int hour = 0;
	int minute = 0;
	int day = 0;
	int month = 0;
	int year = 0;
	
	note = [eventParameters objectForKey: @"note"];
	hour = [[eventParameters objectForKey: @"hour"] intValue];
	minute = [[eventParameters objectForKey: @"minute"] intValue];
	day = [[eventParameters objectForKey: @"day"] intValue];
	month = [[eventParameters objectForKey: @"month"] intValue];
	year = [[eventParameters objectForKey: @"year"] intValue];
	
	// Sanity checks
	
	if(hour>23)
		return;
	
	if(minute>59)
		return;
	
	if( (day==0) || (day>31) )
		return;
	
	if( (month==0) || (month>12) )
		return;
	
	if( (year==0) || (year<2008) )
		return;
	
	// Get the account
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
	
	NSString* team = [defaults objectForKey: k_Pref_TeamsTeamName_Key];
	NSString* datakey = [defaults objectForKey: k_Pref_TeamsTeamKey_Key];
	NSString* user = [defaults objectForKey: k_Pref_TeamsUserName_Key];
	
	if( (nil==team) || (nil==datakey) || (nil==user) || ([team length]==0) ||
	   ([datakey length]==0) || ([user length]==0) )
		return;
	
	NS_DURING
	
	// The call and its params
	XMLRPCCall* rpcCall = [[XMLRPCCall alloc] initWithURLString: SLIFETEAMS_XMLRPC_URL];
	NSArray* params = nil;
	
	// Set the method name
	[rpcCall setMethodName: SLIFETEAMS_LOGNOTE_METHODNAME];
	
	// -------------------------- Set parameters ---------------------------------
	
	// Set the parameters. It's an array. Order matters.
	params = [NSArray arrayWithObjects: 
			  team, 
			  datakey, 
			  user,
			  note,
			  [NSString stringWithFormat:@"%d", hour],
			  [NSString stringWithFormat:@"%d", minute],
			  [NSString stringWithFormat:@"%d", day],
			  [NSString stringWithFormat:@"%d", month],
			  [NSString stringWithFormat:@"%d", year],
			  nil];
	
	[rpcCall setParameters: params];
	
	// Make the XML-RPC Call
	[rpcCall invokeInNewThread: self callbackSelector: @selector (logNoteCallback:)];
	
	// ----------------------------- Debug ------------------------------------------
	
	if(m_debugState)
	{
		NSLog(@"Slife: Logging note to Teams");
	}
	
	// -------------------------------------------------------------------------------
	
	NS_HANDLER
	
	NSLog(@"Slife: Exception in note: %@", localException);
	
	NS_ENDHANDLER
}

// **********************************************************************
//
//							fetchTeamActivities
//
// **********************************************************************
- (BOOL) fetchTeamActivities
{		
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
	
	NSString* team = [defaults objectForKey: k_Pref_TeamsTeamName_Key];
	NSString* datakey = [defaults objectForKey: k_Pref_TeamsTeamKey_Key];
	NSString* user = [defaults objectForKey: k_Pref_TeamsUserName_Key];
	
	if( (nil==team) || (nil==datakey) || (nil==user) || ([team length]==0) ||
		([datakey length]==0) || ([user length]==0) )
		return FALSE;
		
	NS_DURING
	
	// The call and its params
	XMLRPCCall* rpcCall = [[XMLRPCCall alloc] initWithURLString: SLIFETEAMS_XMLRPC_URL];
	NSArray* params = nil;
	
	// Set the method name
	[rpcCall setMethodName: SLIFETEAMS_FETCHTEAMACTIVITIES_METHODNAME];
	
	// -------------------------- Set parameters ---------------------------------
	
	// Set the parameters. It's an array. Order matters.
	params = [NSArray arrayWithObjects: 
		team, 
		datakey, 
		user,
		nil];
		
	[rpcCall setParameters: params];
	
	// Make the XML-RPC Call
	[rpcCall invokeInNewThread: self callbackSelector: @selector(fetchTeamActivitiesCallback:)];
	
	// ----------------------------- Debug ------------------------------------------
	
	if(m_debugState)
	{
		NSLog(@"Slife: Fetching team activities");
	}
	
	// -------------------------------------------------------------------------------
	
	NS_HANDLER
	
	NSLog(@"Slife: Exception in fetchTeamActivitiesCallback: %@", localException);
	
	NS_ENDHANDLER
	
	// Success
	return TRUE;

}

// **********************************************************************
//
//							validateTeamsAccount
//
// **********************************************************************
- (BOOL) validateTeamsAccount
{	
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
	
	NSString* team = [defaults objectForKey: k_Pref_TeamsTeamName_Key];
	NSString* datakey = [defaults objectForKey: k_Pref_TeamsTeamKey_Key];
	NSString* user = [defaults objectForKey: k_Pref_TeamsUserName_Key];
	
	if( (nil==team) || (nil==datakey) || (nil==user) || ([team length]==0) ||
		([datakey length]==0) || ([user length]==0) )
		return FALSE;
		
	NS_DURING
	
	// The call and its params
	XMLRPCCall* rpcCall = [[XMLRPCCall alloc] initWithURLString: SLIFETEAMS_XMLRPC_URL];
	NSArray* params = nil;
	
	// Set the method name
	[rpcCall setMethodName: SLIFETEAMS_VALIDATEACCOUNT_METHODNAME];
	
	// -------------------------- Set parameters ---------------------------------
	
	// Set the parameters. It's an array. Order matters.
	params = [NSArray arrayWithObjects: 
		team, 
		datakey, 
		user,
		nil];
		
	[rpcCall setParameters: params];
	
	// Make the XML-RPC Call
	[rpcCall invokeInNewThread: self callbackSelector: @selector(validateTeamsAccountCallback:)];
	
	// ----------------------------- Debug ------------------------------------------
	
	if(m_debugState)
	{
		NSLog(@"Slife: Validating account for Teams");
	}
	
	// -------------------------------------------------------------------------------
	
	NS_HANDLER
	
	NSLog(@"Slife: Exception in validateTeamsAccount: %@", localException);
	
	NS_ENDHANDLER
	
	// Success
	return TRUE;

}

// **********************************************************************
//							logGoalsToRewards
// **********************************************************************
- (void) logGoalsToRewards: (NSArray*) goalsArray
{
	// Sanity check
	if((nil==goalsArray) || ([goalsArray count]==0))
		return;
	
	NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
	
	// The account info
	NSString* username = [defaults objectForKey: k_Pref_RewardsUsername_Key];
	NSString* password = [SLNetworkController getMD5ForString: [defaults objectForKey: k_Pref_RewardsPassword_Key]];
	
	NS_DURING
	
	// The call and its params
	XMLRPCCall* rpcCall = [[XMLRPCCall alloc] initWithURLString: SLIFEREWARDS_XMLRPC_URL];
	NSArray* params = nil;
	
	// Set the method name
	[rpcCall setMethodName: SLIFEREWARDS_LOGGOALS_METHODNAME];
	
	// -------------------------- Set parameters ---------------------------------
	
	// Set the parameters. It's an array. Order matters.
	params = [NSArray arrayWithObjects: 
			  username, 
			  password, 
			  goalsArray,
			  @"mac", 
			  nil];
	
	[rpcCall setParameters: params];
	
	// Make the XML-RPC Call
	[rpcCall invokeInNewThread: self callbackSelector: @selector (logGoalsCallback:)];
	
	// ----------------------------- Debug ------------------------------------------
	
	if(m_debugState)
	{
		NSLog(@"Slife: Logging goals to Rewards");
	}
	
	// -------------------------------------------------------------------------------
	
	NS_HANDLER
	
	NSLog(@"Slife: Exception in logGoalsToRewards: %@", localException);
	
	NS_ENDHANDLER
}

// **********************************************************************
//
//							validateRewardsAccount
//
// **********************************************************************
- (BOOL) validateRewardsAccount
{	
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
	
	// The account info
	NSString* username = [defaults objectForKey: k_Pref_RewardsUsername_Key];
	NSString* password = [SLNetworkController getMD5ForString: [defaults objectForKey: k_Pref_RewardsPassword_Key]];
	
	if( (nil==username) || (nil==password) || ([username length]==0) || ([password length]==0))
		return FALSE;
	
	NS_DURING
	
	// The call and its params
	XMLRPCCall* rpcCall = [[XMLRPCCall alloc] initWithURLString: SLIFEREWARDS_XMLRPC_URL];
	NSArray* params = nil;
	
	// Set the method name
	[rpcCall setMethodName: SLIFEREWARDS_VALIDATEACCOUNT_METHODNAME];
	
	// -------------------------- Set parameters ---------------------------------
	
	// Set the parameters. It's an array. Order matters.
	params = [NSArray arrayWithObjects: 
			  username, 
			  password,
			  nil];
	
	[rpcCall setParameters: params];
	
	// Make the XML-RPC Call
	[rpcCall invokeInNewThread: self callbackSelector: @selector(validateRewardsAccountCallback:)];
	
	// ----------------------------- Debug ------------------------------------------
	
	if(m_debugState)
	{
		NSLog(@"Slife: Validating account for Rewards");
	}
	
	// -------------------------------------------------------------------------------
	
	NS_HANDLER
	
	NSLog(@"Slife: Exception in validateRewardsAccount: %@", localException);
	
	NS_ENDHANDLER
	
	// Success
	return TRUE;
	
}

#pragma mark -

// **********************************************************************
//
//							 Callbacks
//
// **********************************************************************

// **********************************************************************
//							logEventActionCallback
// **********************************************************************
- (void) logEventActionCallback: (id) rpcCall 
{	
	// This is called when the XML-RPC request has completed and a
	// response has been returned.
	
	// Sanity checks
	if(rpcCall==nil)
		return;
		
	// ----------------------------- Debug ------------------------------------------
	
	if(m_debugState)
	{
		NSLog (@"Slife: XML-RPC request text: %@", [rpcCall requestText]);
		NSLog (@"Slife: XML-RPC response text: %@", [rpcCall responseText]);
	}
	
	// -------------------------------------------------------------------------------
	
	// If there's an error, report it
	if (![rpcCall succeeded]) 
	{
		NSString* errorMessage = [self getCallError: rpcCall];
		
		if(m_debugState && (errorMessage!=nil))
			NSLog(@"Slife: Error in logActivityCallback: %@", errorMessage);
		else
			NSLog(@"Slife: Error in logActivityCallback: no more details available");
	}
}

// **********************************************************************
//							logNoteCallback
// **********************************************************************
- (void) logNoteCallback: (id) rpcCall 
{	
	// This is called when the XML-RPC request has completed and a
	// response has been returned.
	
	// Sanity checks
	if(rpcCall==nil)
		return;
	
	// ----------------------------- Debug ------------------------------------------
	
	if(m_debugState)
	{
		NSLog (@"Slife: XML-RPC request text: %@", [rpcCall requestText]);
		NSLog (@"Slife: XML-RPC response text: %@", [rpcCall responseText]);
	}
	
	// -------------------------------------------------------------------------------
	
	// If there's an error, report it
	if (![rpcCall succeeded]) 
	{
		NSString* errorMessage = [self getCallError: rpcCall];
		
		if(m_debugState && (errorMessage!=nil))
			NSLog(@"Slife: Error in logNoteCallback: %@", errorMessage);
		else
			NSLog(@"Slife: Error in logNoteCallback: no more details available");
	}
}


// **********************************************************************
//							fetchTeamActivitiesCallback
// **********************************************************************
- (void) fetchTeamActivitiesCallback: (id) rpcCall
{
	NSArray* result = [NSArray array];
	
	// This is called when the XML-RPC request has completed and a
	// response has been returned.
	
	// Sanity checks
	if(rpcCall==nil)
		return;
	
	// ----------------------------- Debug ------------------------------------------
	
	if(m_debugState)
	{
		NSLog (@"Slife: XML-RPC request text: %@", [rpcCall requestText]);
		NSLog (@"Slife: XML-RPC response text: %@", [rpcCall responseText]);
	}
	
	// If there's an error, report it
	if (![rpcCall succeeded]) 
	{
		NSString* errorMessage = [self getCallError: rpcCall];
		
		if(m_debugState && (errorMessage!=nil))
			NSLog(@"Slife: Error in fetchTeamActivitiesCallback: %@", errorMessage);
		else
			NSLog(@"Slife: Error in fetchTeamActivitiesCallback: no more details available");
	}
	else
	{
		result = (NSArray*) [rpcCall returnedObject];
	}
	
	// ----------------------------- Notification ------------------------------------
	
	[[NSNotificationCenter defaultCenter] postNotificationName: @"fetchTeamActivitiesResult" object: result];
}


// **********************************************************************
//							validateTeamsAccountCallback
// **********************************************************************
- (void) validateTeamsAccountCallback: (id) rpcCall
{
	NSString* result = @"Could not validate Teams account";
	
	// This is called when the XML-RPC request has completed and a
	// response has been returned.
	
	// Sanity checks
	if(rpcCall==nil)
		return;
	
	// ----------------------------- Debug ------------------------------------------
	
	if(m_debugState)
	{
		NSLog (@"Slife: XML-RPC request text: %@", [rpcCall requestText]);
		NSLog (@"Slife: XML-RPC response text: %@", [rpcCall responseText]);
	}
	
	// If there's an error, report it
	if (![rpcCall succeeded]) 
	{
		NSString* errorMessage = [self getCallError: rpcCall];
		
		if(m_debugState && (errorMessage!=nil))
			NSLog(@"Slife: Error in teamsAccountVerifyCallback: %@", errorMessage);
		else
			NSLog(@"Slife: Error in teamsAccountVerifyCallback: no more details available");
	}
	else
	{
		result = [rpcCall returnedObject];
	}
	
	// ----------------------------- Notification ------------------------------------
	
	[[NSNotificationCenter defaultCenter] postNotificationName: @"teamAccountVerificationResult" object: result];
}

// **********************************************************************
//							logGoalsCallback
// **********************************************************************
- (void) logGoalsCallback: (id) rpcCall 
{	
	// This is called when the XML-RPC request has completed and a
	// response has been returned.
	
	// Sanity checks
	if(rpcCall==nil)
		return;
	
	// ----------------------------- Debug ------------------------------------------
	
	if(m_debugState)
	{
		NSLog (@"Slife: XML-RPC request text: %@", [rpcCall requestText]);
		NSLog (@"Slife: XML-RPC response text: %@", [rpcCall responseText]);
	}
	
	// -------------------------------------------------------------------------------
	
	// If there's an error, report it
	if (![rpcCall succeeded]) 
	{
		NSString* errorMessage = [self getCallError: rpcCall];
		
		if(m_debugState && (errorMessage!=nil))
			NSLog(@"Slife: Error in logGoalsCallback: %@", errorMessage);
		else
			NSLog(@"Slife: Error in logGoalsCallback: no more details available");
	}
}

// **********************************************************************
//							validateRewardsAccountCallback
// **********************************************************************
- (void) validateRewardsAccountCallback: (id) rpcCall
{
	NSString* result = @"Could not validate Rewards account";
	
	// This is called when the XML-RPC request has completed and a
	// response has been returned.
	
	// Sanity checks
	if(rpcCall==nil)
		return;
	
	// ----------------------------- Debug ------------------------------------------
	
	if(m_debugState)
	{
		NSLog (@"Slife: XML-RPC request text: %@", [rpcCall requestText]);
		NSLog (@"Slife: XML-RPC response text: %@", [rpcCall responseText]);
	}
	
	// If there's an error, report it
	if (![rpcCall succeeded]) 
	{
		NSString* errorMessage = [self getCallError: rpcCall];
		
		if(m_debugState && (errorMessage!=nil))
			NSLog(@"Slife: Error in validateRewardsAccountCallback: %@", errorMessage);
		else
			NSLog(@"Slife: Error in validateRewardsAccountCallback: no more details available");
	}
	else
	{
		result = [rpcCall returnedObject];
	}
	
	// ----------------------------- Notification ------------------------------------
	
	[[NSNotificationCenter defaultCenter] postNotificationName: @"rewardsAccountVerificationResult" object: result];
}

#pragma mark -

// **********************************************************************
//
//							 Utilities
//
// **********************************************************************

// **********************************************************************
//							getCallError
// **********************************************************************
- (NSString*) getCallError: (id) rpcCall 
{
	// Figure out what kind of error happened
	
	NSString* title = nil;
	NSString* message = nil;
	
	// Sanity checks
	if(rpcCall==nil)
		return @"RPC call got lost";
		
	// -------------- Download Error ----------------
	
	if ([rpcCall isDownloadError]) 
	{
		int statusCode = [rpcCall statusCode];
		BOOL noData = [rpcCall isNoDataError];

		title = @"Download Error";
		
		if (noData) /*200 response but no data*/
			message = @"The server returned no response.";
		else
			message = [NSString stringWithFormat:
				@"The server returned an unexpected response code: %i.", statusCode];		
	} 
	
	// -------------- Parse Error ----------------
	
	else if ([rpcCall isParseError]) 
	{
		title = [rpcCall parseErrorTitle];
		message = [rpcCall parseErrorMessage];
	} 
	
	// -------------- Fault ----------------
	
	else if ([rpcCall isFault]) 
	{
		title = @"XML-RPC Fault";
		
		message = [NSString stringWithFormat:
			@"Fault code: %i\nFault message: %@", [rpcCall faultCode],
			[rpcCall faultString]];	
	}
	
	if( (title==nil) || (message==nil) )
		return nil;
	
	// Compose the error message and return it
	
	NSString* errorMessage = [[[NSString alloc] initWithFormat: @"%@ - %@", title, message] autorelease];
	
	return errorMessage;
} 

@end
