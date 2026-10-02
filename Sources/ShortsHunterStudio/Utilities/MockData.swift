import Foundation

/// API Key 없이도 화면이 동작하도록 하는 데모 데이터.
enum MockData {
    static var searchResults: [VideoResult] {
        let now = Date()
        func daysAgo(_ days: Int) -> Date {
            Calendar.current.date(byAdding: .day, value: -days, to: now) ?? now
        }

        let raw: [(String, String, String, Int, Int, Int, Int, Int, Int, [String], String)] = [
            ("5분이면 끝나는 아침 스트레칭 루틴", "헬스하는 직장인", "https://www.youtube.com/watch?v=shorts001", 3, 1_820_000, 96_400, 3_120, 48_000, 42, ["스트레칭", "아침루틴", "헬스"], "매일 아침 5분만 투자하세요. 허리와 어깨가 편해집니다."),
            ("편의점 재료로 만드는 초간단 야식 3가지", "자취요리왕", "https://www.youtube.com/watch?v=shorts002", 8, 3_240_000, 210_000, 8_400, 320_000, 58, ["야식", "자취요리", "레시피"], "편의점에서 살 수 있는 재료만으로 만드는 야식 레시피입니다."),
            ("아이폰 배터리 오래 쓰는 숨은 설정", "테크리뷰어", "https://www.youtube.com/watch?v=shorts003", 14, 980_000, 61_000, 2_050, 150_000, 47, ["아이폰", "배터리", "꿀팁"], "설정 하나만 바꿔도 배터리가 오래 갑니다."),
            ("고양이가 밥 달라고 우는 이유", "냥냥박사", "https://www.youtube.com/watch?v=shorts004", 22, 4_500_000, 402_000, 12_300, 88_000, 34, ["고양이", "반려동물", "행동분석"], "고양이가 밥을 달라고 우는 진짜 이유를 알아봅니다."),
            ("월급 200으로 1억 모은 방법", "재테크노트", "https://www.youtube.com/watch?v=shorts005", 35, 2_100_000, 88_000, 5_600, 540_000, 55, ["재테크", "절약", "적금"], "작은 습관으로 목돈을 만드는 현실적인 방법입니다."),
            ("1분 만에 배우는 마우스 단축키 5개", "오피스꿀팁", "https://www.youtube.com/watch?v=shorts006", 52, 640_000, 33_000, 1_100, 25_000, 51, ["엑셀", "단축키", "업무"], "업무 속도가 두 배 빨라지는 단축키를 알려드립니다."),
            ("여행 짐 싸는 꿀팁 (캐리어 압축)", "여행하는사람", "https://www.youtube.com/watch?v=shorts007", 68, 1_450_000, 72_000, 2_400, 210_000, 44, ["여행", "짐싸기", "꿀팁"], "캐리어 공간을 두 배로 쓰는 짐 싸기 방법."),
            ("면접에서 절대 하면 안 되는 말", "커리어코치", "https://www.youtube.com/watch?v=shorts008", 12, 760_000, 45_000, 1_980, 60_000, 39, ["면접", "취업", "커리어"], "면접관을 불편하게 만드는 표현들입니다."),
            ("노트북 발열 줄이는 방법", "IT수리공", "https://www.youtube.com/watch?v=shorts009", 5, 2_950_000, 180_000, 6_700, 190_000, 49, ["노트북", "발열", "관리"], "노트북이 뜨거워질 때 바로 해볼 수 있는 방법."),
            ("커피 맛있게 내리는 물 온도", "홈카페", "https://www.youtube.com/watch?v=shorts010", 27, 1_120_000, 84_000, 2_900, 76_000, 29, ["커피", "홈카페", "추출"], "물 온도만 바꿔도 커피 맛이 달라집니다.")
        ]

        return raw.map { item in
            let video = VideoResult(
                id: item.2,
                title: item.0,
                url: item.2,
                thumbnailURL: "",
                channelTitle: item.1,
                channelId: "channel_\(item.2)",
                publishedAt: daysAgo(item.3),
                durationSeconds: item.8,
                viewCount: item.4,
                likeCount: item.5,
                commentCount: item.6,
                subscriberCount: item.7,
                viralScore: 0,
                description: item.10,
                tags: item.9
            )
            var scored = video
            scored.viralScore = ViralScoreCalculator.score(for: video)
            return scored
        }
    }

