import MEGASwift

/// `FileExtensionOCWrapper` is a class that provides helper methods for working with file extensions.
@objc public class FileExtensionOCWrapper: NSObject {
    /// Returns the filename with a lowercase extension derived from the provided `FileExtension` instance.
    ///
    /// This function attempts to format the file extension of a given `FileExtension` object into lowercase. 
    ///
    /// - Parameter fileExtension: An optional `FileExtension` object which provides the source file extension to be lowercased.
    /// - Returns: A optional string representing the filename with a lowercase file extension if the `FileExtension` object is not `nil`, otherwise returns `nil`.
    ///
    /// - Note: The function will return `nil` if the `fileExtension` parameter is `nil`.
    ///
    /// # Example
    /// ```
    /// let fileExtension: FileExtension? = .init("FileName.JPG")
    /// let lowercasedFilename = FileExtensionOCWrapper.fileNameWithLowercaseExtension(from: fileExtension)
    /// // lowercasedFilename contains "FileName.jpg"
    /// ```
    @objc public static func fileNameWithLowercaseExtension(from fileExtension: FileExtension?) -> String? {
        guard let fileExtension else { return nil }
        return fileExtension.formatted(.filePath().pathExtension(capitalization: .lowercased))
    }
    
    @objc public static func lowercasedLastExtension(in fileExtension: FileExtension?) -> String? {
        guard let fileExtension else { return nil }
        return fileExtension.formatted(.filePath(name: nil).pathExtension(capitalization: .lowercased))
    }
    
}
