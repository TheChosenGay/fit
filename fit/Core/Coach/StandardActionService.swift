import Foundation
import SwiftData

// MARK: - StandardActionService Protocol
@available(iOS 17.0, *)
protocol StandardActionService {
    func loadSequence(exerciseId: String) async throws -> StandardActionSequence?
    func availableSequences(context: ModelContext) throws -> [StandardSequenceCatalog]
    func interpolateFrame(sequence: StandardActionSequence, atTimeMs: Int) -> SequenceFrame
}

// MARK: - Local Implementation

@available(iOS 17.0, *)
final class LocalStandardActionService: StandardActionService {

    private var cache: [String: StandardActionSequence] = [:]

    func loadSequence(exerciseId: String) async throws -> StandardActionSequence? {
        if let cached = cache[exerciseId] { return cached }

        guard let url = sequenceFileURL(for: exerciseId) else { return nil }

        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let sequence = try decoder.decode(StandardActionSequence.self, from: data)
        cache[exerciseId] = sequence
        return sequence
    }

    func availableSequences(context: ModelContext) throws -> [StandardSequenceCatalog] {
        let descriptor = FetchDescriptor<StandardSequenceCatalog>(
            sortBy: [SortDescriptor(\.exerciseName)]
        )
        return try context.fetch(descriptor)
    }

    func interpolateFrame(sequence: StandardActionSequence, atTimeMs: Int) -> SequenceFrame {
        let frames = sequence.frames
        guard !frames.isEmpty else {
            return SequenceFrame(timeMs: atTimeMs, joints: [:])
        }

        let clampedTime: Int
        if sequence.config.isLoopable {
            let duration = sequence.metadata.durationMs
            clampedTime = duration > 0 ? atTimeMs % duration : 0
        } else {
            clampedTime = min(max(atTimeMs, frames.first!.timeMs), frames.last!.timeMs)
        }

        guard let nextIdx = frames.firstIndex(where: { $0.timeMs >= clampedTime }) else {
            return frames.last!
        }

        if nextIdx == 0 || frames[nextIdx].timeMs == clampedTime {
            return frames[nextIdx]
        }

        let prev = frames[nextIdx - 1]
        let next = frames[nextIdx]
        let span = Float(next.timeMs - prev.timeMs)
        let t = span > 0 ? Float(clampedTime - prev.timeMs) / span : 0

        var interpolatedJoints: [String: JointPosition3D] = [:]
        let allKeys = Set(prev.joints.keys).union(next.joints.keys)
        for key in allKeys {
            guard let p = prev.joints[key], let n = next.joints[key] else {
                interpolatedJoints[key] = prev.joints[key] ?? next.joints[key]
                continue
            }
            interpolatedJoints[key] = JointPosition3D(
                x: p.x + (n.x - p.x) * t,
                y: p.y + (n.y - p.y) * t,
                z: p.z + (n.z - p.z) * t
            )
        }

        return SequenceFrame(timeMs: clampedTime, joints: interpolatedJoints)
    }

    // MARK: - Private

    private func sequenceFileURL(for exerciseId: String) -> URL? {
        if let bundleURL = Bundle.main.url(
            forResource: "\(exerciseId)_standard_v1",
            withExtension: "json"
        ) {
            return bundleURL
        }

        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent("StandardSequences")
            .appendingPathComponent("\(exerciseId)_standard_v1.json")
        if let url = documentsURL, FileManager.default.fileExists(atPath: url.path) {
            return url
        }

        return nil
    }
}
