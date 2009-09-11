
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

#import "SLUtilities.h"
#import "UKLoginItemRegistry.h"

// **********************************************************************
//						KeyCode Maps
// **********************************************************************

typedef struct {
    NSString*		character;
    unsigned short	keyCode;
} _KeyCode;

static _KeyCode	_keyCodes[] = {
    {@"0", 0x1D}, {@"1", 0x12}, {@"2", 0x13}, {@"3", 0x14}, 
    {@"4", 0x15}, {@"5", 0x17}, {@"6", 0x16}, {@"7", 0x1A}, 
    {@"8", 0x1C}, {@"9", 0x19}, {@"A", 0x00}, {@"B", 0x0B}, 
    {@"C", 0x08}, {@"D", 0x02}, {@"E", 0x0E}, {@"F", 0x03}, 
    {@"G", 0x05}, {@"H", 0x04}, {@"I", 0x22}, {@"J", 0x26}, 
    {@"K", 0x28}, {@"L", 0x25}, {@"M", 0x2E}, {@"N", 0x2D}, 
    {@"O", 0x1F}, {@"P", 0x23}, {@"Q", 0x0C}, {@"R", 0x0F}, 
    {@"S", 0x01}, {@"T", 0x11}, {@"U", 0x20}, {@"V", 0x09}, 
    {@"W", 0x0D}, {@"X", 0x07}, {@"Y", 0x10}, {@"Z", 0x06},
};

static int	_numOfKeyCodes = sizeof(_keyCodes) / sizeof(_KeyCode);
static NSMutableDictionary*	_keyCodeMap;

@implementation SLUtilities

#pragma mark ---- Process & Files -----

// **********************************************************************
//
//						Process Management
//
// **********************************************************************

// **********************************************************************
//						areWeInFront
// **********************************************************************
+ (BOOL) areWeInFront
{	
	// Get our name
    NSString* ourName = [[NSProcessInfo processInfo] processName];
	
	// Sanity check
	if(ourName==nil)
		return NO;
	
	// Get the app in front
	NSString* appFront = [SLUtilities frontMostApp];
	
	// Sanity check
	if(nil==appFront)
		return NO;
		
   // Check if it's the one we want to know
    if([appFront isEqualToString: ourName])
		return YES;
	
	return NO;
}

// **********************************************************************
//							isAppInFront
// **********************************************************************
+ (BOOL) isAppInFront: (NSString*) name
{	
	// Sanity check
	if(name==nil)
		return NO;
    
	// Get the app in front
	NSString* appFront = [SLUtilities frontMostApp];
	
	// Sanity check
	if(nil==appFront)
		return NO;
		
    // Check if it's the one we want to know
    if([appFront isEqualToString: name])
		return YES;
	
	return NO;
}

// **********************************************************************
//							isAppRunning
// **********************************************************************
+ (BOOL) isAppRunning: (NSString*) name
{		
	// Sanity check
	if(name==nil)
		return FALSE;
	
    // Get all running apps
    NSArray* runningAppsArray = [[NSWorkspace sharedWorkspace] launchedApplications];
	
	// Sanity check
	if(runningAppsArray==nil)
		return FALSE;
	
    // Iterate and examine running apps
    for(NSDictionary *appDictionary in runningAppsArray)
    {
        // Get the info dictionary for each structure
        NSString* appName = [appDictionary objectForKey: @"NSApplicationName"];
        
        // Check if it's the one passed as 'name'
        if([appName isEqualToString: name])
        {
			return YES;
		}
    }
	
	return NO;
}

// **********************************************************************
//						frontMostApp
// **********************************************************************
+ (NSString*) frontMostApp
{	
	// Get the active application name
    NSDictionary* activeAppDict = [[NSWorkspace sharedWorkspace] activeApplication];
    NSString* activeAppName = [activeAppDict objectForKey: @"NSApplicationName"];

	return activeAppName;
}

