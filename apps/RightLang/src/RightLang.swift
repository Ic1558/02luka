import Cocoa
import Carbon
import ApplicationServices

private enum PrefKey {
    static let autoConvertClipboard = "RightLang.autoConvertClipboard"
    static let conversionMode = "RightLang.conversionMode"
    static let minDelta = "RightLang.minDelta"
    static let enableKeyCapture = "RightLang.enableKeyCapture"
    static let enableHotkeyFix = "RightLang.enableHotkeyFix"
    static let enableAutoFix = "RightLang.enableAutoFix"
    static let enableSelectionToggleHotkey = "RightLang.enableSelectionToggleHotkey"
    static let selectionToggleHotkeyKeyCode = "RightLang.selectionToggleHotkeyKeyCode"
    static let selectionToggleHotkeyMods = "RightLang.selectionToggleHotkeyMods"
}

private struct HotkeyMods: OptionSet {
    let rawValue: Int

    static let command = HotkeyMods(rawValue: 1 << 0)
    static let shift = HotkeyMods(rawValue: 1 << 1)
    static let option = HotkeyMods(rawValue: 1 << 2)
    static let control = HotkeyMods(rawValue: 1 << 3)

    static func fromCGFlags(_ flags: CGEventFlags) -> HotkeyMods {
        var m: HotkeyMods = []
        if flags.contains(.maskCommand) { m.insert(.command) }
        if flags.contains(.maskShift) { m.insert(.shift) }
        if flags.contains(.maskAlternate) { m.insert(.option) }
        if flags.contains(.maskControl) { m.insert(.control) }
        return m
    }

    static func fromNSEventFlags(_ flags: NSEvent.ModifierFlags) -> HotkeyMods {
        var m: HotkeyMods = []
        if flags.contains(.command) { m.insert(.command) }
        if flags.contains(.shift) { m.insert(.shift) }
        if flags.contains(.option) { m.insert(.option) }
        if flags.contains(.control) { m.insert(.control) }
        return m
    }

    func toCGFlags() -> CGEventFlags {
        var f: CGEventFlags = []
        if contains(.command) { f.insert(.maskCommand) }
        if contains(.shift) { f.insert(.maskShift) }
        if contains(.option) { f.insert(.maskAlternate) }
        if contains(.control) { f.insert(.maskControl) }
        return f
    }
}

private func keyCodeLabel(_ keyCode: UInt16) -> String {
    // Minimal mapping for A-Z and common keys.
    switch Int(keyCode) {
    case Int(kVK_ANSI_A): return "A"
    case Int(kVK_ANSI_B): return "B"
    case Int(kVK_ANSI_C): return "C"
    case Int(kVK_ANSI_D): return "D"
    case Int(kVK_ANSI_E): return "E"
    case Int(kVK_ANSI_F): return "F"
    case Int(kVK_ANSI_G): return "G"
    case Int(kVK_ANSI_H): return "H"
    case Int(kVK_ANSI_I): return "I"
    case Int(kVK_ANSI_J): return "J"
    case Int(kVK_ANSI_K): return "K"
    case Int(kVK_ANSI_L): return "L"
    case Int(kVK_ANSI_M): return "M"
    case Int(kVK_ANSI_N): return "N"
    case Int(kVK_ANSI_O): return "O"
    case Int(kVK_ANSI_P): return "P"
    case Int(kVK_ANSI_Q): return "Q"
    case Int(kVK_ANSI_R): return "R"
    case Int(kVK_ANSI_S): return "S"
    case Int(kVK_ANSI_T): return "T"
    case Int(kVK_ANSI_U): return "U"
    case Int(kVK_ANSI_V): return "V"
    case Int(kVK_ANSI_W): return "W"
    case Int(kVK_ANSI_X): return "X"
    case Int(kVK_ANSI_Y): return "Y"
    case Int(kVK_ANSI_Z): return "Z"
    case Int(kVK_Space): return "Space"
    default: return "KeyCode(\(keyCode))"
    }
}

private func hotkeyDisplay(mods: HotkeyMods, keyCode: UInt16) -> String {
    var out = ""
    if mods.contains(.control) { out += "⌃" }
    if mods.contains(.option) { out += "⌥" }
    if mods.contains(.shift) { out += "⇧" }
    if mods.contains(.command) { out += "⌘" }
    out += keyCodeLabel(keyCode)
    return out
}

private enum ConversionMode: String, CaseIterable {
    case auto = "auto"
    case enToTh = "enToTh"
    case thToEn = "thToEn"

