//
//  HRPGTableViewController.m
//  HabitRPG
//
//  Created by Phillip Thelen on 08/03/14.
//  Copyright (c) 2014 Phillip Thelen. All rights reserved.
//

#import "HRPGTableViewController.h"
#import "HRPGAppDelegate.h"
#import "HRPGFormViewController.h"
#import "Tag.h"
#import "HRPGTagViewController.h"
#import "HRPGTabBarController.h"
#import "HRPGNavigationController.h"
#import "HRPGImageOverlayManager.h"
#import <POPSpringAnimation.h>
#import "NSString+Emoji.h"

@interface HRPGTableViewController ()
@property NSString *readableName;
@property NSString *typeName;
@property NSIndexPath *openedIndexPath;
@property int indexOffset;
- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath withAnimation:(BOOL)animate;
@end

@implementation HRPGTableViewController
Task *editedTask;
BOOL editable;

- (void)viewDidLoad {
    [super viewDidLoad];

    UIRefreshControl *refresh = [[UIRefreshControl alloc] init];
    [refresh addTarget:self action:@selector(refresh) forControlEvents:UIControlEventValueChanged];
    self.refreshControl = refresh;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didSelectTags:) name:@"tagsSelected"  object:nil];
    [self didSelectTags:nil];
}

- (void)refresh {
    if (self.openedIndexPath) {
        [self tableView:self.tableView expandTaskAtIndexPath:self.openedIndexPath];
    }
    [self.sharedManager fetchUser:^() {
        [self.refreshControl endRefreshing];
    }                     onError:^() {
        [self.refreshControl endRefreshing];
    }];
}

- (NSPredicate*) getPredicate {
    NSPredicate *predicate;
    HRPGTabBarController *tabBarController = (HRPGTabBarController*)self.tabBarController;
    if (tabBarController.selectedTags == nil || [tabBarController.selectedTags count] == 0) {
        if ([_typeName isEqual:@"todo"] && !self.displayCompleted) {
            predicate = [NSPredicate predicateWithFormat:@"type=='todo' && completed==NO"];
        } else {
            predicate = [NSPredicate predicateWithFormat:@"type==%@", _typeName];
        }
    } else {
        if ([_typeName isEqual:@"todo"]) {
            predicate = [NSPredicate predicateWithFormat:@"type=='todo' && completed==NO && SUBQUERY(tags, $tag, $tag IN %@).@count = %d", tabBarController.selectedTags, [tabBarController.selectedTags count]];
        } else {
            predicate = [NSPredicate predicateWithFormat:@"type==%@ && SUBQUERY(tags, $tag, $tag IN %@).@count = %d", _typeName, tabBarController.selectedTags, [tabBarController.selectedTags count]];
        }
    }
    return predicate;
}

- (void) didSelectTags:(NSNotification *)notification {
    [self.fetchedResultsController.fetchRequest setPredicate:[self getPredicate]];
    NSError *error;
    [self.fetchedResultsController performFetch:&error];
    [self.tableView reloadData];
    HRPGTabBarController *tabBarController = (HRPGTabBarController*)self.tabBarController;
    NSUInteger tagCount = tabBarController.selectedTags.count;
    if (tagCount == 0) {
        self.navigationItem.leftBarButtonItem.title = NSLocalizedString(@"Tags", nil);
    } else if (tagCount == 1) {
        self.navigationItem.leftBarButtonItem.title = NSLocalizedString(@"1 Tag", nil);
    } else {
        NSString *localizedString = NSLocalizedString(@"%d Tags", nil);
        self.navigationItem.leftBarButtonItem.title = [NSString stringWithFormat:localizedString, tagCount] ;
    }
}