// **********************************************************************
//						frontMostAppPath
// **********************************************************************
+ (NSString*) frontMostAppPath
{	
	// Get the active application name
    NSDictionary* activeAppDict = [[NSWorkspace sharedWorkspace] activeApplication];
    NSString* activeAppPath = [activeAppDict objectForKey: @"NSApplicationPath"];

	return activeAppPath;
}

// **********************************************************************
//						isApplicationAvailable
// **********************************************************************
+ (BOOL) isApplicationAvailable: (NSString*) applicationName
{
	// Sanity check
	if(nil==applicationName)
		return FALSE;
		
	// Get the path for app
	NSString* appPath = [[NSWorkspace sharedWorkspace] fullPathForApplication: applicationName];
	
	// Return result
	if(nil==appPath)
		return FALSE;
	else
		return TRUE;
}

#pragma mark ---- Scripting -----

// **********************************************************************
//							arrayFromDescriptor
// **********************************************************************
+ (NSArray*) arrayFromDescriptor:(NSAppleEventDescriptor*) descriptor 
{
    // This method converts a event descriptor into an array
    
    NSMutableArray* returnArray = [[NSMutableArray alloc] initWithCapacity: 5];
	
	// If there is no descriptor, just leave
	if(nil==descriptor)
		return returnArray;
	
    int counter;
    int count = [descriptor numberOfItems];
    
    for(counter = 1; counter <= count; counter++) 
    {
        NSAppleEventDescriptor* desc = [descriptor descriptorAtIndex:counter];
		
        if (nil != [desc descriptorAtIndex:1]) 
        {
            [returnArray addObject: [self arrayFromDescriptor:desc]];
        } 
        else 
        {
            NSString *stringValue = [[descriptor descriptorAtIndex:counter] stringValue];
            
            if (nil != stringValue) 
            {
                [returnArray addObject:stringValue];
            } 
            else
            {
                [returnArray addObject: @""];
            }
        }
    }
    
    return (NSArray*) [returnArray autorelease];
}

// **********************************************************************
//						executeApplescript
// **********************************************************************
+ (NSArray*) executeApplescript: (NSAppleScript*) scriptObject
{
	// The result array
	NSArray* scriptResultsArray = nil;
	
	// If no script object
	if(nil==scriptObject)
		return scriptResultsArray;
		
	// Create the script descriptor
	NSDictionary* errorDict = nil;
    NSAppleEventDescriptor* scriptDescriptor = [scriptObject executeAndReturnError: &errorDict];
	
	// If no script descriptor object
	if(nil==scriptDescriptor)
		return scriptResultsArray;
	
    // Convert results descriptor into an array
    scriptResultsArray = [self arrayFromDescriptor: scriptDescriptor];
    
    // Release
    [scriptObject release];

    // Return the result array
    return scriptResultsArray;
}


#pragma mark ---- Login ----

// **********************************************************************
//
//						Login Launch
//
// **********************************************************************

// **********************************************************************
//						addApplicationToLoginLaunchList
// **********************************************************************
+ (BOOL) addApplicationToLoginLaunchList
{
	// Get the main bundle path and add login item
	NSBundle* bundle = [NSBundle mainBundle];
	
	return [UKLoginItemRegistry addLoginItemWithPath: [bundle bundlePath] hideIt: FALSE];
}

// **********************************************************************
//						removeApplicationFromLoginLaunchList
// **********************************************************************
+ (BOOL) removeApplicationFromLoginLaunchList
{
	// Get the main bundle path and remove login item
	NSBundle* bundle = [NSBundle mainBundle];

	return [UKLoginItemRegistry removeLoginItemWithPath: [bundle bundlePath]];
}


#pragma mark ----- Drawing -----

// **********************************************************************
//
//								Icon
//
// **********************************************************************

