import Foundation

/// TikTok oEmbed 공개 정보(메타데이터). 다운로드는 하지 않는다.
struct TikTokMetadata: Codable {
    var url: String
    var title: String
    var authorName: String
    var authorURL: String
    var thumbnailURL: String
    var providerName: String

    static func manual(url: String) -> TikTokMetadata {
        TikTokMetadata(
            url: url,
            title: "",
            authorName: "",
            authorURL: "",
            thumbnailURL: "",
            providerName: "manual"
        )
    }
}

/// TikTok 메타데이터 조회 서비스.
///
/// 정책상 다운로드/우회 크롤링은 구현하지 않는다.
/// 공개 oEmbed 임베드 정보만 조회하며, 실패 시 수동 입력 모드로 폴백한다.
final class TikTokMetadataService {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchMetadata(for urlString: String) async -> (metadata: TikTokMetadata?, isFallback: Bool) {
        guard let input = urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let requestURL = URL(string: "https://www.tiktok.com/oembed?url=\(input)") else {
            return (TikTokMetadata.manual(url: urlString), true)
        }

        do {
            var request = URLRequest(url: requestURL)
            request.timeoutInterval = 10
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return (TikTokMetadata.manual(url: urlString), true)
            }
            let dto = try JSONDecoder().decode(OEmbedDTO.self, from: data)
            let metadata = TikTokMetadata(
                url: urlString,
                title: dto.title ?? "",
                authorName: dto.author_name ?? "",
                authorURL: dto.author_url ?? "",
                thumbnailURL: dto.thumbnail_url ?? "",
                providerName: dto.provider_name ?? "TikTok"
            )
            return (metadata, false)
        } catch {
            return (TikTokMetadata.manual(url: urlString), true)
        }
    }

    private struct OEmbedDTO: Decodable {
        let title: String?
        let author_name: String?
        let author_url: String?
        let thumbnail_url: String?
        let provider_name: String?
    }
}
