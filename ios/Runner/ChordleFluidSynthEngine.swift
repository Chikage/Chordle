import AVFoundation
import Foundation

@_silgen_name("new_fluid_settings")
private func fluidNewSettings() -> OpaquePointer?

@_silgen_name("delete_fluid_settings")
private func fluidDeleteSettings(_ settings: OpaquePointer?)

@_silgen_name("new_fluid_synth")
private func fluidNewSynth(_ settings: OpaquePointer?) -> OpaquePointer?

@_silgen_name("delete_fluid_synth")
private func fluidDeleteSynth(_ synth: OpaquePointer?)

@_silgen_name("new_fluid_audio_driver")
private func fluidNewAudioDriver(
  _ settings: OpaquePointer?,
  _ synth: OpaquePointer?
) -> OpaquePointer?

@_silgen_name("delete_fluid_audio_driver")
private func fluidDeleteAudioDriver(_ driver: OpaquePointer?)

@_silgen_name("fluid_settings_setstr")
private func fluidSettingsSetString(
  _ settings: OpaquePointer?,
  _ name: UnsafePointer<CChar>,
  _ value: UnsafePointer<CChar>
) -> Int32

@_silgen_name("fluid_settings_setint")
private func fluidSettingsSetInt(
  _ settings: OpaquePointer?,
  _ name: UnsafePointer<CChar>,
  _ value: Int32
) -> Int32

@_silgen_name("fluid_settings_setnum")
private func fluidSettingsSetNumber(
  _ settings: OpaquePointer?,
  _ name: UnsafePointer<CChar>,
  _ value: Double
) -> Int32

@_silgen_name("fluid_synth_sfload")
private func fluidSynthLoadSoundFont(
  _ synth: OpaquePointer?,
  _ path: UnsafePointer<CChar>,
  _ resetPresets: Int32
) -> Int32

@_silgen_name("fluid_synth_sfunload")
private func fluidSynthUnloadSoundFont(
  _ synth: OpaquePointer?,
  _ soundFontId: Int32,
  _ resetPresets: Int32
) -> Int32

@_silgen_name("fluid_synth_program_select")
private func fluidSynthProgramSelect(
  _ synth: OpaquePointer?,
  _ channel: Int32,
  _ soundFontId: Int32,
  _ bank: Int32,
  _ program: Int32
) -> Int32

@_silgen_name("fluid_synth_pitch_wheel_sens")
private func fluidSynthPitchWheelSensitivity(
  _ synth: OpaquePointer?,
  _ channel: Int32,
  _ semitones: Int32
) -> Int32

@_silgen_name("fluid_synth_pitch_bend")
private func fluidSynthPitchBend(
  _ synth: OpaquePointer?,
  _ channel: Int32,
  _ value: Int32
) -> Int32

@_silgen_name("fluid_synth_noteon")
private func fluidSynthNoteOn(
  _ synth: OpaquePointer?,
  _ channel: Int32,
  _ key: Int32,
  _ velocity: Int32
) -> Int32

@_silgen_name("fluid_synth_noteoff")
private func fluidSynthNoteOff(
  _ synth: OpaquePointer?,
  _ channel: Int32,
  _ key: Int32
) -> Int32

@_silgen_name("fluid_synth_all_sounds_off")
private func fluidSynthAllSoundsOff(
  _ synth: OpaquePointer?,
  _ channel: Int32
) -> Int32

@_silgen_name("fluid_synth_set_gain")
private func fluidSynthSetGain(_ synth: OpaquePointer?, _ gain: Float)

@_silgen_name("fluid_synth_reverb_on")
private func fluidSynthReverbOn(
  _ synth: OpaquePointer?,
  _ group: Int32,
  _ enabled: Int32
) -> Int32

@_silgen_name("fluid_synth_set_reverb_group_roomsize")
private func fluidSynthSetReverbRoomSize(
  _ synth: OpaquePointer?,
  _ group: Int32,
  _ value: Double
) -> Int32

@_silgen_name("fluid_synth_set_reverb_group_damp")
private func fluidSynthSetReverbDamp(
  _ synth: OpaquePointer?,
  _ group: Int32,
  _ value: Double
) -> Int32

@_silgen_name("fluid_synth_set_reverb_group_level")
private func fluidSynthSetReverbLevel(
  _ synth: OpaquePointer?,
  _ group: Int32,
  _ value: Double
) -> Int32