// **********************************************************************
//						getIconImageForApplication
// **********************************************************************
+ (NSImage*) getIconImageForApplication: (NSString*) applicationName
{
	// Get the path for app
	NSString* appPath = [[NSWorkspace sharedWorkspace] fullPathForApplication: @"Slife"];
	NSImage* theImage = [[NSWorkspace sharedWorkspace] iconForFile: appPath];
	
	// Sanity check
	if( (nil==applicationName) || ([applicationName length]==0) )
		return [[theImage retain] autorelease];
	
	
	// See if it's any of the Adobe apps
	NSRange photoshopRange = [applicationName rangeOfString: @"Photoshop"];
	NSRange illustratorRange = [applicationName rangeOfString: @"Illustrator"];
	NSRange afterEffectsRange = [applicationName rangeOfString: @"After Effects"];
	NSRange fireworksRange = [applicationName rangeOfString: @"Fireworks"];
	NSRange flashVideoEncoderRange = [applicationName rangeOfString: @"Flash Video Encoder"];
	NSRange goLiveRange = [applicationName rangeOfString: @"GoLive"];
	NSRange inDesignRange = [applicationName rangeOfString: @"InDesign"];
	NSRange imageReadyRange = [applicationName rangeOfString: @"ImageReady"];
	
	// See if it's any of the Microsoft apps
	NSRange entourageRange = [applicationName rangeOfString: @"Entourage"];
	NSRange wordRange = [applicationName rangeOfString: @"Word"];
	NSRange excelRange = [applicationName rangeOfString: @"Excel"];
	NSRange powerPointRange = [applicationName rangeOfString: @"PowerPoint"];
	
	// Photoshop
	if(photoshopRange.location!=NSNotFound)
	{
		if([self isApplicationAvailable: @"Adobe Photoshop"])
			applicationName = @"Adobe Photoshop";
		else if([self isApplicationAvailable: @"Adobe Photoshop CS"])
			applicationName = @"Adobe Photoshop CS";
		else if([self isApplicationAvailable: @"Adobe Photoshop CS2"])
			applicationName = @"Adobe Photoshop CS2";
		else if([self isApplicationAvailable: @"Adobe Photoshop CS3"])
			applicationName = @"Adobe Photoshop CS3";
	}
	
	// Illustrator
	else if(illustratorRange.location!=NSNotFound)
	{
		NSRange cs3Range = [applicationName rangeOfString: @"CS3"];
		if(cs3Range.location!=NSNotFound)
		{
			applicationName = @"Adobe Illustrator";
		}
		else
		{
			applicationName = @"Illustrator CS";
		}
	}
	
	// After Effects
	else if(afterEffectsRange.location!=NSNotFound)
	{
		if([self isApplicationAvailable: @"Adobe After Effects CS3"])
			applicationName = @"Adobe After Effects CS3";
		else if([self isApplicationAvailable: @"Adobe After Effects CS2"])
			applicationName = @"Adobe After Effects CS2";
		else if([self isApplicationAvailable: @"Adobe After Effects CS"])
			applicationName = @"Adobe After Effects CS";
		else if([self isApplicationAvailable: @"Adobe After Effects"])
			applicationName = @"Adobe After Effects";
	}
	
	// Fireworks
	else if(fireworksRange.location!=NSNotFound)
	{
		if([self isApplicationAvailable: @"Adobe Fireworks CS3"])
			applicationName = @"Adobe Fireworks CS3";
		else if([self isApplicationAvailable: @"Adobe Fireworks CS2"])
			applicationName = @"Adobe Fireworks CS2";
		else if([self isApplicationAvailable: @"Adobe Fireworks CS"])
			applicationName = @"Adobe Fireworks CS";
		else if([self isApplicationAvailable: @"Adobe Fireworks"])
			applicationName = @"Adobe Fireworks";
	}
	
	// Flash Video Encoder
	else if(flashVideoEncoderRange.location!=NSNotFound)
	{
		if([self isApplicationAvailable: @"Adobe Flash CS3 Video Encoder"])
			applicationName = @"Adobe Flash CS3 Video Encoder";
		else if([self isApplicationAvailable: @"Adobe Flash CS2 Video Encoder"])
			applicationName = @"Adobe Flash CS2 Video Encoder";
		else if([self isApplicationAvailable: @"Adobe Flash CS Video Encoder"])
			applicationName = @"Adobe Flash CS Video Encoder";
		else if([self isApplicationAvailable: @"Adobe Flash Video Encoder"])
			applicationName = @"Adobe Flash Video Encoder";
	}
	
	// GoLive
	else if(goLiveRange.location!=NSNotFound)
	{
		if([self isApplicationAvailable: @"Adobe GoLive 9"])
			applicationName = @"Adobe GoLive 9";
		else if([self isApplicationAvailable: @"Adobe GoLive 8"])
			applicationName = @"Adobe GoLive 8";
	}	
	
	// InDesign
	else if(inDesignRange.location!=NSNotFound)
	{
		if([self isApplicationAvailable: @"Adobe InDesign CS3"])
			applicationName = @"Adobe InDesign CS3";
		else if([self isApplicationAvailable: @"Adobe InDesign CS2"])
			applicationName = @"Adobe InDesign CS2";
		else if([self isApplicationAvailable: @"Adobe InDesign CS"])
			applicationName = @"Adobe InDesign CS";
		else if([self isApplicationAvailable: @"Adobe InDesign"])
			applicationName = @"Adobe InDesign";
	}
	
	// ImageReady
	else if(imageReadyRange.location!=NSNotFound)
	{
		applicationName = @"Adobe ImageReady CS";
	}	
	
	// MS Entourage
	else if(entourageRange.location!=NSNotFound)
	{
		applicationName = @"Microsoft Entourage";
	}
	
	// MS Word
	else if(wordRange.location!=NSNotFound)
	{
		applicationName = @"Microsoft Word";
	}
	
	// MS Excel
	else if(excelRange.location!=NSNotFound)
	{
		applicationName = @"Microsoft Excel";
	}
	
	// MS PowerPoint
	else if(powerPointRange.location!=NSNotFound)
	{
		applicationName = @"Microsoft PowerPoint";
	}
	
	// iWork Numbers
	if([applicationName isEqualToString: @"Numbers"])
		applicationName = @"Numbers.app";
	
	// Get the path for app
	appPath = [[NSWorkspace sharedWorkspace] fullPathForApplication: applicationName];
	
	// If there's no app, use the default image
	if(nil!=appPath)
		theImage = [[NSWorkspace sharedWorkspace] iconForFile: appPath];
		
	// Return the image
	return [[theImage retain] autorelease];
}

