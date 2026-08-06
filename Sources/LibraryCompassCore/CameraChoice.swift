import Foundation

/// Welche Kamera soll scannen? Auf einem Mac melden sich oft mehrere: echte
/// Webcams, aber auch virtuelle von OBS und Co., die nur ein Standbild liefern.
/// Reihenfolge: Autofokus zuerst (nur damit wird ein Strichcode aus der Nähe
/// scharf), dann die höchste Auflösung, virtuelle Kameras zuletzt.
public enum CameraChoice {

    public struct Candidate: Sendable, Equatable {
        public let name: String
        public let pixels: Int
        public let hasAutofocus: Bool

        public init(name: String, pixels: Int, hasAutofocus: Bool) {
            self.name = name
            self.pixels = pixels
            self.hasAutofocus = hasAutofocus
        }
    }

    private static let virtualMarkers = ["obs", "virtual", "snap camera", "mmhmm", "pickle", "camo", "epoccam"]

    public static func isVirtual(_ name: String) -> Bool {
        let lowered = name.lowercased()
        return virtualMarkers.contains { lowered.contains($0) }
    }

    public static func best(of candidates: [Candidate]) -> Candidate? {
        candidates.max { left, right in rank(left) < rank(right) }
    }

    /// Größer ist besser: (echt vor virtuell, Autofokus, Auflösung).
    private static func rank(_ candidate: Candidate) -> (Int, Int, Int) {
        (isVirtual(candidate.name) ? 0 : 1, candidate.hasAutofocus ? 1 : 0, candidate.pixels)
    }
}
