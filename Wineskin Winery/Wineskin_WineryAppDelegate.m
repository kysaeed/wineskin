//
//  Wineskin_WineryAppDelegate.m
//  Wineskin Winery
//
//  Copyright 2011-2013 by The Wineskin Project and Urge Software LLC All rights reserved.
//  Licensed for use under the LGPL <http://www.gnu.org/licenses/lgpl-2.1.txt>
//

#import "Wineskin_WineryAppDelegate.h"

#define WINESKINE_JAPANESE

@implementation Wineskin_WineryAppDelegate

@synthesize window;

// Private feilds
bool _isNoMasterWrapperInstalled = YES;



// Comparator to replace @selector(localizedStandardCompare:) missing in 10.5
static NSInteger localizedComparator(id a, id b, void* context)
{
	NSInteger compareOptions = NSCaseInsensitiveSearch|NSNumericSearch;
	
	return [(NSString*)a compare:b options:compareOptions range:NSMakeRange(0, [a length]) locale:nil]; // nil = current locale
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	/*
	//Beta Alert
	NSAlert *alert = [[NSAlert alloc] init];
	[alert addButtonWithTitle:@"Ok, I got it!"];
	[alert setMessageText:@"BETA warning"];
	[alert setInformativeText:@"This build of Wineskin Winery is a Beta, and only downloading Beta files.\nThere are no manually installed versions of Engines and Wrappers during Beta\n\nWineskin 2.5 wrapper and WS8 engines are also still in Beta and SUBJECT TO CHANGE\n\nIt will INTERACT WITH YOUR REAL FILES and stuff from the current Release Version\n\nIf you convert your WS7 to WS8, it will convert them, and if you try to use non-Beta Wineskin Winery with Wineskin 2.4, WS8 engines will not work.\n\nWS7 and older engines WILL NOT WORK with Wineskin 2.5!\n\nYou may be best off waiting until beta is over to convert, unless you want to just test the function.\n\nIf you get a Wineskin Winery Update that no longer displays this Beta message, you will know Beta is over!\n\n Please report any problems to the News posting about this, or to the Wineskin Support Forums!"];
	[alert setAlertStyle:NSInformationalAlertStyle];
	[alert runModal];
	[alert release];
	 */
	
	SInt32 OSXversionMajor, OSXversionMinor;
	if(Gestalt(gestaltSystemVersionMajor, &OSXversionMajor) == noErr && Gestalt(gestaltSystemVersionMinor, &OSXversionMinor) == noErr)
	{
		if(OSXversionMajor == 10 && OSXversionMinor <= 5) // display warning about 10.5 no longer being supported.
		{
			NSAlert *alert = [[NSAlert alloc] init];
			[alert addButtonWithTitle:NSLocalizedString(@"MAC_OS_VERSION_WARNING_OK", @"Ok, I got it!")];
			[alert setMessageText:NSLocalizedString(@"MAC_OS_VERSION_WARNING_TITLE", @"Mac OS X 10.5 Warning")];
			[alert setInformativeText:NSLocalizedString(@"MAC_OS_VERSION_WARNING_TEXT", @"Wineskin no longer supports Mac OS X 10.5!\n\nYou may want to upgrade your OS!\n\nIf you want to use Wineskin Winery on 10.5 you can, but the built in downloads will get 10.6+ compatible files.\n\nTo use this on 10.5, you must get Manual Download files and only use Wineskin 2.5.3 - 2.5.4 and WS8 based engines.\n\nWineskin 2.5.5+ and WS9 engines are Mac OS X 10.6+ only!")];
			[alert setAlertStyle:NSInformationalAlertStyle];
			[alert runModal];
			[alert release];
		}
	}
	srand(time(NULL));
	[waitWheel startAnimation:self];
	[busyWindow makeKeyAndOrderFront:self];
	[self refreshButtonPressed:self];
	[self checkForUpdates];
	[self runConverter];
}
- (void)runConverter
{
	//check wrapper version is 2.5+, if not then exit
	int numToCheckMajor = [[[self getCurrentWrapperVersion] substringWithRange:NSMakeRange(9,1)] intValue];
	int numToCheckMinor = [[[self getCurrentWrapperVersion] substringWithRange:NSMakeRange(11,1)] intValue];
	if (numToCheckMajor < 3 && numToCheckMinor < 5) return;
	//check if any engines are WS5 - WS7, if not then exit
	NSMutableArray *enginesToConvert = [NSMutableArray arrayWithCapacity:1];
	for (NSString *item in installedEnginesList)
		if (([[item substringWithRange:NSMakeRange(0,3)] isEqualToString:@"WS5"]) || ([[item substringWithRange:NSMakeRange(0,3)] isEqualToString:@"WS6"]) || ([[item substringWithRange:NSMakeRange(0,3)] isEqualToString:@"WS7"]))
			if (![item isEqualToString:@"WS7Wine1.2.2ICE"]) [enginesToConvert addObject:item];
	if ([enginesToConvert count] < 1) return;
	//offer to convert all engines to WS8
	NSAlert *alert = [[NSAlert alloc] init];
	[alert addButtonWithTitle:NSLocalizedString(@"ENGINE_CONVERT_OK", @"Convert!")];
	[alert addButtonWithTitle:NSLocalizedString(@"ENGINE_CONVERT_CANCEL", @"Not Now")];
	[alert setMessageText:NSLocalizedString(@"ENGINE_CONVERT_TITLE", @"Convert Older Engines?")];
	[alert setInformativeText:NSLocalizedString(@"ENGINE_CONVERT_TEXT", @"Wineskin 2.5+ will only use WS8+ engines.\nYou have some WS5/WS6/WS7 engines installed.\n\nWould you like to convert these into WS8 Engines?\n(this could take a while if you have many)")];
	[alert setAlertStyle:NSInformationalAlertStyle];
	if ([alert runModal] != NSAlertFirstButtonReturn)
	{
		[alert release];
		return;
	}
    [alert release];
	//if convert, do convert	
	[busyWindow makeKeyAndOrderFront:self];
	[window orderOut:self];
	NSFileManager *fm = [NSFileManager defaultManager];
	for (NSString *item in enginesToConvert)
	{
		//remove extra left over junk that might mess things up
		[fm removeItemAtPath:[NSString stringWithFormat:@"%@/Library/Application Support/Wineskin/Engines/%@.tar",NSHomeDirectory(),item] error:nil];
		[fm removeItemAtPath:[NSString stringWithFormat:@"%@/Library/Application Support/Wineskin/Engines/WS8%@.tar",NSHomeDirectory(),[item substringFromIndex:3]] error:nil];
		[fm removeItemAtPath:[NSString stringWithFormat:@"%@/Library/Application Support/Wineskin/Engines/wswine.bundle",NSHomeDirectory()] error:nil];
		[fm removeItemAtPath:[NSString stringWithFormat:@"%@/Library/Application Support/Wineskin/Engines/WineskinEngine.bundle",NSHomeDirectory()] error:nil];
		//decompress engine
		system([[NSString stringWithFormat:@"\"%@/Library/Application Support/Wineskin/7za\" x \"%@/Library/Application Support/Wineskin/Engines/%@.tar.7z\" \"-o/%@/Library/Application Support/Wineskin/Engines\"", NSHomeDirectory(),NSHomeDirectory(),item,NSHomeDirectory()] UTF8String]);
		system([[NSString stringWithFormat:@"/usr/bin/tar -C \"%@/Library/Application Support/Wineskin/Engines\" -xf \"%@/Library/Application Support/Wineskin/Engines/%@.tar\"",NSHomeDirectory(),NSHomeDirectory(),item] UTF8String]);
		//remove tar
		[fm removeItemAtPath:[NSString stringWithFormat:@"%@/Library/Application Support/Wineskin/Engines/%@.tar",NSHomeDirectory(),item] error:nil];
		//trash X11 folder
		[fm removeItemAtPath:[NSString stringWithFormat:@"%@/Library/Application Support/Wineskin/Engines/WineskinEngine.bundle/X11",NSHomeDirectory()] error:nil];
		//make wswine.bundle
		[fm createDirectoryAtPath:[NSString stringWithFormat:@"%@/Library/Application Support/Wineskin/Engines/wswine.bundle",NSHomeDirectory()] withIntermediateDirectories:YES attributes:nil error:nil];
		//move contents of Wine to wswine.bundle
		[fm moveItemAtPath:[NSString stringWithFormat:@"%@/Library/Application Support/Wineskin/Engines/WineskinEngine.bundle/Wine/bin",NSHomeDirectory()] toPath:[NSString stringWithFormat:@"%@/Library/Application Support/Wineskin/Engines/wswine.bundle/bin",NSHomeDirectory()] error:nil];
		[fm moveItemAtPath:[NSString stringWithFormat:@"%@/Library/Application Support/Wineskin/Engines/WineskinEngine.bundle/Wine/lib",NSHomeDirectory()] toPath:[NSString stringWithFormat:@"%@/Library/Application Support/Wineskin/Engines/wswine.bundle/lib",NSHomeDirectory()] error:nil];
		[fm moveItemAtPath:[NSString stringWithFormat:@"%@/Library/Application Support/Wineskin/Engines/WineskinEngine.bundle/Wine/share",NSHomeDirectory()] toPath:[NSString stringWithFormat:@"%@/Library/Application Support/Wineskin/Engines/wswine.bundle/share",NSHomeDirectory()] error:nil];
		//put engine version in wswine.bundle
		system([[NSString stringWithFormat:@"echo \"WS8%@\" > \"%@/Library/Application Support/Wineskin/Engines/wswine.bundle/version\"",[item substringFromIndex:3],NSHomeDirectory()] UTF8String]);
		//trash WineskinEngine.bundle
		[fm removeItemAtPath:[NSString stringWithFormat:@"%@/Library/Application Support/Wineskin/Engines/WineskinEngine.bundle",NSHomeDirectory()] error:nil];
		//compress wswine.bundle to engine.tar.7z
		system([[NSString stringWithFormat:@"cd \"%@/Library/Application Support/Wineskin/Engines\";tar -cf WS8%@.tar wswine.bundle",NSHomeDirectory(),[item substringFromIndex:3]] UTF8String]);
		system([[NSString stringWithFormat:@"cd \"%@/Library/Application Support/Wineskin/Engines\";\"%@/Library/Application Support/Wineskin/7za\" a -mx9 WS8%@.tar.7z WS8%@.tar", NSHomeDirectory(),NSHomeDirectory(),[item substringFromIndex:3],[item substringFromIndex:3]] UTF8String]);
		//clean up engine junk now that its in a .tar.7z
		[fm removeItemAtPath:[NSString stringWithFormat:@"%@/Library/Application Support/Wineskin/Engines/WS8%@.tar",NSHomeDirectory(),[item substringFromIndex:3]] error:nil];
		[fm removeItemAtPath:[NSString stringWithFormat:@"%@/Library/Application Support/Wineskin/Engines/wswine.bundle",NSHomeDirectory()] error:nil];
		//trash the old engine
		[fm removeItemAtPath:[NSString stringWithFormat:@"%@/Library/Application Support/Wineskin/Engines/%@.tar.7z",NSHomeDirectory(),item] error:nil];
	}
	[window makeKeyAndOrderFront:self];
	[busyWindow orderOut:self];
	[self refreshButtonPressed:self];
}
- (IBAction)aboutWindow:(id)sender
{
	NSDictionary* plistDictionary = [[NSDictionary alloc] initWithContentsOfFile:[NSString stringWithFormat:@"%@/Contents/Info.plist",[[NSBundle mainBundle] bundlePath]]];
	[aboutWindowVersionNumber setStringValue:[plistDictionary valueForKey:@"CFBundleVersion"]];
	[plistDictionary release];
	[aboutWindow makeKeyAndOrderFront:self];
}
- (IBAction)helpWindow:(id)sender
{
	[helpWindow makeKeyAndOrderFront:self];
}
- (void)makeFoldersAndFiles
{
	NSString *applicationPath = [[NSBundle mainBundle] bundlePath];
	NSFileManager *filemgr = [NSFileManager defaultManager];
	[filemgr createDirectoryAtPath:[NSHomeDirectory() stringByAppendingString:@"/Library/Application Support/Wineskin/Engines"] withIntermediateDirectories:YES attributes:nil error:nil];
#ifdef WINESKINE_JAPANESE
    [filemgr createDirectoryAtPath:[NSHomeDirectory() stringByAppendingString:@"/Library/Application Support/Wineskin/Wrapper-JP"] withIntermediateDirectories:YES attributes:nil error:nil];
    
#else
	[filemgr createDirectoryAtPath:[NSHomeDirectory() stringByAppendingString:@"/Library/Application Support/Wineskin/Wrapper"] withIntermediateDirectories:YES attributes:nil error:nil];
#endif
	[filemgr createDirectoryAtPath:[NSHomeDirectory() stringByAppendingString:@"/Library/Application Support/Wineskin/EngineBase"] withIntermediateDirectories:YES attributes:nil error:nil];
	[filemgr createDirectoryAtPath:[NSHomeDirectory() stringByAppendingString:@"/Applications/Wineskin"] withIntermediateDirectories:YES attributes:nil error:nil];
	if (!([filemgr fileExistsAtPath:[NSHomeDirectory() stringByAppendingString:@"/Library/Application Support/Wineskin/7za"]]))
		[filemgr copyItemAtPath:[applicationPath stringByAppendingString:@"/Contents/Resources/7za"] toPath:[NSHomeDirectory() stringByAppendingString:@"/Library/Application Support/Wineskin/7za"] error:nil];
    
#ifdef WINESKINE_JAPANESE
    [self getCurrentWrapperVersion];
    if (_isNoMasterWrapperInstalled) {
        //remove old one
        [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/Library/Application Support/Wineskin/Wrapper-JP",NSHomeDirectory()] error:nil];
        [filemgr createDirectoryAtPath:[NSHomeDirectory() stringByAppendingString:@"/Library/Application Support/Wineskin/Wrapper-JP"] withIntermediateDirectories:YES attributes:nil error:nil];

        //install default wrapper! (to "/Library/Application Support/Wineskin/Wrapper-JP")
        const NSString* defualtWrapperJpName = @"Wineskin-2.6.2-JP00"; //Default Wrapper for JP
        
        //uncompress
        system([[NSString stringWithFormat:@"\"%@/Library/Application Support/Wineskin/7za\" x \"%@/%@.app.tar.7z\" -o/tmp", NSHomeDirectory(),[applicationPath stringByAppendingString:@"/Contents/Resources"],defualtWrapperJpName] UTF8String]);
        system([[NSString stringWithFormat:@"/usr/bin/tar -C /tmp -xf /tmp/%@.app.tar",defualtWrapperJpName] UTF8String]);
        
        //move wrapper "/tmp" to "Application Support"
        [[NSFileManager defaultManager] moveItemAtPath:[NSString stringWithFormat:@"/tmp/%@.app",defualtWrapperJpName] toPath:[NSString stringWithFormat:@"%@/Library/Application Support/Wineskin/Wrapper-JP/%@.app",NSHomeDirectory(),defualtWrapperJpName] error:nil];
    }
#endif
}
- (void)checkForUpdates
{
#ifdef WINESKINE_JAPANESE
    // Japanse Version not support WineskinWinery.app update yet....
    [window makeKeyAndOrderFront:self];
    [busyWindow orderOut:self];
    return;
#else
	//get current version number
	NSString *currentVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
	//get latest available version number
	NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://wineskin.urgesoftware.com/Winery/NewestVersion.txt?%@",[[NSNumber numberWithLong:rand()] stringValue]]];
	NSString *newVersion = [NSString stringWithContentsOfURL:url encoding:NSUTF8StringEncoding error:nil];
	newVersion = [newVersion stringByReplacingOccurrencesOfString:@"\n" withString:@""]; //remove \n
	if (!([newVersion hasPrefix:@"Wineskin"]) || ([currentVersion isEqualToString:newVersion]))
	{
		[window makeKeyAndOrderFront:self];
		[busyWindow orderOut:self];
		return;
	}
	NSAlert *alert = [[NSAlert alloc] init];
	[alert addButtonWithTitle:NSLocalizedString(@"WINESKIN_UPDATE_OK", @"Do Update")];
	[alert addButtonWithTitle:NSLocalizedString(@"WINESKIN_UPDATE_CANCEL", @"Cancel")];
	[alert setMessageText:NSLocalizedString(@"WINESKIN_UPDATE_TITLE", @"Update Available!")];
	[alert setInformativeText:NSLocalizedString(@"WINESKIN_UPDATE_TEXT", @"An Update to Wineskin Winery is available, would you like to update now?")];
	[alert setAlertStyle:NSInformationalAlertStyle];
	if ([alert runModal] != NSAlertFirstButtonReturn)
	{
		//display warning about not updating.
		NSAlert *warning = [[NSAlert alloc] init];
		[warning addButtonWithTitle:NSLocalizedString(@"WINESKIN_NOT_UPDATING_WARNING_OK", @"OK")];
		[warning setMessageText:NSLocalizedString(@"WINESKIN_NOT_UPDATING_WARNING_TITLE", @"Warning!")];
		[warning setInformativeText:NSLocalizedString(@"WINESKIN_NOT_UPDATING_WARNING_TEXT", @"Some things may not function properly with new Wrappers or Engines until you update!")];
		[warning runModal];
		[warning release];
		[alert release];
		//bring main window up
		[window makeKeyAndOrderFront:self];
		[busyWindow orderOut:self];
		return;
	}
	[alert release];
	//try removing files that might already exist
	NSFileManager *fm = [NSFileManager defaultManager];
	[fm removeItemAtPath:@"/tmp/WineskinWinery.app.tar.7z" error:nil];
	[fm removeItemAtPath:@"/tmp/WineskinWinery.app.tar" error:nil];
	[fm removeItemAtPath:@"/tmp/WineskinWinery.app" error:nil];
	//update selected, download update
	[urlInput setStringValue:[NSString stringWithFormat:@"http://wineskin.urgesoftware.com/Winery/WineskinWinery.app.tar.7z?%@",[[NSNumber numberWithLong:rand()] stringValue]]];
	[urlOutput setStringValue:@"file:///tmp/WineskinWinery.app.tar.7z"];
	[fileName setStringValue:@"Wineskin Winery Update"]; // String but use like flag?
	[downloadingWindow makeKeyAndOrderFront:self];
	[window orderOut:self];
	[busyWindow orderOut:self];
#endif
}

- (IBAction)createNewBlankWrapperButtonPressed:(id)sender
{
	NSString *selectedEngine = [[NSString alloc] initWithString:[installedEnginesList objectAtIndex:[installedEngines selectedRow]]];
	[createWrapperEngine setStringValue:selectedEngine];
	[selectedEngine release];
	[createWrapperWindow makeKeyAndOrderFront:self];
	[window orderOut:self];
}

- (IBAction)refreshButtonPressed:(id)sender
{
	//make sure files and folders are created
	[self makeFoldersAndFiles];
	//set installed engines list
	[self getInstalledEngines:@""];
	[installedEngines setAllowsEmptySelection:NO];
	[installedEngines reloadData];
	//check if engine updates are available
	[self setEnginesAvailablePrompt];
	//set current wrapper version blank
	[wrapperVersion setStringValue:[self getCurrentWrapperVersion]];
	//check if wrapper update is available
	[self setWrapperAvailablePrompt];
	// make sure an engine and master wrapper are both installed first, or have CREATE button disabled!
	if (([installedEnginesList count] == 0) || (_isNoMasterWrapperInstalled))
    {
		[createWrapperButton setEnabled:NO];
        return;
    }
    
	//check wrapper version is 2.5+, if not then do not enable button
	int numToCheckMajor = [[[self getCurrentWrapperVersion] substringWithRange:NSMakeRange(9,1)] intValue];
	int numToCheckMinor = [[[self getCurrentWrapperVersion] substringWithRange:NSMakeRange(11,1)] intValue];
	if (numToCheckMajor < 3 && numToCheckMinor < 5)
    {
        [createWrapperButton setEnabled:NO];
    }
    else
    {
        [createWrapperButton setEnabled:YES];
    }
}

- (IBAction)downloadPackagesManuallyButtonPressed:(id)sender;
{
	NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://wineskin.urgesoftware.com/tiki-index.php?page=Downloads&%@",[[NSNumber numberWithLong:rand()] stringValue]]];
	[[NSWorkspace sharedWorkspace] openURL:url];
}

- (IBAction)plusButtonPressed:(id)sender
{
	[self showAvailableEngines:@""];
	//show the engines window
	[addEngineWindow makeKeyAndOrderFront:self];
	[window orderOut:self];
}
- (void)showAvailableEngines:(NSString *)theFilter
{
	//populate engines list in engines window
	[engineWindowEngineList removeAllItems];
	NSMutableArray *availableEngines = [self getAvailableEngines];
	NSMutableArray *testList = [NSMutableArray arrayWithCapacity:[availableEngines count]];
	for (NSString *itemAE in availableEngines)
	{
		BOOL matchFound=NO;
		for (NSString *itemIE in installedEnginesList)
		{
			if ([itemAE isEqualToString:itemIE])
			{
				matchFound=YES;
				break;
			}
		}
		if (!matchFound) [testList addObject:itemAE];
	}
	for (NSString *item in testList)
	{
		if ([theFilter isEqualToString:@""])
		{
			[engineWindowEngineList addItemWithTitle:item];
			continue;
		}
		else
		{
			if ([item rangeOfString:theFilter options:NSCaseInsensitiveSearch].location != NSNotFound)
				[engineWindowEngineList addItemWithTitle:item];
		}
	}
	if ([[engineWindowEngineList selectedItem] title] == nil)
	{
		[engineWindowDownloadAndInstallButton setEnabled:NO];
		[engineWindowViewWineReleaseNotesButton setEnabled:NO];
		[engineWindowDontPromptAsNewButton setEnabled:NO];
	}
	else
	{
		[engineWindowDontPromptAsNewButton setEnabled:YES];
		[engineWindowDownloadAndInstallButton setEnabled:YES];
		[engineWindowViewWineReleaseNotesButton setEnabled:YES];
		[self engineWindowEngineListChanged:self];
	}
	
}
- (IBAction)minusButtonPressed:(id)sender
{
	NSString *selectedEngine = [[NSString alloc] initWithString:[installedEnginesList objectAtIndex:[installedEngines selectedRow]]];
	NSAlert *alert = [[NSAlert alloc] init];
	[alert addButtonWithTitle:NSLocalizedString(@"DELETE_ENGINE_CONFIRM_OK", @"Yes")];
	[alert addButtonWithTitle:NSLocalizedString(@"DELETE_ENGINE_CONFIRM_CANCEL", @"Cancel")];
	[alert setMessageText:NSLocalizedString(@"DELETE_ENGINE_CONFIRM_TITLE", @"Confirm Deletion")];
	[alert setInformativeText:[NSString stringWithFormat:NSLocalizedString(@"DELETE_ENGINE_CONFIRM_TEXT", @"Are you sure you want to delete the engine \"%@\""),selectedEngine]];
	[alert setAlertStyle:NSInformationalAlertStyle];
	if ([alert runModal] != NSAlertFirstButtonReturn)
    {
        [selectedEngine release];
        [alert release];
        return;
    }
    [alert release];
	//move file to trash
	NSArray *filenamesArray = [NSArray arrayWithObject:[NSString stringWithFormat:@"%@.tar.7z",selectedEngine]];
	[[NSWorkspace sharedWorkspace] performFileOperation:NSWorkspaceRecycleOperation source:[NSString stringWithFormat:@"%@/Library/Application Support/Wineskin/Engines",NSHomeDirectory()] destination:@"" files:filenamesArray tag:nil];
	[self refreshButtonPressed:self];
	[selectedEngine release];
}

- (IBAction)updateButtonPressed:(id)sender
{
#ifdef WINESKINE_JAPANESE
    return;
#else
	//get latest available version number
	NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://wineskin.urgesoftware.com/Wrapper/NewestVersion.txt?%@",[[NSNumber numberWithLong:rand()] stringValue]]];
	NSString *newVersion = [NSString stringWithContentsOfURL:url encoding:NSUTF8StringEncoding error:nil];
	newVersion = [newVersion stringByReplacingOccurrencesOfString:@"\n" withString:@""]; //remove \n
	if (newVersion == nil || ![[newVersion substringToIndex:8] isEqualToString:@"Wineskin"])
	{
		NSAlert *alert = [[NSAlert alloc] init];
		[alert addButtonWithTitle:NSLocalizedString(@"WINESKIN_UPDATE_ERROR_OK", @"OK")];
		[alert setMessageText:NSLocalizedString(@"WINESKIN_UPDATE_ERROR_TITLE", @"Oops!")];
		[alert setInformativeText:NSLocalizedString(@"WINESKIN_UPDATE_ERROR_TEXT", @"Error, connection to download failed!")];
		[alert setAlertStyle:NSInformationalAlertStyle];
		[alert runModal];
		[alert release];
		return;
	}
	//download new wrapper to /tmp
	[urlInput setStringValue:[NSString stringWithFormat:@"http://wineskin.urgesoftware.com/Wrapper/%@.app.tar.7z?%@",newVersion,[[NSNumber numberWithLong:rand()] stringValue]]];
	[urlOutput setStringValue:[NSString stringWithFormat:@"file:///tmp/%@.app.tar.7z",newVersion]];
	[fileName setStringValue:newVersion];
	[fileNameDestination setStringValue:@"Wrapper"];
	[downloadingWindow makeKeyAndOrderFront:self];
	[window orderOut:self];
#endif
}

- (IBAction)wineskinWebsiteButtonPressed:(id)sender
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:[NSString stringWithFormat:@"http://wineskin.urgesoftware.com/?%@",[[NSNumber numberWithLong:rand()] stringValue]]]];
}