// **********************************************************************
//						addRoundedRectToPath
// **********************************************************************
+ (void) addRoundedRectToPath: (CGContextRef) context andRect: (CGRect) rect 
	andOvalWidth: (float) ovalWidth andOvalHeight: (float) ovalHeight
{
	  float fw, fh;
	  if (ovalWidth == 0 || ovalHeight == 0)
	  {
		CGContextAddRect(context, rect);
		return;
	  }

	  CGContextSaveGState(context);
	  CGContextTranslateCTM (context, CGRectGetMinX(rect), CGRectGetMinY(rect));
	  CGContextScaleCTM (context, ovalWidth, ovalHeight);
	  fw = CGRectGetWidth (rect) / ovalWidth;
	  fh = CGRectGetHeight (rect) / ovalHeight;
	  CGContextMoveToPoint(context, fw, fh/2);
	  CGContextAddArcToPoint(context, fw, fh, fw/2, fh, 1);
	  CGContextAddArcToPoint(context, 0, fh, 0, fh/2, 1);
	  CGContextAddArcToPoint(context, 0, 0, fw/2, 0, 1);
	  CGContextAddArcToPoint(context, fw, 0, fw, fh/2, 1);
	  CGContextClosePath(context);
	  CGContextRestoreGState(context);
}

// **********************************************************************
//						fillRoundedRect
// **********************************************************************
+ (void) fillRoundedRect: (NSGraphicsContext*) context andRect: (CGRect) rect 
	andOvalWidth: (float) ovalWidth andOvalHeight: (float) ovalHeight

