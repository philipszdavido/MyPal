import SwiftUI
import FoundationModels

/// Observable wrapper around `SystemLanguageModel.default.availability`.
@MainActor
@Observable
final class ModelAvailability {

    enum Status: Equatable {
        case available
        case deviceNotEligible
        case notEnabled
        case notReady
        case unknown
    }

    private(set) var status: Status = .unknown

    init() { refresh() }

    var isAvailable: Bool { status == .available }

    func refresh() {
        switch SystemLanguageModel.default.availability {
        case .available:
            status = .available
        case .unavailable(let reason):
            switch reason {
            case .deviceNotEligible: status = .deviceNotEligible
            case .appleIntelligenceNotEnabled: status = .notEnabled
            case .modelNotReady: status = .notReady
            default: status = .unknown
            }
        default:
            status = .unknown
        }
    }

    var title: String {
        switch status {
        case .available: "Apple Intelligence is ready"
        case .deviceNotEligible: "This device isn't supported"
        case .notEnabled: "Turn on Apple Intelligence"
        case .notReady: "Getting the model ready"
        case .unknown: "Apple Intelligence is unavailable"
        }
    }

    var message: String {
        switch status {
        case .available: "Replies are generated privately on your device."
        case .deviceNotEligible: "MyPal uses Apple's on-device model, which needs a compatible iPhone or iPad."
        case .notEnabled: "Enable Apple Intelligence in Settings to chat with your pals."
        case .notReady: "The on-device model is still downloading. Try again in a little while."
        case .unknown: "The on-device model can't be used right now."
        }
    }

    var symbol: String {
        switch status {
        case .available: "checkmark.seal.fill"
        case .notReady: "arrow.down.circle"
        default: "exclamationmark.triangle.fill"
        }
    }
}

struct AvailabilityBanner: View {
    let availability: ModelAvailability

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(availability.title).font(.subheadline.weight(.semibold))
                Text(availability.message).font(.footnote).foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: availability.symbol).foregroundStyle(.orange)
        }
        .accessibilityElement(children: .combine)
    }
}
