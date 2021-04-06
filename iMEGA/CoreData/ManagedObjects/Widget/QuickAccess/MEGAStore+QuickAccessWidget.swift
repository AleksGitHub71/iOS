
extension MEGAStore {
    
    func deleteQuickAccessRecentItems(completion: @escaping (Result<Void, QuickAccessWidgetErrorEntity>) -> Void) {
        guard let context = stack.newBackgroundContext() else {
            completion(.failure(.megaStore))
            return
        }
        
        context.perform {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "QuickAccessWidgetRecentItem")
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            
            do {
                try context.execute(deleteRequest)
                completion(.success(()))
            } catch let error as NSError {
                MEGALogError("Could not delete QuickAccessWidgetRecentItem object: \(error.localizedDescription)")
                completion(.failure(.megaStore))
            }
        }
    }
    
    func insertQuickAccessRecentItem(withBase64Handle base64Handle: String,
                                     name: String,
                                     isUpdate: Bool,
                                     timestamp: Date) {
        stack.performBackgroundTask { context in
            let quickAccessRecentItem = QuickAccessWidgetRecentItem.createInstance(withContext: context)
            quickAccessRecentItem.handle = base64Handle
            quickAccessRecentItem.name = name
            quickAccessRecentItem.isUpdate = isUpdate as NSNumber
            quickAccessRecentItem.timestamp = timestamp
            self.save(context)
        }
    }
    
    @available(iOS 14.0, *)
    func batchInsertQuickAccessRecentItems(_ items: [RecentItemEntity], completion: ((Result<Void, QuickAccessWidgetErrorEntity>) -> Void)? = nil) {
        guard !items.isEmpty else {
            completion?(.success(()))
            return
        }
        
        var insertIndex = 0
        let batchInsert = NSBatchInsertRequest(entity: QuickAccessWidgetRecentItem.entity()) { (managedObject: NSManagedObject) -> Bool in
            guard insertIndex < items.count else { return true }
            let entity = items[insertIndex]
            
            if let recentItem = managedObject as? QuickAccessWidgetRecentItem {
                recentItem.handle = entity.base64Handle
                recentItem.name = entity.name
                recentItem.isUpdate = entity.isUpdate as NSNumber
                recentItem.timestamp = entity.timestamp
            }
            
            insertIndex += 1
            return false
        }
        
        stack.performBackgroundTask { context in
            do {
                try context.execute(batchInsert)
                completion?(.success(()))
            } catch {
                MEGALogError("error when to batch insert recent items \(error)")
                completion?(.failure(.megaStore))
            }
        }
    }
    
    func fetchAllQuickAccessRecentItem() -> [RecentItemEntity] {
        var items = [RecentItemEntity]()
        
        guard let context = stack.newBackgroundContext() else { return items }
        context.performAndWait {
            do {
                let fetchRequest: NSFetchRequest<QuickAccessWidgetRecentItem> = QuickAccessWidgetRecentItem.fetchRequest()
                items = try context.fetch(fetchRequest).compactMap {
                    guard let handle = $0.handle,
                          let name = $0.name,
                          let date = $0.timestamp,
                          let isUpdate = $0.isUpdate else {
                        return nil
                    }
                    
                    return RecentItemEntity(base64Handle: handle, name: name, timestamp: date, isUpdate: isUpdate.boolValue)
                }
            } catch let error as NSError {
                MEGALogError("Could not fetch [QuickAccessWidgetRecentItem] object for path \(error.localizedDescription)")
            }
        }
        
        return items
    }
    
    func insertQuickAccessFavouriteItem(withBase64Handle base64Handle: String,
                                        name: String,
                                        timestamp: Date) {
        stack.performBackgroundTask { context in
            let quickAccessWidgetFavouriteItem = QuickAccessWidgetFavouriteItem.createInstance(withContext: context)
            quickAccessWidgetFavouriteItem.handle = base64Handle
            quickAccessWidgetFavouriteItem.name = name
            quickAccessWidgetFavouriteItem.timestamp = timestamp
            self.save(context)
        }
    }
    
    @available(iOS 14.0, *)
    func batchInsertQuickAccessFavouriteItems(_ items: [FavouriteItemEntity], completion: ((Result<Void, QuickAccessWidgetErrorEntity>) -> Void)? = nil) {
        guard !items.isEmpty else {
            completion?(.success(()))
            return
        }
        
        var insertIndex = 0
        let batchInsert = NSBatchInsertRequest(entity: QuickAccessWidgetFavouriteItem.entity()) { (managedObject: NSManagedObject) -> Bool in
            guard insertIndex < items.count else { return true }
            let entity = items[insertIndex]
            
            if let favouriteItem = managedObject as? QuickAccessWidgetFavouriteItem {
                favouriteItem.handle = entity.base64Handle
                favouriteItem.name = entity.name
                favouriteItem.timestamp = entity.timestamp
            }
            
            insertIndex += 1
            return false
        }
        
        stack.performBackgroundTask { context in
            do {
                try context.execute(batchInsert)
                completion?(.success(()))
            } catch {
                MEGALogError("error when to batch insert favourite items \(error)")
                completion?(.failure(.megaStore))
            }
        }
    }
    
    func deleteQuickAccessFavouriteItem(withBase64Handle base64Handle: String) {
        stack.performBackgroundTask { context in
            let fetchRequest: NSFetchRequest<QuickAccessWidgetFavouriteItem> = QuickAccessWidgetFavouriteItem.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "handle == %@", base64Handle)
            
            do {
                if let object = try context.fetch(fetchRequest).first {
                    context.delete(object)
                    self.save(context)
                } else {
                    MEGALogError("Could not find QuickAccessWidgetFavouriteItem object to delete")
                }
            } catch let error as NSError {
                MEGALogError("Could not delete QuickAccessWidgetFavouriteItem object: \(error.localizedDescription)")
            }
        }
    }
    
    func fetchAllQuickAccessFavouriteItems() -> [FavouriteItemEntity] {
        var items = [FavouriteItemEntity]()
        guard let context = stack.newBackgroundContext() else { return items }
        context.performAndWait {
            do {
                let fetchRequest: NSFetchRequest<QuickAccessWidgetFavouriteItem> = QuickAccessWidgetFavouriteItem.fetchRequest()
                items = try context.fetch(fetchRequest).compactMap {
                    guard let handle = $0.handle,
                          let name = $0.name,
                          let date = $0.timestamp else { return nil }
                    return FavouriteItemEntity(base64Handle: handle, name: name, timestamp: date)
                }
                
            } catch let error as NSError {
                MEGALogError("Could not fetch [QuickAccessWidgetFavouriteItem] object for path \(error.localizedDescription)")
            }
        }
        
        return items
    }
    
    func fetchQuickAccessFavourtieItems(withLimit fetchLimit: Int?) -> [FavouriteItemEntity] {
        var items = [FavouriteItemEntity]()
        guard let context = stack.newBackgroundContext() else { return items }
        context.performAndWait {
            let fetchRequest: NSFetchRequest<QuickAccessWidgetFavouriteItem> = QuickAccessWidgetFavouriteItem.fetchRequest()
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
            
            if let fetchLimit = fetchLimit {
                fetchRequest.fetchLimit = fetchLimit
            }
            
            do {
                items = try context.fetch(fetchRequest).compactMap {
                    guard let handle = $0.handle,
                          let name = $0.name,
                          let date = $0.timestamp else { return nil }
                    return FavouriteItemEntity(base64Handle: handle, name: name, timestamp: date)
                }
            } catch let error as NSError {
                MEGALogError("Error fetching QuickAccessWidgetFavouriteItem: \(error.description)")
            }
        }
        
        return items
    }
    
    func deleteQuickAccessFavouriteItems(completion: @escaping (Result<Void, QuickAccessWidgetErrorEntity>) -> Void) {
        stack.performBackgroundTask { context in
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "QuickAccessWidgetFavouriteItem")
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            
            do {
                try context.execute(deleteRequest)
                completion(.success(()))
            } catch let error as NSError {
                MEGALogError("Could not delete QuickAccessWidgetFavouriteItem object: \(error.localizedDescription)")
                completion(.failure(.megaStore))
            }
        }
    }
}