{
	CGContextRef cgContext = [context graphicsPort];

	CGContextBeginPath(cgContext);
	[SLUtilities addRoundedRectToPath: cgContext andRect: rect andOvalWidth: ovalWidth andOvalHeight: ovalHeight];
	CGContextFillPath(cgContext);
}

#pragma mark ----- String -----

// **********************************************************************
//					convertSecondsToTimeString
// **********************************************************************
+ (NSString*) convertSecondsToTimeString: (int) valueInSeconds withRounding: (BOOL) doRound
{
	// Sanity check
	if(valueInSeconds==0)
		return @"";
		
	NSString* timeString = nil;
	
	int minutes = valueInSeconds / 60;
	int seconds = valueInSeconds % 60;
	int hours = minutes / 60;
	minutes = minutes % 60;
	
	if(doRound)
	{
		if( (hours>0) && (minutes>0) && (seconds>0) )
			timeString = [NSString stringWithFormat: @"%d %@ %d %@", hours, (hours>1) ? @"hrs" : @"hr", minutes, (minutes>1) ? @"mins" : @"min"];
		else if( (hours>0) && (minutes>0) && (seconds==0) )
			timeString = [NSString stringWithFormat: @"%d %@ %d %@", hours, (hours>1) ? @"hrs" : @"hr", minutes, (minutes>1) ? @"mins" : @"min"];
		else if( (hours>0) && (minutes==0) && (seconds>0) )
			timeString = [NSString stringWithFormat: @"%d %@", hours, (hours>1) ? @"hrs" : @"hr"];
		else if( (hours>0) && (minutes==0) && (seconds==0) )
			timeString = [NSString stringWithFormat: @"%d %@", hours, (hours>1) ? @"hrs" : @"hr"];
		else if( (hours==0) && (minutes>0) && (seconds>0) )
			timeString = [NSString stringWithFormat: @"%d %@", minutes, (minutes>1) ? @"mins" : @"min"];
		else if( (hours==0) && (minutes>0) && (seconds==0) )
			timeString = [NSString stringWithFormat: @"%d %@", minutes, (minutes>1) ? @"mins" : @"min"];
		else if( (hours==0) && (minutes==0) && (seconds>0) )
			timeString = [NSString stringWithFormat: @"%d %@", seconds, (seconds>1) ? @"secs" : @"sec"];
		else if( (hours==0) && (minutes==0) && (seconds==0) )
			timeString = @"";
		else
			timeString = @"";
	}
	else
	{
		if( (hours>0) && (minutes>0) && (seconds>0) )
			timeString = [NSString stringWithFormat: @"%d %@ %d %@ %d %@", hours, (hours>1) ? @"hrs" : @"hr", minutes, (minutes>1) ? @"mins" : @"min", seconds, (seconds>1) ? @"secs" : @"sec"];
		else if( (hours>0) && (minutes>0) && (seconds==0) )
			timeString = [NSString stringWithFormat: @"%d %@ %d %@", hours, (hours>1) ? @"hrs" : @"hr", minutes, (minutes>1) ? @"mins" : @"min"];
		else if( (hours>0) && (minutes==0) && (seconds>0) )
			timeString = [NSString stringWithFormat: @"%d %@ %d %@", hours, (hours>1) ? @"hrs" : @"hr", seconds, (seconds>1) ? @"secs" : @"sec"];
		else if( (hours>0) && (minutes==0) && (seconds==0) )
			timeString = [NSString stringWithFormat: @"%d %@", hours, (hours>1) ? @"hrs" : @"hr"];
		else if( (hours==0) && (minutes>0) && (seconds>0) )
			timeString = [NSString stringWithFormat: @"%d %@ %d %@", minutes, (minutes>1) ? @"mins" : @"min", seconds, (seconds>1) ? @"secs" : @"sec"];
		else if( (hours==0) && (minutes>0) && (seconds==0) )
			timeString = [NSString stringWithFormat: @"%d %@", minutes, (minutes>1) ? @"mins" : @"min"];
		else if( (hours==0) && (minutes==0) && (seconds>0) )
			timeString = [NSString stringWithFormat: @"%d %@", seconds, (seconds>1) ? @"secs" : @"sec"];
		else if( (hours==0) && (minutes==0) && (seconds==0) )
			timeString = @"";
		else
			timeString = @"";
	}
	
	return [[timeString retain] autorelease];
}

