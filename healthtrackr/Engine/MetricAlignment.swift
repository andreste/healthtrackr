import Foundation

enum MetricAlignment {
    struct AlignedPair {
        let date: Date
        let a: Double
        let b: Double
    }

    static func align(
        a: [MetricSample],
        b: [MetricSample],
        lagHours: Int
    ) -> [AlignedPair] {
        let calendar = Calendar.current
        let lagDays = lagHours / 24
        let hasHalfDayOffset = (lagHours % 24) == 12

        var bByDay: [Date: Double] = [:]
        for sample in b {
            let day = calendar.startOfDay(for: sample.date)
            bByDay[day] = sample.value
        }

        var pairs: [AlignedPair] = []
        for sample in a {
            let dayA = calendar.startOfDay(for: sample.date)

            if hasHalfDayOffset {
                guard let dayB1 = calendar.date(byAdding: .day, value: lagDays, to: dayA),
                      let dayB2 = calendar.date(byAdding: .day, value: lagDays + 1, to: dayA),
                      let val1 = bByDay[dayB1],
                      let val2 = bByDay[dayB2] else { continue }
                pairs.append(AlignedPair(date: sample.date, a: sample.value, b: (val1 + val2) / 2.0))
            } else {
                guard let dayB = calendar.date(byAdding: .day, value: lagDays, to: dayA),
                      let valB = bByDay[dayB] else { continue }
                pairs.append(AlignedPair(date: sample.date, a: sample.value, b: valB))
            }
        }
        return pairs
    }
}
