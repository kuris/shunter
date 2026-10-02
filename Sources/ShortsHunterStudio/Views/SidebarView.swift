import SwiftUI

struct SidebarView: View {
    @Binding var selection: SidebarItem

    var body: some View {
        List(selection: $selection) {
            Section {
                ForEach(SidebarItem.allCases) { item in
                    Label(item.rawValue, systemImage: item.systemImage)
                        .tag(item)
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .top) {
            HStack(spacing: 10) {
                Image(systemName: "film.stack")
                    .font(.title2)
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Shorts Hunter Studio").font(.headline)
                    Text("숏폼 분석 · 대본 · CapCut 준비").font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.bar)
        }
        .safeAreaInset(edge: .bottom) {
            Text("본인 영상 또는 사용 허락을 받은 영상만 사용하세요.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(10)
                .frame(maxWidth: .infinity)
                .background(.bar)
        }
    }
}
