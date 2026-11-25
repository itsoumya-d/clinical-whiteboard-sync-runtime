import Foundation

public enum PatientPhase: String, Codable, CaseIterable, Sendable {
    case admitted = "ADMITTED"
    case triage = "TRIAGE"
    case treatment = "TREATMENT"
    case recovery = "RECOVERY"
    case discharged = "DISCHARGED"
}

public enum CareLevel: String, Codable, Sendable {
    case routine = "ROUTINE"
    case urgent = "URGENT"
    case critical = "CRITICAL"
}

public struct ClinicalTask: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public var name: String
    public var isCompleted: Bool
    public var assignedTo: String?
    public var updatedAt: Date
    public var isRequiredForDischarge: Bool
    public var billingCode: String?

    public init(
        id: String = UUID().uuidString,
        name: String,
        isCompleted: Bool = false,
        assignedTo: String? = nil,
        updatedAt: Date = Date(),
        isRequiredForDischarge: Bool = false,
        billingCode: String? = nil
    ) {
        self.id = id
        self.name = name
        self.isCompleted = isCompleted
        self.assignedTo = assignedTo
        self.updatedAt = updatedAt
        self.isRequiredForDischarge = isRequiredForDischarge
        self.billingCode = billingCode
    }
}

public struct MedicationDose: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let drugName: String
    public let dosage: String
    public let administeredAt: Date
    public let administeredBy: String

    public init(
        id: String = UUID().uuidString,
        drugName: String,
        dosage: String,
        administeredAt: Date = Date(),
        administeredBy: String
    ) {
        self.id = id
        self.drugName = drugName
        self.dosage = dosage
        self.administeredAt = administeredAt
        self.administeredBy = administeredBy
    }
}

public struct PatientRecord: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public var patientName: String
    public var species: String
    public var phase: PatientPhase
    public var careLevel: CareLevel
    public var tasks: [ClinicalTask]
    public var medications: [MedicationDose]
    public var lastModified: Date

    public init(
        id: String,
        patientName: String,
        species: String,
        phase: PatientPhase = .admitted,
        careLevel: CareLevel = .routine,
        tasks: [ClinicalTask] = [],
        medications: [MedicationDose] = [],
        lastModified: Date = Date()
    ) {
        self.id = id
        self.patientName = patientName
        self.species = species
        self.phase = phase
        self.careLevel = careLevel
        self.tasks = tasks
        self.medications = medications
        self.lastModified = lastModified
    }
}
