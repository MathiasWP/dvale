import XCTest
import CoreGraphics
@testable import DvaleCore

final class CommandGestureTests: XCTestCase {
    func testTwoCompleteTapsToggleOnlyOnSecondRelease() {
        var gesture = CommandGesture()
        XCTAssertFalse(gesture.command(key: 55, down: true, otherModifiers: false, at: 0))
        XCTAssertFalse(gesture.command(key: 55, down: false, otherModifiers: false, at: 0.08))
        XCTAssertFalse(gesture.command(key: 55, down: true, otherModifiers: false, at: 0.2))
        XCTAssertTrue(gesture.command(key: 55, down: false, otherModifiers: false, at: 0.28))
        XCTAssertFalse(gesture.command(key: 55, down: true, otherModifiers: false, at: 0.35))
        XCTAssertFalse(gesture.command(key: 55, down: false, otherModifiers: false, at: 0.4))
    }

    func testRightAndAlternatingCommandKeys() {
        var gesture = CommandGesture()
        _ = gesture.command(key: 54, down: true, otherModifiers: false, at: 0)
        _ = gesture.command(key: 54, down: false, otherModifiers: false, at: 0.05)
        _ = gesture.command(key: 55, down: true, otherModifiers: false, at: 0.2)
        XCTAssertTrue(gesture.command(key: 55, down: false, otherModifiers: false, at: 0.25))
    }

    func testCommandShortcutCancelsPendingTap() {
        var gesture = CommandGesture()
        _ = gesture.command(key: 55, down: true, otherModifiers: false, at: 0)
        _ = gesture.command(key: 55, down: false, otherModifiers: false, at: 0.05)
        _ = gesture.command(key: 55, down: true, otherModifiers: false, at: 0.15)
        gesture.reset() // The C key, another modifier, mouse click, or scroll.
        XCTAssertFalse(gesture.command(key: 55, down: false, otherModifiers: false, at: 0.2))
        _ = gesture.command(key: 55, down: true, otherModifiers: false, at: 0.25)
        XCTAssertFalse(gesture.command(key: 55, down: false, otherModifiers: false, at: 0.3))
    }

    func testHeldCommandAndSlowTapsDoNotToggle() {
        var gesture = CommandGesture()
        _ = gesture.command(key: 55, down: true, otherModifiers: false, at: 0)
        XCTAssertFalse(gesture.command(key: 55, down: false, otherModifiers: false, at: 1))
        _ = gesture.command(key: 55, down: true, otherModifiers: false, at: 1.1)
        XCTAssertFalse(gesture.command(key: 55, down: false, otherModifiers: false, at: 1.15))
        _ = gesture.command(key: 55, down: true, otherModifiers: false, at: 2)
        XCTAssertFalse(gesture.command(key: 55, down: false, otherModifiers: false, at: 2.05))
    }

    func testModifiersAndBothCommandsCancelGesture() {
        var gesture = CommandGesture()
        _ = gesture.command(key: 55, down: true, otherModifiers: false, at: 0)
        _ = gesture.command(key: 55, down: false, otherModifiers: false, at: 0.05)
        _ = gesture.command(key: 54, down: true, otherModifiers: true, at: 0.1)
        XCTAssertFalse(gesture.command(key: 54, down: false, otherModifiers: false, at: 0.15))
        _ = gesture.command(key: 55, down: true, otherModifiers: false, at: 0.2)
        XCTAssertFalse(gesture.command(key: 55, down: false, otherModifiers: false, at: 0.25))
    }

    func testResetAcrossWakeAndPermissionChanges() {
        var gesture = CommandGesture()
        _ = gesture.command(key: 55, down: true, otherModifiers: false, at: 0)
        _ = gesture.command(key: 55, down: false, otherModifiers: false, at: 0.05)
        gesture.reset()
        _ = gesture.command(key: 55, down: true, otherModifiers: false, at: 0.1)
        XCTAssertFalse(gesture.command(key: 55, down: false, otherModifiers: false, at: 0.15))
    }
}

final class CommandEventRecognizerTests: XCTestCase {
    private let command = CGEventFlags.maskCommand.rawValue

    func testQueuedFastTapsUseTheirRecordedFlags() {
        var recognizer = CommandEventRecognizer()
        // All events can be delivered after the physical key has been released.
        // The previous live keyState query would classify every event as key-up.
        let flags: [UInt64] = [command | 0x8, 0, command | 0x8, 0]
        let results = flags.enumerated().map { index, flags in
            recognizer.receive(type: .flagsChanged, keyCode: 55, flags: CGEventFlags(rawValue: flags),
                               timestamp: 100 + Double(index) * 0.06)
        }
        XCTAssertEqual(results, [false, false, false, true])
    }

    func testRightCommandDeviceFlags() {
        var recognizer = CommandEventRecognizer()
        let flags: [UInt64] = [command | 0x10, 0, command | 0x10, 0]
        XCTAssertEqual(flags.enumerated().map { index, flags in
            recognizer.receive(type: .flagsChanged, keyCode: 54, flags: CGEventFlags(rawValue: flags), timestamp: Double(index) * 0.07)
        }, [false, false, false, true])
    }

    func testAggregateOnlyFlagsFromRemappedKeyboard() {
        var recognizer = CommandEventRecognizer()
        XCTAssertEqual([command, 0, command, 0].enumerated().map { index, flags in
            recognizer.receive(type: .flagsChanged, keyCode: 55, flags: CGEventFlags(rawValue: flags), timestamp: Double(index) * 0.08)
        }, [false, false, false, true])
    }