struct FluidPlaybackTone {
  let key: Int
  let cents: Double
}

enum ChordleFluidSynthError: LocalizedError {
  case missingSoundFont
  case settingsUnavailable
  case synthUnavailable
  case soundFontLoadFailed
  case audioDriverUnavailable

  var errorDescription: String? {
    switch self {
    case .missingSoundFont:
      return "内置 SoundFont 未找到"
    case .settingsUnavailable:
      return "FluidSynth 设置创建失败"
    case .synthUnavailable:
      return "FluidSynth 合成器创建失败"
    case .soundFontLoadFailed:
      return "FluidSynth 音色加载失败"
    case .audioDriverUnavailable:
      return "FluidSynth CoreAudio 驱动启动失败"
    }
  }
}

final class ChordleFluidSynthEngine {
  static let shared = ChordleFluidSynthEngine()

  private struct ActiveNote {
    let channel: Int32
    let key: Int32
    let generation: Int
  }

  private let queue = DispatchQueue(label: "icu.ringona.chordle.fluidsynth")
  private let queueKey = DispatchSpecificKey<Void>()
  private var settings: OpaquePointer?
  private var synth: OpaquePointer?
  private var audioDriver: OpaquePointer?
  private var soundFontId: Int32 = -1
  private var activeNotes: [ActiveNote] = []
  private var generation = 0
  private var lastProgram = 0
  private var audioSessionConfigured = false
  private var notificationTokens: [NSObjectProtocol] = []
  private var recoveryWorkItem: DispatchWorkItem?

  private let channelCount = 16
  private let centerPitchBend: Int32 = 8_192
  private let pitchBendRangeCents = 200.0
  private let outputGain: Float = 0.8

  private init() {
    queue.setSpecific(key: queueKey, value: ())
    registerAudioNotifications()
  }

  func prepare(program: Int, completion: @escaping (Result<Bool, Error>) -> Void) {
    queue.async {
      do {
        try self.ensureReady(program: program)
        DispatchQueue.main.async { completion(.success(true)) }
      } catch {
        self.cleanup()
        DispatchQueue.main.async { completion(.failure(error)) }
      }
    }
  }

  func play(
    tones: [FluidPlaybackTone],
    velocity: Int,
    program: Int,
    durationMilliseconds: Int
  ) {
    guard !tones.isEmpty else { return }
    queue.async {
      do {
        try self.ensureReady(program: program)
      } catch {
        return
      }
      guard let synth = self.synth, self.soundFontId >= 0 else { return }
      self.allSoundOffLocked()
      self.selectProgram(program)
      let currentGeneration = self.generation
      let safeVelocity = Int32(max(1, min(127, velocity)))
      var started: [ActiveNote] = []

      for (index, tone) in tones.prefix(self.channelCount).enumerated() {
        let channel = Int32(index)
        let key = Int32(max(0, min(127, tone.key)))
        let bend = self.pitchBendValue(cents: tone.cents)
        _ = fluidSynthPitchWheelSensitivity(synth, channel, 2)
        _ = fluidSynthPitchBend(synth, channel, bend)
        if fluidSynthNoteOn(synth, channel, key, safeVelocity) == 0 {
          let note = ActiveNote(
            channel: channel,
            key: key,
            generation: currentGeneration
          )
          self.activeNotes.append(note)
          started.append(note)
        }
      }

      let delay = DispatchTimeInterval.milliseconds(
        max(50, durationMilliseconds)
      )
      self.queue.asyncAfter(deadline: .now() + delay) {
        guard currentGeneration == self.generation, let synth = self.synth else {
          return
        }
        for note in started where note.generation == currentGeneration {
          _ = fluidSynthNoteOff(synth, note.channel, note.key)
        }
        self.activeNotes.removeAll { $0.generation == currentGeneration }
      }
    }
  }

  func allSoundOff() {
    performOnQueueAndWait { self.allSoundOffLocked() }
  }

  func enterBackground() {
    performOnQueueAndWait {
      self.allSoundOffLocked()
      self.stopAudioDriverLocked()
      try? AVAudioSession.sharedInstance().setActive(
        false,
        options: .notifyOthersOnDeactivation
      )
      self.audioSessionConfigured = false
    }
  }