    var displayName: String {
        switch self {
        case .auto: return "Auto"
        case .enToTh: return "Force EN → TH"
        case .thToEn: return "Force TH → EN"
        }
    }
}

private struct ConversionResult {
    let output: String
    let applied: Bool
    let direction: String?
    let delta: Int
}

private enum InputTarget {
    case englishUS
    case thai
}

private final class LayoutConverter {
    // Thai Kedmanee (common macOS layout) — MVP mapping (unshifted keys)
    // Focus: converting the common “typed Thai while in EN layout” gibberish.
    private static let enToTh: [Character: Character] = [
        "1": "ๅ", "2": "/", "3": "-", "4": "ภ", "5": "ถ", "6": "ุ", "7": "ึ", "8": "ค", "9": "ต", "0": "จ", "-": "ข", "=": "ช",
        "q": "ๆ", "w": "ไ", "e": "ำ", "r": "พ", "t": "ะ", "y": "ั", "u": "ี", "i": "ร", "o": "น", "p": "ย", "[": "บ", "]": "ล", "\\": "ฃ",
        "a": "ฟ", "s": "ห", "d": "ก", "f": "ด", "g": "เ", "h": "้", "j": "่", "k": "า", "l": "ส", ";": "ว", "'": "ง",
        "z": "ผ", "x": "ป", "c": "แ", "v": "อ", "b": "ิ", "n": "ื", "m": "ท", ",": "ม", ".": "ใ", "/": "ฝ"
    ]

    private static let thToEn: [Character: Character] = {
        var inverted: [Character: Character] = [:]
        for (en, th) in enToTh {
            inverted[th] = en
        }
        return inverted
    }()

    private static func isThai(_ scalar: Unicode.Scalar) -> Bool {
        (0x0E00...0x0E7F).contains(Int(scalar.value))
    }

    private static func countThai(_ text: String) -> Int {
        text.unicodeScalars.reduce(into: 0) { count, scalar in
            if isThai(scalar) { count += 1 }
        }
    }

    private static func countLatinLetters(_ text: String) -> Int {
        text.unicodeScalars.reduce(into: 0) { count, scalar in
            let v = scalar.value
            if (65...90).contains(v) || (97...122).contains(v) { count += 1 }
        }
    }

    private static func mapChars(_ text: String, map: [Character: Character]) -> (String, Int) {
        var out = String.UnicodeScalarView()
        out.reserveCapacity(text.unicodeScalars.count)
        var changed = 0

        for ch in text {
            let lower = Character(String(ch).lowercased())
            if let mapped = map[ch] ?? map[lower] {
                if mapped != ch { changed += 1 }
                for s in String(mapped).unicodeScalars { out.append(s) }
            } else {
                for s in String(ch).unicodeScalars { out.append(s) }
            }
        }
        return (String(out), changed)
    }

    static func convert(_ text: String, mode: ConversionMode, minDelta: Int) -> ConversionResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return ConversionResult(output: text, applied: false, direction: nil, delta: 0)
        }

        switch mode {
        case .enToTh:
            let (out, changed) = mapChars(text, map: enToTh)
            return ConversionResult(output: out, applied: changed >= minDelta, direction: "EN→TH", delta: changed)
        case .thToEn:
            let (out, changed) = mapChars(text, map: thToEn)
            return ConversionResult(output: out, applied: changed >= minDelta, direction: "TH→EN", delta: changed)
        case .auto:
            let originalThai = countThai(text)
            let originalLatin = countLatinLetters(text)

            let (toThai, changedToThai) = mapChars(text, map: enToTh)
            let (toEnglish, changedToEnglish) = mapChars(text, map: thToEn)

            let toThaiThai = countThai(toThai)
            let toEnglishLatin = countLatinLetters(toEnglish)

            let thaiGain = toThaiThai - originalThai
            let englishGain = toEnglishLatin - originalLatin

            // Heuristic:
            // - If converting increases Thai characters meaningfully, prefer EN→TH.
            // - Else if converting increases Latin letters meaningfully, prefer TH→EN.
            // - Require a minimum "changed" delta to avoid converting normal text.
            if thaiGain >= 3 && changedToThai >= minDelta {
                return ConversionResult(output: toThai, applied: true, direction: "EN→TH", delta: changedToThai)
            }
            if englishGain >= 3 && changedToEnglish >= minDelta {
                return ConversionResult(output: toEnglish, applied: true, direction: "TH→EN", delta: changedToEnglish)
            }

            return ConversionResult(output: text, applied: false, direction: nil, delta: 0)
        }
    }
}

