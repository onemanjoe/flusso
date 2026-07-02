import Foundation
import FlussoCore

func fnStateMachineChecks() async {
    await Harness.check("hold and release processes") {
        let m = FnStateMachine()
        try Harness.expect(m.handle(.fnDown(10.0)) == .startRecording)
        try Harness.expect(m.handle(.fnUp(11.5)) == .stopAndProcess)
    }
    await Harness.check("quick tap cancels") {
        let m = FnStateMachine()
        try Harness.expect(m.handle(.fnDown(10.0)) == .startRecording)
        try Harness.expect(m.handle(.fnUp(10.2)) == .cancelRecording)
    }
    await Harness.check("esc while holding cancels") {
        let m = FnStateMachine()
        _ = m.handle(.fnDown(10.0))
        try Harness.expect(m.handle(.escDown(10.5)) == .cancelRecording)
        try Harness.expect(m.handle(.fnUp(11.0)) == .none, "fnUp after cancel must be none")
    }
    await Harness.check("other key while holding cancels, combos never dictate") {
        let m = FnStateMachine()
        _ = m.handle(.fnDown(10.0))
        try Harness.expect(m.handle(.otherKeyDown(10.1)) == .cancelRecording)
    }
    await Harness.check("stray events while idle are none") {
        let m = FnStateMachine()
        try Harness.expect(m.handle(.fnUp(10.0)) == .none)
        try Harness.expect(m.handle(.escDown(10.0)) == .none)
        try Harness.expect(m.handle(.otherKeyDown(10.0)) == .none)
    }
    await Harness.check("double fnDown does not restart") {
        let m = FnStateMachine()
        _ = m.handle(.fnDown(10.0))
        try Harness.expect(m.handle(.fnDown(10.3)) == .none)
        try Harness.expect(m.handle(.fnUp(11.0)) == .stopAndProcess)
    }
    await Harness.check("hold boundary and post-cancel idle") {
        let m = FnStateMachine()
        _ = m.handle(.fnDown(10.0))
        try Harness.expect(m.handle(.fnUp(10.4)) == .stopAndProcess, "exactly 0.4 s must process")
        _ = m.handle(.fnDown(20.0))
        _ = m.handle(.escDown(20.1))
        try Harness.expect(m.handle(.escDown(20.2)) == .none, "escDown after cancel must be none")
        try Harness.expect(m.handle(.otherKeyDown(20.3)) == .none, "otherKeyDown after cancel must be none")
    }
}
