
//  Slife
//
//  Created by Edison Thomaz
//  Copyright 2007-2008 Slife Labs, LLC. All rights reserved.
//

#import <SSCrypto/SSCrypto.h>
#import "SLRegistrationController.h"

// **********************************************************************
//
//								Constants
//
// **********************************************************************


// ***************************** License ********************************

// Registration keys
extern NSString* k_License_Name_Key;
extern NSString* k_License_Email_Key;
extern NSString* k_License_Code_Key;

// Registration key constants
extern NSString* k_License_Name_Constant;
extern NSString* k_License_Email_Constant;
extern NSString* k_License_Code_Constant;

extern NSString* k_LicenseDialogMessageText;
extern NSString* k_LicenseDialogInformativeText;
extern NSString* k_LicenseDialogFirstButtonText;
extern NSString* k_LicenseDialogSecondButtonText;
extern NSString* k_LicenseDialogThirdButtonText;

extern NSString* k_SlifeMainURL;
extern NSString* k_SlifePurchaseURL;
extern NSString* k_SlifePurchaseInfoURL;

// **********************************************************************
//
//				 SLRegistrationController (Private) Interface
//
// **********************************************************************

@interface SLRegistrationController (Private)

// Load/Save license
- (void) loadLicense;
- (void) saveLicense;
- (void) resetLicense;

@end

@implementation SLRegistrationController

// **********************************************************************
//
//					Initialization and Termination
//
// **********************************************************************

// **********************************************************************
//								init
// **********************************************************************
- (id) init
{
	// Call super
	[super init];
	
	// Make the license dictionary nil at first
	m_licenseDictionary = nil;
	
	// Load license if valid
	[self loadLicense];
	
	return self;
}

// **********************************************************************
//							dealloc
// **********************************************************************
- (void) dealloc
{	
	// Release the license dictionary
	[m_licenseDictionary release];
	
    // Call dealloc in parent class
    [super dealloc];
}

#pragma mark -

// **********************************************************************
//
//							License Checks
//
// **********************************************************************

// **********************************************************************
//						licenseValid
// **********************************************************************
- (NSDictionary*) licenseValid
{	
	// Load the license and see what it is
	[self loadLicense];
	
	// There might not be a license dictionary at all
	if(nil==m_licenseDictionary)
		return nil;
		
	// Maybe there are no elements in the license
	if([m_licenseDictionary count]==0)
		return nil;
		
	// Get the elements out of the license dictionary
	NSString* name = [m_licenseDictionary objectForKey: k_License_Name_Constant];
	NSString* email = [m_licenseDictionary objectForKey: k_License_Email_Constant];
	NSString* code = [m_licenseDictionary objectForKey: k_License_Code_Constant];
	
	// Sanity checks
	if( (nil==name) || (nil==email) || (nil==code) )
		return nil;

	// Sanity checks
	if( ([name length]==0) || ([email length]==0) || ([code length]==0) )
		return nil;

	// Do the check
	return m_licenseDictionary;
}

// **********************************************************************
//					validateLicenseDictionaryWithName
// **********************************************************************
- (NSDictionary*) validateLicenseDictionaryWithName:(NSString*) name andEmail: (NSString*) email andKey: (NSString*) inKey
{	
	// Sanity checks
	if( (nil==name) || (nil==email) || (nil==inKey) )
		return nil;

	// Sanity checks
	if( ([name length]==0) || ([email length]==0) || ([inKey length]==0) )
		return nil;
	
	// Create local string
	NSMutableString* localString = [NSMutableString stringWithCapacity: 5];
	[localString appendString: name];
	[localString appendString: email];
	[localString appendString: [NSString stringWithFormat:@"%d", [name length]*5]];
	[localString appendString: k_SlifeMainURL];
	[localString appendString: [NSString stringWithFormat:@"%d", [email length]*2]];
	
	// Make the local key
	SSCrypto* crypto = [[SSCrypto alloc] init];
	[crypto setClearTextWithString: localString];
	
	NSString* localKeyLong = [[crypto digest:@"MD5"] hexval];
	
	[crypto release];
	
	// Get only part of it
	NSString* localKey = [localKeyLong substringWithRange: NSMakeRange(0, 24)];
	
	// Break remaining part even further
	NSString* localKeyPart1 = [localKey substringWithRange: NSMakeRange(0, 4)];
	NSString* localKeyPart2 = [localKey substringWithRange: NSMakeRange(4, 4)];
	NSString* localKeyPart3 = [localKey substringWithRange: NSMakeRange(8, 4)];
	NSString* localKeyPart4 = [localKey substringWithRange: NSMakeRange(12, 4)];
	NSString* localKeyPart5 = [localKey substringWithRange: NSMakeRange(16, 4)];
	NSString* localKeyPart6 = [localKey substringWithRange: NSMakeRange(20, 4)];

	// Build up final key
	NSMutableString* finalKey = [NSMutableString stringWithCapacity: 5];
	[finalKey appendString: localKeyPart1];
	[finalKey appendString: @"-"];
	[finalKey appendString: localKeyPart2];
	[finalKey appendString: @"-"];
	[finalKey appendString: localKeyPart3];
	[finalKey appendString: @"-"];
	[finalKey appendString: localKeyPart4];
	[finalKey appendString: @"-"];
	[finalKey appendString: localKeyPart5];
	[finalKey appendString: @"-"];
	[finalKey appendString: localKeyPart6];
	
	// Uppercase final key and incoming code
	NSString* finalKeyUppercase = [finalKey uppercaseString];
	NSString* inKeyUppercase = [inKey uppercaseString];
	
	// If they are the same, it's a valid key
	if([finalKeyUppercase isEqualToString: inKeyUppercase])
	{
		// Allocate a license dictionary if one is not available
		if(nil==m_licenseDictionary)
			m_licenseDictionary = [[NSMutableDictionary alloc] initWithCapacity: 3];
			
		// Fill the license dictionary
		[m_licenseDictionary setObject: name forKey: k_License_Name_Constant];
		[m_licenseDictionary setObject: email forKey: k_License_Email_Constant];
		[m_licenseDictionary setObject: finalKeyUppercase forKey: k_License_Code_Constant];
		
		// Save the license
		[self saveLicense];
	}
	else
	{
		// License is not valid. Nuke the dictionary
		[m_licenseDictionary release];
		m_licenseDictionary = nil;
		
		// Reset the license on prefs as well
		[self resetLicense];
	}
	
	// Return the license dictionary.
	return m_licenseDictionary;
}