private final class InputSourceSwitcher {
    static func switchTo(_ target: InputTarget) {
        guard let list = TISCreateInputSourceList(nil, false)?.takeRetainedValue() as? [TISInputSource] else {
            return
        }

        let wantedIDs: [String]
        switch target {
        case .englishUS:
            wantedIDs = ["com.apple.keylayout.US", "com.apple.keylayout.ABC"]
        case .thai:
            wantedIDs = ["com.apple.keylayout.Thai"]
        }

        func inputSourceID(_ src: TISInputSource) -> String? {
            guard let ptr = TISGetInputSourceProperty(src, kTISPropertyInputSourceID) else { return nil }
            return Unmanaged<CFString>.fromOpaque(ptr).takeUnretainedValue() as String
        }

        if let match = list.first(where: { src in
            guard let id = inputSourceID(src) else { return false }
            return wantedIDs.contains(id)
        }) {
            TISSelectInputSource(match)
        }
    }
}

private final class KeyboardFixer {
    static let shared = KeyboardFixer()
    private var isSynthesizing = false

    func shouldIgnoreTapEvent() -> Bool { isSynthesizing }

    func replaceLastToken(token: String, converted: String) {
        guard !token.isEmpty else { return }
        synthLock {
            for _ in 0..<token.count {
                postKey(keyCode: CGKeyCode(kVK_Delete), down: true)
                postKey(keyCode: CGKeyCode(kVK_Delete), down: false)
            }
            typeUnicode(converted)
        }
    }

    func typeSpace() {
        synthLock {
            postKey(keyCode: CGKeyCode(kVK_Space), down: true)
            postKey(keyCode: CGKeyCode(kVK_Space), down: false)
        }
    }

    func typeReturn() {
        synthLock {
            postKey(keyCode: CGKeyCode(kVK_Return), down: true)
            postKey(keyCode: CGKeyCode(kVK_Return), down: false)
        }
    }

    func synthLock(_ block: () -> Void) {
        isSynthesizing = true
        defer { isSynthesizing = false }
        block()
    }

    func chord(keyCode: CGKeyCode, flags: CGEventFlags) {
        synthLock {
            guard let down = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true),
                  let up = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false) else {
                return
            }
            down.flags = flags
            up.flags = flags
            down.post(tap: .cghidEventTap)
            up.post(tap: .cghidEventTap)
        }
    }

    func sendCopy() {
        chord(keyCode: CGKeyCode(kVK_ANSI_C), flags: [.maskCommand])
    }

    func sendPaste() {
        chord(keyCode: CGKeyCode(kVK_ANSI_V), flags: [.maskCommand])
    }

    private func postKey(keyCode: CGKeyCode, down: Bool) {
        guard let event = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: down) else { return }
        event.post(tap: .cghidEventTap)
    }

    private func typeUnicode(_ text: String) {
        let scalars = Array(text.utf16)
        guard let down = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true),
              let up = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false) else {
            return
        }
        down.keyboardSetUnicodeString(stringLength: scalars.count, unicodeString: scalars)
        up.keyboardSetUnicodeString(stringLength: scalars.count, unicodeString: scalars)
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }
}

private final class KeyCaptureService {
    private let fixer = KeyboardFixer.shared
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    private var currentToken: String = ""
    private var lastToken: String = ""
    var onToggleSelection: (() -> Void)?

