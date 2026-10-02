import Foundation

/// 타임코드 및 길이 표기 유틸.
enum TimecodeFormatter {
    /// 00:00:02,400 형식의 SRT 타임코드.
    static func srtTimecode(_ seconds: Double) -> String {
        let clamped = max(0, seconds)
        let totalMilliseconds = Int((clamped * 1000).rounded())
        let milliseconds = totalMilliseconds % 1000
        let totalSeconds = totalMilliseconds / 1000
        let secs = totalSeconds % 60
        let minutes = (totalSeconds / 60) % 60
        let hours = totalSeconds / 3600
        return String(format: "%02d:%02d:%02d,%03d", hours, minutes, secs, milliseconds)
    }

    /// 1:05 / 12:03 형식의 사람이 읽기 쉬운 길이.
    static func durationText(seconds: Int) -> String {
        let clamped = max(0, seconds)
        let secs = clamped % 60
        let minutes = (clamped / 60) % 60
        let hours = clamped / 3600
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }

    /// ISO8601 duration(PT1M5S)을 초로 변환. 파싱 실패 시 nil.
    static func seconds(fromISODuration duration: String) -> Int? {
        guard duration.hasPrefix("PT") else { return nil }
        var total = 0
        var number = ""
        for character in duration.dropFirst(2) {
            if character.isNumber {
                number.append(character)
            } else {
                guard let value = Int(number) else { return total }
                switch character {
                case "H": total += value * 3600
                case "M": total += value * 60
                case "S": total += value
                default: break
                }
                number = ""
            }
        }
        if let value = Int(number) { total += value }
        return total
    }
}
