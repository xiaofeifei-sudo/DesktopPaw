public protocol RandomNumberGenerating: AnyObject {
    func nextDouble(in range: ClosedRange<Double>) -> Double
}

public final class SystemRandomNumberGenerator: RandomNumberGenerating {
    public init() {}

    public func nextDouble(in range: ClosedRange<Double>) -> Double {
        Double.random(in: range)
    }
}