    func startIfEnabled() {
        guard UserDefaults.standard.bool(forKey: PrefKey.enableKeyCapture) else { return }
        if tap != nil { return }

        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { proxy, type, event, refcon in
                let mySelf = Unmanaged<KeyCaptureService>.fromOpaque(refcon!).takeUnretainedValue()
                return mySelf.handleEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        ) else {
            return
        }

        tap = eventTap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        if let src = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
        }
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }

    func stop() {
        guard let eventTap = tap else { return }
        CGEvent.tapEnable(tap: eventTap, enable: false)
        if let src = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .commonModes)
        }
        tap = nil
        runLoopSource = nil
        currentToken = ""
        lastToken = ""
    }

    func restart() {
        stop()
        startIfEnabled()
    }

    func triggerFixLastWord() {
        guard UserDefaults.standard.object(forKey: PrefKey.enableHotkeyFix) as? Bool ?? true else { return }
        let token = !currentToken.isEmpty ? currentToken : lastToken
        guard !token.isEmpty else { return }

        let (result, mode) = convertToken(token)
        guard result.applied, result.output != token else { return }

        fixer.replaceLastToken(token: token, converted: result.output)
        switchInputSourceIfNeeded(result: result, mode: mode)

        currentToken = ""
        lastToken = ""
    }

    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if fixer.shouldIgnoreTapEvent() { return Unmanaged.passUnretained(event) }
        guard type == .keyDown else { return Unmanaged.passUnretained(event) }

        let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags

        // Hotkey: Cmd+Shift+L
        if (UserDefaults.standard.object(forKey: PrefKey.enableHotkeyFix) as? Bool ?? true),
           keyCode == Int(kVK_ANSI_L),
           flags.contains(.maskCommand),
           flags.contains(.maskShift) {
            triggerFixLastWord()
            return nil
        }

        // Hotkey (configurable): toggle selected text layout (copy->convert->paste).
        if UserDefaults.standard.bool(forKey: PrefKey.enableSelectionToggleHotkey) {
            let savedKeyCode = UserDefaults.standard.object(forKey: PrefKey.selectionToggleHotkeyKeyCode) as? Int ?? Int(kVK_ANSI_T)
            let savedModsRaw = UserDefaults.standard.object(forKey: PrefKey.selectionToggleHotkeyMods) as? Int ?? (HotkeyMods.command.union(.shift).rawValue)
            let savedMods = HotkeyMods(rawValue: savedModsRaw)
            let eventMods = HotkeyMods.fromCGFlags(flags)
            if keyCode == savedKeyCode, eventMods.contains(savedMods) {
                onToggleSelection?()
                return nil
            }
        }

        // Backspace updates buffer
        if keyCode == Int(kVK_Delete) {
            if !currentToken.isEmpty { currentToken.removeLast() }
            return Unmanaged.passUnretained(event)
        }

        let autoFixEnabled = UserDefaults.standard.bool(forKey: PrefKey.enableAutoFix)
        if keyCode == Int(kVK_Space) || keyCode == Int(kVK_Return) {
            if autoFixEnabled, !currentToken.isEmpty {
                let token = currentToken
                finishToken()
                let (result, mode) = convertToken(token)
                if result.applied, result.output != token {
                    fixer.synthLock {
                        fixer.replaceLastToken(token: token, converted: result.output)
                        if keyCode == Int(kVK_Space) { fixer.typeSpace() } else { fixer.typeReturn() }
                    }
                    switchInputSourceIfNeeded(result: result, mode: mode)
                    return nil
                }
            }
            finishToken()
            return Unmanaged.passUnretained(event)
        }

        // Extract typed unicode.
        var length = 0
        var buffer = [UniChar](repeating: 0, count: 8)
        event.keyboardGetUnicodeString(maxStringLength: 8, actualStringLength: &length, unicodeString: &buffer)
        if length > 0 {
            let s = String(utf16CodeUnits: buffer, count: length)
            appendTypedString(s)
        }

        return Unmanaged.passUnretained(event)
    }

    private func appendTypedString(_ s: String) {
        if s.trimmingCharacters(in: .controlCharacters).isEmpty { return }
        if s == "\n" || s == "\r" || s == "\t" || s == " " {
            finishToken()
            return
        }
        if s.unicodeScalars.contains(where: { $0.value < 0x20 }) { return }
        currentToken.append(contentsOf: s)
    }

    private func finishToken() {
        if !currentToken.isEmpty {
            lastToken = currentToken
            currentToken = ""
        }
    }

    private func convertToken(_ token: String) -> (ConversionResult, ConversionMode) {
        let defaults = UserDefaults.standard
        let rawMode = defaults.string(forKey: PrefKey.conversionMode) ?? ConversionMode.auto.rawValue
        let mode = ConversionMode(rawValue: rawMode) ?? .auto
        let minDelta = defaults.object(forKey: PrefKey.minDelta) as? Int ?? 4
        return (LayoutConverter.convert(token, mode: mode, minDelta: minDelta), mode)
    }

    private func switchInputSourceIfNeeded(result: ConversionResult, mode: ConversionMode) {
        // Only switch when the direction is known (auto or forced conversion).
        guard let dir = result.direction else {
            if mode == .enToTh { InputSourceSwitcher.switchTo(.thai) }
            if mode == .thToEn { InputSourceSwitcher.switchTo(.englishUS) }
            return
        }
        if dir == "EN→TH" { InputSourceSwitcher.switchTo(.thai) }
        if dir == "TH→EN" { InputSourceSwitcher.switchTo(.englishUS) }
    }
}

