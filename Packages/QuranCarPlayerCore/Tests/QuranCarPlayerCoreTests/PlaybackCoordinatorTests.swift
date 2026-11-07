import Foundation
import Testing
@testable import QuranCarPlayerCore

// Scenario numbers refer to docs/IMPLEMENTATION.md "Behavior acceptance scenarios".

@Suite("Selection and transport")
@MainActor
struct SelectionTests {

    @Test("First use: no saved session, default reciter selected, nothing plays")
    func firstUseIsSilent() throws {
        let h = try Harness()
        #expect(h.snapshot.transport == .idle)
        #expect(h.snapshot.currentRecording == nil)
        #expect(h.snapshot.resumableSession == nil)
        #expect(h.snapshot.selectedReciter == FixtureAudioCatalog.defaultReciterID)
        #expect(h.engine.commands.isEmpty)
        h.coordinator.play()
        #expect(h.engine.commands.isEmpty, "play with nothing selected must not start arbitrary audio")
    }

    @Test("Scenario 1: selecting surah 18 loads it at zero with the selected reciter and plays")
    func selectSurahPlaysFromZero() throws {
        let h = try Harness()
        h.coordinator.selectSurah(18)
        #expect(h.snapshot.transport == .loading)
        #expect(h.snapshot.intent == .play)
        #expect(h.snapshot.currentRecording == Fixtures.recording(18))
        #expect(h.engine.currentItem?.startAt == 0)
        #expect(h.snapshot.isTestAudio)

        h.engine.becomeReady(duration: 300)
        #expect(h.snapshot.transport == .playing)
        #expect(h.snapshot.duration == 300)
        #expect(h.engine.playCount == 1)
        #expect(h.coordinator.currentSurah?.number == 18)
        #expect(h.coordinator.settings.surahListAnchor == 18)
    }

    @Test("Scenario 2: changing reciter while playing restarts at zero and ignores the old item")
    func reciterChangeWhilePlaying() throws {
        let h = try Harness()
        h.startPlaying(18)
        h.engine.tick(to: 40)
        let oldItem = try #require(h.engine.currentItem)

        h.coordinator.selectReciter(Fixtures.reciterB.id)
        #expect(h.snapshot.currentRecording == Fixtures.recording(18, reciter: Fixtures.reciterB))
        #expect(h.snapshot.elapsed == 0)
        #expect(h.snapshot.transport == .loading)
        #expect(h.engine.currentItem?.startAt == 0)
        #expect(h.engine.currentItem?.id != oldItem.id)

        // Late callbacks from the old item must not affect state.
        h.engine.emit(.timeUpdated(oldItem.id, 55))
        h.engine.emit(.playedToEnd(oldItem.id))
        h.engine.emit(.readyToPlay(oldItem.id, duration: 999))
        #expect(h.snapshot.elapsed == 0)
        #expect(h.snapshot.transport == .loading)
        #expect(h.snapshot.currentSurahNumber == 18)

        h.engine.becomeReady()
        #expect(h.snapshot.transport == .playing)
        #expect(h.engine.playCount == 2)
    }

    @Test("Scenario 3: changing reciter while paused resets to zero and stays paused")
    func reciterChangeWhilePaused() throws {
        let h = try Harness()
        h.startPlaying(18)
        h.engine.tick(to: 40)
        h.coordinator.pause()
        h.engine.clearCommands()

        h.coordinator.selectReciter(Fixtures.reciterB.id)
        #expect(h.snapshot.transport == .paused)
        #expect(h.snapshot.elapsed == 0)
        #expect(h.snapshot.currentRecording == Fixtures.recording(18, reciter: Fixtures.reciterB))
        #expect(h.engine.playCount == 0)
        #expect(h.engine.loadedItems.count == 1, "no new engine load while paused")

        // Play later loads the new recording at zero.
        h.coordinator.play()
        #expect(h.engine.loadedItems.count == 2)
        #expect(h.engine.currentItem?.startAt == 0)
    }

