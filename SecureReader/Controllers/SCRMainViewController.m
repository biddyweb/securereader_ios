//
//  SRMainViewController.m
//  SecureReader
//
//  Created by N-Pex on 2014-10-27.
//  Copyright (c) 2014 Guardian Project. All rights reserved.
//

#import "SCRMainViewController.h"
#import "SCRItem.h"
#import "SCRItemView.h"
#import "SCRFeedFetcher.h"
#import "YapDatabase.h"
#import "SCRDatabaseManager.h"
#import "YapDatabaseView.h"
#import "UIImageView+AFNetworking.h"
#import "SCRItemViewController.h"

@interface SCRMainViewController ()

// Prototype cells for height calculation
@property (nonatomic, strong) SCRItemView *prototypeCellNoPhotos;
@property (nonatomic, strong) SCRItemView *prototypeCellLandscapePhotos;
@property (nonatomic, strong) SCRItemView *prototypeCellPortraitPhotos;

@property (strong,nonatomic) SCRItemViewController *expander;

@property (nonatomic, strong, readonly) SCRFeedFetcher *feedFetcher;

@property (nonatomic, strong) YapDatabaseViewMappings *mappings;
@property (nonatomic, strong) YapDatabaseConnection *readConnection;
@property (nonatomic, strong, readonly) NSString *yapViewName;

@end

@implementation SCRMainViewController

@synthesize selectedItemRect;

- (void)viewDidLoad
{
    [super viewDidLoad];
    _yapViewName = [SCRDatabaseManager sharedInstance].allFeedItemsViewName;
    [self setupMappings];
    _feedFetcher = [[SCRFeedFetcher alloc] init];
    
    //UIRefreshControl *refreshControl = [[UIRefreshControl alloc]
    //                                    init];
    //refreshControl.tintColor = [UIColor magentaColor];
    //self.refreshControl = refreshControl;
}

- (void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self.tableView reloadData];
    NSArray *feedURLs = @[@"http://www.voanews.com/api/epiqq",
                          @"http://www.theguardian.com/world/rss",
                          @"http://feeds.washingtonpost.com/rss/world",
                          @"http://www.nytimes.com/services/xml/rss/nyt/InternationalHome.xml",
                          @"http://rss.cnn.com/rss/cnn_topstories.rss",
                          @"http://rss.cnn.com/rss/cnn_world.rss"];
    [feedURLs enumerateObjectsUsingBlock:^(NSString *feedURLString, NSUInteger idx, BOOL *stop) {
        [self.feedFetcher fetchFeedDataFromURL:[NSURL URLWithString:feedURLString]];
    }];
}

- (void)viewWillAppear:(BOOL)animated
{
    [self.navigationController setNavigationBarHidden:NO];
}

- (NSString *) getCellIdentifierForItem:(SCRItem *) item
{
    NSString *cellIdentifier = @"cellNoPhotos";
    if (item.thumbnailURL) {
        // perhaps we can also provide "cellPortraitPhotos" via thumbnailSize property
        cellIdentifier = @"cellNoPhotos";
    }
    return cellIdentifier;
}

- (SCRItemView *) getPrototypeForItem:(SCRItem *) item
{
    NSString *cellIdentifier = [self getCellIdentifierForItem:item];
    if ([cellIdentifier compare:@"cellLandscapePhotos"] == NSOrderedSame)
    {
        if (!self.prototypeCellLandscapePhotos)
            self.prototypeCellLandscapePhotos = [self.tableView dequeueReusableCellWithIdentifier:cellIdentifier];
        return self.prototypeCellLandscapePhotos;
    }
    else if ([cellIdentifier compare:@"cellPortraitPhotos"] == NSOrderedSame)
    {
        if (!self.prototypeCellPortraitPhotos)
            self.prototypeCellPortraitPhotos = [self.tableView dequeueReusableCellWithIdentifier:cellIdentifier];
        return self.prototypeCellPortraitPhotos;
    }
    else
    {
        // No photos
        if (!self.prototypeCellNoPhotos)
            self.prototypeCellNoPhotos = [self.tableView dequeueReusableCellWithIdentifier:cellIdentifier];
        return self.prototypeCellNoPhotos;
    }
}

