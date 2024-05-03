import MEGASwiftUI
import SwiftUI

struct AlbumListPlaceholderView: View {
    let isActive: Bool
    let onCreateTapHandler: (() -> Void)
    private let placeholderCount = 15
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass: UserInterfaceSizeClass?
    
    var body: some View {
        ScrollView(.vertical) {
            ZStack(alignment: .topLeading) {
                LazyVGrid(columns: columns) {
                    ForEach(0..<placeholderCount, id: \.self) { index in
                        placeholderCell
                            .opacity(index == 0 ? 0 : 1)
                    }
                }
                .shimmering(active: isActive)
                LazyVGrid(columns: columns) {
                    CreateAlbumCell(onTapHandler: onCreateTapHandler)
                }
            }
            .padding(.horizontal, 8)
        }
        .background(Color(UIColor.systemBackground))
        .opacity(isActive ? 1 : 0)
        .animation(.smooth, value: isActive)
    }
    
    private var placeholderCell: some View {
        VStack(alignment: .leading, spacing: 6) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .aspectRatio(contentMode: .fill)
            
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .frame(height: 18, alignment: .leading)
            
            HStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .frame(height: 18, alignment: .leading)
                Rectangle()
                    .hidden()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
    
    private var columns: [GridItem] {
        let count = 
        switch horizontalSizeClass {
        case .compact, nil: 3
        default: 5
        }
        return Array(
            repeating: .init(.flexible(), spacing: 10),
            count: count)
    }
}

#Preview {
    AlbumListPlaceholderView(isActive: true) { print("AlbumListPlaceholderView onCreateTapHandler tapped") }
}
