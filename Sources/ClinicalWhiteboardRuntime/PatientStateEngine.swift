import Foundation

public enum ClinicalWorkflowError: Error, Equatable {
    case patientNotFound(String)
    case invalidPhaseTransition(from: PatientPhase, to: PatientPhase)
    case incompleteRequiredTasks([String])
    case patientAlreadyDischarged
}

public final class PatientStateEngine: @unchecked Sendable {
    private let lock = NSLock()
    private var records: [String: PatientRecord] = [:]

    public init(initialRecords: [PatientRecord] = []) {
        for record in initialRecords {
            self.records[record.id] = record
        }
    }

    public func upsertPatient(_ record: PatientRecord) {
        lock.lock()
        defer { lock.unlock() }
        records[record.id] = record
    }

    public func getPatient(_ id: String) -> PatientRecord? {
        lock.lock()
        defer { lock.unlock() }
        return records[id]
    }

    public func allActivePatients() -> [PatientRecord] {
        lock.lock()
        defer { lock.unlock() }
        return records.values
            .filter { $0.phase != .discharged }
            .sorted { (lhs, rhs) -> Bool in
                if lhs.careLevel != rhs.careLevel {
                    return priorityWeight(lhs.careLevel) > priorityWeight(rhs.careLevel)
                }
                return lhs.lastModified > rhs.lastModified
            }
    }

    private func priorityWeight(_ level: CareLevel) -> Int {
        switch level {
        case .critical: return 3
        case .urgent: return 2
        case .routine: return 1
        }
    }

    public func transitionPhase(patientId: String, targetPhase: PatientPhase) throws -> PatientRecord {
        lock.lock()
        defer { lock.unlock() }

        guard var record = records[patientId] else {
            throw ClinicalWorkflowError.patientNotFound(patientId)
        }

        if record.phase == .discharged {
            throw ClinicalWorkflowError.patientAlreadyDischarged
        }

        guard isValidTransition(from: record.phase, to: targetPhase) else {
            throw ClinicalWorkflowError.invalidPhaseTransition(from: record.phase, to: targetPhase)
        }

        if targetPhase == .discharged {
            let pendingTasks = record.tasks
                .filter { $0.isRequiredForDischarge && !$0.isCompleted }
                .map { $0.name }
            if !pendingTasks.isEmpty {
                throw ClinicalWorkflowError.incompleteRequiredTasks(pendingTasks)
            }
        }

        record.phase = targetPhase
        record.lastModified = Date()
        records[patientId] = record
        return record
    }

    public func recordMedication(patientId: String, dose: MedicationDose) throws -> PatientRecord {
        lock.lock()
        defer { lock.unlock() }

        guard var record = records[patientId] else {
            throw ClinicalWorkflowError.patientNotFound(patientId)
        }
        if record.phase == .discharged {
            throw ClinicalWorkflowError.patientAlreadyDischarged
        }

        record.medications.append(dose)
        record.lastModified = Date()
        records[patientId] = record
        return record
    }

    public func setTaskCompletion(patientId: String, taskId: String, isCompleted: Bool) throws -> PatientRecord {
        lock.lock()
        defer { lock.unlock() }

        guard var record = records[patientId] else {
            throw ClinicalWorkflowError.patientNotFound(patientId)
        }
        guard let idx = record.tasks.firstIndex(where: { $0.id == taskId }) else {
            return record
        }

        record.tasks[idx].isCompleted = isCompleted
        record.tasks[idx].updatedAt = Date()
        record.lastModified = Date()
        records[patientId] = record
        return record
    }

    public func reconcileRemotePatient(remote: PatientRecord) -> PatientRecord {
        lock.lock()
        defer { lock.unlock() }

        guard let local = records[remote.id] else {
            records[remote.id] = remote
            return remote
        }

        // Causal / timestamp resolution: merge task statuses based on newest update
        var mergedTasks = local.tasks
        for remoteTask in remote.tasks {
            if let lIdx = mergedTasks.firstIndex(where: { $0.id == remoteTask.id }) {
                if remoteTask.updatedAt > mergedTasks[lIdx].updatedAt {
                    mergedTasks[lIdx] = remoteTask
                }
            } else {
                mergedTasks.append(remoteTask)
            }
        }

        // Union medication logs (immutable append-only audit trail)
        var medMap: [String: MedicationDose] = [:]
        for m in local.medications + remote.medications {
            medMap[m.id] = m
        }
        let mergedMeds = Array(medMap.values).sorted { $0.administeredAt < $1.administeredAt }

        let activePhase = remote.lastModified > local.lastModified ? remote.phase : local.phase
        let resolvedModified = max(local.lastModified, remote.lastModified)

        let merged = PatientRecord(
            id: local.id,
            patientName: remote.patientName,
            species: remote.species,
            phase: activePhase,
            careLevel: remote.careLevel,
            tasks: mergedTasks,
            medications: mergedMeds,
            lastModified: resolvedModified
        )
        records[local.id] = merged
        return merged
    }

    private func isValidTransition(from: PatientPhase, to: PatientPhase) -> Bool {
        switch (from, to) {
        case (.admitted, .triage), (.admitted, .treatment):
            return true
        case (.triage, .treatment), (.triage, .recovery):
            return true
        case (.treatment, .recovery), (.treatment, .triage):
            return true
        case (.recovery, .treatment), (.recovery, .discharged):
            return true
        default:
            return false
        }
    }
}
