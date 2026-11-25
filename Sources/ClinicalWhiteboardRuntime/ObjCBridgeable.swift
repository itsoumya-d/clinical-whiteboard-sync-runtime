import Foundation

#if canImport(ObjectiveC)
@objc(CWRObjCWhiteboardBridge)
public final class ObjCWhiteboardBridge: NSObject {
    private let engine: PatientStateEngine

    @objc public override init() {
        self.engine = PatientStateEngine()
        super.init()
    }

    public init(engine: PatientStateEngine) {
        self.engine = engine
        super.init()
    }

    @objc public func registerPatient(id: String, name: String, species: String, isCritical: Bool) {
        let level: CareLevel = isCritical ? .critical : .routine
        let record = PatientRecord(id: id, patientName: name, species: species, careLevel: level)
        engine.upsertPatient(record)
    }

    @objc public func transitionPatient(patientId: String, toPhaseString: String, error outError: NSErrorPointer) -> Bool {
        guard let phase = PatientPhase(rawValue: toPhaseString.uppercased()) else {
            outError?.pointee = NSError(
                domain: "ClinicalWhiteboardRuntime",
                code: 1001,
                userInfo: [NSLocalizedDescriptionKey: "Unknown phase: \(toPhaseString)"]
            )
            return false
        }
        do {
            _ = try engine.transitionPhase(patientId: patientId, targetPhase: phase)
            return true
        } catch let err as ClinicalWorkflowError {
            outError?.pointee = NSError(
                domain: "ClinicalWhiteboardRuntime",
                code: 1002,
                userInfo: [NSLocalizedDescriptionKey: "\(err)"]
            )
            return false
        } catch let err {
            outError?.pointee = err as NSError
            return false
        }
    }

    @objc public func recordMedication(patientId: String, drug: String, dosage: String, nurse: String) -> Bool {
        let dose = MedicationDose(drugName: drug, dosage: dosage, administeredBy: nurse)
        do {
            _ = try engine.recordMedication(patientId: patientId, dose: dose)
            return true
        } catch {
            return false
        }
    }

    @objc public func activePatientIds() -> [String] {
        return engine.allActivePatients().map { $0.id }
    }
}
#else
public final class ObjCWhiteboardBridge {
    private let engine: PatientStateEngine

    public init(engine: PatientStateEngine = PatientStateEngine()) {
        self.engine = engine
    }

    public func registerPatient(id: String, name: String, species: String, isCritical: Bool) {
        let level: CareLevel = isCritical ? .critical : .routine
        let record = PatientRecord(id: id, patientName: name, species: species, careLevel: level)
        engine.upsertPatient(record)
    }

    public func transitionPatient(patientId: String, toPhaseString: String) throws -> Bool {
        guard let phase = PatientPhase(rawValue: toPhaseString.uppercased()) else {
            throw ClinicalWorkflowError.invalidPhaseTransition(from: .admitted, to: .discharged)
        }
        _ = try engine.transitionPhase(patientId: patientId, targetPhase: phase)
        return true
    }

    public func recordMedication(patientId: String, drug: String, dosage: String, nurse: String) -> Bool {
        let dose = MedicationDose(drugName: drug, dosage: dosage, administeredBy: nurse)
        do {
            _ = try engine.recordMedication(patientId: patientId, dose: dose)
            return true
        } catch {
            return false
        }
    }

    public func activePatientIds() -> [String] {
        return engine.allActivePatients().map { $0.id }
    }
}
#endif
