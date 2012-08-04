//
//  TasksViewController.m
//  tasker
//
//  Created by Thomas Gamble on 6/17/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "TasksViewController.h"
#import "TaskCell.h"
#import "Task.h"
#import "UIImage+Resize.h"
#import "UITableViewController+NextPhotoId.h"
#import "UITableViewController+DateString.h"
#import <SDWebImage/UIImageView+WebCache.h>


@interface TasksViewController ()

@end

@implementation TasksViewController{
    NSFetchedResultsController *fetchedResultsController;
}

@synthesize managedObjectContext;
@synthesize objectManager;
@synthesize userEmail;
@synthesize addButton;
@synthesize loginButton;


  static const int ddLogLevel = LOG_LEVEL_INFO;

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {

    }
    return self;
}

- (void)viewDidLoad
{
    DDLogVerbose(@"View did load");
    
    [self getUserInfo];
    
    [self getTasks];
    
    [super viewDidLoad];
    [self configureUI];
    
    [self performFetch];
    
}

- (void)viewDidUnload
{
    DDLogVerbose(@"View did unload");
    [self setAddButton:nil];
    [self setLoginButton:nil];
    [super viewDidUnload];
    
    fetchedResultsController.delegate = nil;
    fetchedResultsController = nil;    
    userEmail = nil;

}

-(void)dealloc
{
    fetchedResultsController.delegate = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

/*
-(IBAction)launchFeedback {
    [TestFlight openFeedbackView];
}
*/


#pragma mark - Table view data source

/*
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}
*/

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    DDLogVerbose(@"Number of rows in section");
    if(userEmail==nil)
    {
        return 0;
    
    } else {
    id <NSFetchedResultsSectionInfo> sectionInfo = [[self.fetchedResultsController sections] objectAtIndex:section];
    DDLogVerbose(@"Number of objects is: %d", [sectionInfo numberOfObjects]);
    return [sectionInfo numberOfObjects];
    }
}

-(void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath
{
    DDLogVerbose(@"Configuring cell");
    TaskCell *taskCell = (TaskCell *)cell;
    Task *task = [self.fetchedResultsController objectAtIndexPath:indexPath];

    taskCell.title.text = task.title;
    
    taskCell.dueDate.text = [self getDateString:task.dueDate];

    [self getCellImage:taskCell:task];
    
    if([task isComplete]) {
        taskCell.completeCheck.hidden = NO;
    }
    else {
        taskCell.completeCheck.hidden = YES;
    }
    
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    DDLogVerbose(@"Cell for row and index path");
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Task"];
    [self configureCell:cell atIndexPath:indexPath];
    return cell;
}



/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/


// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    DDLogVerbose(@"User initiated delete");
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        Task *task = [self.fetchedResultsController objectAtIndexPath:indexPath];
        [self deleteRemote:task];
        [task removePhotoFiles];
        [self.managedObjectContext deleteObject:task];
        
        NSError *error;
        if (![self.managedObjectContext save:&error]) {
            FATAL_CORE_DATA_ERROR(error);
            return;
        }
    }
}


/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath
{
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    DDLogVerbose(@"Preparing for seque");
    if([segue.identifier isEqualToString:@"AddTask"]) {
        UINavigationController *navigationController = segue.destinationViewController;
        TaskDetailViewController *controller = (TaskDetailViewController *)navigationController.topViewController;
        controller.managedObjectContext = self.managedObjectContext;
        controller.objectManager = objectManager;
        controller.delegate = self;
        controller.userEmail = self.userEmail;
        controller.taskEdit = FALSE;
    }
         
    if([segue.identifier isEqualToString:@"EditTask"]) {
        UINavigationController *navigationController = segue.destinationViewController;
        TaskDetailViewController *controller = (TaskDetailViewController *)navigationController.topViewController;
        controller.managedObjectContext = self.managedObjectContext;
        
        NSIndexPath *indexPath = [self.tableView indexPathForCell:sender];
        Task *task = [self.fetchedResultsController objectAtIndexPath:indexPath];
        controller.taskToEdit = task;
        controller.userEmail = self.userEmail;
        controller.objectManager = objectManager;
        controller.delegate = self;
        controller.taskEdit = TRUE;
    }
    
    if([segue.identifier isEqualToString:@"Login"]) {
        self.userEmail = nil;
        self.loginButton.title = @"Login";
        [[NSUserDefaults standardUserDefaults] setValue:nil forKey:@"UserEmail"];
        UINavigationController *navigationController = segue.destinationViewController;
        LoginViewController *controller = (LoginViewController *)navigationController.topViewController;
        controller.managedObjectContext = self.managedObjectContext;
        
        controller.delegate = self;
    }
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Navigation logic may go here. Create and push another view controller.
    /*
     <#DetailViewController#> *detailViewController = [[<#DetailViewController#> alloc] initWithNibName:@"<#Nib name#>" bundle:nil];
     // ...
     // Pass the selected object to the new view controller.
     [self.navigationController pushViewController:detailViewController animated:YES];
     */
}

