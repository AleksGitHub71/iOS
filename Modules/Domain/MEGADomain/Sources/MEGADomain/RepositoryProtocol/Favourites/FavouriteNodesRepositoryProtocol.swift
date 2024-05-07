import Foundation

public protocol FavouriteNodesRepositoryProtocol: RepositoryProtocol {
    func getAllFavouriteNodes(completion: @escaping (Result<[NodeEntity], GetFavouriteNodesErrorEntity>) -> Void)
    func getFavouriteNodes(limitCount: Int, completion: @escaping (Result<[NodeEntity], GetFavouriteNodesErrorEntity>) -> Void)
    func allFavouriteNodes(searchString: String?, completion: @escaping (Result<[NodeEntity], GetFavouriteNodesErrorEntity>) -> Void)
    func allFavouritesNodes(searchString: String?) async throws -> [NodeEntity]
    func allFavouritesNodes() async throws -> [NodeEntity]
    func registerOnNodesUpdate(callback: @escaping ([NodeEntity]) -> Void)
    func unregisterOnNodesUpdate()
}
