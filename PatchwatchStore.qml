pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// All patchwatch state lives here. A bar widget is instantiated once per
// monitor, so a Process or Timer declared in Panel.qml would run once per
// monitor; this singleton is the model and Panel.qml is only a view.
//
// The CLI next to this file does the work and prints its findings as JSON.
// That output is treated as input like any other: capped while it streams,
// parsed, and rebuilt field by field with fixed types and lengths before the
// panel sees any of it.
Singleton {
  id: root

  readonly property string cli:
    Qt.resolvedUrl("bin/omarchy-patchwatch").toString().replace(/^file:\/\//, "")

  readonly property int maxBytes: 524288
  readonly property int maxFindings: 200
  readonly property int maxField: 600
  readonly property var levels: ({ "ok": true, "info": true, "warn": true })

  // A check costs a GitHub request per tracked PR, so it runs at startup,
  // every half hour, and when asked for; never on a tight loop.
  readonly property int pollInterval: 30 * 60 * 1000
  readonly property int staleAfter: 60 * 1000
  readonly property int deadline: 90 * 1000

  property var findings: []
  property bool loaded: false
  property bool checking: false
  property string error: ""
  property double lastCheck: 0

  readonly property var patches: findings.filter(function(f) { return f.key.indexOf("pr") === 0 })
  readonly property var pending: findings.filter(function(f) { return f.level !== "ok" && !f.acked })
  readonly property int warnCount: pending.filter(function(f) { return f.level === "warn" }).length
  readonly property int infoCount: pending.length - warnCount

  readonly property string tooltip: {
    if (error !== "") return "Patchwatch: " + error
    if (!loaded) return "Patchwatch: checking"
    if (warnCount > 0) return "Patchwatch: " + warnCount + " patch" + (warnCount === 1 ? "" : "es") + " need" + (warnCount === 1 ? "s" : "") + " a look"
    if (infoCount > 0) return "Patchwatch: " + infoCount + " note" + (infoCount === 1 ? "" : "s")
    if (patches.length === 0) return "Patchwatch: no patches tracked"
    return "Patchwatch: " + patches.length + " patch" + (patches.length === 1 ? "" : "es") + " in place"
  }

  // For shell components whose text format is not ours to set (the bar
  // tooltip): nothing that could be read as markup goes in.
  function plain(value) {
    return String(value === undefined || value === null ? "" : value).replace(/[<>&]/g, "")
  }

  function clean(value) {
    if (typeof value !== "string") return ""
    var s = value.replace(/[\u0000-\u001f\u007f-\u009f‎‏‪-‮⁦-⁩]/g, " ")
    return s.length > root.maxField ? s.slice(0, root.maxField) : s
  }

  // --- checking -----------------------------------------------------------

  property string buffer: ""
  property bool overflow: false

  function refresh() {
    if (checkProc.running) return
    root.buffer = ""
    root.overflow = false
    root.checking = true
    checkProc.running = true
    deadlineTimer.restart()
  }

  function refreshIfStale() {
    if (Date.now() - root.lastCheck > root.staleAfter) root.refresh()
  }

  function stop(proc) {
    proc.signal(15)
    killTimer.target = proc
    killTimer.restart()
  }

  Process {
    id: checkProc
    command: ["/usr/bin/bash", root.cli, "check", "--json"]
    stdout: SplitParser {
      splitMarker: ""
      onRead: function(chunk) {
        if (root.overflow) return
        root.buffer += chunk
        // .length counts UTF-16 units; the CLI already caps every field and
        // the number of findings, so this is the backstop, not the bound.
        if (root.buffer.length > root.maxBytes) {
          root.overflow = true
          root.buffer = ""
          root.stop(checkProc)
        }
      }
    }
    onExited: function(code, status) {
      deadlineTimer.stop()
      root.checking = false
      root.lastCheck = Date.now()
      if (root.overflow) root.error = "the check printed more than expected"
      else if (code !== 0) root.error = "the check failed (exit " + code + ")"
      else root.apply(root.buffer)
      root.buffer = ""
      root.loaded = true
    }
  }

  function apply(text) {
    var parsed
    try {
      parsed = JSON.parse(text)
    } catch (e) {
      root.error = "the check printed something that is not JSON"
      return
    }
    if (!Array.isArray(parsed) || parsed.length > root.maxFindings) {
      root.error = "the check printed an unexpected shape"
      return
    }
    var out = []
    for (var i = 0; i < parsed.length; i++) {
      var f = parsed[i]
      if (f === null || typeof f !== "object" || typeof f.key !== "string" || !root.levels[f.level]) {
        root.error = "the check printed an unexpected shape"
        return
      }
      out.push({
        key: root.clean(f.key),
        state: root.clean(f.state),
        title: root.clean(f.title),
        advice: root.clean(f.advice),
        details: root.clean(f.details),
        command: root.clean(f.command),
        level: f.level,
        acked: f.acked === true
      })
    }
    // Most urgent first, so the panel opens on what needs doing.
    var rank = { "warn": 0, "info": 1, "ok": 2 }
    out.sort(function(a, b) { return rank[a.level] - rank[b.level] })
    root.findings = out
    root.error = ""
  }

  Timer {
    id: deadlineTimer
    interval: root.deadline
    onTriggered: if (checkProc.running) root.stop(checkProc)
  }

  Timer {
    id: killTimer
    property var target: null
    interval: 2000
    onTriggered: if (target && target.running) target.signal(9)
  }

  Timer {
    interval: root.pollInterval
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  // --- actions ------------------------------------------------------------

  // Keys are passed as their own argv element, and the CLI only acts on a
  // key that matches one of its current findings.
  function acknowledge(key) {
    if (ackProc.running) return
    ackProc.command = ["/usr/bin/bash", root.cli, "ack", String(key)]
    ackProc.running = true
    actionDeadline.restart()
  }

  function copyCommand(key) {
    if (copyProc.running) return
    copyProc.command = ["/usr/bin/bash", root.cli, "copy-command", String(key)]
    copyProc.running = true
    actionDeadline.restart()
  }

  // The CLI owns the prompt, and focuses a session already open rather than
  // starting a second one.
  function openAgent() {
    Quickshell.execDetached(["/usr/bin/bash", root.cli, "open-agent"])
  }

  function openReadme() {
    Qt.openUrlExternally("https://github.com/mudiam/omarchy-patchwatch#track-a-patch")
  }

  Process {
    id: ackProc
    onExited: root.refresh()
  }

  Process { id: copyProc }

  // Both actions re-run the check to find the key, so they get the same
  // deadline as a check.
  Timer {
    id: actionDeadline
    interval: root.deadline
    onTriggered: {
      if (ackProc.running) root.stop(ackProc)
      if (copyProc.running) root.stop(copyProc)
    }
  }

  Component.onDestruction: {
    if (checkProc.running) checkProc.signal(15)
    if (ackProc.running) ackProc.signal(15)
    if (copyProc.running) copyProc.signal(15)
  }
}