#pragma mark - NSFetchedResultsControllerDelegate

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller
{
    DDLogVerbose(@"*** controllerWillChangeContent");
    [self.tableView beginUpdates];
}

- (void)controller:(NSFetchedResultsController *)controller
   didChangeObject:(id)anObject
       atIndexPath:(NSIndexPath *)indexPath
     forChangeType:(NSFetchedResultsChangeType)type
      newIndexPath:(NSIndexPath *)newIndexPath
{
    switch (type) {
        case NSFetchedResultsChangeInsert:
            DDLogVerbose(@"*** controllerDidChangeObject - NSFetchedResultsChangeInsert");
            [self.tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeDelete:
            DDLogVerbose(@"*** controllerDidChangeObject - NSFetchedResultsChangeDelete");
            [self.tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeUpdate:
            DDLogVerbose(@"*** controllerDidChangeObject - NSFetchedResultsChangeUpdate");
            [self configureCell:[self.tableView cellForRowAtIndexPath:indexPath] atIndexPath:indexPath];
            break;
            
        case NSFetchedResultsChangeMove:
            DDLogVerbose(@"*** controllerDidChangeObject - NSFetchedResultsChangeMove");
            [self.tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
            [self.tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
    }
}

- (void)controller:(NSFetchedResultsController *)controller
  didChangeSection:(id <NSFetchedResultsSectionInfo>)sectionInfo
           atIndex:(NSUInteger)sectionIndex
     forChangeType:(NSFetchedResultsChangeType)type
{
    switch (type) {
        case NSFetchedResultsChangeInsert:
            DDLogVerbose(@"*** controllerDidChangeSection - NSFetchedResultsChangeInsert");
            [self.tableView insertSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeDelete:
            DDLogVerbose(@"*** controllerDidChangeSection - NSFetchedResultsChangeDelete");
            [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationFade];
            break;
    }
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
    DDLogVerbose(@"*** controllerDidChangeContent");
    [self.tableView endUpdates];
    
    NSError *error;
    if(![self.managedObjectContext save:&error]) {
        FATAL_CORE_DATA_ERROR(error);
        return;
    }
    else
    {
        DDLogInfo(@"Saved context");
    }
}


#pragma mark - Login Delegate

- (void)loginCompleted:(LoginViewController *)login didLogin:(NSString *)theUserEmail
{
    self.addButton.enabled = TRUE;
    self.loginButton.title = @"Logout";
    
    [[NSUserDefaults standardUserDefaults] setValue:theUserEmail forKey:@"UserEmail"];
    
    self.userEmail = theUserEmail;
    [self dismissModalViewControllerAnimated:NO];
    
    [NSFetchedResultsController deleteCacheWithName:@"Tasks"];
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"completor == %@", self.userEmail];
    [self.fetchedResultsController.fetchRequest setPredicate:predicate];

    [self getTasks];
    
    [self performFetch];
    
    [self.tableView reloadData];
    
    [TestFlight passCheckpoint:@"SUCCESFUL LOGIN"];
    
}

-(void)loginCancelled:(LoginViewController *)login
{
    [self dismissModalViewControllerAnimated:NO];
    
    [NSFetchedResultsController deleteCacheWithName:@"Tasks"];
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"completor == %@", self.userEmail];
    [self.fetchedResultsController.fetchRequest setPredicate:predicate];
    
    [self.tableView reloadData];
    
    [TestFlight passCheckpoint:@"CANCELLED LOGIN"];
}

#pragma mark - Task Detail Delegate

-(void)taskDetailCancelled:(TaskDetailViewController *)taskDetail 
{
   [self dismissModalViewControllerAnimated:NO];
}

-(void)sendTask:(Task *)task withMethod:(RKRequestMethod)method {
    
    NSDictionary *queryParams = [NSDictionary dictionaryWithObjectsAndKeys:
                                 task.title, @"title",
                                 task.creator, @"creator",
                                 task.status, @"status",
                                 task.completor, @"completor",
                                 task.taskID, @"taskID",
                                 task.taskDescription, @"taskDescription",
                                 task.dueDate, @"dueDate",
                                 task.completedDate, @"completedDate",
                                 nil];
    NSString *resourcePath = [TASK_PATH stringByAppendingQueryParameters:queryParams];
    DDLogInfo(@"%@", resourcePath);
    [objectManager loadObjectsAtResourcePath:resourcePath usingBlock:^(RKObjectLoader *loader) {
        loader.delegate = self;
        loader.method = method;
        loader.targetObject = task;
        
        if(([task hasBeforePhoto]) && (task.beforePhotoUrl==nil))
        {
            DDLogInfo(@"Trying to send image");
            RKParams *params = [RKParams params];
            NSData *data = UIImagePNGRepresentation([task photoImage:task.beforePhotoId]);
            [params setData:data MIMEType:@"image/png" forParam:@"beforeimage"];
            loader.params = params;
        }
    }];
    
}

-(void)taskDetailCompleted:(TaskDetailViewController *)taskDetail forTask:(Task *)task updateMethod:(RKRequestMethod)method
{
    DDLogVerbose(@"Task detail completed with update");
    [self dismissModalViewControllerAnimated:NO];
    [self sendTask:task withMethod:method];
}

-(void)taskDetailCompleted:(TaskDetailViewController *)taskDetail
{
    DDLogVerbose(@"Task detail completed");
//    [self.tableView reloadData];
    [self dismissModalViewControllerAnimated:NO];
}

#pragma utility functions

-(void)getCellImage:(TaskCell *)taskCell:(Task *)task
{
    UIImage *image = nil;
    if([task hasBeforePhoto]) {
        image = [task photoImage:task.beforePhotoId];
        if(image!=nil) {
            image = [image resizedImageWithBounds:CGSizeMake(60, 60)];
            taskCell.imageView.image = image;
        }
        else if(task.beforePhotoUrl==nil && task.beforePhotoId == 0)
        {
            DDLogWarn(@"Resetting photoID as no photoURL was found");
            task.beforePhotoId = [NSNumber numberWithInt:-1];
            
        } else if ([task.beforePhotoId intValue] != -1) {
            #if DEBUG
            NSString *tempString = [NSString stringWithFormat:@"%@%@", HOST, task.beforePhotoUrl.path];
            DDLogVerbose(@"%@", tempString);
            NSURL *url = [[NSURL alloc] initWithString:tempString];
            #else
            NSURL *url = task.beforePhotoUrl;
            #endif
            
            task.beforePhotoId = [NSNumber numberWithInt:-1];
            [taskCell.imageView setImageWithURL:url success:^(UIImage *newImage) {
                
                NSData *data = UIImagePNGRepresentation(newImage);
                taskCell.imageView.image = [taskCell.imageView.image resizedImageWithBounds:CGSizeMake(60, 60)];
                
                task.beforePhotoId = [NSNumber numberWithInt:[self nextPhotoId]];
                DDLogInfo(@"Succesfull image download for photoID: %@", task.beforePhotoId);
                NSError *error;
                if (![data writeToFile:[task photoPath:task.beforePhotoId]   options:NSDataWritingAtomic error:&error]) {
                    DDLogError(@"Error writing file: %@", error);
                    if([task photoPath:task.beforePhotoId]==nil)
                    {
                        DDLogWarn(@"Resetting photoID due to error");
                        task.beforePhotoId = [NSNumber numberWithInt:-1];
                    }
                }
                
            } failure:^(NSError *error) {
                DDLogError(@"Error downloading image: %@", [error localizedDescription]);
            }
             
             ];
            
        }
    }
    else{
        taskCell.imageView.image = nil;
    }
    
}

-(void)getUserInfo
{
    self.userEmail = [[NSUserDefaults standardUserDefaults] valueForKey:@"UserEmail"];
}

-(void)configureUI
{
    if(self.userEmail == nil) {
        addButton.enabled = FALSE;
    }
    else {
        self.addButton.enabled = TRUE;
        self.loginButton.title = @"Logout";
    }
}

#pragma Data Access 

-(NSPredicate *)currentPredicate
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"completor == %@", self.userEmail];
    return predicate;
    
}

-(NSFetchedResultsController *)fetchedResultsController
{
    DDLogVerbose(@"Getting fetched results controller");
    if (fetchedResultsController == nil) {
        
        NSFetchRequest *fetchRequest = [[[RKObjectManager sharedManager]
                                         mappingProvider] fetchRequestForResourcePath:TASK_PATH];
        
        [NSFetchedResultsController deleteCacheWithName:@"Tasks"];
        
        [fetchRequest setFetchBatchSize:20];
        
        [fetchRequest setPredicate:[self currentPredicate]];
        
        fetchedResultsController = [[NSFetchedResultsController alloc]
                                    initWithFetchRequest:fetchRequest managedObjectContext:managedObjectContext sectionNameKeyPath:nil cacheName:@"Tasks"];
        
        fetchedResultsController.delegate = self;
    }
    return fetchedResultsController;
}


-(void)getTasks
{
    DDLogVerbose(@"Getting tasks");
    DDLogInfo(@"Host name is %@", HOST);
    if(userEmail!=nil)
    {
        NSDictionary *queryParams = [NSDictionary dictionaryWithObjectsAndKeys:self.userEmail, @"user", nil];
        NSString *resourcePath = [TASK_PATH stringByAppendingQueryParameters:queryParams];
        DDLogVerbose(@"%@", resourcePath);
        [objectManager loadObjectsAtResourcePath:resourcePath delegate:self];
    }
}

-(void)performFetch
{
    DDLogVerbose(@"Performing fetch");
    NSError *error;
    if(![self.fetchedResultsController performFetch:&error])
    {
        FATAL_CORE_DATA_ERROR(error);
        return;
    }
    else{
#if DEBUG
        DDLogVerbose(@"Fetch succesful");
        id <NSFetchedResultsSectionInfo> sectionInfo = [[self.fetchedResultsController sections] objectAtIndex:0];
        DDLogInfo(@"Number objects fetched: %d", [sectionInfo numberOfObjects]);
#endif
    }
}

- (void)objectLoader:(RKObjectLoader *)objectLoader didFailWithError:(NSError *)error
{
    DDLogError(@"Error: %@", [error localizedDescription]);
}

- (void)request:(RKRequest*)request didLoadResponse:(RKResponse*)response {
    DDLogVerbose(@"response code: %d", [response statusCode]);
    DDLogVerbose(@"response is: %@", [response bodyAsString]);
}

- (void)objectLoader:(RKObjectLoader *)objectLoader didLoadObjects:(NSArray *)objects
{
    DDLogInfo(@"Objectloader loaded objects[%d]", [objects count]);
}

-(void)deleteRemote:(Task *)task {
    DDLogVerbose(@"Contacting server to delete %@", task.title);
    NSDictionary *queryParams = [NSDictionary dictionaryWithObjectsAndKeys:
                                 task.taskID, @"taskID",
                                 nil];
    NSString *resourcePath = [TASK_PATH stringByAppendingQueryParameters:queryParams];
    
    [objectManager loadObjectsAtResourcePath:resourcePath usingBlock:^(RKObjectLoader *loader) {
        loader.delegate = self;
        loader.method = RKRequestMethodDELETE;
    }];
}

/*
 -(void)objectLoaderDidFinishLoading:(RKObjectLoader *)objectLoader{
 
 }
 */

@end
