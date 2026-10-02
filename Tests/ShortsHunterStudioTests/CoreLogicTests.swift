import XCTest
@testable import ShortsHunterStudio

final class CoreLogicTests: XCTestCase {

    func testViralScoreIsClampedAndLabelled() {
        let score = ViralScoreCalculator.calculate(
            viewCount: 1_000_000,
            likeCount: 100_000,
            commentCount: 20_000,
            subscriberCount: 1_000,
            publishedAt: Date(),
            durationSeconds: 30
        )
        XCTAssertGreaterThanOrEqual(score, 0)
        XCTAssertLessThanOrEqual(score, 100)
        XCTAssertEqual(ViralScoreCalculator.label(for: 95), "매우 강한 바이럴")
        XCTAssertEqual(ViralScoreCalculator.label(for: 10), "약함")
    }

    func testSubscriberRatioDrivesScore() {
        let low = ViralScoreCalculator.calculate(
            viewCount: 10_000, likeCount: 100, commentCount: 10,
            subscriberCount: 1_000_000, publishedAt: Date(), durationSeconds: 30
        )
        let high = ViralScoreCalculator.calculate(
            viewCount: 10_000, likeCount: 100, commentCount: 10,
            subscriberCount: 1_000, publishedAt: Date(), durationSeconds: 30
        )
        XCTAssertGreaterThan(high, low)
    }

    func testSRTFormatAndWrapping() {
        let segments = [
            TranscriptSegment(startTime: 0, endTime: 2.4, text: "첫 번째 자막입니다"),
            TranscriptSegment(startTime: 2.4, endTime: 5.2, text: "두 번째 자막입니다")
        ]
        let srt = SRTService.srt(from: segments)
        XCTAssertTrue(srt.contains("00:00:00,000 --> 00:00:02,400"))
        XCTAssertTrue(srt.contains("1\n00:00:00,000"))
        XCTAssertTrue(srt.contains("2\n00:00:02,400"))
    }

    func testSRTWrapSplitsLongLines() {
        let long = "아주 긴 문장을 한 줄 최대 길이에 맞게 자동으로 줄바꿈하는지 확인합니다"
        let wrapped = SRTService.wrap(long, maxLineLength: 10)
        for line in wrapped.components(separatedBy: .newlines) {
            XCTAssertLessThanOrEqual(line.count, 10)
        }
    }

    func testSimilarityIdenticalIsHigh() {
        let result = SimilarityService.compare(
            sourceTitle: "아침 스트레칭 루틴",
            candidateTitle: "아침 스트레칭 루틴",
            sourceScript: "매일 아침 스트레칭을 하면 몸이 가벼워집니다",
            candidateScript: "매일 아침 스트레칭을 하면 몸이 가벼워집니다"
        )
        XCTAssertGreaterThan(result.totalSimilarity, 80)
    }

    func testSimilarityUnrelatedIsLow() {
        let result = SimilarityService.compare(
            sourceTitle: "아침 스트레칭",
            candidateTitle: "주식 투자 전략",
            sourceScript: "스트레칭은 건강에 좋습니다",
            candidateScript: "배당주 포트폴리오 구성 방법"
        )
        XCTAssertLessThan(result.totalSimilarity, 50)
    }

    func testExportCreatesFolderAndFiles() async throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("shs_export_test_\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: temp) }

        let document = MockData.transcript(for: "sample.mp4")
        let input = ExportInput(
            projectName: "테스트",
            keyword: "테스트",
            outputDirectory: temp,
            videoFileURL: nil,
            audioFileURL: nil,
            transcript: document,
            videoDuration: 28,
            translations: [.english: "hello\nworld"],
            rewrittenScript: "재작성 데모",
            titleCandidates: ["제목1", "제목2"],
            hooks: ["후킹1"],
            sourcePlatform: "YouTube",
            sourceURL: "https://example.com",
            sourceCreator: "@tester",
            permissionStatus: "본인 영상",
            notes: "메모",
            includeOriginalVideo: false,
            includeAudio: false
        )

        let result = try await ExportService().export(input)
        let files = try FileManager.default.contentsOfDirectory(atPath: result.folderURL.path)
        XCTAssertTrue(files.contains("transcript_original.txt"))
        XCTAssertTrue(files.contains("subtitle_original.srt"))
        XCTAssertTrue(files.contains("project_metadata.json"))
        XCTAssertTrue(files.contains("source_notes.txt"))
        XCTAssertFalse(result.files.isEmpty)
    }

    func testMockDataHasResults() {
        XCTAssertEqual(MockData.searchResults.count, 10)
        XCTAssertTrue(MockData.searchResults.allSatisfy { $0.viralScore >= 0 && $0.viralScore <= 100 })
    }
}