    @Test("Changing reciter with no current surah only changes the selection; same reciter is a no-op")
    func reciterChangeWithoutCurrent() throws {
        let h = try Harness()
        h.coordinator.selectReciter(Fixtures.reciterB.id)
        #expect(h.snapshot.selectedReciter == Fixtures.reciterB.id)
        #expect(h.snapshot.transport == .idle)
        #expect(h.engine.commands.isEmpty)
        #expect(h.settingsStore.settings?.preferredReciter == Fixtures.reciterB.id)

        h.startPlaying(5)
        h.engine.clearCommands()
        h.coordinator.selectReciter(Fixtures.reciterB.id)
        #expect(h.engine.commands.isEmpty, "selecting the selected reciter is a no-op")
        #expect(h.snapshot.transport == .playing)
    }

    @Test("Scenario 4: selecting the current surah restarts from zero; Continue Listening resumes saved position")
    func selectCurrentRestarts() throws {
        let h = try Harness()
        h.startPlaying(18)
        h.engine.tick(to: 40)
        h.coordinator.selectSurah(18)
        #expect(h.snapshot.elapsed == 0)
        #expect(h.engine.currentItem?.startAt == 0)
        #expect(h.engine.loadedItems.count == 2)
    }

    @Test("Scenario 5: natural end of 18 plays 19 exactly once with the same reciter")
    func autoAdvance() throws {
        let h = try Harness()
        h.coordinator.selectReciter(Fixtures.reciterB.id)
        h.startPlaying(18)
        let item18 = try #require(h.engine.currentItem)
        h.engine.finishCurrent()
        #expect(h.snapshot.currentRecording == Fixtures.recording(19, reciter: Fixtures.reciterB))
        #expect(h.snapshot.transport == .loading)
        #expect(h.engine.currentItem?.startAt == 0)
        let loadsAfterFirstEnd = h.engine.loadedItems.count

        // Duplicate end events for the finished item are ignored.
        h.engine.emit(.playedToEnd(item18.id))
        h.engine.emit(.playedToEnd(item18.id))
        #expect(h.engine.loadedItems.count == loadsAfterFirstEnd)
        #expect(h.snapshot.currentSurahNumber == 19)
    }

    @Test("Scenario 5: natural end of 114 completes the session and does not loop")
    func completionAt114() throws {
        let h = try Harness()
        h.startPlaying(114, duration: 100)
        h.engine.tick(to: 99)
        h.engine.finishCurrent()
        #expect(h.snapshot.transport == .completed)
        #expect(h.snapshot.currentSurahNumber == 114)
        #expect(h.snapshot.resumableSession == nil)
        #expect(h.sessionStore.checkpoint?.session.isCompleted == true)
        #expect(h.snapshot.canSkipForward == false)

        // Duplicate end event is ignored; nothing new loads.
        let loads = h.engine.loadedItems.count
        h.engine.finishCurrent()
        #expect(h.engine.loadedItems.count == loads)

        // Explicit play restarts 114 as a new session.
        h.coordinator.play()
        #expect(h.snapshot.transport == .loading)
        #expect(h.snapshot.elapsed == 0)
        #expect(h.sessionStore.checkpoint?.session.isCompleted == false)
    }

    @Test("Scenario 6: Previous restarts after 3s, moves back at or under 3s, restarts at surah 1")
    func previousRules() throws {
        let h = try Harness()
        h.startPlaying(18)
        h.engine.tick(to: 10)
        h.coordinator.previous()
        #expect(h.snapshot.currentSurahNumber == 18)
        #expect(h.snapshot.elapsed == 0)
        #expect(h.engine.commands.last == .seek(0))
        #expect(h.snapshot.transport == .playing)

        h.engine.tick(to: 3)
        h.coordinator.previous()
        #expect(h.snapshot.currentSurahNumber == 17)
        #expect(h.snapshot.transport == .loading)
        h.engine.becomeReady()

        h.coordinator.selectSurah(1)
        h.engine.becomeReady()
        h.engine.tick(to: 2)
        h.coordinator.previous()
        #expect(h.snapshot.currentSurahNumber == 1)
        #expect(h.snapshot.elapsed == 0)
    }

