/*
 * Copyright 2011 Jason Rush and John Flanagan. All rights reserved.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#import <AudioToolbox/AudioToolbox.h>
#import "SettingsViewController.h"
#import "SelectionListViewController.h"
#import "SFHFKeychainUtils.h"

@implementation SettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    
    hidePasswordsSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(200, 10, 0, 0)];
    hidePasswordsSwitch.on = [userDefaults boolForKey:@"hidePasswords"];
    [hidePasswordsSwitch addTarget:self action:@selector(toggleHidePasswords:) forControlEvents:UIControlEventValueChanged];
    
    rememberPasswordsSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(200, 10, 0, 0)];
    rememberPasswordsSwitch.on = [userDefaults boolForKey:@"rememberPasswords"];
    [rememberPasswordsSwitch addTarget:self action:@selector(toggleRememberPasswords:) forControlEvents:UIControlEventValueChanged];
    
    pinSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(200, 10, 0, 0)];
    pinSwitch.on = [userDefaults boolForKey:@"pinEnabled"];
    [pinSwitch addTarget:self action:@selector(togglePin:) forControlEvents:UIControlEventValueChanged];
    
    lockTimeoutLabels = [[NSArray arrayWithObjects:@"Immediately", @"30 Seconds", @"1 Minute", @"2 Minutes", @"5 Minutes", nil] retain];

    self.title = @"Settings";
}

- (void)dealloc {
    [rememberPasswordsSwitch release];
    [hidePasswordsSwitch release];
    [pinSwitch release];
    [lockTimeoutLabels release];
    [super dealloc];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 4;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
        cell.selectionStyle = UITableViewCellEditingStyleNone;
    }
    
    switch (indexPath.row) {
        case 0:
            cell.textLabel.text = @"Hide Passwords";
            [cell addSubview:hidePasswordsSwitch];
            break;
        
        case 1:
            cell.textLabel.text = @"Remember Passwords";
            [cell addSubview:rememberPasswordsSwitch];
            break;
            
        case 2:
            cell.textLabel.text = @"Enable PIN";
            [cell addSubview:pinSwitch];
            break;
            
        case 3:
            cell.textLabel.text = [NSString stringWithFormat:@"Lock Timeout: %@", [lockTimeoutLabels objectAtIndex:[[NSUserDefaults standardUserDefaults] integerForKey:@"lockTimeout"]]];
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            break;
            
        default:
            break;
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row == 2) {
        SelectionListViewController *selectionListViewController = [[SelectionListViewController alloc] initWithStyle:UITableViewStyleGrouped];
        selectionListViewController.items = lockTimeoutLabels;
        selectionListViewController.selectedIndex = [[NSUserDefaults standardUserDefaults] integerForKey:@"lockTimeout"];
        selectionListViewController.delegate = self;
        selectionListViewController.title = @"Lock Timeout";
        [self.navigationController pushViewController:selectionListViewController animated:YES];
        [selectionListViewController release];
    }
}

- (void)selectionListViewController:(SelectionListViewController *)controller selectedIndex:(NSInteger)selectedIndex {
    // Save the user setting
    NSUserDefaults *standardUserDefaults = [NSUserDefaults standardUserDefaults];
    [standardUserDefaults setInteger:selectedIndex forKey:@"lockTimeout"];
    
    // Update the cell text
    UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:2 inSection:0]]; 
    cell.textLabel.text = [NSString stringWithFormat:@"Lock Timeout: %@", [lockTimeoutLabels objectAtIndex:selectedIndex]];
}

- (void)toggleHidePasswords:(id)sender {
    [[NSUserDefaults standardUserDefaults] setBool:hidePasswordsSwitch.on forKey:@"hidePasswords"];
}

- (void)toggleRememberPasswords:(id)sender {
    [[NSUserDefaults standardUserDefaults] setBool:rememberPasswordsSwitch.on forKey:@"rememberPasswords"];
}

- (void)togglePin:(id)sender {
    if (pinSwitch.on) {
        PinViewController* pinViewController = [[PinViewController alloc] initWithText:@"Set PIN"];
        pinViewController.delegate = self;
        [self presentModalViewController:pinViewController animated:YES];
        [pinViewController release];
    } else {
        [SFHFKeychainUtils deleteItemForUsername:@"PIN" andServiceName:@"net.fizzawizza.MobileKeePass" error:nil];
    }
    
    [[NSUserDefaults standardUserDefaults] setBool:pinSwitch.on forKey:@"pinEnabled"];
}

- (void)pinViewController:(PinViewController *)controller pinEntered:(NSString *)pin {        
    if (tempPin == nil) {
        tempPin = [pin copy];
        controller.string = @"Confirm PIN";
        [controller clearEntry];
    } else if ([tempPin isEqualToString:pin]) {
        NSError *error;
        [SFHFKeychainUtils storeUsername:@"PIN" andPassword:pin forServiceName:@"net.fizzawizza.MobileKeePass" updateExisting:YES error:&error];
        
        [tempPin release];
        tempPin = nil;

        [controller dismissModalViewControllerAnimated:YES];
    } else {
        controller.string = @"PINs did not match. Try again";
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
        
        [tempPin release];
        tempPin = nil;
        
        [controller clearEntry];
    }
}

- (void)pinViewControllerCancelButtonPressed:(PinViewController *)controller {
    [pinSwitch setOn:NO animated:YES];

    [SFHFKeychainUtils deleteItemForUsername:@"PIN" andServiceName:@"net.fizzawizza.MobileKeePass" error:nil];
    
    NSUserDefaults *standardUserDefaults = [NSUserDefaults standardUserDefaults];
    [standardUserDefaults setBool:NO forKey:@"pinEnabled"];
    
    [tempPin release];
    tempPin = nil;

    [controller dismissModalViewControllerAnimated:YES];
}

@end
