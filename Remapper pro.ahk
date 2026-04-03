#Requires AutoHotkey v2.0
#SingleInstance Force

; ---------------- GLOBALS ----------------
global Remaps := []
global SettingsFile := A_ScriptDir "\remaps.txt"
global GlobalsFile := A_ScriptDir "\globals.txt"

; Default Global Hotkeys
global GlobalConfig := Map(
    "Reload", "^Pause",
    "Exit", "^+Esc",
    "Pause", "Pause",
    "Suspend", ""
)

global MainGui := ""
global ActivePopup := ""

; ---------------- TRAY MENU ----------------
A_TrayMenu.Delete() 
A_TrayMenu.Add("Show Remapper", (*) => ShowMainView())
A_TrayMenu.Add("Reload Script", (*) => Reload())
A_TrayMenu.Add("Exit", (*) => ExitApp())
A_TrayMenu.Default := "Show Remapper"

; ---------------- INITIALIZATION ----------------
LoadGlobals()
LoadData()
ApplyGlobalHotkeys()
ShowMainView()

OnMessage(0x0201, WM_LBUTTONDOWN)
OnMessage(0x00A1, WM_NCLBUTTONDOWN)

WM_LBUTTONDOWN(wParam, lParam, msg, hwnd) {
    global ActivePopup, MainGui
    if (MainGui && hwnd == MainGui.Hwnd && ActivePopup != "") {
        BlinkWindow(ActivePopup)
    }
}
WM_NCLBUTTONDOWN(wParam, lParam, msg, hwnd) {
    global ActivePopup, MainGui
    if (MainGui && hwnd == MainGui.Hwnd && ActivePopup != "") {
        BlinkWindow(ActivePopup)
    }
}

; ---------------- DATA PERSISTENCE ----------------
LoadGlobals() {
    global GlobalConfig, GlobalsFile
    if (FileExist(GlobalsFile)) {
        try {
            loop read GlobalsFile {
                p := StrSplit(A_LoopReadLine, "=")
                if (p.Length == 2 && GlobalConfig.Has(p[1])) {
                    GlobalConfig[p[1]] := Trim(p[2])
                }
            }
        }
    }
}

SaveGlobals() {
    global GlobalConfig, GlobalsFile
    txt := ""
    for k, v in GlobalConfig {
        txt .= k "=" v "`n"
    }
    if (FileExist(GlobalsFile))
        FileDelete(GlobalsFile)
    FileAppend(txt, GlobalsFile)
}

ApplyGlobalHotkeys() {
    global GlobalConfig
    for action, hk in GlobalConfig {
        if (hk != "") {
            try {
                if (action == "Reload")
                    Hotkey(hk, (*) => Reload(), "On")
                else if (action == "Exit")
                    Hotkey(hk, (*) => ExitApp(), "On")
                else if (action == "Pause")
                    Hotkey(hk, (*) => Pause(-1), "On")
                else if (action == "Suspend")
                    Hotkey(hk, (*) => Suspend(-1), "On")
            } catch {
                ; Silently ignore invalid global hotkeys on startup
            }
        }
    }
}

LoadData() {
    global Remaps, SettingsFile
    Remaps := []
    if (FileExist(SettingsFile)) {
        try {
            content := FileRead(SettingsFile)
            loop parse, content, "`n", "`r" {
                if (A_LoopField == "")
                    continue
                p := StrSplit(A_LoopField, "|")
                if (p.Length >= 4) {
                    realSend := StrReplace(p[3], "\n", "`n")
                    Remaps.Push({name: p[1], hotkey: p[2], send: realSend, enabled: (p[4] == "1")})
                }
            }
        }
    }
}

SaveData() {
    global Remaps, SettingsFile
    txt := ""
    for r in Remaps {
        safeSend := StrReplace(r.send, "`n", "\n")
        safeSend := StrReplace(safeSend, "`r", "")
        txt .= r.name "|" r.hotkey "|" safeSend "|" (r.enabled ? "1" : "0") "`n"
    }
    if (FileExist(SettingsFile))
        FileDelete(SettingsFile)
    FileAppend(txt, SettingsFile)
}