  func shutdown() {
    notificationTokens.forEach(NotificationCenter.default.removeObserver)
    notificationTokens.removeAll()
    recoveryWorkItem?.cancel()
    performOnQueueAndWait { self.cleanup() }
  }

  private func ensureReady(program: Int) throws {
    try configureAudioSession()
    if synth == nil {
      try createEngine()
    } else if audioDriver == nil {
      try startAudioDriver()
    }
    selectProgram(program)
    lastProgram = max(0, min(127, program))
  }

  private func configureAudioSession() throws {
    guard !audioSessionConfigured else { return }
    let session = AVAudioSession.sharedInstance()
    try session.setCategory(.playback, mode: .default, options: [])
    try session.setPreferredSampleRate(44_100)
    try session.setPreferredIOBufferDuration(0.0058)
    try session.setActive(true)
    audioSessionConfigured = true
  }

  private func createEngine() throws {
    guard let soundFontURL = soundFontURL() else {
      throw ChordleFluidSynthError.missingSoundFont
    }
    guard let settings = fluidNewSettings() else {
      throw ChordleFluidSynthError.settingsUnavailable
    }
    self.settings = settings

    setString("audio.driver", "coreaudio", on: settings)
    setString("audio.sample-format", "float", on: settings)
    setInt("audio.period-size", 256, on: settings)
    setInt("audio.periods", 2, on: settings)
    setInt("synth.polyphony", 1_024, on: settings)
    setInt("synth.midi-channels", 32, on: settings)
    setInt("synth.chorus.active", 0, on: settings)
    setInt("synth.threadsafe-api", 1, on: settings)
    setNumber("synth.sample-rate", 44_100, on: settings)
    setNumber("synth.gain", Double(outputGain), on: settings)
    setInt("synth.reverb.active", 1, on: settings)
    setNumber("synth.reverb.room-size", 0.8, on: settings)
    setNumber("synth.reverb.damp", 0.5, on: settings)
    setNumber("synth.reverb.level", 0.54, on: settings)

    guard let synth = fluidNewSynth(settings) else {
      throw ChordleFluidSynthError.synthUnavailable
    }
    self.synth = synth

    soundFontId = soundFontURL.path.withCString {
      fluidSynthLoadSoundFont(synth, $0, 1)
    }
    guard soundFontId >= 0 else {
      throw ChordleFluidSynthError.soundFontLoadFailed
    }

    fluidSynthSetGain(synth, outputGain)
    _ = fluidSynthReverbOn(synth, -1, 1)
    _ = fluidSynthSetReverbRoomSize(synth, -1, 0.8)
    _ = fluidSynthSetReverbDamp(synth, -1, 0.5)
    _ = fluidSynthSetReverbLevel(synth, -1, 0.54)

    try startAudioDriver()
  }

  private func startAudioDriver() throws {
    guard audioDriver == nil, let settings, let synth else { return }
    guard let driver = fluidNewAudioDriver(settings, synth) else {
      throw ChordleFluidSynthError.audioDriverUnavailable
    }
    audioDriver = driver
  }

  private func stopAudioDriverLocked() {
    if let audioDriver {
      fluidDeleteAudioDriver(audioDriver)
      self.audioDriver = nil
    }
  }

  private func selectProgram(_ requestedProgram: Int) {
    guard let synth, soundFontId >= 0 else { return }
    let program = Int32(max(0, min(127, requestedProgram)))
    for channel in 0..<channelCount {
      let channelValue = Int32(channel)
      if fluidSynthProgramSelect(
        synth,
        channelValue,
        soundFontId,
        0,
        program
      ) != 0 {
        _ = fluidSynthProgramSelect(
          synth,
          channelValue,
          soundFontId,
          0,
          0
        )
      }
      _ = fluidSynthPitchWheelSensitivity(synth, channelValue, 2)
      _ = fluidSynthPitchBend(synth, channelValue, centerPitchBend)
    }
  }

  private func allSoundOffLocked() {
    generation += 1
    guard let synth else {
      activeNotes.removeAll()
      return
    }
    for channel in 0..<channelCount {
      let channelValue = Int32(channel)
      _ = fluidSynthAllSoundsOff(synth, channelValue)
      _ = fluidSynthPitchBend(synth, channelValue, centerPitchBend)
    }
    activeNotes.removeAll()
  }