    static func transcript(for fileName: String) -> TranscriptDocument {
        let lines: [(Double, Double, String)] = [
            (0.0, 2.4, "안녕하세요, 오늘은 5분이면 끝나는 아침 스트레칭 루틴을 알려드릴게요."),
            (2.4, 5.6, "하루 종일 앉아서 일하는 분들이라면 꼭 따라 해 보세요."),
            (5.6, 9.2, "먼저 목을 천천히 좌우로 돌려줍니다. 절대 빠르게 하지 마세요."),
            (9.2, 13.0, "다음은 어깨를 앞뒤로 크게 돌려주세요. 열 번씩 반복합니다."),
            (13.0, 17.4, "허리를 숙일 때는 무릎을 살짝 굽히고 천천히 내려갑니다."),
            (17.4, 21.0, "마지막으로 종아리 스트레칭을 좌우 각 30초씩 해 줍니다."),
            (21.0, 25.0, "매일 아침 5분, 이 루틴만 지켜도 몸이 훨씬 가벼워집니다."),
            (25.0, 28.0, "도움이 되셨다면 저장해 두고 내일 아침부터 시작해 보세요.")
        ]
        let segments = lines.map { TranscriptSegment(startTime: $0.0, endTime: $0.1, text: $0.2, confidence: 0.92) }
        var document = TranscriptDocument(
            sourceVideoFileName: fileName,
            language: "ko",
            segments: segments
        )
        document.rebuildPlainText()
        return document
    }

    static func translation(for document: TranscriptDocument, language: TranslateLanguage) -> String {
        let prefix: String
        switch language {
        case .korean: prefix = "[한국어 번역 · 데모]"
        case .japanese: prefix = "[日本語訳 · デモ]"
        case .english: prefix = "[English · demo]"
        case .chinese: prefix = "[中文 · 演示]"
        }
        let sentences = document.segments.map(\.text).joined(separator: "\n")
        return """
        \(prefix) 오프라인 데모 번역입니다. (API Key를 입력하면 실제 번역이 수행됩니다.)
        \(sentences)
        """
    }

    static func rewrittenScript(style: RewriteStyle, source: String) -> String {
        """
        [\(style.displayName) 재작성 데모]
        원문의 구조와 아이디어만 참고해 새롭게 작성된 예시입니다.

        1) 후킹: "이거 모르면 매일 손해 봅니다."
        2) 문제 제기: 대부분 이 부분을 놓치고 있습니다.
        3) 핵심 정보: \(source.prefix(60))...
        4) 마무리: 저장해 두고 오늘 바로 적용해 보세요.

        * 원문을 그대로 복제하지 않고 표현/전개/사례를 새롭게 구성합니다.
        """
    }

    static func titleCandidates(from source: String) -> [String] {
        [
            "이거 모르면 계속 손해 봅니다",
            "5분이면 끝, 오늘부터 바로 가능",
            "대부분 모르는 숨은 방법",
            "전문가가 알려주는 핵심 3가지",
            "저장해두면 평생 쓰는 꿀팁",
            "1분 안에 이해하는 핵심 정리",
            "지금 바로 따라 해보세요",
            "이 방법 하나로 달라집니다",
            "초보자도 바로 따라하는 방법",
            "알고 나면 후회하는 정보"
        ]
    }

    static func hooks() -> [String] {
        [
            "이거 모르면 진짜 손해입니다.",
            "솔직히 대부분 잘못하고 있습니다.",
            "딱 30초만 집중해 보세요.",
            "이건 알려주는 사람이 거의 없어요.",
            "오늘부터 바로 바꿀 수 있습니다.",
            "저도 이걸 알고 인생이 편해졌어요.",
            "끝까지 보면 이유를 알게 됩니다.",
            "지금 저장해 두세요, 나중에 필요합니다.",
            "한 번만 따라 하면 차이가 납니다.",
            "이 영상 하나로 정리 끝냅니다."
        ]
    }
}
