import Foundation
import Combine

@MainActor
final class ShortsSearchViewModel: ObservableObject {
    @Published var keyword: String = "아침 스트레칭"
    @Published var regionCode: String = "KR"
    @Published var period: SearchPeriod = .last30
    @Published var minViewCount: Int = 10_000
    @Published var maxDuration: Int = 60
    @Published var sort: SearchSort = .viralScore

    @Published var results: [VideoResult] = []
    @Published var isSearching: Bool = false
    @Published var isMock: Bool = false
    @Published var statusMessage: String = ""
    @Published var selectedVideo: VideoResult?

    private let service = YouTubeService()
    private let settingsStore: SettingsStore

    init(settingsStore: SettingsStore) {
        self.settingsStore = settingsStore
    }

    func loadDefaults(from settings: AppSettings) {
        minViewCount = settings.minViewCount
        period = settings.defaultSearchPeriod
        maxDuration = settings.shortsMaxDuration
    }

    func search() async {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            statusMessage = "검색 키워드를 입력해 주세요."
            return
        }
        isSearching = true
        statusMessage = "검색 중..."
        let query = ShortsSearchQuery(
            keyword: trimmed,
            regionCode: regionCode,
            period: period,
            minViewCount: minViewCount,
            maxDuration: maxDuration,
            sort: sort
        )
        let response = await service.search(query: query, apiKey: settingsStore.settings.youTubeAPIKey)
        results = response.results
        isMock = response.isMock
        statusMessage = response.message
        isSearching = false
    }

    func exportCSV() -> String {
        var lines = ["제목,채널,업로드일,길이(초),조회수,좋아요,댓글,구독자,구독자대비조회수,바이럴점수,링크"]
        for video in results {
            let title = video.title.replacingOccurrences(of: ",", with: " ")
            let channel = video.channelTitle.replacingOccurrences(of: ",", with: " ")
            lines.append([
                title,
                channel,
                video.publishedText,
                "\(video.durationSeconds)",
                "\(video.viewCount)",
                "\(video.likeCount)",
                "\(video.commentCount)",
                "\(video.subscriberCount)",
                String(format: "%.2f", video.subscriberRatio),
                String(format: "%.1f", video.viralScore),
                video.url
            ].joined(separator: ","))
        }
        return lines.joined(separator: "\n")
    }
}