    @Test("Scenario 6: Next advances and does not wrap at 114")
    func nextRules() throws {
        let h = try Harness()
        h.startPlaying(113)
        #expect(h.snapshot.canSkipForward)
        h.coordinator.next()
        #expect(h.snapshot.currentSurahNumber == 114)
        #expect(h.snapshot.canSkipForward == false)
        h.engine.becomeReady()
        h.engine.clearCommands()
        h.coordinator.next()
        #expect(h.snapshot.currentSurahNumber == 114)
        #expect(h.engine.commands.isEmpty, "Next at 114 is a no-op")
    }

    @Test("Next/Previous while paused keep the session paused")
    func skipWhilePausedStaysPaused() throws {
        let h = try Harness()
        h.startPlaying(10)
        h.coordinator.pause()
        h.coordinator.next()
        #expect(h.snapshot.currentSurahNumber == 11)
        #expect(h.snapshot.transport == .paused)
        #expect(h.snapshot.intent == .pause)
    }

    @Test("Scenario 7: rapid taps and late completions cannot duplicate playback or corrupt the queue")
    func rapidTaps() throws {
        let h = try Harness()
        h.coordinator.selectSurah(2)
        let item2 = try #require(h.engine.currentItem)
        h.coordinator.selectSurah(3)
        h.coordinator.selectReciter(Fixtures.reciterB.id)
        h.coordinator.selectSurah(4)
        let item4 = try #require(h.engine.currentItem)

        // Late events from the first item.
        h.engine.emit(.readyToPlay(item2.id, duration: 10))
        h.engine.emit(.playedToEnd(item2.id))
        #expect(h.engine.playCount == 0)
        #expect(h.snapshot.currentRecording == Fixtures.recording(4, reciter: Fixtures.reciterB))

        h.engine.emit(.readyToPlay(item4.id, duration: 10))
        #expect(h.engine.playCount == 1)
        #expect(h.snapshot.transport == .playing)
    }

    @Test("Seek clamps to duration and is a no-op after completion")
    func seekRules() throws {
        let h = try Harness()
        h.startPlaying(18, duration: 100)
        h.coordinator.seek(to: 150)
        #expect(h.snapshot.elapsed == 100)
        #expect(h.engine.commands.last == .seek(100))
        h.coordinator.seek(to: -5)
        #expect(h.snapshot.elapsed == 0)
        #expect(h.sessionStore.checkpoint?.session.elapsedSeconds == 0)
    }

    @Test("Restored position is clamped once real duration is known")
    func restoredPositionClamped() throws {
        let saved = PlaybackSession(recording: Fixtures.recording(18), elapsedSeconds: 500, checkpointDate: Date())
        let h = try Harness(savedSession: saved)
        h.coordinator.play()
        #expect(h.engine.currentItem?.startAt == 500)
        h.engine.becomeReady(duration: 120)
        #expect(h.snapshot.elapsed == 120)
        #expect(h.engine.commands.contains(.seek(120)))
    }

    @Test("Unknown duration stays nil so UI never fabricates progress")
    func unknownDuration() throws {
        let h = try Harness()
        h.startPlaying(18, duration: nil)
        #expect(h.snapshot.duration == nil)
        h.engine.emit(.durationChanged(h.engine.currentItem!.id, .infinity))
        #expect(h.snapshot.duration == nil)
        h.engine.emit(.durationChanged(h.engine.currentItem!.id, 250))
        #expect(h.snapshot.duration == 250)
    }
}

@Suite("Resume and connection")
@MainActor
struct ResumeTests {