// **********************************************************************
//                  trimWhiteSpace
// **********************************************************************
+ (NSString*) trimWhiteSpace: (NSString*) inString
{
	if( (nil==inString) || ([inString length]==0) )
		return inString;
		
	return [inString stringByTrimmingCharactersInSet: 
		[NSCharacterSet whitespaceCharacterSet]];
}

// **********************************************************************
//                  extractSourceFromString
// **********************************************************************
+ (NSString*) extractSourceFromString: (NSString*) inString
{
	if( (nil==inString) || ([inString length]==0) )
		return inString;
	
	NSArray* stringElements = [inString componentsSeparatedByString:@"-"];
	
	int shortestSegment = -1;
	int shortestSegmentValue = 1000;
	
	int counter=0;
	for(counter=0; counter<[stringElements count]; counter++)
	{
		if([[stringElements objectAtIndex: counter] length]<shortestSegmentValue)
		{
			shortestSegmentValue = [[stringElements objectAtIndex: counter] length];
			shortestSegment = counter;
		}
	}
	
	return [SLUtilities trimWhiteSpace: [stringElements objectAtIndex: shortestSegment]];
}

// **********************************************************************
//                  removeLoadingPrefixFromWebPageTitle
// **********************************************************************
+ (NSString*) removeLoadingPrefixFromWebPageTitle: (NSString*) theTitle
{
	if( (nil==theTitle) || ([theTitle length]==0) )
		return theTitle;
	
	NSRange loadingPrefixRange = [theTitle rangeOfString: @"Loading"];
	
	if(loadingPrefixRange.location!=NSNotFound)
	{
		NSRange rangeForTitle;
		rangeForTitle.location = 9;
		rangeForTitle.length = [theTitle length] - 10;
		
		NSString* titleWithoutPrefix = [theTitle substringWithRange: rangeForTitle];
		
		if(nil!=titleWithoutPrefix)
			return titleWithoutPrefix;
		else
			return theTitle;
	}
	else
		return theTitle;
}

// **********************************************************************
//                  limitStringToNumberOfCharacters
// **********************************************************************
+ (NSString *) limitString: (NSString*) theString toNumberOfCharacters: (int) numberOfCharacters
{
	if( (nil==theString) || ([theString length]==0) )
		return theString;

    int len = [theString length];
    
    if(len <= numberOfCharacters)
    {
        return theString;
    }
    else
    {
        NSMutableString* s = [NSMutableString stringWithCapacity: numberOfCharacters+3];
        NSString* range = [theString substringWithRange: NSMakeRange (0, numberOfCharacters-1)];
        
        [s appendString: range];
        [s appendString: @"..."];
        
        return (NSString *) [[s copy] autorelease];
    }
}

// **********************************************************************
//                     keyCodeOfString
// **********************************************************************
+ (NSNumber*) keyCodeOfString: (NSString*) str
{
    if (!_keyCodeMap) 
	{
        int	i;
        
        // Make key code map
        _keyCodeMap = [[NSMutableDictionary dictionary] retain];
        
        for (i = 0; i < _numOfKeyCodes; i++) {
            [_keyCodeMap setObject:[NSNumber numberWithUnsignedShort:_keyCodes[i].keyCode] 
                            forKey:_keyCodes[i].character];
        }
    }
    
    return [_keyCodeMap objectForKey:str];
}

@end