; ---------------- VIEW: MAIN LIST ----------------
ShowMainView() {
    global MainGui, Remaps
    if (MainGui is Gui)
        MainGui.Destroy()

    MainGui := Gui("+AlwaysOnTop", "Key Remapper Pro")
    MainGui.SetFont("s9", "Segoe UI")
    
    MainGui.SetFont("Bold s10")
    MainGui.Add("Text", "x15 y15 w100", "NAME / KEY")
    MainGui.Add("Text", "x125 y15 w70", "MACRO / SEND")
    MainGui.Add("Text", "x200 y15 w70 Center", "STATUS")
    MainGui.Add("Text", "x280 y15 w150 Center", "TOOLS")
    
    btnSettings := MainGui.Add("Button", "x415 y10 w35 h30", "⚙")
    btnSettings.OnEvent("Click", (*) => ShowSettingsView())
    
    MainGui.SetFont("Norm s9")
    MainGui.Add("Text", "x10 y+5 w440 h1 0x10")

    for index, r in Remaps {
        isEnabled   := r.enabled
        statusColor := isEnabled ? "cGreen" : "cRed"
        toggleIcon  := isEnabled ? "⏸" : "▶"

        displaySend := InStr(r.send, "`n") ? "[Sequence Macro]" : r.send

        MainGui.SetFont("Bold s8")
        MainGui.Add("Text", "x15 y+15 w100", r.name)
        MainGui.SetFont("Norm s9 cBlue")
        MainGui.Add("Text", "x15 y+0 w100", StrUpper(r.hotkey))
        MainGui.SetFont("Norm s8 cDefault")
        MainGui.Add("Text", "x125 yp-10 w70", StrUpper(displaySend))
        MainGui.SetFont("s8 Bold " statusColor)
        MainGui.Add("Text", "x200 yp w70 Center", isEnabled ? "Active" : "OFF")
        MainGui.SetFont("s9 norm cDefault")

        MainGui.Add("Button", "x295 yp-6 w32 h26", toggleIcon).OnEvent("Click", HandleToggle.Bind(index))
        MainGui.Add("Button", "x+2 w32 h26", "✎").OnEvent("Click", ShowEditView.Bind(index))
        MainGui.Add("Button", "x+2 w32 h26", "🗑").OnEvent("Click", ShowDeleteConfirm.Bind(index))
        MainGui.Add("Button", "x+2 w32 h26", "🧪").OnEvent("Click", HandleTest.Bind(r.send))
    }

    MainGui.Add("Text", "x10 y+25 w440 h1 0x10")
    MainGui.Add("Button", "x10 y+15 w215 h45", "+ ADD NEW KEY").OnEvent("Click", (*) => ShowAddView())
    MainGui.Add("Button", "x+10 yp w215 h45 Default", "START / APPLY").OnEvent("Click", (*) => StartEngine())

    MainGui.Show("w460")
}

; ---------------- CUSTOM DIALOGS ----------------
BlinkWindow(GuiObj) {
    if (GuiObj is Gui) {
        Loop 4 {
            DllCall("FlashWindow", "Ptr", GuiObj.Hwnd, "Int", 1)
            Sleep(80)
        }
    }
}

ShowMissingInfoAlert() {
    global MainGui, ActivePopup
    MainGui.Opt("+Disabled")
    ErrGui := Gui("-MinimizeBox -MaximizeBox +AlwaysOnTop +Owner" MainGui.Hwnd, "Missing Information")
    ActivePopup := ErrGui
    ErrGui.SetFont("s10", "Segoe UI")
    ErrGui.Add("Picture", "x20 y20 w32 h32 Icon2", "shell32.dll")
    ErrGui.Add("Text", "x65 y25 w200", "The Hotkey and Macro fields must be filled out.")
    btnOk := ErrGui.Add("Button", "x90 y+20 w100 h35 Default", "OK")
    btnOk.OnEvent("Click", (*) => CleanupPopup(ErrGui))
    ErrGui.OnEvent("Close", (*) => CleanupPopup(ErrGui))
    ErrGui.Show("w280")
    BlinkWindow(ErrGui)
}

