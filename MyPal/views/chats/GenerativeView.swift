//
//  GenerativeView.swift
//  MyPal
//
//  Created by Chidume Nnamdi on 09/08/2025.
//

import SwiftUI
import FoundationModels

struct GenerativeView: View {
    private let foundationModel = FoundationModel.shared

    var body: some View {
        
        
        switch foundationModel.model.availability {
        case .available:
            Image(systemName: "checkmark.circle")
                .foregroundStyle(.green)

        case .unavailable(.deviceNotEligible):
            // Show an alternative UI.
            Image(systemName: "xmark").foregroundStyle(.red)

        case .unavailable(.appleIntelligenceNotEnabled):
            // Ask the person to turn on Apple Intelligence.
            Image(systemName: "xmark").foregroundStyle(.red)

        case .unavailable(.modelNotReady):
            // The model isn't ready because it's downloading or because of other system reasons.
            Image(systemName: "xmark").foregroundStyle(.red)

        case .unavailable(let other):
            // The model is unavailable for an unknown reason.
            Image(systemName: "xmark").foregroundStyle(.red)

        }
        
    }
}

#Preview {
    GenerativeView()
}