#pragma mark -

// **********************************************************************
//
//						License Persistence
//
// **********************************************************************

// **********************************************************************
//							loadLicense
// **********************************************************************
- (void) loadLicense
{
	// Get the defaults
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
		
	NSString* name = [defaults objectForKey: k_License_Name_Key];
	NSString* email = [defaults objectForKey: k_License_Email_Key];
	NSString* code = [defaults objectForKey: k_License_Code_Key];
	
	// Sanity checks
	if( (nil==name) || (nil==email) || (nil==code) )
		return;

	// Sanity checks
	if( ([name length]==0) || ([email length]==0) || ([code length]==0) )
		return;
		
	// Try to validate license
	[self validateLicenseDictionaryWithName: name andEmail: email andKey: code];
}

// **********************************************************************
//							saveLicense
// **********************************************************************
- (void) saveLicense
{
	// Get the defaults
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
	
	// Save the license dictionary
	if(m_licenseDictionary && [m_licenseDictionary count]>0)
	{
		[defaults setObject: [m_licenseDictionary objectForKey: k_License_Name_Constant] forKey: k_License_Name_Key];
		[defaults setObject: [m_licenseDictionary objectForKey: k_License_Email_Constant] forKey: k_License_Email_Key];
		[defaults setObject: [m_licenseDictionary objectForKey: k_License_Code_Constant] forKey: k_License_Code_Key];
	}
}

// **********************************************************************
//							resetLicense
// **********************************************************************
- (void) resetLicense
{
	// Get the defaults
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
	
	// Reset the defaults
	[defaults setObject: @"" forKey: k_License_Name_Key];
	[defaults setObject: @"" forKey: k_License_Email_Key];
	[defaults setObject: @"" forKey: k_License_Code_Key];
}

#pragma mark -

// **********************************************************************
//
//							License Sheet
//
// **********************************************************************

// **********************************************************************
//							showTrialOverDialog
// **********************************************************************
- (void) showTrialOverDialog
{
	// Show the license dialog
	NSAlert* alert = [[NSAlert alloc] init];
	[alert addButtonWithTitle: k_LicenseDialogFirstButtonText];
	[alert addButtonWithTitle: k_LicenseDialogSecondButtonText];
	[alert addButtonWithTitle: k_LicenseDialogThirdButtonText];
	[alert setMessageText: k_LicenseDialogMessageText];
	[alert setInformativeText: k_LicenseDialogInformativeText];
	[alert setAlertStyle: NSWarningAlertStyle];
	
	int buttonResult = [alert runModal];
	
	if(buttonResult == NSAlertFirstButtonReturn) 
	{
		// Do nothing - user just pressed OK
	}
	
	else if(buttonResult == NSAlertSecondButtonReturn) 
	{
		// Go to Slife purchase info page
		[[NSWorkspace  sharedWorkspace] openURL:[NSURL URLWithString: k_SlifePurchaseInfoURL]];
	} 
	
	else if(buttonResult == NSAlertThirdButtonReturn) 
	{
		// Go to Slife purchase page
		[[NSWorkspace  sharedWorkspace] openURL:[NSURL URLWithString: k_SlifePurchaseURL]];
	} 
	
	[alert release];
}

@end