#pragma mark UITableViewDelegate methods

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (self.expander == nil)
    {
         self.expander = [self.storyboard instantiateViewControllerWithIdentifier:@"itemView"];
    }
    self.expander.item = [self itemForIndexPath:indexPath];
    self.selectedItemRect = [self.tableView rectForRowAtIndexPath:indexPath];
    
    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];

    self.selectedItemRect = CGRectMake(self.selectedItemRect.origin.x - tableView.bounds.origin.x, self.selectedItemRect.origin.y - tableView.bounds.origin.y, self.selectedItemRect.size.width, self.selectedItemRect.size.height);
    
    [self.navigationController pushViewController:self.expander animated:NO];

    if ([cell class] == [SCRItemView class])
        [self.expander willExpandFromView:(SCRItemView*)cell];
}

#pragma mark UITableViewDataSource methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)sender
{
    NSInteger numberOfSections = [self.mappings numberOfSections];
    return numberOfSections;
}

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSInteger numberOfRows = [self.mappings numberOfItemsInSection:section];
    return numberOfRows;
}

- (SCRItem *) itemForIndexPath:(NSIndexPath *) indexPath
{
    __block SCRItem *item = nil;
    [self.readConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
        item = [[transaction extension:self.yapViewName] objectAtIndexPath:indexPath withMappings:self.mappings];
    }];
    return item;
}

- (void)configureCell:(SCRItemView *)cell forItem:(SCRItem *)item
{
    cell.titleView.text = item.title;
    cell.sourceView.labelSource.text = [item.linkURL host];
    
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    SCRItem *item = [self itemForIndexPath:indexPath];
    
    NSString *cellIdentifier = [self getCellIdentifierForItem:item];
    
    SCRItemView *cell = [tableView
                      dequeueReusableCellWithIdentifier:cellIdentifier forIndexPath:indexPath];
    [self configureCell:cell forItem:item];
    
    cell.imageView.image = nil;
    if (item.thumbnailURL) {
        [cell.imageView setImageWithURL:item.thumbnailURL];
    }
    
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    SCRItem *item = [self itemForIndexPath:indexPath];
    SCRItemView *prototype = [self getPrototypeForItem:item];
    [self configureCell:prototype forItem:item];
    [prototype layoutIfNeeded];
    
    CGSize size = [prototype.contentView systemLayoutSizeFittingSize:UILayoutFittingCompressedSize];
    return size.height+1;
}

#pragma mark YapDatabase

- (void) setupMappings {
    self.readConnection = [[SCRDatabaseManager sharedInstance].database newConnection];
    self.mappings = [[YapDatabaseViewMappings alloc] initWithGroupFilterBlock:^BOOL(NSString *group, YapDatabaseReadTransaction *transaction) {
        return YES;
    } sortBlock:^NSComparisonResult(NSString *group1, NSString *group2, YapDatabaseReadTransaction *transaction) {
        return [group1 compare:group2];
    } view:self.yapViewName];
    
    // Freeze our databaseConnection on the current commit.
    // This gives us a snapshot-in-time of the database,
    // and thus a stable data source for our UI thread.
    [self.readConnection beginLongLivedReadTransaction];
    
    // Initialize our mappings.
    // Note that we do this after we've started our database longLived transaction.
    [self.readConnection readWithBlock:^(YapDatabaseReadTransaction *transaction){
        
        // Calling this for the first time will initialize the mappings,
        // and will allow mappings to cache certain information
        // such as the counts for each section.
        [self.mappings updateWithTransaction:transaction];
    }];
    
    // And register for notifications when the database changes.
    // Our method will be invoked on the main-thread,
    // and will allow us to move our stable data-source from our existing state to an updated state.
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(yapDatabaseModified:)
                                                 name:YapDatabaseModifiedNotification
                                               object:self.readConnection.database];
    
    [self.tableView reloadData];
}