  private func cleanup() {
    allSoundOffLocked()
    stopAudioDriverLocked()
    if let synth, soundFontId >= 0 {
      _ = fluidSynthUnloadSoundFont(synth, soundFontId, 1)
      soundFontId = -1
    }
    if let synth {
      fluidDeleteSynth(synth)
      self.synth = nil
    }
    if let settings {
      fluidDeleteSettings(settings)
      self.settings = nil
    }
    audioSessionConfigured = false
  }

  private func registerAudioNotifications() {
    let center = NotificationCenter.default
    notificationTokens.append(
      center.addObserver(
        forName: AVAudioSession.interruptionNotification,
        object: nil,
        queue: nil
      ) { [weak self] notification in
        self?.handleInterruption(notification)
      }
    )
    notificationTokens.append(
      center.addObserver(
        forName: AVAudioSession.routeChangeNotification,
        object: nil,
        queue: nil
      ) { [weak self] notification in
        self?.handleRouteChange(notification)
      }
    )
    notificationTokens.append(
      center.addObserver(
        forName: AVAudioSession.mediaServicesWereResetNotification,
        object: nil,
        queue: nil
      ) { [weak self] _ in
        self?.scheduleDriverRecovery(fullReset: true)
      }
    )
  }

  private func handleInterruption(_ notification: Notification) {
    guard let rawValue = notification.userInfo?[AVAudioSessionInterruptionTypeKey]
      as? UInt,
      let type = AVAudioSession.InterruptionType(rawValue: rawValue)
    else {
      return
    }
    switch type {
    case .began:
      queue.async {
        self.allSoundOffLocked()
        self.stopAudioDriverLocked()
        self.audioSessionConfigured = false
      }
    case .ended:
      scheduleDriverRecovery(fullReset: false)
    @unknown default:
      scheduleDriverRecovery(fullReset: false)
    }
  }

  private func handleRouteChange(_ notification: Notification) {
    if let rawValue = notification.userInfo?[AVAudioSessionRouteChangeReasonKey]
      as? UInt,
      let reason = AVAudioSession.RouteChangeReason(rawValue: rawValue),
      reason == .categoryChange
    {
      return
    }
    scheduleDriverRecovery(fullReset: false)
  }

  private func scheduleDriverRecovery(fullReset: Bool) {
    queue.async {
      self.recoveryWorkItem?.cancel()
      self.allSoundOffLocked()
      if fullReset {
        self.cleanup()
      } else {
        self.stopAudioDriverLocked()
        self.audioSessionConfigured = false
      }
      let workItem = DispatchWorkItem { [weak self] in
        guard let self else { return }
        do {
          try self.ensureReady(program: self.lastProgram)
        } catch {
          self.cleanup()
        }
      }
      self.recoveryWorkItem = workItem
      self.queue.asyncAfter(deadline: .now() + 0.25, execute: workItem)
    }
  }

  private func performOnQueueAndWait(_ action: () -> Void) {
    if DispatchQueue.getSpecific(key: queueKey) != nil {
      action()
    } else {
      queue.sync(execute: action)
    }
  }

  private func pitchBendValue(cents: Double) -> Int32 {
    let normalized = max(-1, min(1, cents / pitchBendRangeCents))
    return Int32(max(0, min(16_383, 8_192 + Int((normalized * 8_191).rounded()))))
  }

  private func soundFontURL() -> URL? {
    let bundle = Bundle.main
    return bundle.url(forResource: "DefaultSoundFont", withExtension: "sf2")
      ?? bundle.url(
        forResource: "DefaultSoundFont",
        withExtension: "sf2",
        subdirectory: "Audio"
      )
      ?? bundle.urls(forResourcesWithExtension: "sf2", subdirectory: nil)?.first
  }

  private func setString(
    _ name: String,
    _ value: String,
    on settings: OpaquePointer
  ) {
    name.withCString { namePointer in
      value.withCString { valuePointer in
        _ = fluidSettingsSetString(settings, namePointer, valuePointer)
      }
    }
  }

  private func setInt(_ name: String, _ value: Int32, on settings: OpaquePointer) {
    name.withCString { _ = fluidSettingsSetInt(settings, $0, value) }
  }

  private func setNumber(
    _ name: String,
    _ value: Double,
    on settings: OpaquePointer
  ) {
    name.withCString { _ = fluidSettingsSetNumber(settings, $0, value) }
  }
}