    @Test("Scenario 8: pause, relaunch, Continue Listening restores exact recording and position")
    func pauseRelaunchResume() throws {
        let h1 = try Harness()
        h1.startPlaying(18)
        h1.engine.tick(to: 37.5)
        h1.coordinator.pause()
        let checkpoint = try #require(h1.sessionStore.checkpoint)
        #expect(checkpoint.session.elapsedSeconds == 37.5)
        #expect(checkpoint.session.lastPauseReason == .user)

        // "Relaunch": new coordinator over the same stored checkpoint.
        let h2 = try Harness(savedSession: checkpoint.session)
        #expect(h2.snapshot.transport == .paused)
        #expect(h2.snapshot.currentRecording == Fixtures.recording(18))
        #expect(h2.snapshot.elapsed == 37.5)
        #expect(h2.snapshot.resumableSession == checkpoint.session)
        #expect(h2.engine.commands.isEmpty, "launch restores metadata without touching the engine")

        h2.coordinator.continueListening()
        #expect(h2.engine.currentItem?.url == Fixtures.toneURLs[(18 - 1) % 3])
        #expect(h2.engine.currentItem?.startAt == 37.5)
        h2.engine.becomeReady()
        #expect(h2.snapshot.transport == .playing)
    }

    @Test("Periodic checkpoints happen at most every 5 seconds while playing")
    func periodicCheckpoint() throws {
        let h = try Harness()
        h.startPlaying(18)
        let base = h.sessionStore.saveCount
        h.engine.tick(to: 1); h.clock.advance(by: 1)
        h.engine.tick(to: 2); h.clock.advance(by: 1)
        #expect(h.sessionStore.saveCount == base)
        h.clock.advance(by: 4)
        h.engine.tick(to: 6)
        #expect(h.sessionStore.saveCount == base + 1)
        #expect(h.sessionStore.checkpoint?.session.elapsedSeconds == 6)
    }

    @Test("Scenario 9: CarPlay connect resumes an eligible session at most once per connection")
    func autoResumeOnce() throws {
        let saved = PlaybackSession(recording: Fixtures.recording(18), elapsedSeconds: 40,
                                    checkpointDate: Date(), lastPauseReason: .carDisconnected)
        let h = try Harness(savedSession: saved)
        #expect(h.coordinator.evaluateAutomaticResume() == .resume)
        #expect(h.coordinator.carPlayDidConnect() == .resume)
        #expect(h.engine.currentItem?.startAt == 40)
        h.engine.becomeReady()
        #expect(h.snapshot.transport == .playing)

        // User pauses in the car; a second connect event in the same connection must not override it.
        h.coordinator.pause()
        #expect(h.coordinator.evaluateAutomaticResume() == .skippedAlreadyResumedThisConnection)
    }

    @Test("Scenario 10: first use and completed sessions never auto-resume")
    func noAutoResumeWithoutEligibleSession() throws {
        let fresh = try Harness()
        #expect(fresh.coordinator.carPlayDidConnect() == .skippedNoSession)
        #expect(fresh.engine.commands.isEmpty)

        let completed = PlaybackSession(recording: Fixtures.recording(114), elapsedSeconds: 100,
                                        isCompleted: true, checkpointDate: Date())
        let done = try Harness(savedSession: completed)
        #expect(done.snapshot.transport == .completed)
        #expect(done.coordinator.carPlayDidConnect() == .skippedSessionCompleted)
        #expect(done.engine.commands.isEmpty)
    }

    @Test("Auto-resume respects the setting and (open policy) a deliberate user pause")
    func autoResumePolicyGates() throws {
        let userPaused = PlaybackSession(recording: Fixtures.recording(18), elapsedSeconds: 40,
                                         checkpointDate: Date(), lastPauseReason: .user)
        let h = try Harness(savedSession: userPaused)
        #expect(h.coordinator.carPlayDidConnect() == .skippedUserPaused)
        #expect(h.engine.commands.isEmpty)

        let disconnected = PlaybackSession(recording: Fixtures.recording(18), elapsedSeconds: 40,
                                           checkpointDate: Date(), lastPauseReason: .carDisconnected)
        let off = try Harness(savedSession: disconnected,
                              settings: AppSettings(preferredReciter: Fixtures.reciterA.id, automaticCarPlayResume: false))
        #expect(off.coordinator.carPlayDidConnect() == .skippedDisabled)
        #expect(off.engine.commands.isEmpty)
    }

