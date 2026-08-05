import Foundation

/// Zoom-Schritte der Toolbar (README §6): ±0,10, geklemmt 0,70–1,70.
/// Jeder Schritt rechnet auf dem zuletzt gesetzten Wert — zwei schnelle Klicks
/// ergeben deshalb zwei Schritte.
public enum Zoom {
    public static let minimum = 0.70
    public static let maximum = 1.70
    public static let step = 0.10

    public static func clamp(_ value: Double) -> Double {
        (Swift.min(maximum, Swift.max(minimum, value)) * 100).rounded() / 100
    }

    public static func stepped(_ value: Double, by delta: Double) -> Double {
        clamp(value + delta)
    }

    /// Position auf der Spur (0…1) → Zoomstufe.
    public static func fromTrack(_ fraction: Double) -> Double {
        clamp(minimum + Swift.min(1, Swift.max(0, fraction)) * (maximum - minimum))
    }

    public static func trackFraction(_ value: Double) -> Double {
        (clamp(value) - minimum) / (maximum - minimum)
    }
}