ShowConflictAlert(hk, conflictName) {
    global MainGui, ActivePopup
    MainGui.Opt("+Disabled")
    ErrGui := Gui("-MinimizeBox -MaximizeBox +AlwaysOnTop +Owner" MainGui.Hwnd, "Hotkey Conflict")
    ActivePopup := ErrGui
    ErrGui.SetFont("s10", "Segoe UI")
    ErrGui.Add("Picture", "x20 y20 w32 h32 Icon4", "shell32.dll") 
    ErrGui.Add("Text", "x65 y15 w200", "The hotkey '" StrUpper(hk) "' is already active and assigned to:`n`n" conflictName "`n`nPlease choose a different hotkey or disable the conflicting one first.")
    btnOk := ErrGui.Add("Button", "x90 y+15 w100 h35 Default", "OK")
    btnOk.OnEvent("Click", (*) => CleanupPopup(ErrGui))
    ErrGui.OnEvent("Close", (*) => CleanupPopup(ErrGui))
    ErrGui.Show("w290")
    BlinkWindow(ErrGui)
}

ShowInvalidAlert(hotkey) {
    global MainGui, ActivePopup
    MainGui.Opt("+Disabled")
    ErrGui := Gui("-MinimizeBox -MaximizeBox +AlwaysOnTop +Owner" MainGui.Hwnd, "Invalid Hotkey")
    ActivePopup := ErrGui
    ErrGui.SetFont("s10", "Segoe UI")
    ErrGui.Add("Picture", "x20 y20 w32 h32 Icon4", "shell32.dll") 
    ErrGui.Add("Text", "x65 y22 w200", "The hotkey '" hotkey "' is not valid.`n`nPlease check the Key Reference.")
    btnOk := ErrGui.Add("Button", "x90 y+25 w100 h35 Default", "OK")
    btnOk.OnEvent("Click", (*) => CleanupPopup(ErrGui))
    ErrGui.OnEvent("Close", (*) => CleanupPopup(ErrGui))
    ErrGui.Show("w280")
    BlinkWindow(ErrGui)
}

ShowDeleteConfirm(index, *) {
    global MainGui, ActivePopup, Remaps
    MainGui.Opt("+Disabled")
    ConfGui := Gui("-MinimizeBox -MaximizeBox +AlwaysOnTop +Owner" MainGui.Hwnd, "Confirm Delete")
    ActivePopup := ConfGui
    ConfGui.SetFont("s10", "Segoe UI")
    ConfGui.Add("Text", "Center w250", "Are you sure you want to delete this remap?`n`n" Remaps[index].name)
    btnYes := ConfGui.Add("Button", "x30 y+20 w90 h30", "&Yes")
    btnNo := ConfGui.Add("Button", "x+10 yp w90 h30 Default", "&No")
    btnYes.OnEvent("Click", (*) => (Remaps.RemoveAt(index), SaveData(), CleanupPopup(ConfGui), ShowMainView()))
    btnNo.OnEvent("Click", (*) => CleanupPopup(ConfGui))
    ConfGui.OnEvent("Close", (*) => CleanupPopup(ConfGui))
    ConfGui.Show("w260")
    BlinkWindow(ConfGui)
}