private final class SettingsWindowController: NSWindowController {
    private let autoConvertCheckbox = NSButton(checkboxWithTitle: "Auto convert clipboard", target: nil, action: nil)
    private let enableKeyCaptureCheckbox = NSButton(checkboxWithTitle: "Enable keyboard capture (for auto-fix)", target: nil, action: nil)
    private let enableHotkeyCheckbox = NSButton(checkboxWithTitle: "Enable hotkey: ⌘⇧L (fix last word)", target: nil, action: nil)
    private let enableAutoFixCheckbox = NSButton(checkboxWithTitle: "Auto-fix wrong layout while typing", target: nil, action: nil)
    private let enableSelectionHotkeyCheckbox = NSButton(checkboxWithTitle: "Enable selection toggle hotkey", target: nil, action: nil)
    private let selectionHotkeyLabel = NSTextField(labelWithString: "")
    private let recordSelectionHotkeyButton = NSButton(title: "Record shortcut…", target: nil, action: nil)
    private let modePopUp = NSPopUpButton(frame: .zero, pullsDown: false)
    private let deltaField = NSTextField(string: "")
    private let accessibilityButton = NSButton(title: "Open Accessibility Settings…", target: nil, action: nil)
    var onPrefsChanged: (() -> Void)?
    private var shortcutMonitor: Any?
    private var isRecordingShortcut = false

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 320),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "then Settings"
        self.init(window: window)
        window.center()
        setupUI()
        load()
    }

    private func setupUI() {
        guard let contentView = window?.contentView else { return }

        autoConvertCheckbox.setButtonType(.switch)
        autoConvertCheckbox.target = self
        autoConvertCheckbox.action = #selector(onChange)

        enableKeyCaptureCheckbox.setButtonType(.switch)
        enableKeyCaptureCheckbox.target = self
        enableKeyCaptureCheckbox.action = #selector(onChange)

        enableHotkeyCheckbox.setButtonType(.switch)
        enableHotkeyCheckbox.target = self
        enableHotkeyCheckbox.action = #selector(onChange)

        enableAutoFixCheckbox.setButtonType(.switch)
        enableAutoFixCheckbox.target = self
        enableAutoFixCheckbox.action = #selector(onChange)

        enableSelectionHotkeyCheckbox.setButtonType(.switch)
        enableSelectionHotkeyCheckbox.target = self
        enableSelectionHotkeyCheckbox.action = #selector(onChange)

        selectionHotkeyLabel.textColor = .secondaryLabelColor

        recordSelectionHotkeyButton.target = self
        recordSelectionHotkeyButton.action = #selector(recordSelectionHotkey)

        modePopUp.addItems(withTitles: ConversionMode.allCases.map { $0.displayName })
        modePopUp.target = self
        modePopUp.action = #selector(onChange)

        deltaField.placeholderString = "Min changed chars (default 4)"
        deltaField.target = self
        deltaField.action = #selector(onChange)

        accessibilityButton.target = self
        accessibilityButton.action = #selector(openAccessibilitySettings)

        let modeLabel = NSTextField(labelWithString: "Conversion mode:")
        let deltaLabel = NSTextField(labelWithString: "Sensitivity:")
        let help = NSTextField(labelWithString: "Auto-fix requires granting Accessibility permission to RightLang.")
        help.textColor = .secondaryLabelColor

        for v in [
            autoConvertCheckbox,
            enableKeyCaptureCheckbox,
            enableHotkeyCheckbox,
            enableAutoFixCheckbox,
            enableSelectionHotkeyCheckbox,
            selectionHotkeyLabel,
            recordSelectionHotkeyButton,
            accessibilityButton,
            modeLabel,
            modePopUp,
            deltaLabel,
            deltaField,
            help
        ] {
            v.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(v)
        }

        NSLayoutConstraint.activate([
            autoConvertCheckbox.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 18),
            autoConvertCheckbox.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 18),

            enableKeyCaptureCheckbox.topAnchor.constraint(equalTo: autoConvertCheckbox.bottomAnchor, constant: 10),
            enableKeyCaptureCheckbox.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 18),

            enableHotkeyCheckbox.topAnchor.constraint(equalTo: enableKeyCaptureCheckbox.bottomAnchor, constant: 10),
            enableHotkeyCheckbox.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 18),

            enableAutoFixCheckbox.topAnchor.constraint(equalTo: enableHotkeyCheckbox.bottomAnchor, constant: 10),
            enableAutoFixCheckbox.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 18),

            enableSelectionHotkeyCheckbox.topAnchor.constraint(equalTo: enableAutoFixCheckbox.bottomAnchor, constant: 10),
            enableSelectionHotkeyCheckbox.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 18),

            recordSelectionHotkeyButton.centerYAnchor.constraint(equalTo: enableSelectionHotkeyCheckbox.centerYAnchor),
            recordSelectionHotkeyButton.leadingAnchor.constraint(equalTo: enableSelectionHotkeyCheckbox.trailingAnchor, constant: 12),

            selectionHotkeyLabel.topAnchor.constraint(equalTo: enableSelectionHotkeyCheckbox.bottomAnchor, constant: 6),
            selectionHotkeyLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 18),

            accessibilityButton.topAnchor.constraint(equalTo: selectionHotkeyLabel.bottomAnchor, constant: 10),
            accessibilityButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 18),

            modeLabel.topAnchor.constraint(equalTo: accessibilityButton.bottomAnchor, constant: 16),
            modeLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 18),

            modePopUp.centerYAnchor.constraint(equalTo: modeLabel.centerYAnchor),
            modePopUp.leadingAnchor.constraint(equalTo: modeLabel.trailingAnchor, constant: 12),

            deltaLabel.topAnchor.constraint(equalTo: modeLabel.bottomAnchor, constant: 16),
            deltaLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 18),

            deltaField.centerYAnchor.constraint(equalTo: deltaLabel.centerYAnchor),
            deltaField.leadingAnchor.constraint(equalTo: deltaLabel.trailingAnchor, constant: 12),
            deltaField.widthAnchor.constraint(equalToConstant: 220),

            help.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -18),
            help.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 18),
        ])
    }

    private func load() {
        let defaults = UserDefaults.standard
        autoConvertCheckbox.state = defaults.bool(forKey: PrefKey.autoConvertClipboard) ? .on : .off
        enableKeyCaptureCheckbox.state = defaults.bool(forKey: PrefKey.enableKeyCapture) ? .on : .off
        enableHotkeyCheckbox.state = (defaults.object(forKey: PrefKey.enableHotkeyFix) as? Bool ?? true) ? .on : .off
        enableAutoFixCheckbox.state = defaults.bool(forKey: PrefKey.enableAutoFix) ? .on : .off
        enableSelectionHotkeyCheckbox.state = defaults.bool(forKey: PrefKey.enableSelectionToggleHotkey) ? .on : .off
        let rawMode = defaults.string(forKey: PrefKey.conversionMode) ?? ConversionMode.auto.rawValue
        let mode = ConversionMode(rawValue: rawMode) ?? .auto
        modePopUp.selectItem(at: ConversionMode.allCases.firstIndex(of: mode) ?? 0)
        let minDelta = defaults.object(forKey: PrefKey.minDelta) as? Int ?? 4
        deltaField.stringValue = "\(minDelta)"

        let kc = UInt16(defaults.object(forKey: PrefKey.selectionToggleHotkeyKeyCode) as? Int ?? Int(kVK_ANSI_T))
        let modsRaw = defaults.object(forKey: PrefKey.selectionToggleHotkeyMods) as? Int ?? HotkeyMods.command.union(.shift).rawValue
        selectionHotkeyLabel.stringValue = "Current: \(hotkeyDisplay(mods: HotkeyMods(rawValue: modsRaw), keyCode: kc))"
    }

    @objc private func onChange() {
        let defaults = UserDefaults.standard
        defaults.set(autoConvertCheckbox.state == .on, forKey: PrefKey.autoConvertClipboard)
        defaults.set(enableKeyCaptureCheckbox.state == .on, forKey: PrefKey.enableKeyCapture)
        defaults.set(enableHotkeyCheckbox.state == .on, forKey: PrefKey.enableHotkeyFix)
        defaults.set(enableAutoFixCheckbox.state == .on, forKey: PrefKey.enableAutoFix)
        defaults.set(enableSelectionHotkeyCheckbox.state == .on, forKey: PrefKey.enableSelectionToggleHotkey)

        let idx = modePopUp.indexOfSelectedItem
        let mode = (0..<ConversionMode.allCases.count).contains(idx) ? ConversionMode.allCases[idx] : .auto
        defaults.set(mode.rawValue, forKey: PrefKey.conversionMode)

        let parsed = Int(deltaField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines))
        defaults.set(parsed ?? 4, forKey: PrefKey.minDelta)

        onPrefsChanged?()
    }

    @objc private func recordSelectionHotkey() {
        if isRecordingShortcut {
            stopRecording()
            return
        }

        isRecordingShortcut = true
        recordSelectionHotkeyButton.title = "Press keys…"

        shortcutMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            let mods = HotkeyMods.fromNSEventFlags(event.modifierFlags)
            if mods.isEmpty {
                NSSound.beep()
                return nil
            }
            let defaults = UserDefaults.standard
            defaults.set(Int(event.keyCode), forKey: PrefKey.selectionToggleHotkeyKeyCode)
            defaults.set(mods.rawValue, forKey: PrefKey.selectionToggleHotkeyMods)
            self.selectionHotkeyLabel.stringValue = "Current: \(hotkeyDisplay(mods: mods, keyCode: event.keyCode))"
            self.stopRecording()
            self.onPrefsChanged?()
            return nil
        }
    }

    private func stopRecording() {
        isRecordingShortcut = false
        recordSelectionHotkeyButton.title = "Record shortcut…"
        if let mon = shortcutMonitor {
            NSEvent.removeMonitor(mon)
        }
        shortcutMonitor = nil
    }

    @objc private func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}

