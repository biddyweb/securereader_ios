//
//  SCRMoreViewController.m
//  SecureReader
//
//  Created by N-Pex on 2014-12-16.
//  Copyright (c) 2014 Guardian Project. All rights reserved.
//

#import "SCRMoreViewController.h"
#import "SCRFeedViewController.h"
#import "SCRReceiveShareView.h"
#import "SCRNavigationController.h"
#import "UIView+Theming.h"

@interface SCRMoreViewController ()

@end

@implementation SCRMoreViewController

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (BOOL)shouldPerformSegueWithIdentifier:(NSString *)identifier sender:(id)sender
{
    if ([identifier isEqualToString:@"segueToReceived"])
    {
        SCRFeedViewController *feedViewController = [self.storyboard instantiateViewControllerWithIdentifier:@"feedViewController"];
        [feedViewController setFeedViewType:SCRFeedViewTypeReceived feed:nil];

        // Set the header
        SCRReceiveShareView *header = [[SCRReceiveShareView alloc] initWithFrame:CGRectMake(0, 0, 100, 60)];
        feedViewController.tableView.tableHeaderView = header;
        
        [self.navigationController pushViewController:feedViewController animated:YES];
        return NO;
    }
    return [super shouldPerformSegueWithIdentifier:identifier sender:sender];
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    
    UIView* view = [[UIView alloc] init];
    UILabel* label = [[UILabel alloc] init];
    
    [view setTheme:@"MoreSectionStyle"];
    label.text = [self tableView: tableView titleForHeaderInSection: section];
    label.textAlignment = NSTextAlignmentCenter;
    [label setTheme:@"MoreSectionStyle"];
    [label sizeToFit];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    [view addSubview:label];
    [view addConstraints:
     @[[NSLayoutConstraint constraintWithItem:label
                                    attribute:NSLayoutAttributeLeading
                                    relatedBy:NSLayoutRelationEqual
                                       toItem:view
                                    attribute:NSLayoutAttributeLeading
                                   multiplier:1 constant:15],
       [NSLayoutConstraint constraintWithItem:label
                                    attribute:NSLayoutAttributeCenterY
                                    relatedBy:NSLayoutRelationEqual
                                       toItem:view
                                    attribute:NSLayoutAttributeCenterY
                                   multiplier:1 constant:0]]];
    return view;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    if ([[self tableView:tableView titleForHeaderInSection:section] length] == 0)
        return 0;
    return 50;
}

@end
