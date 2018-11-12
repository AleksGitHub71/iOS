
#import "MEGAStore.h"

#import "NSString+MNZCategory.h"

@interface MEGAStore ()

@property (strong, nonatomic) NSManagedObjectModel *managedObjectModel;
@property (strong, nonatomic) NSManagedObjectContext *managedObjectContext;
@property (strong, nonatomic) NSPersistentStoreCoordinator *persistentStoreCoordinator;

@end

@implementation MEGAStore

static MEGAStore *_megaStore = nil;

#pragma mark - Singleton Lifecycle

+ (MEGAStore *)shareInstance {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _megaStore = [[self alloc] init];
    });
    return _megaStore;
}

- (instancetype)init {
    self = [super init];
    if (self != nil) {
        [self configureMEGAStore];
    }
    
    return self;
}

- (void)configureMEGAStore {
    _managedObjectModel = [NSManagedObjectModel mergedModelFromBundles:nil];
    NSURL *storeURL = [self storeURL];
    
    NSError *error = nil;
    _persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:_managedObjectModel];
    NSDictionary *options = @{ NSMigratePersistentStoresAutomaticallyOption : @YES,
                              NSInferMappingModelAutomaticallyOption : @YES };
    
    if (![_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:options error:&error]) {
        MEGALogError(@"Unresolved error %@, %@", error, error.userInfo);
        abort();
    }
    
    if (_persistentStoreCoordinator != nil) {
        _managedObjectContext = [[NSManagedObjectContext alloc] init];
        [_managedObjectContext setPersistentStoreCoordinator:_persistentStoreCoordinator];
    }
}

- (NSURL *)storeURL {
    NSString *dbName = @"MEGACD.sqlite";
    NSError *error;
    NSFileManager *fileManager = NSFileManager.defaultManager;
    NSURL *groupSupportURL = [[fileManager containerURLForSecurityApplicationGroupIdentifier:@"group.mega.ios"] URLByAppendingPathComponent:@"GroupSupport"];
    if (![fileManager fileExistsAtPath:groupSupportURL.path]) {
        if (![fileManager createDirectoryAtURL:groupSupportURL withIntermediateDirectories:NO attributes:nil error:&error]) {
            MEGALogError(@"Error creating GroupSupport directory in the shared sandbox: %@", error);
            abort();
        }
    }
    
    NSURL *applicationSupportDirectoryURL = [fileManager URLForDirectory:NSApplicationSupportDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:NO error:nil];
    NSURL *oldStoreURL = [applicationSupportDirectoryURL URLByAppendingPathComponent:dbName];
    NSURL *newStoreURL = [groupSupportURL URLByAppendingPathComponent:dbName];

    if ([fileManager fileExistsAtPath:oldStoreURL.path]) {
        if (![fileManager moveItemAtURL:oldStoreURL toURL:newStoreURL error:&error]) {
            MEGALogError(@"Error moving MEGACD.sqlite to the GroupSupport directory in the shared sandbox: %@", error);
        }
    }
    
    return newStoreURL;
}

- (void)saveContext {
    NSError *error = nil;
    if ([self.managedObjectContext hasChanges] && ![self.managedObjectContext save:&error]) {
        MEGALogError(@"Unresolved error %@, %@", error, [error userInfo]);
        abort();
    }
}

#pragma mark - MOOfflineNode entity

- (void)insertOfflineNode:(MEGANode *)node api:(MEGASdk *)api path:(NSString *)path {
    if (!node.base64Handle || !path) return;
    
    MOOfflineNode *offlineNode = [NSEntityDescription insertNewObjectForEntityForName:@"OfflineNode" inManagedObjectContext:self.managedObjectContext];

    [offlineNode setBase64Handle:node.base64Handle];
    [offlineNode setParentBase64Handle:[[api parentNodeForNode:[api nodeForHandle:node.handle]] base64Handle]];
    [offlineNode setLocalPath:path];
    [offlineNode setFingerprint:node.fingerprint];

    MEGALogDebug(@"Save context: insert offline node: %@", offlineNode);
    
    [self saveContext];
}