@objc final class ThenServiceProvider: NSObject {
    @objc func toggleLayoutService(_ pboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        guard let text = pboard.string(forType: .string) else {
            error.pointee = "No text found on pasteboard" as NSString
            return
        }

        let defaults = UserDefaults.standard
        let minDelta = defaults.object(forKey: PrefKey.minDelta) as? Int ?? 4
        let result = LayoutConverter.convert(text, mode: .auto, minDelta: minDelta)
        guard result.applied, result.output != text else { return }

        pboard.clearContents()
        pboard.setString(result.output, forType: .string)

        if result.direction == "EN→TH" { InputSourceSwitcher.switchTo(.thai) }
        if result.direction == "TH→EN" { InputSourceSwitcher.switchTo(.englishUS) }
    }

    @objc func convertSelectionToThai(_ pboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        guard let text = pboard.string(forType: .string) else {
            error.pointee = "No text found on pasteboard" as NSString
            return
        }
        let defaults = UserDefaults.standard
        let minDelta = defaults.object(forKey: PrefKey.minDelta) as? Int ?? 4
        let result = LayoutConverter.convert(text, mode: .enToTh, minDelta: minDelta)
        guard result.applied, result.output != text else { return }
        pboard.clearContents()
        pboard.setString(result.output, forType: .string)
        InputSourceSwitcher.switchTo(.thai)
    }

