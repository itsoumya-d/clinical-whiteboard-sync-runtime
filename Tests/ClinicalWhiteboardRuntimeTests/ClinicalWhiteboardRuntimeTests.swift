import XCTest
@testable import ClinicalWhiteboardRuntime

final class ClinicalWhiteboardRuntimeTests: XCTestCase {

    func testValidLifecycleTransitionFlow() throws {
        let engine = PatientStateEngine()
        let patient = PatientRecord(
            id: "P-101",
            patientName: "Bella",
            species: "Canine",
            tasks: [
                ClinicalTask(id: "T-1", name: "Discharge vitals check", isCompleted: true, isRequiredForDischarge: true)
            ]
        )
        engine.upsertPatient(patient)

        let triage = try engine.transitionPhase(patientId: "P-101", targetPhase: .triage)
        XCTAssertEqual(triage.phase, .triage)

        let treatment = try engine.transitionPhase(patientId: "P-101", targetPhase: .treatment)
        XCTAssertEqual(treatment.phase, .treatment)

        let recovery = try engine.transitionPhase(patientId: "P-101", targetPhase: .recovery)
        XCTAssertEqual(recovery.phase, .recovery)

        let discharged = try engine.transitionPhase(patientId: "P-101", targetPhase: .discharged)
        XCTAssertEqual(discharged.phase, .discharged)
    }

    func testIllegalDischargePreventedWhenRequiredTasksIncomplete() {
        let engine = PatientStateEngine()
        let patient = PatientRecord(
            id: "P-102",
            patientName: "Max",
            species: "Feline",
            phase: .recovery,
            tasks: [
                ClinicalTask(id: "T-2", name: "Post-op catheter removal", isCompleted: false, isRequiredForDischarge: true)
            ]
        )
        engine.upsertPatient(patient)

        XCTAssertThrowsError(try engine.transitionPhase(patientId: "P-102", targetPhase: .discharged)) { error in
            guard case let ClinicalWorkflowError.incompleteRequiredTasks(tasks) = error else {
                XCTFail("Expected incompleteRequiredTasks, got \(error)")
                return
            }
            XCTAssertTrue(tasks.contains("Post-op catheter removal"))
        }
    }

    func testIllegalDirectTransitionPrevented() {
        let engine = PatientStateEngine()
        let patient = PatientRecord(id: "P-103", patientName: "Charlie", species: "Canine", phase: .admitted)
        engine.upsertPatient(patient)

        // Admitted cannot jump directly to Discharged
        XCTAssertThrowsError(try engine.transitionPhase(patientId: "P-103", targetPhase: .discharged)) { error in
            guard case let ClinicalWorkflowError.invalidPhaseTransition(from, to) = error else {
                XCTFail("Expected invalidPhaseTransition, got \(error)")
                return
            }
            XCTAssertEqual(from, .admitted)
            XCTAssertEqual(to, .discharged)
        }
    }

    func testMedicationAdministrationLogging() throws {
        let engine = PatientStateEngine()
        let patient = PatientRecord(id: "P-104", patientName: "Luna", species: "Feline", phase: .treatment)
        engine.upsertPatient(patient)

        let dose = MedicationDose(drugName: "Meloxicam", dosage: "0.2mg/kg", administeredBy: "Nurse Sarah")
        let updated = try engine.recordMedication(patientId: "P-104", dose: dose)

        XCTAssertEqual(updated.medications.count, 1)
        XCTAssertEqual(updated.medications.first?.drugName, "Meloxicam")
        XCTAssertEqual(updated.medications.first?.administeredBy, "Nurse Sarah")
    }

    func testWhiteboardPrioritySorting() {
        let engine = PatientStateEngine()
        let routine = PatientRecord(id: "P-1", patientName: "Milo", species: "Canine", careLevel: .routine)
        let critical = PatientRecord(id: "P-2", patientName: "Rocky", species: "Canine", careLevel: .critical)
        let urgent = PatientRecord(id: "P-3", patientName: "Daisy", species: "Feline", careLevel: .urgent)

        engine.upsertPatient(routine)
        engine.upsertPatient(critical)
        engine.upsertPatient(urgent)

        let active = engine.allActivePatients()
        XCTAssertEqual(active.map { $0.id }, ["P-2", "P-3", "P-1"])
    }

    func testOptimisticConflictResolution() {
        let engine = PatientStateEngine()
        let olderDate = Date(timeIntervalSince1970: 1000)
        let newerDate = Date(timeIntervalSince1970: 2000)

        let local = PatientRecord(
            id: "P-105",
            patientName: "Bailey",
            species: "Canine",
            tasks: [
                ClinicalTask(id: "T-3", name: "IV Fluids check", isCompleted: false, updatedAt: olderDate)
            ]
        )
        engine.upsertPatient(local)

        let remote = PatientRecord(
            id: "P-105",
            patientName: "Bailey",
            species: "Canine",
            tasks: [
                ClinicalTask(id: "T-3", name: "IV Fluids check", isCompleted: true, updatedAt: newerDate)
            ],
            lastModified: newerDate
        )

        let reconciled = engine.reconcileRemotePatient(remote: remote)
        XCTAssertEqual(reconciled.tasks.first?.isCompleted, true)
    }

    func testObjCBridgeableCompatibility() {
        let bridge = ObjCWhiteboardBridge()
        bridge.registerPatient(id: "OB-1", name: "Coco", species: "Canine", isCritical: true)

        XCTAssertEqual(bridge.activePatientIds(), ["OB-1"])

        var err: NSError?
        let ok = bridge.transitionPatient(patientId: "OB-1", toPhaseString: "TRIAGE", error: &err)
        XCTAssertTrue(ok)
        XCTAssertNil(err)

        let medOk = bridge.recordMedication(patientId: "OB-1", drug: "Buprenorphine", dosage: "0.02mg/kg", nurse: "Vet Tech Alex")
        XCTAssertTrue(medOk)

        let badOk = bridge.transitionPatient(patientId: "OB-1", toPhaseString: "DISCHARGED", error: &err)
        XCTAssertFalse(badOk)
        XCTAssertNotNil(err)
    }
}
