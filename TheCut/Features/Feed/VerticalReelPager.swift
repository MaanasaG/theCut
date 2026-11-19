import SwiftUI

/// Instagram Reels–style vertical paging (swipe up / down). No rotation hacks.
struct VerticalReelPager<Item: Identifiable, Content: View>: View {
    let items: [Item]
    @Binding var index: Int
    @ViewBuilder var content: (Int, Item) -> Content

    var body: some View {
        GeometryReader { geo in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { i, item in
                        content(i, item)
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()
                            .id(i)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: Binding(
                get: { Optional(index) },
                set: { newValue in
                    if let newValue {
                        index = newValue
                    }
                }
            ))
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea()
    }
}
