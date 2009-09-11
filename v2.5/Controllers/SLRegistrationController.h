
//  Slife
//
//  Created by Edison Thomaz
//  Copyright 2007-2008 Slife Labs, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface SLRegistrationController : NSObject
{
	// The license dictionary
	NSMutableDictionary*	m_licenseDictionary;
}

// Validate license
- (NSDictionary*) licenseValid;
- (NSDictionary*) validateLicenseDictionaryWithName:(NSString*) name andEmail: (NSString*) email andKey: (NSString*) inKey;

// Trial over dialog
- (void) showTrialOverDialog;

@end