    @objc func convertSelectionToEnglish(_ pboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        guard let text = pboard.string(forType: .string) else {
            error.pointee = "No text found on pasteboard" as NSString
            return
        }
        let defaults = UserDefaults.standard
        let minDelta = defaults.object(forKey: PrefKey.minDelta) as? Int ?? 4
        let result = LayoutConverter.convert(text, mode: .thToEn, minDelta: minDelta)
        guard result.applied, result.output != text else { return }
        pboard.clearContents()
        pboard.setString(result.output, forType: .string)
        InputSourceSwitcher.switchTo(.englishUS)
    }
}

@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var settingsWC: SettingsWindowController?

    private let pasteboard = NSPasteboard.general
    private var lastChangeCount: Int = 0
    private var clipboardTimer: Timer?
    private let keyCapture = KeyCaptureService()
    private let servicesProvider = ThenServiceProvider()
    private let didShowWelcomeKey = "then.didShowWelcome"

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        NSApp.servicesProvider = servicesProvider
        NSUpdateDynamicServices()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.toolTip = "then"
            if #available(macOS 11.0, *), let img = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "then") {
                button.image = img
                button.title = ""
            } else {
                button.image = nil
                button.title = "then"
            }
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Convert Clipboard Now", action: #selector(convertClipboardNow), keyEquivalent: "c"))
        menu.addItem(NSMenuItem(title: "Toggle Selected Text Layout", action: #selector(toggleSelectedTextLayout), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Fix Last Word (⌘⇧L)", action: #selector(fixLastWord), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())

        let autoItem = NSMenuItem(title: "Auto Convert Clipboard", action: #selector(toggleAutoConvert), keyEquivalent: "")
        autoItem.state = UserDefaults.standard.bool(forKey: PrefKey.autoConvertClipboard) ? .on : .off
        menu.addItem(autoItem)

        let keyCaptureItem = NSMenuItem(title: "Enable Keyboard Capture", action: #selector(toggleKeyCapture), keyEquivalent: "")
        keyCaptureItem.state = UserDefaults.standard.bool(forKey: PrefKey.enableKeyCapture) ? .on : .off
        menu.addItem(keyCaptureItem)

        menu.addItem(NSMenuItem(title: "Open Accessibility Settings…", action: #selector(openAccessibilitySettings), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit then", action: #selector(quit), keyEquivalent: "q"))
        statusItem.menu = menu

        maybeShowWelcome()

        lastChangeCount = pasteboard.changeCount
        refreshClipboardTimer()
        keyCapture.onToggleSelection = { [weak self] in
            self?.toggleSelectedTextLayout()
        }
        refreshKeyCapture()
    }

    func applicationWillTerminate(_ notification: Notification) {
        clipboardTimer?.invalidate()
        keyCapture.stop()
    }

    private func refreshClipboardTimer() {
        clipboardTimer?.invalidate()
        clipboardTimer = nil

        if UserDefaults.standard.bool(forKey: PrefKey.autoConvertClipboard) {
            clipboardTimer = Timer.scheduledTimer(timeInterval: 0.4, target: self, selector: #selector(onClipboardTick), userInfo: nil, repeats: true)
        }
    }

    private func refreshKeyCapture() {
        keyCapture.restart()
    }

    @objc private func onClipboardTick() {
        let current = pasteboard.changeCount
        if current == lastChangeCount { return }
        lastChangeCount = current

        guard let text = pasteboard.string(forType: .string) else { return }
        let result = convert(text)
        if result.applied, result.output != text {
            pasteboard.clearContents()
            pasteboard.setString(result.output, forType: .string)
            lastChangeCount = pasteboard.changeCount
        }
    }

    private func convert(_ text: String) -> ConversionResult {
        let defaults = UserDefaults.standard
        let rawMode = defaults.string(forKey: PrefKey.conversionMode) ?? ConversionMode.auto.rawValue
        let mode = ConversionMode(rawValue: rawMode) ?? .auto
        let minDelta = defaults.object(forKey: PrefKey.minDelta) as? Int ?? 4
        return LayoutConverter.convert(text, mode: mode, minDelta: minDelta)
    }

    @objc private func convertClipboardNow() {
        guard let text = pasteboard.string(forType: .string) else { return }
        let result = convert(text)
        if result.applied, result.output != text {
            pasteboard.clearContents()
            pasteboard.setString(result.output, forType: .string)
            lastChangeCount = pasteboard.changeCount
        }
    }

    @objc private func toggleAutoConvert(_ sender: NSMenuItem) {
        let newValue = sender.state != .on
        sender.state = newValue ? .on : .off
        UserDefaults.standard.set(newValue, forKey: PrefKey.autoConvertClipboard)
        refreshClipboardTimer()
    }

    @objc private func toggleKeyCapture(_ sender: NSMenuItem) {
        let newValue = sender.state != .on
        sender.state = newValue ? .on : .off
        UserDefaults.standard.set(newValue, forKey: PrefKey.enableKeyCapture)
        refreshKeyCapture()
    }

    @objc private func fixLastWord() {
        keyCapture.triggerFixLastWord()
    }

    @objc private func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func openSettings() {
        if settingsWC == nil {
            settingsWC = SettingsWindowController()
            settingsWC?.onPrefsChanged = { [weak self] in
                self?.refreshClipboardTimer()
                self?.refreshKeyCapture()
            }
        }
        settingsWC?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func maybeShowWelcome() {
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: didShowWelcomeKey) { return }
        defaults.set(true, forKey: didShowWelcomeKey)

        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = "then is running"
        alert.informativeText = "This is a menu bar app. Look for the keyboard icon in the top menu bar.\n\nFor selection convert: select text → right click → Services → then.\nFor hotkeys/auto-fix: grant Accessibility permission in System Settings."
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Open Settings…")

        let response = alert.runModal()
        if response == .alertSecondButtonReturn {
            openSettings()
        }
    }

    @objc private func toggleSelectedTextLayout() {
        // Strategy: Cmd+C (copy selection) -> convert clipboard -> Cmd+V (paste).
        // Requires Accessibility permission to synthesize keystrokes reliably.
        let beforeCount = pasteboard.changeCount
        KeyboardFixer.shared.sendCopy()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            guard let self else { return }
            if self.pasteboard.changeCount == beforeCount { return }
            guard let text = self.pasteboard.string(forType: .string) else { return }

            let result = self.convert(text)
            guard result.applied, result.output != text else { return }

            self.pasteboard.clearContents()
            self.pasteboard.setString(result.output, forType: .string)
            self.lastChangeCount = self.pasteboard.changeCount

            if result.direction == "EN→TH" { InputSourceSwitcher.switchTo(.thai) }
            if result.direction == "TH→EN" { InputSourceSwitcher.switchTo(.englishUS) }

            KeyboardFixer.shared.sendPaste()
        }
    }
}
