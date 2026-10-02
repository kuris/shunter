import Foundation

/// 쇼츠 검색 조건.
struct ShortsSearchQuery {
    var keyword: String
    var regionCode: String = "KR"
    var period: SearchPeriod = .last30
    var minViewCount: Int = 10_000
    var maxDuration: Int = 60
    var sort: SearchSort = .viralScore
}

/// 검색 응답. mock 여부와 메시지를 함께 전달한다.
struct ShortsSearchResponse {
    var results: [VideoResult]
    var isMock: Bool
    var message: String
}

enum YouTubeServiceError: LocalizedError {
    case invalidURL
    case missingAPIKey
    case http(Int)
    case decoding

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "요청 URL을 만들 수 없습니다."
        case .missingAPIKey: return "YouTube Data API Key가 필요합니다."
        case .http(let code): return "YouTube API 오류 (HTTP \(code))"
        case .decoding: return "YouTube 응답을 해석할 수 없습니다."
        }
    }
}

/// YouTube Data API v3 연동 서비스.
///
/// API Key가 없거나 요청에 실패하면 mock 데이터로 안전하게 폴백한다.
final class YouTubeService {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func search(query: ShortsSearchQuery, apiKey: String?) async -> ShortsSearchResponse {
        let trimmedKey = apiKey?.trimmingCharacters(in: .whitespaces) ?? ""
        guard !trimmedKey.isEmpty else {
            return ShortsSearchResponse(
                results: sorted(MockData.searchResults, by: query.sort),
                isMock: true,
                message: "YouTube API Key가 없어 데모 데이터를 표시합니다."
            )
        }

        do {
            let videos = try await fetchVideos(query: query, apiKey: trimmedKey)
            if videos.isEmpty {
                return ShortsSearchResponse(
                    results: [],
                    isMock: false,
                    message: "조건에 맞는 영상이 없습니다."
                )
            }
            return ShortsSearchResponse(
                results: sorted(videos, by: query.sort),
                isMock: false,
                message: "YouTube Data API 결과 \(videos.count)건"
            )
        } catch {
            return ShortsSearchResponse(
                results: sorted(MockData.searchResults, by: query.sort),
                isMock: true,
                message: "API 호출 실패로 데모 데이터를 표시합니다. (\(error.localizedDescription))"
            )
        }
    }

    // MARK: - Sorting

    private func sorted(_ videos: [VideoResult], by sort: SearchSort) -> [VideoResult] {
        switch sort {
        case .viralScore:
            return videos.sorted { $0.viralScore > $1.viralScore }
        case .viewCount:
            return videos.sorted { $0.viewCount > $1.viewCount }
        case .latest:
            return videos.sorted { $0.publishedAt > $1.publishedAt }
        }
    }

    // MARK: - YouTube API

    private func fetchVideos(query: ShortsSearchQuery, apiKey: String) async throws -> [VideoResult] {
        let publishedAfter = ISO8601.string(
            from: Calendar.current.date(byAdding: .day, value: -query.period.days, to: Date()) ?? Date()
        )

        var components = URLComponents(string: "https://www.googleapis.com/youtube/v3/search")
        components?.queryItems = [
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "part", value: "snippet"),
            URLQueryItem(name: "q", value: query.keyword),
            URLQueryItem(name: "type", value: "video"),
            URLQueryItem(name: "videoDuration", value: "short"),
            URLQueryItem(name: "maxResults", value: "25"),
            URLQueryItem(name: "regionCode", value: query.regionCode),
            URLQueryItem(name: "publishedAfter", value: publishedAfter),
            URLQueryItem(name: "order", value: youTubeOrder(for: query.sort))
        ]
        guard let url = components?.url else { throw YouTubeServiceError.invalidURL }
        let searchResponse: SearchListResponse = try await get(url)
        let videoIDs = searchResponse.items.map { $0.id.videoId }.filter { !$0.isEmpty }
        guard !videoIDs.isEmpty else { return [] }

        let details = try await fetchVideoDetails(ids: videoIDs, apiKey: apiKey)
        let subscriberMap = try await fetchSubscribers(
            channelIDs: Array(Set(details.map { $0.snippet.channelId })),
            apiKey: apiKey
        )