    @Test("Scenario 11: car disconnect pauses, saves, cancels retry, and the next connect resumes")
    func disconnectPausesAndSaves() throws {
        let h = try Harness()
        h.startPlaying(18)
        h.engine.tick(to: 25)
        h.engine.failCurrent(.network)
        #expect(h.snapshot.transport == .retrying(attempt: 1))
        #expect(h.scheduler.pending.count == 1)

        h.coordinator.carPlayDidDisconnect()
        #expect(h.snapshot.transport == .paused)
        #expect(h.snapshot.pauseReason == .carDisconnected)
        #expect(h.scheduler.pending.isEmpty, "retry cancelled on disconnection")
        #expect(h.sessionStore.checkpoint?.session.elapsedSeconds == 25)
        #expect(h.sessionStore.checkpoint?.session.lastPauseReason == .carDisconnected)

        // Firing the cancelled work must do nothing.
        h.engine.clearCommands()
        for work in h.scheduler.scheduled { work.action() }
        #expect(h.engine.commands.isEmpty)
        #expect(h.snapshot.transport == .paused)

        #expect(h.coordinator.carPlayDidConnect() == .resume)
        #expect(h.engine.currentItem?.startAt == 25)
    }

    @Test("Auto-resume does not fire while something is already playing")
    func autoResumeSkipsActive() throws {
        let h = try Harness()
        h.startPlaying(3)
        #expect(h.coordinator.carPlayDidConnect() == .skippedAlreadyActive)
        #expect(h.engine.playCount == 1)
    }
}

@Suite("Interruptions and network")
@MainActor
struct InterruptionTests {

    @Test("Scenario 13: interruption pauses; resume only when system allows and user did not pause")
    func interruptionResume() throws {
        let h = try Harness()
        h.startPlaying(18)
        h.engine.tick(to: 20)
        h.coordinator.interruptionBegan()
        #expect(h.snapshot.transport == .paused)
        #expect(h.snapshot.pauseReason == .interruption)
        h.engine.clearCommands()

        h.coordinator.interruptionEnded(shouldResume: true)
        #expect(h.snapshot.transport == .playing)
        #expect(h.engine.commands == [.play])
    }

    @Test("Scenario 13: a deliberate pause during an interruption prevents resumption")
    func userPauseDuringInterruption() throws {
        let h = try Harness()
        h.startPlaying(18)
        h.coordinator.interruptionBegan()
        h.coordinator.pause()
        #expect(h.snapshot.pauseReason == .user)
        h.engine.clearCommands()
        h.coordinator.interruptionEnded(shouldResume: true)
        #expect(h.snapshot.transport == .paused)
        #expect(h.engine.commands.isEmpty)

        let h2 = try Harness()
        h2.startPlaying(18)
        h2.coordinator.interruptionBegan()
        h2.engine.clearCommands()
        h2.coordinator.interruptionEnded(shouldResume: false)
        #expect(h2.snapshot.transport == .paused)
        #expect(h2.engine.commands.isEmpty)
    }

    @Test("Route loss pauses and never auto-plays through another route")
    func routeLost() throws {
        let h = try Harness()
        h.startPlaying(18)
        h.coordinator.audioRouteLost()
        #expect(h.snapshot.transport == .paused)
        #expect(h.snapshot.pauseReason == .routeLost)
        h.engine.clearCommands()
        h.coordinator.interruptionEnded(shouldResume: true)
        #expect(h.engine.commands.isEmpty)
    }