- (MOOfflineNode *)fetchOfflineNodeWithPath:(NSString *)path {
    NSEntityDescription *entityDescription = [NSEntityDescription entityForName:@"OfflineNode" inManagedObjectContext:self.managedObjectContext];
    
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    [request setEntity:entityDescription];
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"localPath == %@", path];
    [request setPredicate:predicate];
    
    NSError *error;
    NSArray *array = [self.managedObjectContext executeFetchRequest:request error:&error];

    return [array firstObject];
}

- (MOOfflineNode *)offlineNodeWithNode:(MEGANode *)node {
    NSEntityDescription *entityDescription = [NSEntityDescription entityForName:@"OfflineNode" inManagedObjectContext:self.managedObjectContext];
    
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    [request setEntity:entityDescription];

    NSPredicate *predicate;
    NSString *fingerprint = node.fingerprint;
    if(fingerprint) {
        predicate = [NSPredicate predicateWithFormat:@"fingerprint == %@", fingerprint];
    } else {
        predicate = [NSPredicate predicateWithFormat:@"base64Handle == %@", node.base64Handle];
    }
    
    [request setPredicate:predicate];
    
    NSError *error;
    NSArray *array = [self.managedObjectContext executeFetchRequest:request error:&error];
    
    return [array firstObject];

}

- (void)removeOfflineNode:(MOOfflineNode *)offlineNode {
    [self.managedObjectContext deleteObject:offlineNode];
    MEGALogDebug(@"Save context - remove offline node: %@", offlineNode);
    [self saveContext];
}

- (void)removeAllOfflineNodes {
    NSFetchRequest *allOfflineNodes = [[NSFetchRequest alloc] init];
    [allOfflineNodes setEntity:[NSEntityDescription entityForName:@"OfflineNode" inManagedObjectContext:self.managedObjectContext]];
    [allOfflineNodes setIncludesPropertyValues:NO]; //only fetch the managedObjectID
    
    NSError *error = nil;
    NSArray *offlineNodes = [self.managedObjectContext executeFetchRequest:allOfflineNodes error:&error];

    for (NSManagedObject *offNode in offlineNodes) {
        MEGALogDebug(@"Save context - remove offline node: %@", offNode);
        [self.managedObjectContext deleteObject:offNode];
    }
    
    [self saveContext];
}

#pragma mark - MOUser entity

- (void)insertUserWithUserHandle:(uint64_t)userHandle firstname:(NSString *)firstname lastname:(NSString *)lastname email:(NSString *)email {
    NSString *base64userHandle = [MEGASdk base64HandleForUserHandle:userHandle];
    
    if (!base64userHandle) return;
    
    MOUser *moUser          = [NSEntityDescription insertNewObjectForEntityForName:@"User" inManagedObjectContext:self.managedObjectContext];
    moUser.base64userHandle = base64userHandle;
    moUser.firstname        = firstname;
    moUser.lastname         = lastname;
    moUser.email            = email;
    
    MEGALogDebug(@"Save context - insert user: %@", moUser.description);
    
    [self saveContext];
}

- (void)updateUserWithUserHandle:(uint64_t)userHandle firstname:(NSString *)firstname {
    MOUser *moUser = [[MEGAStore shareInstance] fetchUserWithUserHandle:userHandle];
    
    if (moUser) {
        moUser.firstname = firstname;
        MEGALogDebug(@"Save context - update firstname: %@", firstname);
        [self saveContext];
    }
}

- (void)updateUserWithUserHandle:(uint64_t)userHandle lastname:(NSString *)lastname {
    MOUser *moUser = [[MEGAStore shareInstance] fetchUserWithUserHandle:userHandle];
    
    if (moUser) {
        moUser.lastname = lastname;
        MEGALogDebug(@"Save context - update lastname: %@", lastname);
        [self saveContext];
    }
}

- (void)updateUserWithUserHandle:(uint64_t)userHandle email:(NSString *)email {
    MOUser *moUser = [[MEGAStore shareInstance] fetchUserWithUserHandle:userHandle];
    
    if (moUser) {
        moUser.email = email;
        MEGALogDebug(@"Save context - update email: %@", email);
        [self saveContext];
    }
}

- (void)updateUserWithEmail:(NSString *)email firstname:(NSString *)firstname {
    MOUser *moUser = [[MEGAStore shareInstance] fetchUserWithEmail:email];
    
    if (moUser) {
        moUser.firstname = firstname;
        MEGALogDebug(@"Save context - update firstname: %@", firstname);
        [self saveContext];
    }
}