- (void)getInstalledEngines:(NSString *)theFilter
{
	//clear the array
	[installedEnginesList removeAllObjects];
	//get files in folder and put in array
	NSString *folder = [NSString stringWithFormat:@"%@/Library/Application Support/Wineskin/Engines",NSHomeDirectory()];
	NSFileManager *fm = [NSFileManager defaultManager];
	NSArray *filesTEMP = [[fm contentsOfDirectoryAtPath:folder error:nil] sortedArrayUsingFunction:localizedComparator context:nil];
	NSArray *files = [[filesTEMP reverseObjectEnumerator] allObjects];
	if ([theFilter isEqualToString:@""])
	{
		for(NSString *file in files) // standard first
			if ([file hasSuffix:@".tar.7z"] && (NSEqualRanges([file rangeOfString:@"CX"],NSMakeRange(NSNotFound, 0)))) [installedEnginesList addObject:[file stringByReplacingOccurrencesOfString:@".tar.7z" withString:@""]];
		for(NSString *file in files) // CX at end of list
			if ([file hasSuffix:@".tar.7z"] && !(NSEqualRanges([file rangeOfString:@"CX"],NSMakeRange(NSNotFound, 0)))) [installedEnginesList addObject:[file stringByReplacingOccurrencesOfString:@".tar.7z" withString:@""]];		
	}
	else
	{
		for(NSString *file in files) // standard first
			if ([file hasSuffix:@".tar.7z"] && (NSEqualRanges([file rangeOfString:@"CX"],NSMakeRange(NSNotFound, 0))) && ([file rangeOfString:theFilter options:NSCaseInsensitiveSearch].location != NSNotFound)) [installedEnginesList addObject:[file stringByReplacingOccurrencesOfString:@".tar.7z" withString:@""]];
		for(NSString *file in files) // CX at end of list
			if ([file hasSuffix:@".tar.7z"] && !(NSEqualRanges([file rangeOfString:@"CX"],NSMakeRange(NSNotFound, 0))) && ([file rangeOfString:theFilter options:NSCaseInsensitiveSearch].location != NSNotFound)) [installedEnginesList addObject:[file stringByReplacingOccurrencesOfString:@".tar.7z" withString:@""]];
	}
}