ShowSettingsView(*) {
    global MainGui, ActivePopup, GlobalConfig
    MainGui.Opt("+Disabled")
    SettingsGui := Gui("-MinimizeBox -MaximizeBox +AlwaysOnTop +Owner" MainGui.Hwnd, "Global Settings")
    ActivePopup := SettingsGui
    SettingsGui.SetFont("s9", "Segoe UI")
    
    SettingsGui.Add("GroupBox", "x10 y10 w280 h170", "Global Script Hotkeys")
    
    SettingsGui.Add("Text", "x25 y35 w100", "Reload Script:")
    edRel := SettingsGui.Add("Edit", "x130 yp-3 w140", GlobalConfig["Reload"])
    
    SettingsGui.Add("Text", "x25 y+15 w100", "Exit Script:")
    edExt := SettingsGui.Add("Edit", "x130 yp-3 w140", GlobalConfig["Exit"])

    SettingsGui.Add("Text", "x25 y+15 w100", "Pause Script:")
    edPau := SettingsGui.Add("Edit", "x130 yp-3 w140", GlobalConfig["Pause"])

    SettingsGui.Add("Text", "x25 y+15 w100", "Suspend Script:")
    edSus := SettingsGui.Add("Edit", "x130 yp-3 w140", GlobalConfig["Suspend"])

    btnSave := SettingsGui.Add("Button", "x25 y+25 w120 h35 Default", "Save && Reload")
    btnSave.OnEvent("Click", (*) => SaveGlobalSettings(SettingsGui, edRel.Value, edExt.Value, edPau.Value, edSus.Value))
    
    btnCancel := SettingsGui.Add("Button", "x+10 yp w110 h35", "Cancel")
    btnCancel.OnEvent("Click", (*) => CleanupPopup(SettingsGui))

    btnReset := SettingsGui.Add("Button", "x10 y+15 w280 h30", "🔄 Factory Reset All Remaps")
    btnReset.OnEvent("Click", (*) => HandleClearAll(SettingsGui))

    SettingsGui.OnEvent("Close", (*) => CleanupPopup(SettingsGui))
    SettingsGui.Show("w300 h280")
}

SaveGlobalSettings(GuiObj, rel, ext, pau, sus) {
    global GlobalConfig
    
    ; Basic validation to ensure they aren't trying to use a hotkey already active in the main list
    arr := [rel, ext, pau, sus]
    for hk in arr {
        if (hk != "") {
            conflict := CheckIfRemapUsesHotkey(hk)
            if (conflict != "") {
                ShowConflictAlert(hk, conflict " (Main List)")
                return
            }
        }
    }

    GlobalConfig["Reload"] := rel
    GlobalConfig["Exit"] := ext
    GlobalConfig["Pause"] := pau
    GlobalConfig["Suspend"] := sus
    SaveGlobals()
    MsgBox("Global settings updated. The script will now reload to apply them.", "Settings Saved", 0x40040)
    Reload()
}

CleanupPopup(GuiObj) {
    global MainGui, ActivePopup
    ActivePopup := ""
    MainGui.Opt("-Disabled")
    GuiObj.Destroy()
}

; ---------------- ADD / EDIT VIEWS ----------------
ShowAddView(*) {
    ConstructEditGui("Add New Remap", "", "", "", (n, h, s, e) => SaveNew(n, h, s, e), false)
}

ShowEditView(index, *) {
    global Remaps
    r := Remaps[index]
    ConstructEditGui("Edit Remap", r.name, r.hotkey, r.send, (n, h, s, e) => UpdateExisting(index, n, h, s, e), true, index)
}