- (void)updateUserWithEmail:(NSString *)email lastname:(NSString *)lastname {
    MOUser *moUser = [[MEGAStore shareInstance] fetchUserWithEmail:email];

    if (moUser) {
        moUser.lastname = lastname;
        MEGALogDebug(@"Save context - update lastname: %@", lastname);
        [self saveContext];
    }
}

- (MOUser *)fetchUserWithUserHandle:(uint64_t)userHandle {
    NSEntityDescription *entityDescription = [NSEntityDescription entityForName:@"User" inManagedObjectContext:self.managedObjectContext];
    
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    [request setEntity:entityDescription];
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"base64userHandle == %@", [MEGASdk base64HandleForUserHandle:userHandle]];
    [request setPredicate:predicate];
    
    NSError *error;
    NSArray *array = [self.managedObjectContext executeFetchRequest:request error:&error];
    
    return [array firstObject];
}

- (MOUser *)fetchUserWithEmail:(NSString *)email {
    NSEntityDescription *entityDescription = [NSEntityDescription entityForName:@"User" inManagedObjectContext:self.managedObjectContext];
    
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    [request setEntity:entityDescription];
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"email == %@", email];
    [request setPredicate:predicate];
    
    NSError *error;
    NSArray *array = [self.managedObjectContext executeFetchRequest:request error:&error];
    
    return [array firstObject];
}

#pragma mark - MOChatDraft entity

- (void)insertOrUpdateChatDraftWithChatId:(uint64_t)chatId text:(NSString *)text {
    MOChatDraft *moChatDraft = [self fetchChatDraftWithChatId:chatId];
    if (!text.mnz_isEmpty) {
        if (moChatDraft) {
            moChatDraft.text = text;
            
            MEGALogDebug(@"Save context - update chat draft with chatId %@ and text %@", moChatDraft.chatId, moChatDraft.text);
        } else {
            MOChatDraft *moChatDraft = [NSEntityDescription insertNewObjectForEntityForName:@"ChatDraft" inManagedObjectContext:self.managedObjectContext];
            moChatDraft.chatId = [NSNumber numberWithUnsignedLongLong:chatId];
            moChatDraft.text = text;
            
            MEGALogDebug(@"Save context - insert chat draft with chatId %@ and text %@", moChatDraft.chatId, moChatDraft.text);
        }
    } else if (moChatDraft) {
        [self.managedObjectContext deleteObject:moChatDraft];
        
        MEGALogDebug(@"Save context - remove chat draft with chatId %@", moChatDraft.chatId);
    }

    [self saveContext];
}

- (MOChatDraft *)fetchChatDraftWithChatId:(uint64_t)chatId {
    NSFetchRequest *request = [MOChatDraft fetchRequest];
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"chatId == %@", [NSNumber numberWithUnsignedLongLong:chatId]];
    request.predicate = predicate;
    
    NSError *error;
    NSArray *array = [self.managedObjectContext executeFetchRequest:request error:&error];
    
    return array.firstObject;
}

#pragma mark - MOMediaDestination entity

- (void)insertOrUpdateMediaDestinationWithFingerprint:(NSString *)fingerprint destination:(NSNumber *)destination timescale:(NSNumber *)timescale {
    MOMediaDestination *moMediaDestination = [self fetchMediaDestinationWithFingerprint:fingerprint];
    
    if (moMediaDestination) {
        moMediaDestination.destination = destination;
        moMediaDestination.timescale = timescale;
        
        MEGALogDebug(@"Save context - update media destination with fingerprint %@ and destination %@", moMediaDestination.fingerprint, moMediaDestination.destination);
    } else {
        MOMediaDestination *moMediaDestination = [NSEntityDescription insertNewObjectForEntityForName:@"MediaDestination" inManagedObjectContext:self.managedObjectContext];
        moMediaDestination.fingerprint = fingerprint;
        moMediaDestination.destination = destination;
        moMediaDestination.timescale = timescale;

        MEGALogDebug(@"Save context - insert media destination with fingerprint %@ and destination %@", moMediaDestination.fingerprint, moMediaDestination.destination);
    }
    
    [self saveContext];
}