- (NSArray *)getEnginesToIgnore
{
	NSString *fileString = [NSString stringWithContentsOfFile:[NSString stringWithFormat:@"%@/Library/Application Support/Wineskin/IgnoredEngines.txt",NSHomeDirectory()] encoding:NSUTF8StringEncoding error:nil];
	if ([fileString hasSuffix:@"\n"])
	{
		fileString = [fileString stringByAppendingString:@":!:!:"];
		fileString = [fileString stringByReplacingOccurrencesOfString:@"\n:!:!:" withString:@""];
	}
	return [fileString componentsSeparatedByString:@"\n"];
}

- (NSMutableArray *)getAvailableEngines
{
	NSString *fileString = [NSString stringWithContentsOfURL:[NSURL URLWithString:[NSString stringWithFormat:@"http://wineskin.urgesoftware.com/Engines/EngineList.txt?%@",[[NSNumber numberWithLong:rand()] stringValue]]] encoding:NSUTF8StringEncoding error:nil];
	if ([fileString hasSuffix:@"\n"])
	{
		fileString = [fileString stringByAppendingString:@":!:!:"];
		fileString = [fileString stringByReplacingOccurrencesOfString:@"\n:!:!:" withString:@""];
	}
	NSArray *tempA = [fileString componentsSeparatedByString:@"\n"];
	NSMutableArray *tempMA = [NSMutableArray arrayWithCapacity:[tempA count]];
	for(NSString *item in tempA) [tempMA addObject:item];
	return tempMA;	
}

