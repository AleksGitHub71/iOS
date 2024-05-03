import MEGADesignToken
import SwiftUI

struct CameraUploadStatusImageView: View {
    @ObservedObject var viewModel: CameraUploadStatusImageViewModel
    @State private var shouldRotate = false
    
    private var statusImageTintColor: Color {
        switch viewModel.status {
        case .checkPendingItemsToUpload:
            TokenColors.Icon.secondary.swiftUI
        case .uploading:
            TokenColors.Support.info.swiftUI
        case .completed:
            TokenColors.Support.success.swiftUI
        case .warning:
            TokenColors.Support.warning.swiftUI
        case .idle:
            TokenColors.Icon.primary.swiftUI
        default: TokenColors.Icon.primary.swiftUI
        }
    }
    
    var body: some View {
        ZStack(alignment: .center) {
            if let progress = viewModel.progress {
                progressView(progress: progress)
            }
            
            Image(viewModel.baseImageResource)
                .renderingMode(isDesignTokenEnabled ? .template : .original)
                .resizable()
                .frame(width: 21.5,
                       height: 21.5)
                .foregroundColor(isDesignTokenEnabled ? TokenColors.Icon.primary.swiftUI : nil)
            
            if let statusImageResource = viewModel.statusImageResource {
                Group {
                    Circle()
                        .fill(.navigationBg)
                        .frame(width: 15.5,
                               height: 15.5)
                    
                    statusImage(resource: statusImageResource)
                        .animation(nil, value: shouldRotate)
                        .rotationEffect(.degrees(shouldRotate ? 360 : 0))
                        .animation(viewModel.shouldRotateStatusImage ? statusImageAnimation : .linear(duration: 0), value: shouldRotate)
                        .onAppear { update(shouldRotate: viewModel.shouldRotateStatusImage) }
                        .onDisappear { update(shouldRotate: false) }
                        .onChange(of: viewModel.shouldRotateStatusImage) { update(shouldRotate: $0) }
                }
                .offset(x: 8,
                        y: 8)
            }
        }
        .frame(width: 28,
               height: 28)
    }
    
    private func update(shouldRotate: Bool) {
        guard self.shouldRotate != shouldRotate else {
            return
        }
        self.shouldRotate = shouldRotate
    }
    
    @ViewBuilder
    private func statusImage(resource: ImageResource) -> some View {
        Image(resource)
            .renderingMode(isDesignTokenEnabled ? .template : .original)
            .resizable()
            .frame(width: 12.5,
                   height: 12.5)
            .foregroundColor(isDesignTokenEnabled ? statusImageTintColor : nil)
    }
    
    private var statusImageAnimation: Animation {
        .linear
        .speed(0.1)
        .repeatForever(autoreverses: false)
    }
    
    private func progressView(progress: Float) -> some View {
        Circle()
            .trim(from: 0.0, to: min(CGFloat(progress), 1.0))
            .stroke(viewModel.progressLineColor,
                    lineWidth: 1.6)
            .rotationEffect(.degrees(-90))
            .animation(.linear, value: progress)
            .frame(width: 27.5,
                   height: 27.5)
    }
}

#Preview {
    Group {
        CameraUploadStatusImageView(
            viewModel: .init(status: .turnedOff))
        
        CameraUploadStatusImageView(
            viewModel: .init(status: .checkPendingItemsToUpload))
        
        CameraUploadStatusImageView(
            viewModel: .init(status: .uploading(progress: 0.20)))
        
        CameraUploadStatusImageView(
            viewModel: .init(status: .uploading(progress: 0.45)))
        
        CameraUploadStatusImageView(
            viewModel: .init(status: .uploading(progress: 0.65)))
        
        CameraUploadStatusImageView(
            viewModel: .init(status: .completed))
        
        CameraUploadStatusImageView(
            viewModel: .init(status: .idle))
        
        CameraUploadStatusImageView(
            viewModel: .init(status: .warning))
    }
}
