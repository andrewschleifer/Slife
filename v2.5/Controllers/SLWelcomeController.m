//
//  Slife
//
//  Created by Edison Thomaz
//  Copyright 2007-2008 Slife Labs, LLC. All rights reserved.
//

#import "SLWelcomeController.h"


// **********************************************************************
//							Constants
// **********************************************************************

// Slife URLs
extern NSString* k_SlifeGuideURL;
extern NSString* k_SlifeTeamsURL;

@implementation SLWelcomeController

// **********************************************************************
//								init
// **********************************************************************
- (id) init
{
	if(self = [super initWithWindowNibName: @"Welcome"])
    {
        // Set the name of the key for the defaults database for the window
        [self setWindowFrameAutosaveName:@"WelcomeGuideWindow"];
	}
    
    return self;
}

// **********************************************************************
//							awakeFromNib
// **********************************************************************
- (void) awakeFromNib
{
	[m_mainViewPlaceholder addSubview: m_tutorialView];
}

// **********************************************************************
//							resetViews
// **********************************************************************
- (void) resetViews
{
	// Show accessibility view if assistive devices feature is not enabled 
	if(!AXAPIEnabled())
	{
		[m_mainViewPlaceholder replaceSubview:  [[m_mainViewPlaceholder subviews] lastObject] with: m_accessibilityView];
	}
	else
	{
		[m_mainViewPlaceholder replaceSubview:  [[m_mainViewPlaceholder subviews] lastObject] with: m_tutorialView];
	}
}

// **********************************************************************
//						showPreferencesButtonClicked
// **********************************************************************
- (IBAction) showPreferencesButtonClicked: (id) sender
{
	[[NSWorkspace sharedWorkspace] openFile: @"/System/Library/PreferencePanes/UniversalAccessPref.prefPane"];
}

// **********************************************************************
//						goToTutorialButtonClicked
// **********************************************************************
- (IBAction) goToTutorialButtonClicked: (id) sender
{
	[[self window] orderOut: self];
}

// **********************************************************************
//					slifeTeamsLearnMoreButtonClicked
// **********************************************************************
- (IBAction) slifeTeamsLearnMoreButtonClicked: (id) sender
{
	NSString* linkString = k_SlifeTeamsURL;
	[[NSWorkspace sharedWorkspace] openURL: [NSURL URLWithString: linkString]];
}

// **********************************************************************
//						slifeLearnMoreButtonClicked
// **********************************************************************
- (IBAction) slifeLearnMoreButtonClicked: (id) sender
{
	NSString* linkString = k_SlifeGuideURL;
	[[NSWorkspace sharedWorkspace] openURL: [NSURL URLWithString: linkString]];
}

// **********************************************************************
//						closeButtonClicked
// **********************************************************************
- (IBAction) closeButtonClicked: (id) sender
{
	// Show accessibility view if assistive devices feature is not enabled 
	if(!AXAPIEnabled())
	{
		[m_mainViewPlaceholder replaceSubview: m_tutorialView with: m_accessibilityView];
	}
	else
	{
		[[self window] orderOut: self];
	}
}

@end