        let results: [VideoResult] = details.compactMap { item in
            let duration = TimecodeFormatter.seconds(fromISODuration: item.contentDetails.duration) ?? 0
            guard duration > 0, duration <= query.maxDuration else { return nil }
            let viewCount = Int(item.statistics.viewCount ?? "0") ?? 0
            guard viewCount >= query.minViewCount else { return nil }
            let likeCount = Int(item.statistics.likeCount ?? "0") ?? 0
            let commentCount = Int(item.statistics.commentCount ?? "0") ?? 0
            let subscriberCount = subscriberMap[item.snippet.channelId] ?? 0
            let publishedAt = ISO8601.date(from: item.snippet.publishedAt) ?? Date()

            var video = VideoResult(
                id: item.id,
                title: item.snippet.title,
                url: "https://www.youtube.com/watch?v=\(item.id)",
                thumbnailURL: item.snippet.thumbnails?.high?.url ?? "",
                channelTitle: item.snippet.channelTitle,
                channelId: item.snippet.channelId,
                publishedAt: publishedAt,
                durationSeconds: duration,
                viewCount: viewCount,
                likeCount: likeCount,
                commentCount: commentCount,
                subscriberCount: subscriberCount,
                viralScore: 0,
                description: item.snippet.description ?? "",
                tags: item.snippet.tags ?? []
            )
            video.viralScore = ViralScoreCalculator.score(for: video)
            return video
        }
        return results
    }

    private func fetchVideoDetails(ids: [String], apiKey: String) async throws -> [VideoItem] {
        var components = URLComponents(string: "https://www.googleapis.com/youtube/v3/videos")
        components?.queryItems = [
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "part", value: "snippet,contentDetails,statistics"),
            URLQueryItem(name: "id", value: ids.joined(separator: ","))
        ]
        guard let url = components?.url else { throw YouTubeServiceError.invalidURL }
        let response: VideoListResponse = try await get(url)
        return response.items
    }

    private func fetchSubscribers(channelIDs: [String], apiKey: String) async throws -> [String: Int] {
        guard !channelIDs.isEmpty else { return [:] }
        var components = URLComponents(string: "https://www.googleapis.com/youtube/v3/channels")
        components?.queryItems = [
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "part", value: "statistics"),
            URLQueryItem(name: "id", value: channelIDs.joined(separator: ","))
        ]
        guard let url = components?.url else { throw YouTubeServiceError.invalidURL }
        let response: ChannelListResponse = try await get(url)
        var map: [String: Int] = [:]
        for channel in response.items {
            map[channel.id] = Int(channel.statistics.subscriberCount ?? "0") ?? 0
        }
        return map
    }

    private func youTubeOrder(for sort: SearchSort) -> String {
        switch sort {
        case .viralScore: return "viewCount"
        case .viewCount: return "viewCount"
        case .latest: return "date"
        }
    }

    private func get<T: Decodable>(_ url: URL) async throws -> T {
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse else { throw YouTubeServiceError.decoding }
        guard (200..<300).contains(http.statusCode) else { throw YouTubeServiceError.http(http.statusCode) }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw YouTubeServiceError.decoding
        }
    }
}

// MARK: - API Response DTO

private enum ISO8601 {
    static func date(from string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }

    static func string(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }
}

private struct SearchListResponse: Decodable {
    struct Item: Decodable {
        struct Identifier: Decodable { let videoId: String }
        let id: Identifier
    }
    let items: [Item]
}

private struct VideoListResponse: Decodable {
    let items: [VideoItem]
}

private struct VideoItem: Decodable {
    struct Snippet: Decodable {
        struct Thumbnails: Decodable {
            struct Thumbnail: Decodable { let url: String }
            let high: Thumbnail?
            let medium: Thumbnail?
        }
        let title: String
        let channelTitle: String
        let channelId: String
        let publishedAt: String
        let description: String?
        let tags: [String]?
        let thumbnails: Thumbnails?
    }
    struct ContentDetails: Decodable { let duration: String }
    struct Statistics: Decodable {
        let viewCount: String?
        let likeCount: String?
        let commentCount: String?
    }
    let id: String
    let snippet: Snippet
    let contentDetails: ContentDetails
    let statistics: Statistics
}

private struct ChannelListResponse: Decodable {
    struct Item: Decodable {
        struct Statistics: Decodable { let subscriberCount: String? }
        let id: String
        let statistics: Statistics
    }
    let items: [Item]
}