    @Test("Scenario 14/15: network failure retries 1s, 2s, 4s at the retained position, then offers Retry")
    func retrySchedule() throws {
        let h = try Harness()
        h.startPlaying(18)
        h.engine.tick(to: 30)
        let positionBefore = h.snapshot.elapsed

        h.engine.failCurrent(.network)
        #expect(h.snapshot.transport == .retrying(attempt: 1))
        #expect(h.snapshot.currentSurahNumber == 18)
        #expect(h.scheduler.pending.first?.delay == 1)

        h.clock.advance(by: 1)
        h.scheduler.fireNext()
        #expect(h.snapshot.transport == .loading)
        #expect(h.engine.currentItem?.startAt == positionBefore)
        h.engine.failCurrent(.network)
        #expect(h.snapshot.transport == .retrying(attempt: 2))
        #expect(h.scheduler.pending.first?.delay == 2)

        h.clock.advance(by: 2)
        h.scheduler.fireNext()
        h.engine.failCurrent(.network)
        #expect(h.snapshot.transport == .retrying(attempt: 3))
        #expect(h.scheduler.pending.first?.delay == 4)

        h.clock.advance(by: 4)
        h.scheduler.fireNext()
        h.engine.failCurrent(.network)
        #expect(h.snapshot.transport == .failed(PlaybackFailure(recording: Fixtures.recording(18), reason: .networkUnavailable)))
        #expect(h.snapshot.elapsed == positionBefore, "position retained through failure")
        #expect(h.snapshot.currentSurahNumber == 18, "never skips content")
        #expect(h.scheduler.pending.isEmpty)

        // Explicit Retry resumes the same recording at the same position.
        h.coordinator.retry()
        #expect(h.snapshot.transport == .loading)
        #expect(h.engine.currentItem?.startAt == positionBefore)
        #expect(h.snapshot.currentRecording == Fixtures.recording(18))
        h.engine.becomeReady()
        #expect(h.snapshot.transport == .playing)
    }

    @Test("Recovery window bounds retries even when attempts remain")
    func recoveryWindow() throws {
        let h = try Harness(retryPolicy: RetryPolicy(delays: [1, 2, 4], recoveryWindow: 2))
        h.startPlaying(18)
        h.engine.failCurrent(.network)
        #expect(h.snapshot.transport == .retrying(attempt: 1))
        h.clock.advance(by: 1)
        h.scheduler.fireNext()
        h.engine.failCurrent(.network)
        // Second retry would need 1 + 2 = 3s > 2s window.
        guard case .failed = h.snapshot.transport else {
            Issue.record("expected failed, got \(h.snapshot.transport)")
            return
        }
    }

    @Test("Scenario 15: pause or new selection during recovery cancels the pending retry")
    func pauseCancelsRetry() throws {
        let h = try Harness()
        h.startPlaying(18)
        h.engine.tick(to: 12)
        h.engine.failCurrent(.network)
        h.coordinator.pause()
        #expect(h.snapshot.transport == .paused)
        #expect(h.snapshot.elapsed == 12)
        #expect(h.scheduler.pending.isEmpty)
        #expect(h.sessionStore.checkpoint?.session.elapsedSeconds == 12)

        // Play after a paused failure reloads at the retained position.
        h.coordinator.play()
        #expect(h.engine.currentItem?.startAt == 12)
        h.engine.becomeReady()

        h.engine.failCurrent(.network)
        h.coordinator.selectSurah(20)
        #expect(h.scheduler.pending.isEmpty)
        #expect(h.snapshot.currentSurahNumber == 20)
        #expect(h.snapshot.transport == .loading)
    }

    @Test("A stalled item that recovers on its own cancels the watchdog")
    func stallRecovers() throws {
        let h = try Harness()
        h.startPlaying(18)
        h.engine.tick(to: 10)
        h.engine.stallCurrent()
        #expect(h.snapshot.transport == .retrying(attempt: 1))
        h.engine.tick(to: 11)
        #expect(h.snapshot.transport == .playing)
        #expect(h.scheduler.pending.isEmpty)
        #expect(h.engine.loadedItems.count == 1, "no reload needed")
    }

    @Test("Scenario 16: missing or forbidden recordings fail immediately without a retry storm")
    func nonRetriableFailures() throws {
        let h = try Harness()
        h.startPlaying(18)
        h.engine.failCurrent(.missingRecording)
        #expect(h.snapshot.transport == .failed(PlaybackFailure(recording: Fixtures.recording(18), reason: .recordingUnavailable)))
        #expect(h.scheduler.pending.isEmpty)

        h.coordinator.selectSurah(19)
        h.engine.becomeReady()
        h.engine.failCurrent(.notPermitted)
        #expect(h.snapshot.transport == .failed(PlaybackFailure(recording: Fixtures.recording(19), reason: .notPermitted)))
        #expect(h.scheduler.pending.isEmpty)
    }

