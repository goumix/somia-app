import Foundation

enum Tool: CaseIterable, Identifiable {
    case cardiacCoherence
    case dataExport
    case glucoseTracking

    var id: Self { self }

    var title: String {
        switch self {
        case .cardiacCoherence: return "Cohérence cardiaque"
        case .dataExport:       return "Export de données"
        case .glucoseTracking:  return "Suivi glycémie"
        }
    }

    var subtitle: String {
        switch self {
        case .cardiacCoherence: return "Exercice de respiration guidée"
        case .dataExport:       return "Exporter vos données de santé"
        case .glucoseTracking:  return "Suivez votre taux de glucose"
        }
    }

    var systemImage: String {
        switch self {
        case .cardiacCoherence: return "heart.circle"
        case .dataExport:       return "square.and.arrow.up"
        case .glucoseTracking:  return "drop.fill"
        }
    }
}
