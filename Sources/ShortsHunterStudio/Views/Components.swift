import SwiftUI

/// 카드형 섹션 컨테이너.
struct Card<Content: View>: View {
    var title: String? = nil
    var subtitle: String? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline)
                    if let subtitle {
                        Text(subtitle).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.gray.opacity(0.15), lineWidth: 1)
        )
    }
}

/// 화면 상단 제목 영역.
struct PageHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.largeTitle.bold())
            Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// 안전 안내 문구.
struct SafetyNotice: View {
    let text: String
    var systemImage: String = "exclamationmark.shield"

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(.orange)
            Text(text)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.orange.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.orange.opacity(0.25), lineWidth: 1)
        )
    }
}

/// 상태 뱃지.
struct StatusBadge: View {
    let text: String
    var color: Color = .blue

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(color.opacity(0.15)))
            .foregroundStyle(color)
    }
}

/// 바이럴 점수 뱃지.
struct ViralScoreBadge: View {
    let score: Double

    private var color: Color {
        switch score {
        case 90...: return .green
        case 75..<90: return .mint
        case 60..<75: return .orange
        default: return .gray
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Text(String(format: "%.1f", score)).font(.caption.bold())
            Text(ViralScoreCalculator.label(for: score)).font(.caption2)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Capsule().fill(color.opacity(0.15)))
        .foregroundStyle(color)
    }
}

/// 통계 숫자 카드.
struct StatTile: View {
    let title: String
    let value: String
    let systemImage: String
    var tint: Color = .accentColor

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: systemImage).foregroundStyle(tint)
                Spacer()
            }
            Text(value).font(.system(size: 28, weight: .bold, design: .rounded))
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.gray.opacity(0.15), lineWidth: 1)
        )
    }
}

/// 진행률 표시 카드.
struct ProgressCard: View {
    let title: String
    let progress: Double
    var detail: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title).font(.callout)
                Spacer()
                Text("\(Int(progress * 100))%").font(.callout.monospacedDigit()).foregroundStyle(.secondary)
            }
            ProgressView(value: progress)
            if !detail.isEmpty {
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