- (NSString *)getCurrentWrapperVersion
{
#ifdef WINESKINE_JAPANESE
    NSString *folder = [NSString stringWithFormat:@"%@/Library/Application Support/Wineskin/Wrapper-JP",NSHomeDirectory()];
    
#else
	NSString *folder = [NSString stringWithFormat:@"%@/Library/Application Support/Wineskin/Wrapper",NSHomeDirectory()];
#endif
	NSFileManager *fm = [NSFileManager defaultManager];
	NSArray *filesArray = [fm contentsOfDirectoryAtPath:folder error:nil];
	NSMutableArray *files = [NSMutableArray arrayWithCapacity:2];
	for(NSString *file in filesArray)
	{
		if (!([file isEqualToString:@".DS_Store"])) [files addObject:file];
	}
	
	if ([files count] < 1)
    {
        _isNoMasterWrapperInstalled = YES;
        return NSLocalizedString(@"CURRENT_WRAPPER_NOT_FOUND", @"No Wrapper Installed");
    }
    if ([files count] > 1)
    {
        // if Wrapper Folder is Crashed, No Wrapper....
        _isNoMasterWrapperInstalled = YES;
        return NSLocalizedString(@"CURRENT_WRAPPER_FOLDER_ERROR", @"Error In Wrapper Folder");
    }
    
	NSString *currentVersion = [files objectAtIndex:0];
	currentVersion = [currentVersion stringByReplacingOccurrencesOfString:@".app" withString:@""];
    _isNoMasterWrapperInstalled = NO; //Current Wrapper Detected!!
	return currentVersion;
}

- (void)setEnginesAvailablePrompt
{
	NSMutableArray *availableEngines = [self getAvailableEngines];
	NSArray *ignoredEngines = [self getEnginesToIgnore];
	NSMutableArray *testList = [NSMutableArray arrayWithCapacity:[availableEngines count]];
	for (NSString *itemAE in availableEngines)
	{
		BOOL matchFound=NO;
		for (NSString *itemIE in installedEnginesList)
		{
			if ([itemAE isEqualToString:itemIE])
			{
				matchFound=YES;
				break;
			}
		}
		if (!matchFound)
		{
			for (NSString *itemIE in ignoredEngines)
			{
				if ([itemAE isEqualToString:itemIE])
				{
					matchFound=YES;
					break;
				}
			}
		}
		if (!matchFound) [testList addObject:itemAE];
	}
	if ([testList count] > 0) [engineAvailableLabel setHidden:NO];
	else [engineAvailableLabel setHidden:YES];
}