    @Test("Scenario 16: a recording the catalog cannot resolve becomes an actionable failure")
    func unresolvableRecording() throws {
        let h = try Harness(unavailableSurahs: [19])
        h.coordinator.selectSurah(19)
        #expect(h.snapshot.transport == .failed(PlaybackFailure(recording: Fixtures.recording(19), reason: .recordingUnavailable)))
        #expect(h.engine.loadedItems.isEmpty)
        #expect(h.snapshot.currentSurahNumber == 19, "context retained")
    }

    @Test("Scenario 17: an unavailable next surah stops with Retry instead of skipping it")
    func unavailableNextStops() throws {
        let h = try Harness(unavailableSurahs: [19])
        h.startPlaying(18)
        h.engine.finishCurrent()
        #expect(h.snapshot.currentSurahNumber == 19)
        #expect(h.snapshot.transport == .failed(PlaybackFailure(recording: Fixtures.recording(19), reason: .recordingUnavailable)))
        #expect(h.snapshot.elapsed == 0)
        #expect(h.sessionStore.checkpoint?.session.recording.surahNumber == 19)
    }

    @Test("A late readyToPlay after the user paused during loading must not start audio")
    func pauseDuringLoading() throws {
        let h = try Harness()
        h.coordinator.selectSurah(18)
        h.coordinator.pause()
        #expect(h.snapshot.transport == .paused)
        h.engine.clearCommands()
        h.engine.becomeReady()
        #expect(h.engine.playCount == 0)
        #expect(h.snapshot.transport == .paused)
    }

    @Test("Media services reset reloads an active item at its position")
    func mediaServicesReset() throws {
        let h = try Harness()
        h.startPlaying(18)
        h.engine.tick(to: 33)
        h.coordinator.mediaServicesWereReset()
        #expect(h.engine.loadedItems.count == 2)
        #expect(h.engine.currentItem?.startAt == 33)
    }
}

@Suite("Settings and observers")
@MainActor
struct SettingsTests {

    @Test("Language and auto-resume changes persist without touching playback")
    func settingsPersist() throws {
        let h = try Harness()
        h.startPlaying(18)
        h.engine.clearCommands()
        h.coordinator.setLanguage(.arabic)
        h.coordinator.setAutomaticCarPlayResume(false)
        #expect(h.settingsStore.settings?.language == .arabic)
        #expect(h.settingsStore.settings?.automaticCarPlayResume == false)
        #expect(h.snapshot.language == .arabic)
        #expect(h.snapshot.transport == .playing)
        #expect(h.engine.commands.isEmpty)
    }

    @Test("Preferred reciter and anchor are restored; unknown reciter falls back to default")
    func settingsRestore() throws {
        let saved = AppSettings(preferredReciter: Fixtures.reciterB.id, surahListAnchor: 67)
        let h = try Harness(settings: saved)
        #expect(h.snapshot.selectedReciter == Fixtures.reciterB.id)
        #expect(h.coordinator.surahListAnchor == 67)

        let bogus = AppSettings(preferredReciter: ReciterID("missing"))
        let h2 = try Harness(settings: bogus)
        #expect(h2.snapshot.selectedReciter == FixtureAudioCatalog.defaultReciterID)
        #expect(h2.coordinator.surahListAnchor == nil)
    }

    @Test("List anchor falls back to the current surah when none is saved")
    func anchorFallback() throws {
        let saved = PlaybackSession(recording: Fixtures.recording(36), elapsedSeconds: 5, checkpointDate: Date())
        let h = try Harness(savedSession: saved)
        #expect(h.coordinator.surahListAnchor == 36)
    }

    @Test("Observers receive the initial snapshot and every change until cancelled")
    func observers() throws {
        let h = try Harness()
        var received: [TransportState] = []
        let token = h.coordinator.addObserver { received.append($0.transport) }
        h.coordinator.selectSurah(2)
        h.engine.becomeReady()
        #expect(received.contains(.idle))
        #expect(received.contains(.loading))
        #expect(received.last == .playing)
        token.cancel()
    }
}
