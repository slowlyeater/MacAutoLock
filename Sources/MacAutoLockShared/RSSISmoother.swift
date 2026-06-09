import Foundation

public struct RSSISmoother: Equatable, Sendable {
    public private(set) var current: Int?
    public var alpha: Double

    public init(current: Int? = nil, alpha: Double = 0.35) {
        self.current = current
        self.alpha = alpha
    }

    public mutating func addSample(_ sample: Int) -> Int {
        guard let current else {
            self.current = sample
            return sample
        }

        let blended = (Double(sample) * alpha) + (Double(current) * (1 - alpha))
        let rounded = Int(blended.rounded())
        self.current = rounded
        return rounded
    }

    public mutating func reset() {
        current = nil
    }
}