- (void)setWrapperAvailablePrompt
{
#ifdef WINESKINE_JAPANESE
    // Japanse Version not support Wrapper update yet....
    [updateButton setEnabled:NO];
    [updateButton setHidden:YES];
    [updateAvailableLabel setHidden:YES];
    return;
#else
	//get latest available version number
	NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://wineskin.urgesoftware.com/Wrapper/NewestVersion.txt?%@",[[NSNumber numberWithLong:rand()] stringValue]]];
	NSString *newVersion = [NSString stringWithContentsOfURL:url encoding:NSUTF8StringEncoding error:nil];
	newVersion = [newVersion stringByReplacingOccurrencesOfString:@"\n" withString:@""]; //remove \n
	if (newVersion == nil || ![[newVersion substringToIndex:8] isEqualToString:@"Wineskin"]) return;
	//if different, prompt update available
	if ([[wrapperVersion stringValue] isEqualToString:newVersion])
	{
		[updateButton setEnabled:NO];
		[updateAvailableLabel setHidden:YES];
		return;
	}
	[updateButton setEnabled:YES];
	[updateAvailableLabel setHidden:NO];
#endif
}
- (IBAction)engineSearchFilter:(id)sender
{
	[self getInstalledEngines:[[sender stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
	[installedEngines reloadData];
}
- (IBAction)availEngineSearchFilter:(id)sender
{
	[self showAvailableEngines:[[sender stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
}

- (void)ds:(NSString *)input
{
	if (input == nil) input=@"nil";
	NSAlert *TESTER = [[NSAlert alloc] init];
	[TESTER addButtonWithTitle:@"close"];
	[TESTER setMessageText:@"Contents of string"];
	[TESTER setInformativeText:input];
	[TESTER setAlertStyle:NSInformationalAlertStyle];
	[TESTER runModal];
	[TESTER release];
}
//******************* engine build window *****************************
- (IBAction)engineBuildChooseButtonPressed:(id)sender
{
	NSOpenPanel *panel = [NSOpenPanel openPanel];
	[panel setTitle:NSLocalizedString(@"CHOOSE_WINE_SOURCE_TITLE", @"Choose Wine Source Folder")];
	[panel setPrompt:NSLocalizedString(@"CHOOSE_WINE_SOURCE_PROMPT", @"Choose")];
	[panel setCanChooseDirectories:YES];
	[panel setCanChooseFiles:NO];
	[panel setAllowsMultipleSelection:NO];
	int error = [panel runModal];
	if (error == 0) return;
	[engineBuildWineSource setStringValue:[[panel filenames] objectAtIndex:0]];
}
- (IBAction)engineBuildBuildButtonPressed:(id)sender
{
	if ([[engineBuildWineSource stringValue] isEqualToString:@""])
	{
		NSAlert *alert = [[NSAlert alloc] init];
		[alert addButtonWithTitle:NSLocalizedString(@"WINE_SOURCE_NOT_SPECIFY_OK", @"OK")];
		[alert setMessageText:NSLocalizedString(@"WINE_SOURCE_NOT_SPECIFY_TITLE", @"Oops!")];
		[alert setInformativeText:NSLocalizedString(@"WINE_SOURCE_NOT_SPECIFY_TEXT", @"You must select a folder with the Wine source code and a valid engine name")];
		[alert setAlertStyle:NSInformationalAlertStyle];
		[alert runModal];
		[alert release];
		return;
	}
	if ([[engineBuildEngineName stringValue] isEqualToString:@""])
	{
		NSAlert *alert = [[NSAlert alloc] init];
		[alert addButtonWithTitle:NSLocalizedString(@"WINE_ENGINE_NAME_NOT_SPECIFY_OK", @"OK")];
		[alert setMessageText:NSLocalizedString(@"WINE_ENGINE_NAME_NOT_SPECIFY_TITLE", @"Oops!")];
		[alert setInformativeText:NSLocalizedString(@"WINE_ENGINE_NAME_NOT_SPECIFY_TEXT", @"You must enter a name for the Engine")];
		[alert setAlertStyle:NSInformationalAlertStyle];
		[alert runModal];
		[alert release];
		return;
	}
	if ([[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@/Library/Application Support/Wineskin/Engines/%@.tar.7z",NSHomeDirectory(),[engineBuildEngineName stringValue]]])
	{
		NSAlert *alert = [[NSAlert alloc] init];
		[alert addButtonWithTitle:NSLocalizedString(@"WINE_ENGINE_NAME_ALREADY_USE_OK", @"OK")];
		[alert setMessageText:NSLocalizedString(@"WINE_ENGINE_NAME_ALREADY_USE_TITLE", @"Oops!")];
		[alert setInformativeText:NSLocalizedString(@"WINE_ENGINE_NAME_ALREADY_USE_TEXT", @"That engine name is already in use!")];
		[alert setAlertStyle:NSInformationalAlertStyle];
		[alert runModal];
		[alert release];
		return;
	}
	
	//write out the config file
	NSString *configFileContents = [NSString stringWithFormat:@"%@\n%@\n%@\n%@\n%@\n%@\n",[engineBuildWineSource stringValue],[engineBuildEngineName stringValue],[engineBuildConfigurationOptions stringValue],[engineBuildCurrentEngineBase stringValue],[NSString stringWithFormat:@"%@/Library/Application Support/Wineskin/7za", NSHomeDirectory()],[[engineBuildOSVersionToBuildEngineFor selectedItem] title]];
	[configFileContents writeToFile:[NSString stringWithFormat:@"%@/Library/Application Support/Wineskin/EngineBase/%@/config.txt",NSHomeDirectory(),[engineBuildCurrentEngineBase stringValue]] atomically:NO encoding:NSUTF8StringEncoding error:nil];
	//launch terminal with the script
	system([[NSString stringWithFormat:@"open -a Terminal.app \"%@/Library/Application Support/Wineskin/EngineBase/%@/WineskinEngineBuild\"", NSHomeDirectory(),[engineBuildCurrentEngineBase stringValue]] UTF8String]);
	//prompt user warning
	NSAlert *alert = [[NSAlert alloc] init];
	[alert addButtonWithTitle:NSLocalizedString(@"WINE_ENGINE_BUILD_PROMPT_OK", @"OK")];
	[alert setMessageText:NSLocalizedString(@"WINE_ENGINE_BUILD_PROMPT_TITLE", @"WARNING!")];
	[alert setInformativeText:NSLocalizedString(@"WINE_ENGINE_BUILD_PROMPT_TEXT", @"This build will fail if you use Wineskin Winery, Wineskin, or any Wineskin wrapper while it is running!!!")];
	[alert setAlertStyle:NSInformationalAlertStyle];
	[alert runModal];
	[alert release];
	//exit program
	[NSApp terminate:sender];
}
- (IBAction)engineBuildUpdateButtonPressed:(id)sender
{
	//get latest available version number
	NSString *newVersion = [self availableEngineBuildVersion];
	//download new wrapper to /tmp
	[urlInput setStringValue:[NSString stringWithFormat:@"http://wineskin.urgesoftware.com/EngineBase/%@.tar.7z?%@",newVersion,[[NSNumber numberWithLong:rand()] stringValue]]];
	[urlOutput setStringValue:[NSString stringWithFormat:@"file:///tmp/%@.tar.7z",newVersion]];
	[fileName setStringValue:newVersion];
	[fileNameDestination setStringValue:@"EngineBase"];
	[downloadingWindow makeKeyAndOrderFront:self];
	[wineskinEngineBuilderWindow orderOut:self];
}
- (IBAction)engineBuildCancelButtonPressed:(id)sender
{
	[window makeKeyAndOrderFront:self];
	[wineskinEngineBuilderWindow orderOut:self];
}
- (NSString *)currentEngineBuildVersion
{
	NSString *folder = [NSString stringWithFormat:@"%@/Library/Application Support/Wineskin/EngineBase",NSHomeDirectory()];
	NSFileManager *fm = [NSFileManager defaultManager];
	NSArray *filesArray = [fm contentsOfDirectoryAtPath:folder error:nil];
	NSMutableArray *files = [NSMutableArray arrayWithCapacity:2];
	for(NSString *file in filesArray)
		if (!([file isEqualToString:@".DS_Store"])) [files addObject:file];
	if ([files count] < 1)
	{
		[engineBuildBuildButton setEnabled:NO];
		return NSLocalizedString(@"WINE_ENGINE_BASE_NOT_FOUND", @"No Engine Base Installed");
	}
	if ([files count] > 1)
	{
		[engineBuildBuildButton setEnabled:NO];
		return NSLocalizedString(@"WINE_ENGINE_BASE_FOLDER_ERROR", @"Error In Engine Base Folder");
	}
	[engineBuildBuildButton setEnabled:YES];
	NSString *currentVersion = [files objectAtIndex:0];
	return currentVersion;
}
- (NSString *)availableEngineBuildVersion
{
	NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://wineskin.urgesoftware.com/EngineBase/NewestVersion.txt?%@",[[NSNumber numberWithLong:rand()] stringValue]]];
	NSString *newVersion = [NSString stringWithContentsOfURL:url encoding:NSUTF8StringEncoding error:nil];
	newVersion = [newVersion stringByReplacingOccurrencesOfString:@"\n" withString:@""]; //remove \n
	if (newVersion == nil || ![newVersion hasSuffix:@"EngineBase"]) return @"ERROR";
	return newVersion;
}

//************ Engine Window (+ button) methods *******************
- (IBAction)engineWindowDownloadAndInstallButtonPressed:(id)sender
{
	[urlInput setStringValue:[NSString stringWithFormat:@"http://wineskin.urgesoftware.com/Engines/%@.tar.7z?%@",[[engineWindowEngineList selectedItem] title],[[NSNumber numberWithLong:rand()] stringValue]]];
	[urlOutput setStringValue:[NSString stringWithFormat:@"file:///tmp/%@.tar.7z",[[engineWindowEngineList selectedItem] title]]];
	[fileName setStringValue:[[engineWindowEngineList selectedItem] title]];
	[fileNameDestination setStringValue:@"Engines"];
	[downloadingWindow makeKeyAndOrderFront:self];
	[addEngineWindow orderOut:self];
}
- (IBAction)engineWindowViewWineReleaseNotesButtonPressed:(id)sender
{
	NSArray *tempArray = [[[engineWindowEngineList selectedItem] title] componentsSeparatedByString:@"Wine"];
	NSString *wineVersion = [tempArray objectAtIndex:1];
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:[NSString stringWithFormat:@"http://www.winehq.org/announce/%@",wineVersion]]];
}
- (IBAction)engineWindowEngineListChanged:(id)sender
{
	NSArray *ignoredEngines = [self getEnginesToIgnore];
	BOOL matchFound=NO;
	for (NSString *item in ignoredEngines)
		if ([item isEqualToString:[[engineWindowEngineList selectedItem] title]]) matchFound=YES;
	if (matchFound) [engineWindowDontPromptAsNewButton setEnabled:NO];
	else [engineWindowDontPromptAsNewButton setEnabled:YES];
	NSArray *tempArray = [[[engineWindowEngineList selectedItem] title] componentsSeparatedByString:@"Wine"];
	NSString *wineVersion = [tempArray objectAtIndex:1];
	if ([wineVersion hasPrefix:@"C"]) [engineWindowViewWineReleaseNotesButton setEnabled:NO];
	else [engineWindowViewWineReleaseNotesButton setEnabled:YES];
}
- (IBAction)engineWindowDontPromptAsNewButtonPressed:(id)sender
{
	//read current ignore list into string
	NSArray *ignoredEngines = [self getEnginesToIgnore];
	NSString *ignoredEnginesString = @"";
	for (NSString *item in ignoredEngines)
		ignoredEnginesString = [ignoredEnginesString stringByAppendingString:[item stringByAppendingString:@"\n"]];
	ignoredEnginesString = [NSString stringWithFormat:@"%@\n%@",ignoredEnginesString,[[engineWindowEngineList selectedItem] title]];
	//write engine to ignored engines text file
	[ignoredEnginesString writeToFile:[NSHomeDirectory() stringByAppendingString:@"/Library/Application Support/Wineskin/IgnoredEngines.txt"] atomically:YES encoding:NSUTF8StringEncoding error:nil];
	//disable prompt button
	[engineWindowDontPromptAsNewButton setEnabled:NO];
	
}
- (IBAction)engineWindowDontPromptAllEnginesAsNewButtonPressed:(id)sender
{
	NSArray *ignoredEngines = [self getEnginesToIgnore];
	NSMutableArray *availableEngines = [NSMutableArray arrayWithCapacity:[ignoredEngines count]];
	int length = [engineWindowEngineList numberOfItems];
	for (int i=0;i<length;i++)
		[availableEngines addObject:[engineWindowEngineList itemTitleAtIndex:i]];
	NSMutableArray *fixedIgnoredEnginesList = [NSMutableArray arrayWithCapacity:[ignoredEngines count]];
	for (NSString *item in ignoredEngines)
	{
		if (!([availableEngines containsObject:item]))
			[fixedIgnoredEnginesList addObject:item];
	}
	NSString *ignoredEnginesString = @"";
	//add all fixed ignored list if any... new ones already removed.
	for (NSString *item in fixedIgnoredEnginesList)
		ignoredEnginesString = [NSString stringWithFormat:@"%@\n%@",ignoredEnginesString,item];
	//add all the engines available to the string
	for (NSString *item in availableEngines)
		ignoredEnginesString = [NSString stringWithFormat:@"%@\n%@",ignoredEnginesString,item];
	//remove any \n off the front of the string
	if ([ignoredEnginesString hasPrefix:@"\n"])
	{
		ignoredEnginesString = [ignoredEnginesString stringByReplacingCharactersInRange:[ignoredEnginesString rangeOfString:@"\n"] withString:@""];
	}
	//write engine to ignored engines text file
	[ignoredEnginesString writeToFile:[NSHomeDirectory() stringByAppendingString:@"/Library/Application Support/Wineskin/IgnoredEngines.txt"] atomically:YES encoding:NSUTF8StringEncoding error:nil];
	//disable prompt button
	[engineWindowDontPromptAsNewButton setEnabled:NO];
}
- (IBAction)engineWindowCustomBuildAnEngineButtonPressed:(id)sender
{
	[self refreshButtonPressed:self];
	[self makeFoldersAndFiles];
	[wineskinEngineBuilderWindow makeKeyAndOrderFront:self];
	[addEngineWindow orderOut:self];
	NSString *currentEngineBuild = [self currentEngineBuildVersion];
	[engineBuildCurrentEngineBase setStringValue:currentEngineBuild];
	NSString *availableEngineBase = [self availableEngineBuildVersion];
	//set update button and label
	if ([availableEngineBase isEqualToString:currentEngineBuild] || [availableEngineBase isEqualToString:@"ERROR"])
	{
		[engineBuildUpdateButton setEnabled:NO];
		[engineBuildUpdateAvailable setHidden:YES];
	}
	else
	{
		[engineBuildUpdateButton setEnabled:YES];
		[engineBuildUpdateAvailable setHidden:NO];
	}
}
- (IBAction)engineWindowCancelButtonPressed:(id)sender
{
	[window makeKeyAndOrderFront:self];
	[addEngineWindow orderOut:self];
	[self refreshButtonPressed:self];
}
//***************************** Downloader ************************
- (IBAction) startDownload:(NSButton *)sender;
{
	[self downloadToggle:YES];
	NSString *input = [urlInput stringValue];
	NSURL *url = [NSURL URLWithString:input];
	
	request = [NSURLRequest requestWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:20.0];
	connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
	if (connection)
	{
		payload = [[NSMutableData data] retain];
		//NSLog(@"Connection starting: %@", connection);
	}
	else
	{
		NSAlert *alert = [[[NSAlert alloc] init] autorelease];
		[alert addButtonWithTitle:NSLocalizedString(@"DOWNLOAD_ERROR_OK", @"OK")];
		[alert setMessageText:NSLocalizedString(@"DOWNLOAD_ERROR_TITLE", @"Download Failed!")];
		[alert setInformativeText:NSLocalizedString(@"DOWNLOAD_ERROR_TEXT", @"unable to download!")];
		[alert setAlertStyle:NSCriticalAlertStyle];
		[alert beginSheetModalForWindow:[cancelButton window] modalDelegate:self didEndSelector:nil contextInfo:nil];
		[self downloadToggle:NO];
	}
}

- (IBAction) stopDownloading:(NSButton *)sender;
{
	if (connection) [connection cancel];
	[self downloadToggle:NO];
	if (([[fileNameDestination stringValue] isEqualToString:@"EngineBase"]))
	{
		[wineskinEngineBuilderWindow makeKeyAndOrderFront:self];
		[downloadingWindow orderOut:self];
	}
	else if (([[fileNameDestination stringValue] isEqualToString:@"Engines"]))
	{
		[addEngineWindow makeKeyAndOrderFront:self];
		[downloadingWindow orderOut:self];
	}
	else if ([[fileName stringValue] isEqualToString:@"Wineskin Winery Update"])
	{
		//display warning about not updating.
		NSAlert *warning = [[NSAlert alloc] init];
		[warning addButtonWithTitle:NSLocalizedString(@"NOT_UPDATE_WARNING_OK", @"OK")];
		[warning setMessageText:NSLocalizedString(@"NOT_UPDATE_WARNING_TITLE", @"Warning!")];
		[warning setInformativeText:NSLocalizedString(@"NOT_UPDATE_WARNING_TEXT", @"Some things may not function properly with new Wrappers or Engines until you update!")];
		[warning runModal];
		[warning release];
		[window makeKeyAndOrderFront:self];
		[downloadingWindow orderOut:self];
	}
	else
	{
		[window makeKeyAndOrderFront:self];
		[downloadingWindow orderOut:self];
	}
}

- (void) downloadToggle:(BOOL)toggle
{
	[progressBar setMaxValue:100.0];
	[progressBar setDoubleValue:1.0];
	if (toggle == YES)
	{
		[downloadButton setEnabled:NO];
		[progressBar setHidden:NO];
	}
	else
	{
		[downloadButton setEnabled:YES];
		[progressBar setHidden:YES];
	}
}

- (void)connection:(NSURLConnection *)conn didReceiveResponse:(NSURLResponse *)response
{
	//NSLog(@"Recieved response with expected length: %i", [response expectedContentLength]);
	[payload setLength:0];
	[progressBar setMaxValue:[response expectedContentLength]];
}
- (void)connection:(NSURLConnection *)conn didReceiveData:(NSData *)data
{
	//NSLog(@"Recieving data. Incoming Size: %i  Total Size: %i", [data length], [payload length]);
	[payload appendData:data];
	[progressBar setDoubleValue:[payload length]];
}
- (void)connectionDidFinishLoading:(NSURLConnection *)conn
{
	[self downloadToggle:NO];
	//delete any files that might exist in /tmp first
	[[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"/tmp/%@.app.tar.7z",[fileName stringValue]] error:nil];
	[[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"/tmp/%@.app.tar",[fileName stringValue]] error:nil];
	[[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"/tmp/%@.app",[fileName stringValue]] error:nil];
	[[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"/tmp/%@.tar.7z",[fileName stringValue]] error:nil];
	[[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"/tmp/%@.tar",[fileName stringValue]] error:nil];
	[[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"/tmp/%@",[fileName stringValue]] error:nil];
	[[NSFileManager defaultManager] removeItemAtPath:@"/tmp/WineskinWinery.app.tar.7z" error:nil];
	[[NSFileManager defaultManager] removeItemAtPath:@"/tmp/WineskinWinery.app.tar" error:nil];
	[[NSFileManager defaultManager] removeItemAtPath:@"/tmp/WineskinWinery.app" error:nil];
	[payload writeToURL:[NSURL URLWithString:[urlOutput stringValue]] atomically:YES];
	[conn release];
	[busyWindow makeKeyAndOrderFront:self];
	[downloadingWindow orderOut:self];
	if (([[fileNameDestination stringValue] isEqualToString:@"Wrapper"]))
	{
		//uncompress download
		[self makeFoldersAndFiles];
		system([[NSString stringWithFormat:@"\"%@/Library/Application Support/Wineskin/7za\" x \"/tmp/%@.app.tar.7z\" -o/tmp", NSHomeDirectory(),[fileName stringValue]] UTF8String]);
		system([[NSString stringWithFormat:@"/usr/bin/tar -C /tmp -xf /tmp/%@.app.tar",[fileName stringValue]] UTF8String]);
		//remove 7z and tar
		[[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"/tmp/%@.app.tar.7z",[fileName stringValue]] error:nil];
		[[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"/tmp/%@.app.tar",[fileName stringValue]] error:nil];
		//remove old one
#ifdef WINESKINE_JAPANESE
        [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/Library/Application Support/Wineskin/Wrapper-JP",NSHomeDirectory()] error:nil];
#else
        [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/Library/Application Support/Wineskin/Wrapper",NSHomeDirectory()] error:nil];
#endif
		[self makeFoldersAndFiles];
		//move download into place
		[[NSFileManager defaultManager] moveItemAtPath:[NSString stringWithFormat:@"/tmp/%@.app",[fileName stringValue]] toPath:[NSString stringWithFormat:@"%@/Library/Application Support/Wineskin/%@/%@.app",NSHomeDirectory(),[fileNameDestination stringValue],[fileName stringValue]] error:nil];
		[window makeKeyAndOrderFront:self];
		[busyWindow orderOut:self];
		[self runConverter];
	}
	else if (([[fileNameDestination stringValue] isEqualToString:@"Engines"]))
	{
		//move download into place
		[[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/Library/Application Support/Wineskin/%@/%@.tar.7z",NSHomeDirectory(),[fileNameDestination stringValue],[fileName stringValue]] error:nil];
		[[NSFileManager defaultManager] moveItemAtPath:[NSString stringWithFormat:@"/tmp/%@.tar.7z",[fileName stringValue]] toPath:[NSString stringWithFormat:@"%@/Library/Application Support/Wineskin/%@/%@.tar.7z",NSHomeDirectory(),[fileNameDestination stringValue],[fileName stringValue]] error:nil];
		//Add engine to ignored list
		NSArray *ignoredEngines = [self getEnginesToIgnore];
		NSString *ignoredEnginesString = @"";
		BOOL fixTheList=YES;
		for (NSString *item in ignoredEngines)
		{
			if ([item isEqualToString:[fileName stringValue]])
			{
				fixTheList=NO;
				break;
			}
			ignoredEnginesString = [ignoredEnginesString stringByAppendingString:[item stringByAppendingString:@"\n"]];	
		}
		if (fixTheList)
		{
			ignoredEnginesString = [NSString stringWithFormat:@"%@\n%@",ignoredEnginesString,[fileName stringValue]];
			[ignoredEnginesString writeToFile:[NSHomeDirectory() stringByAppendingString:@"/Library/Application Support/Wineskin/IgnoredEngines.txt"] atomically:YES encoding:NSUTF8StringEncoding error:nil];
		}		
		[window makeKeyAndOrderFront:self];
		[busyWindow orderOut:self];
	}
	else if (([[fileNameDestination stringValue] isEqualToString:@"EngineBase"]))
	{
		//uncompress download
		[self makeFoldersAndFiles];
		system([[NSString stringWithFormat:@"\"%@/Library/Application Support/Wineskin/7za\" x \"/tmp/%@.tar.7z\" -o/tmp", NSHomeDirectory(),[fileName stringValue]] UTF8String]);
		system([[NSString stringWithFormat:@"/usr/bin/tar -C /tmp -xf /tmp/%@.tar",[fileName stringValue]] UTF8String]);
		//remove 7z and tar
		[[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"/tmp/%@.tar.7z",[fileName stringValue]] error:nil];
		[[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"/tmp/%@.tar",[fileName stringValue]] error:nil];
		//remove old one
		[[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/Library/Application Support/Wineskin/EngineBase",NSHomeDirectory()] error:nil];
		[self makeFoldersAndFiles];
		//move download into place
		[[NSFileManager defaultManager] moveItemAtPath:[NSString stringWithFormat:@"/tmp/%@",[fileName stringValue]] toPath:[NSString stringWithFormat:@"%@/Library/Application Support/Wineskin/%@/%@",NSHomeDirectory(),[fileNameDestination stringValue],[fileName stringValue]] error:nil];		
		NSString *currentEngineBuild = [self currentEngineBuildVersion];
		[engineBuildCurrentEngineBase setStringValue:currentEngineBuild];
		NSString *availableEngineBase = [self availableEngineBuildVersion];
		//set update button and label
		if ([availableEngineBase isEqualToString:currentEngineBuild])
		{
			[engineBuildUpdateButton setEnabled:NO];
			[engineBuildUpdateAvailable setHidden:YES];
		}
		else
		{
			[engineBuildUpdateButton setEnabled:YES];
			[engineBuildUpdateAvailable setHidden:NO];
		}
		[wineskinEngineBuilderWindow makeKeyAndOrderFront:self];
		[busyWindow orderOut:self];
	}
	if ([[fileName stringValue] isEqualToString:@"Wineskin Winery Update"])
	{
		//take care of update
		[self makeFoldersAndFiles];
		[[NSFileManager defaultManager] removeItemAtPath:@"/tmp/WineskinWineryUpdater" error:nil];
#ifdef WINESKINE_JAPANESE
       system([[NSString stringWithFormat:@"\"%@/Library/Application Support/Wineskin/7za\" x \"/tmp/WineskinWineryJP.app.tar.7z\" -o/tmp", NSHomeDirectory()] UTF8String]);
       system([[NSString stringWithFormat:@"/usr/bin/tar -C /tmp -xf /tmp/WineskinWineryJP.app.tar"] UTF8String]);
#else
		system([[NSString stringWithFormat:@"\"%@/Library/Application Support/Wineskin/7za\" x \"/tmp/WineskinWinery.app.tar.7z\" -o/tmp", NSHomeDirectory()] UTF8String]);
		system([[NSString stringWithFormat:@"/usr/bin/tar -C /tmp -xf /tmp/WineskinWinery.app.tar"] UTF8String]);
#endif
        
		[[NSFileManager defaultManager] copyItemAtPath:@"/tmp/WineskinWinery.app/Contents/Resources/WineskinWineryUpdater" toPath:@"/tmp/WineskinWineryUpdater" error:nil];
		//run updater program
		system([[NSString stringWithFormat:@"/tmp/WineskinWineryUpdater \"%@\" &",[[NSBundle mainBundle] bundlePath]] UTF8String]);
		//kill this app, Updater will restart it after changing out contents.
		[NSApp terminate:self];
	}
	[self refreshButtonPressed:self];
}
- (void)connection:(NSURLConnection *)conn didFailWithError:(NSError *)error
{
	[self downloadToggle:NO];
	[payload setLength:0];	
	NSAlert *alert = [[[NSAlert alloc] init] autorelease];
	[alert addButtonWithTitle:NSLocalizedString(@"CONNECTION_RESULT_OK", @"OK")];
	[alert setMessageText:[error localizedDescription]];
	[alert setAlertStyle:NSCriticalAlertStyle];
	[alert beginSheetModalForWindow:[cancelButton window] modalDelegate:self didEndSelector:nil contextInfo:nil];
	[window makeKeyAndOrderFront:self];
	[downloadingWindow orderOut:self];
}
//*********************** wrapper creation **********************
- (IBAction)createWrapperOkButtonPressed:(id)sender
{
	//replace common symbols...
	[createWrapperName setStringValue:[[createWrapperName stringValue] stringByReplacingOccurrencesOfString:@"&" withString:@"and"]];
	[createWrapperName setStringValue:[[createWrapperName stringValue] stringByReplacingOccurrencesOfString:@"!" withString:@""]];
	[createWrapperName setStringValue:[[createWrapperName stringValue] stringByReplacingOccurrencesOfString:@"#" withString:@""]];
	[createWrapperName setStringValue:[[createWrapperName stringValue] stringByReplacingOccurrencesOfString:@"$" withString:@""]];
	[createWrapperName setStringValue:[[createWrapperName stringValue] stringByReplacingOccurrencesOfString:@"%" withString:@""]];
	[createWrapperName setStringValue:[[createWrapperName stringValue] stringByReplacingOccurrencesOfString:@"^" withString:@""]];
	[createWrapperName setStringValue:[[createWrapperName stringValue] stringByReplacingOccurrencesOfString:@"*" withString:@""]];
	[createWrapperName setStringValue:[[createWrapperName stringValue] stringByReplacingOccurrencesOfString:@"(" withString:@""]];
	[createWrapperName setStringValue:[[createWrapperName stringValue] stringByReplacingOccurrencesOfString:@")" withString:@""]];
	[createWrapperName setStringValue:[[createWrapperName stringValue] stringByReplacingOccurrencesOfString:@"+" withString:@""]];
	[createWrapperName setStringValue:[[createWrapperName stringValue] stringByReplacingOccurrencesOfString:@"=" withString:@""]];
	[createWrapperName setStringValue:[[createWrapperName stringValue] stringByReplacingOccurrencesOfString:@"|" withString:@""]];
	[createWrapperName setStringValue:[[createWrapperName stringValue] stringByReplacingOccurrencesOfString:@"\\" withString:@""]];
	[createWrapperName setStringValue:[[createWrapperName stringValue] stringByReplacingOccurrencesOfString:@"?" withString:@""]];
	[createWrapperName setStringValue:[[createWrapperName stringValue] stringByReplacingOccurrencesOfString:@">" withString:@""]];
	[createWrapperName setStringValue:[[createWrapperName stringValue] stringByReplacingOccurrencesOfString:@"<" withString:@""]];
	[createWrapperName setStringValue:[[createWrapperName stringValue] stringByReplacingOccurrencesOfString:@";" withString:@""]];
	[createWrapperName setStringValue:[[createWrapperName stringValue] stringByReplacingOccurrencesOfString:@":" withString:@""]];
	[createWrapperName setStringValue:[[createWrapperName stringValue] stringByReplacingOccurrencesOfString:@"@" withString:@""]];
	//make sure wrapper name is unique
	if ([[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@/Applications/Wineskin/%@.app",NSHomeDirectory(),[createWrapperName stringValue]]])
	{
		NSAlert *alert = [[NSAlert alloc] init];
		[alert addButtonWithTitle:NSLocalizedString(@"WRAPPER_ALREADY_EXISTS_OK", @"OK")];
		[alert setMessageText:NSLocalizedString(@"WRAPPER_ALREADY_EXISTS_TITLE", @"Oops! File already exists!")];
		[alert setInformativeText:[NSString stringWithFormat:NSLocalizedString(@"WRAPPER_ALREADY_EXISTS_TEXT", @"A wrapper at \"%@/Applications/Wineskin\" with the name \"%@\" already exists!  Please choose a different name."),NSHomeDirectory(),[createWrapperName stringValue]]];
		[alert setAlertStyle:NSInformationalAlertStyle];
		[alert runModal];
		[alert release];
		return;
	}
	//get rid of window
	[busyWindow makeKeyAndOrderFront:self];
	[createWrapperWindow orderOut:self];
	[self makeFoldersAndFiles];
	//delete files that might already exist
	NSFileManager *fm = [NSFileManager defaultManager];
	[fm removeItemAtPath:[NSString stringWithFormat:@"/tmp/%@.app",[createWrapperName stringValue]] error:nil];
	[fm removeItemAtPath:[NSString stringWithFormat:@"%@/Library/Application Support/Wineskin/Engines/%@.tar",NSHomeDirectory(),[createWrapperEngine stringValue]] error:nil];
	[fm removeItemAtPath:[NSString stringWithFormat:@"%@/Library/Application Support/Wineskin/Engines/wswine.bundle",NSHomeDirectory()] error:nil];
	//copy master wrapper to /tmp with correct name
#ifdef WINESKINE_JAPANESE
    [fm copyItemAtPath:[NSString stringWithFormat:@"%@/Library/Application Support/Wineskin/Wrapper-JP/%@.app",NSHomeDirectory(),[wrapperVersion stringValue]] toPath:[NSString stringWithFormat:@"/tmp/%@.app",[createWrapperName stringValue]] error:nil];
#else
	[fm copyItemAtPath:[NSString stringWithFormat:@"%@/Library/Application Support/Wineskin/Wrapper/%@.app",NSHomeDirectory(),[wrapperVersion stringValue]] toPath:[NSString stringWithFormat:@"/tmp/%@.app",[createWrapperName stringValue]] error:nil];
#endif
	//decompress engine
	system([[NSString stringWithFormat:@"\"%@/Library/Application Support/Wineskin/7za\" x \"%@/Library/Application Support/Wineskin/Engines/%@.tar.7z\" \"-o/%@/Library/Application Support/Wineskin/Engines\"", NSHomeDirectory(),NSHomeDirectory(),[createWrapperEngine stringValue],NSHomeDirectory()] UTF8String]);
	system([[NSString stringWithFormat:@"/usr/bin/tar -C \"%@/Library/Application Support/Wineskin/Engines\" -xf \"%@/Library/Application Support/Wineskin/Engines/%@.tar\"",NSHomeDirectory(),NSHomeDirectory(),[createWrapperEngine stringValue]] UTF8String]);
	//remove tar
	[fm removeItemAtPath:[NSString stringWithFormat:@"%@/Library/Application Support/Wineskin/Engines/%@.tar",NSHomeDirectory(),[createWrapperEngine stringValue]] error:nil];
	//test a couple of file sint he engine just to make sure it isn't corrupted
	BOOL engineError=NO;
	if (![fm fileExistsAtPath:[NSString stringWithFormat:@"%@/Library/Application Support/Wineskin/Engines/wswine.bundle",NSHomeDirectory()]]) engineError=YES;
	else if (![fm fileExistsAtPath:[NSString stringWithFormat:@"%@/Library/Application Support/Wineskin/Engines/wswine.bundle/bin/wineserver",NSHomeDirectory()]]) engineError=YES;
	else if (![fm fileExistsAtPath:[NSString stringWithFormat:@"%@/Library/Application Support/Wineskin/Engines/wswine.bundle/bin/wine",NSHomeDirectory()]]) engineError=YES;
	//if its ICE the above two errors are wrong... if 7za is in the bundle then its ICE and assume its OK and go along.
	if ([fm fileExistsAtPath:[NSString stringWithFormat:@"%@/Library/Application Support/Wineskin/Engines/wswine.bundle/7za",NSHomeDirectory()]]) engineError=NO;
	if (engineError)
	{
		NSAlert *alert = [[NSAlert alloc] init];
		[alert addButtonWithTitle:NSLocalizedString(@"ENGINE_ERROR_OK", @"OH NO!!")];
		[alert setMessageText:NSLocalizedString(@"ENGINE_ERROR_TITLE", @"ERROR!")];
		[alert setInformativeText:[NSString stringWithFormat:NSLocalizedString(@"ENGINE_ERROR_TEXT", @"The engine %@ is corrupted or opened incorrectly. If this error continues next time you try, reinstall the selected engine"),[createWrapperEngine stringValue]]];
		[alert setAlertStyle:NSCriticalAlertStyle];
		[alert runModal];
        [alert release];
		//get rid of junk in /tmp
		[fm removeItemAtPath:[NSString stringWithFormat:@"/tmp/%@.app",[createWrapperName stringValue]] error:nil];
		[fm removeItemAtPath:[NSString stringWithFormat:@"%@/Library/Application Support/Wineskin/Engines/%@.tar",NSHomeDirectory(),[createWrapperEngine stringValue]] error:nil];
		[fm removeItemAtPath:[NSString stringWithFormat:@"%@/Library/Application Support/Wineskin/Engines/wswine.bundle",NSHomeDirectory()] error:nil];
	}
	else
	{
		//put engine in wrapper
		[fm moveItemAtPath:[NSString stringWithFormat:@"%@/Library/Application Support/Wineskin/Engines/wswine.bundle",NSHomeDirectory()] toPath:[NSString stringWithFormat:@"/tmp/%@.app/Contents/Frameworks/wswine.bundle",[createWrapperName stringValue]] error:nil];
		// 777 the bundle
		system([[NSString stringWithFormat:@"chmod 777 \"/tmp/%@.app/Contents/Frameworks/wswine.bundle\"",[createWrapperName stringValue]] UTF8String]);
		//refresh wrapper
		system([[NSString stringWithFormat:@"\"/tmp/%@.app/Contents/Frameworks/bin/Wineskin\" WSS-wineprefixcreate",[createWrapperName stringValue]] UTF8String]);
		//move wrapper to ~/Applications/Wineskin
		[fm moveItemAtPath:[NSString stringWithFormat:@"/tmp/%@.app",[createWrapperName stringValue]] toPath:[NSString stringWithFormat:@"%@/Applications/Wineskin/%@.app",NSHomeDirectory(),[createWrapperName stringValue]] error:nil];
		//put ending message
		NSAlert *alert = [[NSAlert alloc] init];
		[alert addButtonWithTitle:NSLocalizedString(@"WRAPPER_CREATE_END_FINDER", @"View wrapper in Finder")];
		[alert addButtonWithTitle:NSLocalizedString(@"WRAPPER_CREATE_END_OK", @"OK")];
		[alert setMessageText:NSLocalizedString(@"WRAPPER_CREATE_END_TITLE", @"Wrapper Creation Finished")];
		[alert setInformativeText:[NSString stringWithFormat:NSLocalizedString(@"WRAPPER_CREATE_END_TEXT", @"Created File: %@.app\n\nCreated In:%@/Applications/Wineskin\n"),[createWrapperName stringValue],NSHomeDirectory()]];
		[alert setAlertStyle:NSInformationalAlertStyle];
		if ([alert runModal] == NSAlertFirstButtonReturn)
        {
			[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:[NSString stringWithFormat:@"file://%@/Applications/Wineskin/",NSHomeDirectory()]]];
        }
        [alert release];
	}
	// bring main window back
	[window makeKeyAndOrderFront:self];
	[busyWindow orderOut:self];
}
- (IBAction)createWrapperCancelButtonPressed:(id)sender
{
	[window makeKeyAndOrderFront:self];
	[createWrapperWindow orderOut:self];
}
//***************************** OVERRIDES *************************
- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
	return [installedEnginesList count];
}
- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
	return [installedEnginesList objectAtIndex:rowIndex];
}
- (id)init
{
	self = [super init];
	if (self)
	{
		installedEnginesList = [[NSMutableArray alloc] initWithObjects:NSLocalizedString(@"ENGINE_LIST_INITALIZE_TEXT", @"Please Wait..."),nil];
	}
	return self;
}
- (void)dealloc
{
	[installedEnginesList release];
	[super dealloc];
}
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication
{
    return YES;
}

@end