- (void)deleteMediaDestinationWithFingerprint:(NSString *)fingerprint {
    MOMediaDestination *moMediaDestination = [self fetchMediaDestinationWithFingerprint:fingerprint];

    if (moMediaDestination) {
        [self.managedObjectContext deleteObject:moMediaDestination];
        
        MEGALogDebug(@"Save context - remove media destination with fingerprint %@", moMediaDestination.fingerprint);
    }
    
    [self saveContext];
}

- (MOMediaDestination *)fetchMediaDestinationWithFingerprint:(NSString *)fingerprint {
    NSFetchRequest *request = [MOMediaDestination fetchRequest];
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"fingerprint == %@", fingerprint];
    request.predicate = predicate;
    
    NSError *error;
    NSArray *array = [self.managedObjectContext executeFetchRequest:request error:&error];
    
    return array.firstObject;
}

#pragma mark - MOUploadTransfer entity

- (void)insertUploadTransferWithLocalIdentifier:(NSString *)localIdentifier parentNodeHandle:(uint64_t)parentNodeHandle {
    MOUploadTransfer *mOUploadTransfer = [NSEntityDescription insertNewObjectForEntityForName:@"MOUploadTransfer" inManagedObjectContext:self.managedObjectContext];
    mOUploadTransfer.localIdentifier = localIdentifier;
    mOUploadTransfer.parentNodeHandle = [NSNumber numberWithUnsignedLongLong:parentNodeHandle];
    
    MEGALogDebug(@"Save context - insert MOUploadTransfer with local identifier %@", localIdentifier);
    
    [self saveContext];
}

- (void)deleteUploadTransfer:(MOUploadTransfer *)uploadTransfer {
    [self.managedObjectContext deleteObject:uploadTransfer];
    
    MEGALogDebug(@"Save context - remove MOUploadTransfer with local identifier %@", uploadTransfer.localIdentifier);
    
    [self saveContext];
}

- (NSArray<MOUploadTransfer *> *)fetchUploadTransfers {
    NSFetchRequest *request = [MOUploadTransfer fetchRequest];
    
    NSError *error;
    
    return [self.managedObjectContext executeFetchRequest:request error:&error];
}

- (MOUploadTransfer *)fetchTransferUpdateWithLocalIdentifier:(NSString *)localIdentifier {
    NSFetchRequest *request = [MOUploadTransfer fetchRequest];
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"localIdentifier == %@", localIdentifier];
    request.predicate = predicate;
    
    NSError *error;
    NSArray *array = [self.managedObjectContext executeFetchRequest:request error:&error];
    
    return array.firstObject;
}

- (void)removeAllUploadTransfers {
    NSArray<MOUploadTransfer *> *uploadTransfers = [self fetchUploadTransfers];
    for (MOUploadTransfer *uploadTransfer in uploadTransfers) {
        [self.managedObjectContext deleteObject:uploadTransfer];
    }
    
    [self saveContext];
}

#pragma mark - MOMessage entity

- (void)insertMessage:(uint64_t)messageId chatId:(uint64_t)chatId {
    MOMessage *mMessage = [NSEntityDescription insertNewObjectForEntityForName:@"MOMessage" inManagedObjectContext:self.managedObjectContext];
    mMessage.chatId = [NSNumber numberWithUnsignedLongLong:chatId];
    mMessage.messageId = [NSNumber numberWithUnsignedLongLong:messageId];
    
    MEGALogDebug(@"Save context - insert MOMessage with chat %@ and message %@", [MEGASdk base64HandleForUserHandle:chatId], [MEGASdk base64HandleForUserHandle:messageId]);
    
    [self saveContext];
}

- (void)deleteMessage:(MOMessage *)message {
    [self.managedObjectContext deleteObject:message];
    
    MEGALogDebug(@"Save context - remove MOMessage with chat %@ and message %@", [MEGASdk base64HandleForUserHandle:message.chatId.unsignedLongLongValue],[MEGASdk base64HandleForUserHandle:message.messageId.unsignedLongLongValue]);
    
    [self saveContext];
}

- (MOUploadTransfer *)fetchMessageWithChatId:(uint64_t)chatId messageId:(uint64_t)messageId {
    NSFetchRequest *request = [MOMessage fetchRequest];
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"chatId == %llu AND messageId == %llu", chatId, messageId];
    request.predicate = predicate;
    
    NSError *error;
    NSArray *array = [self.managedObjectContext executeFetchRequest:request error:&error];
    
    return array.firstObject;
    
}

@end
