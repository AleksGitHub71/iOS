import SwiftUI

// For more reference, please visit: https://github.com/markiv/SwiftUI-Shimmer/blob/main/Sources/Shimmer/Shimmer.swift
public struct Shimmer: ViewModifier {
    @State private var isInitialState = true
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.colorScheme) var colorScheme

    private let animation = Animation.linear(duration: 1.5).delay(0.25).repeatForever(autoreverses: false)
    // Unit point dimensions beyond the gradient's edges by the band size of 0.3
    private let min: CGFloat = -0.3
    private let max: CGFloat = 1.3

    private var gradient: Gradient {
        .init(
            colors: colorScheme == .light ? [.black.opacity(0.1), .black.opacity(0.2), .black.opacity(0.1)] : [.white.opacity(0.2), .white.opacity(0.3), .white.opacity(0.2)]
        )
    }

    /// The start unit point of our gradient, adjusting for layout direction.
    private var startPoint: UnitPoint {
        if layoutDirection == .rightToLeft {
            return isInitialState ? UnitPoint(x: max, y: min) : UnitPoint(x: 0, y: 1)
        } else {
            return isInitialState ? UnitPoint(x: min, y: min) : UnitPoint(x: 1, y: 1)
        }
    }

    /// The end unit point of our gradient, adjusting for layout direction.
    private var endPoint: UnitPoint {
        if layoutDirection == .rightToLeft {
            return isInitialState ? UnitPoint(x: 1, y: 0) : UnitPoint(x: min, y: max)
        } else {
            return isInitialState ? UnitPoint(x: 0, y: 0) : UnitPoint(x: max, y: max)
        }
    }

    public func body(content: Content) -> some View {
        content
            .mask(LinearGradient(gradient: gradient, startPoint: startPoint, endPoint: endPoint))
            .onAppear {
                withAnimation(animation) {
                    isInitialState = false
                }
            }
    }
}

public extension View {
    /// Adds an animated shimmering effect to any view, typically to show that an operation is in progress.
    /// - Parameters:
    ///   - active: Convenience parameter to conditionally enable the effect. Defaults to `true`.
    @ViewBuilder func shimmering(
        active: Bool = true
    ) -> some View {
        if active {
            modifier(Shimmer())
        } else {
            self
        }
    }
}

struct Shimmer_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            Text("SwiftUI Shimmer").preferredColorScheme(.light)
            Text("SwiftUI Shimmer").preferredColorScheme(.dark)

            VStack(alignment: .leading) {
                Text("Loading...").font(.title)
                Text(String(repeating: "Shimmer", count: 12))
                    .redacted(reason: .placeholder)
            }.frame(maxWidth: 200)
        }
        .padding()
        .shimmering()
        .previewLayout(.sizeThatFits)

        VStack(alignment: .leading) {
            Text("← Right-to-left layout direction").font(.body)
        }
        .font(.largeTitle)
        .shimmering()
        .environment(\.layoutDirection, .rightToLeft)
    }
}
