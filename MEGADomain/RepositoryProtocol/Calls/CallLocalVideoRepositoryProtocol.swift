
protocol CallLocalVideoRepositoryProtocol {
    func enableLocalVideo(for chatId: MEGAHandle, completion: @escaping (Result<Void, CallErrorEntity>) -> Void)
    func disableLocalVideo(for chatId: MEGAHandle, completion: @escaping (Result<Void, CallErrorEntity>) -> Void)
    func addLocalVideo(for chatId: MEGAHandle, localVideoListener: CallLocalVideoListenerRepositoryProtocol)
    func removeLocalVideo(for chatId: MEGAHandle, localVideoListener: CallLocalVideoListenerRepositoryProtocol)
    func videoDeviceSelected() -> String?
    func selectCamera(withLocalizedName localizedName: String, completion: @escaping (Result<Void, CameraSelectionErrorEntity>) -> Void)
    func openVideoDevice(completion: @escaping (Result<Void, CallErrorEntity>) -> Void)
    func releaseVideoDevice(completion: @escaping (Result<Void, CallErrorEntity>) -> Void)
}

protocol CallLocalVideoListenerRepositoryProtocol {
    func localVideoFrameData(width: Int, height: Int, buffer: Data)
    func localVideoChangedCameraPosition()
}