ConstructEditGui(title, nameVal, hkVal, sdVal, saveCallback, isEdit, index := 0) {
    global MainGui, Remaps
    if (MainGui is Gui)
        MainGui.Destroy()
    
    MainGui := Gui("-MinimizeBox -MaximizeBox +AlwaysOnTop", title)
    MainGui.SetFont("s9", "Segoe UI")
    
    MainGui.Add("Text", "x50 y20 w100", "Name/Label:")
    edNm := MainGui.Add("Edit", "x150 yp-3 w165 Limit18", nameVal)
    
    if (isEdit) {
        btnTrash := MainGui.Add("Button", "x+5 yp-1 w30 h26", "🗑")
        btnTrash.OnEvent("Click", (*) => ShowDeleteConfirm(index))
    }
    
    MainGui.Add("Text", "x50 y+15 w100", "Hotkey:")
    edHk := MainGui.Add("Edit", "x150 yp-3 w165", hkVal)
    
    btnHelp := MainGui.Add("Button", "x+5 yp-1 w30 h26", "?")
    btnHelp.OnEvent("Click", (*) => ShowHelpView())
    
    MainGui.Add("Text", "x50 y+15 w100", "Send / Macro:")
    edSd := MainGui.Add("Edit", "x150 yp-3 w200 r5 vScroll", sdVal)
    
    MainGui.SetFont("s8 cGray", "Segoe UI")
    tipText := "Syntax Tip:`nLine 1: {Enter}`nLine 2: [sleep 500]  <- Uses brackets to pause 0.5s`nLine 3: Hello World"
    MainGui.Add("Text", "x150 y+5 w200", tipText)
    MainGui.SetFont("s9 cDefault")

    currState := isEdit ? Remaps[index].enabled : 1
    chkEnable := MainGui.Add("Checkbox", "x150 y+10 Checked" currState, "Enable this hotkey immediately")

    MainGui.Add("Button", "x100 y+20 w100 h35", "Save/Update").OnEvent("Click", (*) => saveCallback(edNm.Value, edHk.Value, edSd.Value, chkEnable.Value))
    MainGui.Add("Button", "x+20 yp w100 h35", "Cancel").OnEvent("Click", (*) => ShowMainView())
    MainGui.Show("w450 h320")
}

; ---------------- VALIDATION & EXECUTION LOGIC ----------------

; Checks if a hotkey is used by an active main remap
CheckIfRemapUsesHotkey(hk, ignoreIndex := 0) {
    global Remaps
    for i, r in Remaps {
        if (i != ignoreIndex && r.enabled && StrLower(r.hotkey) == StrLower(hk))
            return r.name
    }
    return ""
}

; Checks if a hotkey is used by a Global Setting
CheckIfGlobalUsesHotkey(hk) {
    global GlobalConfig
    for action, gh in GlobalConfig {
        if (gh != "" && StrLower(gh) == StrLower(hk))
            return "Global Setting: " action
    }
    return ""
}

GenerateAutoName() {
    global Remaps
    base := "New Remap"
    
    ; Check if base exists
    exists := false
    for r in Remaps {
        if (r.name == base)
            exists := true
    }
    if (!exists)
        return base
        
    ; Find next number
    num := 2
    loop {
        exists := false
        for r in Remaps {
            if (r.name == (base " " num))
                exists := true
        }
        if (!exists)
            return base " " num
        num++
    }
}

ValidateAndSave(nm, hk, sd, isEnabled, callback, ignoreIndex := 0) {
    nm := Trim(nm)
    hk := Trim(hk)
    sd := Trim(sd)
    
    ; Auto-name if blank
    if (nm == "")
        nm := GenerateAutoName()
        
    ; Only block if Hotkey or Send is blank
    if (hk == "" || sd == "") {
        ShowMissingInfoAlert()
        return false
    }
    
    ; Verify the syntax is valid by doing a test bind
    try {
        Hotkey(hk, (*) => "", "Off") 
    } catch as e {
        ShowInvalidAlert(hk)
        return false
    }

    ; Conflict Check (ONLY if they are trying to enable it)
    if (isEnabled) {
        ; 1. Check Globals
        globConflict := CheckIfGlobalUsesHotkey(hk)
        if (globConflict != "") {
            ShowConflictAlert(hk, globConflict)
            return false
        }
        
        ; 2. Check other active Remaps
        remapConflict := CheckIfRemapUsesHotkey(hk, ignoreIndex)
        if (remapConflict != "") {
            ShowConflictAlert(hk, remapConflict)
            return false
        }
    }
    
    callback(nm, hk, sd, isEnabled)
    return true
}

SaveNew(nm, hk, sd, isEnabled) {
    global Remaps
    ValidateAndSave(nm, hk, sd, isEnabled, (fnm, fhk, fsd, fEnb) => (
        Remaps.Push({name: fnm, hotkey: fhk, send: fsd, enabled: fEnb}),
        SaveData(),
        ShowMainView()
    ))
}

