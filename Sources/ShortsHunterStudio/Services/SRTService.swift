import Foundation

/// SRT 자막 생성 서비스. 실제로 동작한다.
enum SRTService {

    /// 세그먼트 배열을 SRT 문자열로 변환한다.
    /// - Parameters:
    ///   - useTranslation: translatedText가 있으면 번역문을 사용한다.
    ///   - maxLineLength: 한 줄 최대 글자 수(초과 시 자동 줄바꿈).
    static func srt(
        from segments: [TranscriptSegment],
        useTranslation: Bool = false,
        maxLineLength: Int = 24
    ) -> String {
        var output = ""
        var index = 1
        for segment in segments {
            let raw = useTranslation
                ? (segment.translatedText?.isEmpty == false ? segment.translatedText! : segment.text)
                : segment.text
            let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }

            output += "\(index)\n"
            output += "\(TimecodeFormatter.srtTimecode(segment.startTime)) --> \(TimecodeFormatter.srtTimecode(segment.endTime))\n"
            output += "\(wrap(text, maxLineLength: maxLineLength))\n\n"
            index += 1
        }
        return output
    }

    /// 공백 기준으로 줄바꿈하되, 한 단어가 너무 길면 강제로 자른다.
    static func wrap(_ text: String, maxLineLength: Int) -> String {
        guard maxLineLength > 0 else { return text }
        let words = text.split(separator: " ").map(String.init)
        var lines: [String] = []
        var current = ""

        func flush() {
            if !current.isEmpty {
                lines.append(current)
                current = ""
            }
        }

        for word in words {
            if word.count > maxLineLength {
                flush()
                var remaining = word
                while remaining.count > maxLineLength {
                    let cutIndex = remaining.index(remaining.startIndex, offsetBy: maxLineLength)
                    lines.append(String(remaining[remaining.startIndex..<cutIndex]))
                    remaining = String(remaining[cutIndex...])
                }
                current = remaining
                continue
            }
            if current.isEmpty {
                current = word
            } else if current.count + 1 + word.count <= maxLineLength {
                current += " " + word
            } else {
                flush()
                current = word
            }
        }
        flush()
        return lines.joined(separator: "\n")
    }
}