    func testOverlappingCommandsDoNotLookLikeTaps() {
        var recognizer = CommandEventRecognizer()
        let events: [(Int, UInt64)] = [(55, command | 0x8), (54, command | 0x18),
                                       (55, command | 0x10), (54, 0), (55, command | 0x8), (55, 0)]
        for (index, event) in events.enumerated() {
            XCTAssertFalse(recognizer.receive(type: .flagsChanged, keyCode: event.0,
                                              flags: CGEventFlags(rawValue: event.1), timestamp: Double(index) * 0.05))
        }
    }

    func testKeyDownBetweenTapsCancelsShortcut() {
        var recognizer = CommandEventRecognizer()
        _ = recognizer.receive(type: .flagsChanged, keyCode: 55, flags: CGEventFlags(rawValue: command | 0x8), timestamp: 0)
        _ = recognizer.receive(type: .flagsChanged, keyCode: 55, flags: [], timestamp: 0.05)
        _ = recognizer.receive(type: .flagsChanged, keyCode: 55, flags: CGEventFlags(rawValue: command | 0x8), timestamp: 0.1)
        XCTAssertFalse(recognizer.receive(type: .keyDown, keyCode: 8, flags: .maskCommand, timestamp: 0.12))
        XCTAssertFalse(recognizer.receive(type: .flagsChanged, keyCode: 55, flags: [], timestamp: 0.15))
    }

    func testOtherModifiersInvalidateSequence() {
        for modifier in [CGEventFlags.maskShift, .maskAlternate, .maskControl, .maskSecondaryFn] {
            var recognizer = CommandEventRecognizer()
            for (index, flags) in [command, 0, command | modifier.rawValue, 0].enumerated() {
                XCTAssertFalse(recognizer.receive(type: .flagsChanged, keyCode: 55, flags: CGEventFlags(rawValue: flags), timestamp: Double(index) * 0.06))
            }
        }
    }

    func testComfortableTapsAndSystemDoubleClickInterval() {
        var recognizer = CommandEventRecognizer(doubleTapInterval: 0.6)
        let events: [(Double, UInt64)] = [(0, command), (0.3, 0), (0.85, command), (1.2, 0)]
        XCTAssertEqual(events.map { time, flags in
            recognizer.receive(type: .flagsChanged, keyCode: 55, flags: CGEventFlags(rawValue: flags), timestamp: time)
        }, [false, false, false, true])
    }

    func testCapsLockDoesNotBlockCommandTaps() {
        var recognizer = CommandEventRecognizer()
        XCTAssertEqual([command, 0, command, 0].enumerated().map { index, flags in
            recognizer.receive(type: .flagsChanged, keyCode: 55,
                               flags: CGEventFlags(rawValue: flags | CGEventFlags.maskAlphaShift.rawValue), timestamp: Double(index) * 0.06)
        }, [false, false, false, true])
    }
}

final class OffPolicyTests: XCTestCase {
    func testDoesNotWriteWhenOnOrAlreadyDark() {
        var policy = OffPolicy()
        XCTAssertFalse(policy.shouldRequestOff(dark: false, now: 0))
        policy.select(off: true)
        XCTAssertFalse(policy.shouldRequestOff(dark: true, now: 0))
        XCTAssertTrue(policy.shouldRequestOff(dark: false, now: 0))
    }

    func testStatusStormsAreRateLimited() {
        var policy = OffPolicy()
        policy.select(off: true)
        XCTAssertTrue(policy.shouldRequestOff(dark: false, now: 0))
        XCTAssertFalse(policy.shouldRequestOff(dark: false, now: 0.01))
        XCTAssertFalse(policy.shouldRequestOff(dark: false, now: 0.05, force: true))
        XCTAssertTrue(policy.shouldRequestOff(dark: false, now: 0.11))
    }

    func testSelectingOnCancelsDelayedOffRequests() {
        var policy = OffPolicy()
        policy.select(off: true)
        let oldToken = policy.generation
        policy.select(off: false)
        XCTAssertFalse(policy.shouldRequestOff(dark: false, now: 1, token: oldToken, force: true))
        XCTAssertFalse(policy.shouldRequestOff(dark: false, now: 2, force: true))
        policy.select(off: true)
        XCTAssertFalse(policy.shouldRequestOff(dark: false, now: 3, token: oldToken, force: true))
        XCTAssertTrue(policy.shouldRequestOff(dark: false, now: 3, token: policy.generation))
    }

    func testSleepSuspendsRequestsAndWakeInvalidatesOldWork() {
        var policy = OffPolicy()
        policy.select(off: true)
        let oldToken = policy.generation
        policy.setSleeping(true)
        XCTAssertFalse(policy.shouldRequestOff(dark: false, now: 10, force: true))
        policy.setSleeping(false)
        XCTAssertTrue(policy.keepOff)
        XCTAssertFalse(policy.shouldRequestOff(dark: false, now: 11, token: oldToken))
        XCTAssertTrue(policy.shouldRequestOff(dark: true, now: 11, force: true))
    }

    func testWakePreservesOnChoice() {
        var policy = OffPolicy()
        policy.select(off: false)
        policy.setSleeping(true)
        policy.setSleeping(false)
        XCTAssertFalse(policy.shouldRequestOff(dark: false, now: 10, force: true))
    }
}
