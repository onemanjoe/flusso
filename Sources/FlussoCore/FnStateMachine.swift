import Foundation

public enum FnEvent {
    case fnDown(TimeInterval)
    case fnUp(TimeInterval)
    case escDown(TimeInterval)
    case otherKeyDown(TimeInterval)
}

public enum FnAction: Equatable {
    case startRecording, stopAndProcess, cancelRecording, none
}

public final class FnStateMachine {
    public static let minHoldSeconds: Double = 0.4
    private var recordingSince: TimeInterval?

    public init() {}

    public func handle(_ event: FnEvent) -> FnAction {
        switch event {
        case .fnDown(let t):
            guard recordingSince == nil else { return .none }
            recordingSince = t
            return .startRecording
        case .fnUp(let t):
            guard let start = recordingSince else { return .none }
            recordingSince = nil
            return (t - start) >= Self.minHoldSeconds ? .stopAndProcess : .cancelRecording
        case .escDown, .otherKeyDown:
            guard recordingSince != nil else { return .none }
            recordingSince = nil
            return .cancelRecording
        }
    }
}