#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    if (self.displayCompleted) {
        if ([self.fetchedResultsController sections].count == 0) {
            return 1;
        } else if ([self.fetchedResultsController sections].count == 1) {
            Task *task = (Task*) [self.fetchedResultsController objectAtIndexPath:[NSIndexPath indexPathForItem:0 inSection:0]];
            if ([task.completed boolValue]) {
                return 1;
            } else {
                return 2;
            }
        } else {
            return 2;
        }
    } else {
        return [self.fetchedResultsController sections].count;
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if ([self.fetchedResultsController sections].count == 0) {
        return 0;
    }
    if (section > [self.fetchedResultsController sections].count-1) {
        return 1;
    } else {
        id <NSFetchedResultsSectionInfo> sectionInfo = [self.fetchedResultsController sections][section];
        return [sectionInfo numberOfObjects] + self.indexOffset;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (indexPath.section > [self.fetchedResultsController sections].count-1) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"EmptyCell" forIndexPath:indexPath];
        return cell;
    }
    
    NSString *cellname = @"Cell";
    Task *task = [self taskAtIndexPath:indexPath];
    if (task.duedate) {
        cellname = @"SubCell";
    }
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellname forIndexPath:indexPath];

    UIView *whitespaceView = [cell viewWithTag:6];
    NSLayoutConstraint *whiteSpaceHeightConstraint;
    for (NSLayoutConstraint *con in whitespaceView.constraints) {
        if (con.firstItem == whitespaceView || con.secondItem == whitespaceView) {
            whiteSpaceHeightConstraint = con;
            break;
        }
    }
    if ([self.tableView numberOfRowsInSection:indexPath.section] == indexPath.row+1) {
        whiteSpaceHeightConstraint.constant = 0;
    } else {
        whiteSpaceHeightConstraint.constant = 4;
    }
    
    [self configureCell:cell atIndexPath:indexPath withAnimation:NO];
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {

        if (editingStyle == UITableViewCellEditingStyleDelete) {
            Task *task = [self taskAtIndexPath:indexPath];
            [self.sharedManager deleteTask:task onSuccess:^() {
            }                      onError:^() {

            }];
        }
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section > [self.fetchedResultsController sections].count-1) {
        return 44;
    }
    
    Task *task = [self taskAtIndexPath:indexPath];
    float width;
    NSInteger height = 30;
    if ([task.type isEqualToString:@"habit"]) {
        //50 for each button and 1 for seperator
        width = self.screenWidth - 117;
    } else if ([task.checklist count] > 0) {
        width = self.screenWidth - 110;
    } else {
        width = self.screenWidth - 50;
    }
    height = height + [[task.text stringByReplacingEmojiCheatCodesWithUnicode] boundingRectWithSize:CGSizeMake(width, MAXFLOAT)
                                               options:NSStringDrawingUsesLineFragmentOrigin
                                            attributes:@{
                                                    NSFontAttributeName : [UIFont preferredFontForTextStyle:UIFontTextStyleBody]
                                            }
                                               context:nil].size.height;
    if (task.duedate) {
        height = height + 5;
    }
    return height;
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    return editable;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath == self.openedIndexPath) {
        [self tableView:tableView expandTaskAtIndexPath:self.openedIndexPath];
    }
    editedTask = [self taskAtIndexPath:indexPath];
    [self performSegueWithIdentifier:@"FormSegue" sender:self];
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}


- (IBAction)unwindToList:(UIStoryboardSegue *)segue {
    if ([segue.identifier isEqualToString:@"UnwindTagSegue"]) {
        HRPGTagViewController *tagViewController = (HRPGTagViewController*)segue.sourceViewController;
        HRPGTabBarController *tabBarController = (HRPGTabBarController*)self.tabBarController;
        tabBarController.selectedTags = tagViewController.selectedTags;
        NSUInteger tagCount = tabBarController.selectedTags.count;
        if (tagCount == 0) {
            self.navigationItem.leftBarButtonItem.title = NSLocalizedString(@"Tags", nil);
        } else if (tagCount == 1) {
            self.navigationItem.leftBarButtonItem.title = NSLocalizedString(@"1 Tag", nil);
        } else {
            NSString *localizedString = NSLocalizedString(@"%d Tags", nil);
            self.navigationItem.leftBarButtonItem.title = [NSString stringWithFormat:localizedString, tagCount] ;
        }
        [[NSNotificationCenter defaultCenter] postNotificationName:@"tagsSelected" object:nil];
    }
}

- (IBAction)unwindToListSave:(UIStoryboardSegue *)segue {
    HRPGFormViewController *formViewController = (HRPGFormViewController *) segue.sourceViewController;
    [self addActivityCounter];
    if (formViewController.editTask) {
        [self.sharedManager updateTask:formViewController.task onSuccess:^() {
            [self removeActivityCounter];
        }                      onError:^() {
            [self removeActivityCounter];
        }];
    } else {
        [self.sharedManager createTask:formViewController.task onSuccess:^() {
            [self removeActivityCounter];
        }                      onError:^() {
            [self removeActivityCounter];
        }];
    }
}


