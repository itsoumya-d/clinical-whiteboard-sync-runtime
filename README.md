# Clinical Whiteboard Sync Runtime

In-hospital clinical whiteboard workflow runtime and dynamic patient record synchronization engine for iOS / iPadOS applications.

## Overview

Designed for high-reliability medical and veterinary in-hospital environments, this framework provides:
- **Clinical Patient Lifecycle FSM**: Enforces strict transitions across patient care phases (`Admitted`, `Triage`, `Treatment`, `Recovery`, `Discharged`).
- **Dynamic Task & Medication Audit Log**: Optimistic offline-first event recording with conflict resolution and billing transaction readiness.
- **Objective-C Interoperability Bridge**: Idiomatic modern Swift engine exposed cleanly to Objective-C runtime callers for phased modernization.

## Build & Test

```bash
swift build
swift test
```
