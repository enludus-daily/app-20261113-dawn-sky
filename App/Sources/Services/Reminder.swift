import Foundation
import UserNotifications

/// 起きる時刻のお知らせ（オプトイン。曜日ごとに 1 回。端末の中だけ）
enum Reminder {
    static func ids() -> [String] { (1...7).map { "wake-\($0)" } }

    /// 許可を聞いて、曜日ごとに予約する。許可がなければ false
    static func enable(schedule: WakeSchedule, japanese: Bool) async -> Bool {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        guard granted else { return false }
        center.removePendingNotificationRequests(withIdentifiers: ids())
        for weekday in 1...7 {
            let minutes = schedule.minutes(forWeekday: weekday)
            let content = UNMutableNotificationContent()
            content.title = japanese ? "空を撮る 15 分です" : "Your 15-minute sky window is open"
            content.body = japanese ? "カーテンを開けて、今朝の色を図鑑へ。" : "Open the curtains and add this morning's color to your atlas."
            content.sound = .default
            var when = DateComponents()
            when.weekday = weekday
            when.hour = minutes / 60
            when.minute = minutes % 60
            let request = UNNotificationRequest(identifier: "wake-\(weekday)", content: content,
                                                trigger: UNCalendarNotificationTrigger(dateMatching: when, repeats: true))
            try? await center.add(request)
        }
        return true
    }

    static func disable() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids())
    }
}