- (NSFetchedResultsController *)fetchedResultsController {
    if (_fetchedResultsController != nil) {
        return _fetchedResultsController;
    }

    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"Task" inManagedObjectContext:self.managedObjectContext];
    [fetchRequest setEntity:entity];
    [fetchRequest setFetchBatchSize:20];
    [fetchRequest setPredicate:[self getPredicate]];

    NSSortDescriptor *completedDescriptor = [[NSSortDescriptor alloc] initWithKey:@"completed" ascending:YES];
    NSSortDescriptor *orderDescriptor = [[NSSortDescriptor alloc] initWithKey:@"order" ascending:YES];
    NSSortDescriptor *dateDescriptor = [[NSSortDescriptor alloc] initWithKey:@"dateCreated" ascending:NO];
    NSArray *sortDescriptors;
    NSString *sectionKey;
    if ([_typeName isEqual:@"todo"]) {
        sectionKey = @"completed";
        sortDescriptors = @[completedDescriptor, orderDescriptor, dateDescriptor];
    } else {
        sortDescriptors = @[orderDescriptor, dateDescriptor];
    }

    [fetchRequest setSortDescriptors:sortDescriptors];

    NSFetchedResultsController *aFetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest managedObjectContext:self.managedObjectContext sectionNameKeyPath:sectionKey cacheName:nil];
    aFetchedResultsController.delegate = self;
    self.fetchedResultsController = aFetchedResultsController;

    NSError *error = nil;
    if (![self.fetchedResultsController performFetch:&error]) {
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
        abort();
    }

    return _fetchedResultsController;
}


- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller {
    [self.tableView beginUpdates];
}

