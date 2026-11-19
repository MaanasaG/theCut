import SwiftUI

/// Instagram Reels–style vertical paging (swipe up / down), not side swipe.
struct VerticalReelPager<Item: Identifiable, Content: View>: View {
    let items: [Item]
    @Binding var index: Int
    @ViewBuilder var content: (Int, Item) -> Content

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { i, item in
                    content(i, item)
                        .containerRelativeFrame(.vertical)
                        .id(i)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: Binding(
            get: { index },
            set: { newValue in
                if let newValue { index = newValue }
            }
        ))
        .ignoresSafeArea()
    }
}
