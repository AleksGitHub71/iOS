
@interface MEGANodeList (MNZCategory)

- (NSArray *)mnz_numberOfFilesAndFolders;

- (BOOL)mnz_existsFolderWithName:(NSString *)name;
- (BOOL)mnz_existsFileWithName:(NSString *)name;

- (NSArray<MEGANode*> *)mnz_nodesArrayFromNodeList;
- (NSMutableArray *)mnz_mediaNodesMutableArrayFromNodeList;

#pragma mark - onNodesUpdate filtering

- (BOOL)mnz_shouldProcessOnNodesUpdateForParentNode:(MEGANode *)parentNode childNodesArray:(NSArray<MEGANode *> *)childNodesArray;
- (BOOL)mnz_shouldProcessOnNodesUpdateInSharedForNodes:(NSArray<MEGANode *> *)nodesArray itemSelected:(NSInteger)itemSelected;

@end