UpdateExisting(index, nm, hk, sd, isEnabled) {
    global Remaps
    ValidateAndSave(nm, hk, sd, isEnabled, (fnm, fhk, fsd, fEnb) => (
        Remaps[index].name := fnm,
        Remaps[index].hotkey := fhk,
        Remaps[index].send := fsd,
        Remaps[index].enabled := fEnb,
        SaveData(),
        ShowMainView()
    ), index)
}

ExecuteRemap(payload, hotkeyName := "") {
    loop parse, payload, "`n", "`r" {
        line := Trim(A_LoopField)
        if (line == "")
            continue
        
        ; NEW SYNTAX: Looks explicitly for [sleep X] or [Sleep X]
        if (RegExMatch(line, "^\[[sS]leep\s+(\d+)\]$", &match)) {
            Sleep(Integer(match[1]))
        } else {
            Send(line)
        }
    }
}

StartEngine(*) {
    global Remaps, MainGui
    Suspend(true)
    for index, r in Remaps {
        if (r.enabled && r.hotkey != "" && r.send != "") {
            try {
                Hotkey(r.hotkey, ExecuteRemap.Bind(r.send), "On")
            } catch as e {
                ShowInvalidAlert(r.hotkey)
                return 
            }
        }
    }
    Suspend(false)
    MainGui.Hide()
    TrayTip "Remapper Active", "Keys applied.", 1
}

; ---------------- REMAINING LOGIC ----------------

ShowHelpView(*) {
    global MainGui, ActivePopup
    MainGui.Opt("+Disabled")
    HelpGui := Gui("-MinimizeBox -MaximizeBox +AlwaysOnTop +Owner" MainGui.Hwnd, "Hotkey Reference")
    ActivePopup := HelpGui
    HelpGui.SetFont("s9", "Consolas")
    HelpText := "MODIFIERS:`n^=Ctrl +=Shift !=Alt #=Win`n`nSPECIALS (Use {}):`n{Enter} {Tab} {Space} {Backspace} {Delete}`n{Home} {End} {PgUp} {PgDn} {Up} {Down}`n`nNUMPAD:`nNumpadAdd (+), NumpadSub (-), NumpadMult (*), NumpadDiv (/), NumpadEnter, Numpad0-9"
    HelpGui.Add("Edit", "ReadOnly x10 y10 w330 h180 -Theme", HelpText)
    btnBack := HelpGui.Add("Button", "x115 y+15 w120 h35 Default", "← BACK")
    btnBack.OnEvent("Click", (*) => CleanupPopup(HelpGui))
    HelpGui.OnEvent("Close", (*) => CleanupPopup(HelpGui))
    HelpGui.Show("w350 h260")
    btnBack.Focus() 
}

HandleClearAll(SettingsGui) {
    global Remaps, SettingsFile, GlobalsFile
    if (MsgBox("This will delete all keys, globals, and save files. Proceed?", "Reset Confirmation", 0x40004) == "Yes") {
        Remaps := []
        if (FileExist(SettingsFile)) 
            FileDelete(SettingsFile)
        if (FileExist(GlobalsFile))
            FileDelete(GlobalsFile)
        CleanupPopup(SettingsGui)
        Reload() ; Easiest way to reset script state
    }
}

HandleTest(ValueToSend, *) {
    val := Trim(ValueToSend)
    if (val == "")
        return
    ToolTip("Testing in 1s...")
    Sleep(1000)
    ToolTip()
    ExecuteRemap(val)
}

HandleToggle(index, *) {
    global Remaps
    
    ; If we are turning it ON, we must check for conflicts first
    if (!Remaps[index].enabled) {
        hk := Remaps[index].hotkey
        
        globConflict := CheckIfGlobalUsesHotkey(hk)
        if (globConflict != "") {
            ShowConflictAlert(hk, globConflict)
            return
        }
        
        remapConflict := CheckIfRemapUsesHotkey(hk, index)
        if (remapConflict != "") {
            ShowConflictAlert(hk, remapConflict)
            return
        }
    }
    
    ; If no conflicts (or if turning it off), proceed
    Remaps[index].enabled := !Remaps[index].enabled
    SaveData()
    ShowMainView()
}