import Foundation

struct DayTask: Identifiable, Hashable {
    let id: UUID
    /// 0..24, fractional. No duration, no end time, no category.
    var hour: Double
    var label: String

    init(id: UUID = UUID(), hour: Double, label: String) {
        self.id = id
        self.hour = hour
        self.label = label
    }
}