- (void)yapDatabaseModified:(NSNotification *)notification
{
    // Jump to the most recent commit.
    // End & Re-Begin the long-lived transaction atomically.
    // Also grab all the notifications for all the commits that I jump.
    // If the UI is a bit backed up, I may jump multiple commits.
    
    NSArray *notifications = [self.readConnection beginLongLivedReadTransaction];
    
    // If the view isn't visible, we might decide to skip the UI animation stuff.
    if (!([self isViewLoaded] && self.view.window))
    {
        // Since we moved our databaseConnection to a new commit,
        // we need to update the mappings too.
        [self.readConnection readWithBlock:^(YapDatabaseReadTransaction *transaction){
            [self.mappings updateWithTransaction:transaction];
        }];
        return;
    }
    
    // Process the notification(s),
    // and get the change-set(s) as applies to my view and mappings configuration.
    //
    // Note: the getSectionChanges:rowChanges:forNotifications:withMappings: method
    // automatically invokes the equivalent of [mappings updateWithTransaction:] for you.
    
    NSArray *sectionChanges = nil;
    NSArray *rowChanges = nil;
    
    [[self.readConnection ext:self.yapViewName] getSectionChanges:&sectionChanges
                                                       rowChanges:&rowChanges
                                                 forNotifications:notifications
                                                     withMappings:self.mappings];
    
    // No need to update mappings.
    // The above method did it automatically.
    
    if ([sectionChanges count] == 0 & [rowChanges count] == 0)
    {
        // Nothing has changed that affects our tableView
        return;
    }
    
    [self.tableView beginUpdates];
    
    for (YapDatabaseViewSectionChange *sectionChange in sectionChanges)
    {
        switch (sectionChange.type)
        {
            case YapDatabaseViewChangeDelete :
            {
                [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:sectionChange.index]
                                       withRowAnimation:UITableViewRowAnimationAutomatic];
                break;
            }
            case YapDatabaseViewChangeInsert :
            {
                [self.tableView insertSections:[NSIndexSet indexSetWithIndex:sectionChange.index]
                                       withRowAnimation:UITableViewRowAnimationAutomatic];
                break;
            }
            case YapDatabaseViewChangeMove:
            {
                break;
            }
            case YapDatabaseViewChangeUpdate:
            {
                break;
            }
        }
    }
    
    for (YapDatabaseViewRowChange *rowChange in rowChanges)
    {
        switch (rowChange.type)
        {
            case YapDatabaseViewChangeDelete :
            {
                [self.tableView deleteRowsAtIndexPaths:@[ rowChange.indexPath ]
                                               withRowAnimation:UITableViewRowAnimationAutomatic];
                break;
            }
            case YapDatabaseViewChangeInsert :
            {
                [self.tableView insertRowsAtIndexPaths:@[ rowChange.newIndexPath ]
                                               withRowAnimation:UITableViewRowAnimationAutomatic];
                break;
            }
            case YapDatabaseViewChangeMove :
            {
                [self.tableView deleteRowsAtIndexPaths:@[ rowChange.indexPath ]
                                               withRowAnimation:UITableViewRowAnimationAutomatic];
                [self.tableView insertRowsAtIndexPaths:@[ rowChange.newIndexPath ]
                                               withRowAnimation:UITableViewRowAnimationAutomatic];
                break;
            }
            case YapDatabaseViewChangeUpdate :
            {
                [self.tableView reloadRowsAtIndexPaths:@[ rowChange.indexPath ]
                                               withRowAnimation:UITableViewRowAnimationNone];
                break;
            }
        }
    }
    
    [self.tableView endUpdates];
}


// Prepare for the segue going forward
//- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
//    if([segue isKindOfClass:[SCRExpandSegue class]]) {
//        SCRExpandSegue *expand = (SCRExpandSegue *)segue;
//        expand.isExpanding = YES;
//        expand.sourceRect = self.chosenCellFrame;
//        expand.targetRect = self.view.frame;
//    }
//}



@end