- (void)controller:(NSFetchedResultsController *)controller didChangeSection:(id <NSFetchedResultsSectionInfo>)sectionInfo
           atIndex:(NSUInteger)sectionIndex forChangeType:(NSFetchedResultsChangeType)type {
    switch (type) {
        case NSFetchedResultsChangeInsert:
            [self.tableView insertSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationFade];
            break;

        case NSFetchedResultsChangeDelete:
            [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeUpdate:
            [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationAutomatic];
            break;
            
        case NSFetchedResultsChangeMove:
            break;
    }
}

- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject
       atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type
      newIndexPath:(NSIndexPath *)newIndexPath {
    UITableView *tableView = self.tableView;


    switch (type) {
        case NSFetchedResultsChangeInsert:
            if (self.openedIndexPath) {
                [self tableView:tableView expandTaskAtIndexPath:self.openedIndexPath];
            }
            [tableView insertRowsAtIndexPaths:@[[self indexPathWithOffset:newIndexPath]] withRowAnimation:UITableViewRowAnimationFade];
            break;

        case NSFetchedResultsChangeDelete: {
            if (self.openedIndexPath) {
                if (indexPath.section == self.openedIndexPath.section && indexPath.item == self.openedIndexPath.item) {
                    [tableView deleteRowsAtIndexPaths:[self checklistitemIndexPathsWithOffset:self.indexOffset atIndexPath:indexPath] withRowAnimation:UITableViewRowAnimationFade];
                    self.openedIndexPath = nil;
                    self.indexOffset = 0;
                }
            }
            [tableView deleteRowsAtIndexPaths:@[[self indexPathWithOffset:indexPath]] withRowAnimation:UITableViewRowAnimationFade];
            break;
        }

        case NSFetchedResultsChangeUpdate:
            [self configureCell:[tableView cellForRowAtIndexPath:[self indexPathWithOffset:indexPath]] atIndexPath:[self indexPathWithOffset:indexPath] withAnimation:YES];
            break;

        case NSFetchedResultsChangeMove:
            if (self.openedIndexPath) {
                [self tableView:tableView expandTaskAtIndexPath:self.openedIndexPath];
            }
            [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
            [tableView insertRowsAtIndexPaths:@[newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
    }
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller {
    [self.tableView endUpdates];
}

- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath withAnimation:(BOOL)animate {
    NSManagedObject *object = [self.fetchedResultsController objectAtIndexPath:indexPath];
    cell.textLabel.text = [[object valueForKey:@"text"] description];
}


- (UIView *)viewWithIcon:(UIImage *)image {
    UIImageView *imageView = [[UIImageView alloc] initWithImage:image];
    imageView.contentMode = UIViewContentModeCenter;
    return imageView;
}

- (void) tableView:(UITableView *)tableView expandTaskAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section > [self.fetchedResultsController sections].count-1) {
        return;
    }
    
    if (indexPath.section == 1) {
        return;
    }
    
    if (self.openedIndexPath != nil && self.openedIndexPath.item == indexPath.item) {
        NSIndexPath *tempPath = self.openedIndexPath;
        self.openedIndexPath = nil;
        [self configureCell:[tableView cellForRowAtIndexPath:tempPath] atIndexPath:tempPath withAnimation:YES];
        [self.tableView beginUpdates];
        [self.tableView deleteRowsAtIndexPaths:[self checklistitemIndexPathsWithOffset:self.indexOffset atIndexPath:indexPath] withRowAnimation:UITableViewRowAnimationTop];
        self.indexOffset = 0;
        [self.tableView endUpdates];
    } else {
        if (self.openedIndexPath) {
            if (indexPath.section == self.openedIndexPath.section && indexPath.item > self.openedIndexPath.item) {
                indexPath = [NSIndexPath indexPathForItem:indexPath.item-self.indexOffset inSection:indexPath.section];
            }
            [self.tableView beginUpdates];
            [self tableView:tableView expandTaskAtIndexPath:self.openedIndexPath];
            [self.tableView endUpdates];
        }
        
        Task *task = [self taskAtIndexPath:indexPath];
        if ([task.checklist count] > 0) {
            self.openedIndexPath = indexPath;
            self.indexOffset = (int) [task.checklist count];
            [self configureCell:[tableView cellForRowAtIndexPath:indexPath] atIndexPath:indexPath withAnimation:YES];
            [self.tableView beginUpdates];
            [self.tableView insertRowsAtIndexPaths:[self checklistitemIndexPathsWithOffset:self.indexOffset atIndexPath:indexPath] withRowAnimation:UITableViewRowAnimationTop];
            [self.tableView endUpdates];
        }
    }
}

- (NSIndexPath*)indexPathForTaskWithOffset:(NSIndexPath*) indexPath {
    if (self.openedIndexPath.item + self.indexOffset < indexPath.item && self.indexOffset > 0) {
        return [NSIndexPath indexPathForItem:indexPath.item - self.indexOffset inSection:indexPath.section];
    } else if (self.openedIndexPath.item + self.indexOffset >= indexPath.item && self.openedIndexPath.item < indexPath.item && self.indexOffset > 0) {
        return self.openedIndexPath;
    } else {
        return indexPath;
    }
}

- (NSIndexPath*)indexPathWithOffset:(NSIndexPath*) indexPath {
    if (self.openedIndexPath.item < indexPath.item) {
        return [NSIndexPath indexPathForItem:indexPath.item + self.indexOffset inSection:indexPath.section];
    } else {
        return indexPath;
    }
}

- (Task*)taskAtIndexPath:(NSIndexPath*)indexPath {
    if (self.openedIndexPath.item + self.indexOffset < indexPath.item && self.indexOffset > 0) {
        indexPath = [NSIndexPath indexPathForItem:indexPath.item - self.indexOffset inSection:indexPath.section];
    } else if (self.openedIndexPath.item + self.indexOffset >= indexPath.item && self.openedIndexPath.item < indexPath.item && self.indexOffset > 0) {
        indexPath = self.openedIndexPath;
    }
    if (self.fetchedResultsController.sections.count > indexPath.section) {
        id <NSFetchedResultsSectionInfo> sectionInfo = [self.fetchedResultsController sections][indexPath.section];
        if ([sectionInfo numberOfObjects] > indexPath.item) {
            return [self.fetchedResultsController objectAtIndexPath:indexPath];
        }
    }
    return nil;
}

- (NSArray*)checklistitemIndexPathsWithOffset:(NSInteger)offset atIndexPath:(NSIndexPath*)indexPath {
    NSMutableArray *array = [[NSMutableArray alloc] init];
    for (int i = 1; i <= offset; i++) {
        [array addObject:[NSIndexPath indexPathForItem:indexPath.item + i inSection:indexPath.section]];
    }
    return array;
}

- (NSArray*)checklistitemIndexPathsForTask:(Task*)task atIndexPath:(NSIndexPath*)indexPath {
    NSMutableArray *array = [[NSMutableArray alloc] init];
    for (int i = 1; i <= task.checklist.count; i++) {
        [array addObject:[NSIndexPath indexPathForItem:indexPath.item + i inSection:indexPath.section]];
    }
    return array;
}

#pragma mark - Navigation

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"FormSegue"]) {
        HRPGNavigationController *destViewController = segue.destinationViewController;
        destViewController.sourceViewController = self;
        
        HRPGFormViewController *formController = (HRPGFormViewController *) destViewController.topViewController;
        formController.taskType = self.typeName;
        formController.readableTaskType = self.readableName;
        HRPGTabBarController *tabBarController = (HRPGTabBarController*) self.tabBarController;
        formController.activeTags = tabBarController.selectedTags;
        if (editedTask) {
            formController.editTask = YES;
            formController.task = editedTask;
            editedTask = nil;
        }
    } else if ([segue.identifier isEqualToString:@"TagSegue"]) {
        HRPGTabBarController *tabBarController = (HRPGTabBarController*)self.tabBarController;
        HRPGNavigationController *navigationController = (HRPGNavigationController *) segue.destinationViewController;
        navigationController.sourceViewController = self;
        HRPGTagViewController *tagController = (HRPGTagViewController *) navigationController.topViewController;
        tagController.selectedTags = [tabBarController.selectedTags mutableCopy];
    }
}



@end
