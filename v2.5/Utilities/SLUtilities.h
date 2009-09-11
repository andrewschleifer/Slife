
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


@interface SLUtilities : NSObject 

// Process
+ (BOOL) isAppInFront: (NSString*) name;
+ (BOOL) areWeInFront;
+ (BOOL) isAppRunning: (NSString*) name;
+ (NSString*) frontMostApp;
+ (NSString*) frontMostAppPath;

// Login Launch
+ (BOOL) addApplicationToLoginLaunchList;
+ (BOOL) removeApplicationFromLoginLaunchList;

// Icon Image
+ (NSImage*) getIconImageForApplication: (NSString*) applicationName;
+ (BOOL) isApplicationAvailable: (NSString*) applicationName;

// Drawing
+ (void) addRoundedRectToPath: (CGContextRef) context andRect: (CGRect) rect 
	andOvalWidth: (float) ovalWidth andOvalHeight: (float) ovalHeight;
	
+ (void) fillRoundedRect: (NSGraphicsContext*) context andRect: (CGRect) rect 
	andOvalWidth: (float) ovalWidth andOvalHeight: (float) ovalHeight;

// Key Code
+ (NSNumber*) keyCodeOfString: (NSString*) str;

// Scripting
+ (NSArray*) executeApplescript: (NSAppleScript*) scriptObject;

// String
+ (NSString*) convertSecondsToTimeString: (int) valueInSeconds withRounding: (BOOL) doRound;
+ (NSString*) removeLoadingPrefixFromWebPageTitle: (NSString*) theTitle;
+ (NSString *) limitString: (NSString*) theString toNumberOfCharacters: (int) numberOfCharacters;
+ (NSString*) extractSourceFromString: (NSString*) inString;
+ (NSString*) trimWhiteSpace: (NSString*) inString;

@end
