import QtQuick
import Quickshell.Io

// Single-line text field that never lets Qt read the Wayland clipboard itself.
//
// Qt's TextInput calls mimeData()->text() on every clipboard change while it is
// editable, and its native paste path buffers the whole foreign offer with no
// byte limit or deadline. TextEdit only inspects offered MIME types, so this
// wraps a single-line TextEdit, swallows every native paste/drop gesture and
// reads clipboard text through a bounded wl-paste helper instead.
FocusScope {
  id: root

  property alias text: edit.text
  property alias font: edit.font
  property alias color: edit.color
  property alias selectByMouse: edit.selectByMouse
  property alias horizontalAlignment: edit.horizontalAlignment
  property alias verticalAlignment: edit.verticalAlignment
  property alias inputMethodHints: edit.inputMethodHints
  property alias cursorPosition: edit.cursorPosition
  property int maximumLength: 2048
  property bool digitsOnly: false
  property bool pasteEnabled: true

  readonly property int maxPasteBytes: 16384
  readonly property int pasteTimeoutMs: 2000

  signal accepted()
  signal editingFinished()

  property bool _sanitizing: false
  property string _pasteBaseText: ""
  property int _pasteSelectionStart: 0
  property int _pasteSelectionEnd: 0

  function sanitize(value) {
    var out = String(value || "").replace(/[\r\n\u2028\u2029]+/g, " ")
    if (root.digitsOnly) out = out.replace(/[^0-9]/g, "")
    return out
  }

  function requestPaste(primary) {
    if (!root.pasteEnabled || pasteProcess.running) return
    root._pasteBaseText = edit.text
    root._pasteSelectionStart = edit.selectionStart
    root._pasteSelectionEnd = edit.selectionEnd
    pasteProcess.command = [
      "bash", "-c",
      "set -o pipefail; timeout -s KILL 2 wl-paste \"$@\" --no-newline --type text 2>/dev/null | head -c " + (root.maxPasteBytes + 1),
      "omarchy-rss-paste"
    ].concat(primary ? ["--primary"] : [])
    pasteProcess.running = true
    pasteDeadline.restart()
  }

  function finishPaste(exitCode) {
    pasteDeadline.stop()
    // Drop stale results: the field changed or lost focus while reading.
    if (exitCode !== 0 || edit.text !== root._pasteBaseText || !edit.activeFocus) return
    var data = pasteStdout.data
    var bytes = data && data.byteLength !== undefined ? data.byteLength : pasteStdout.text.length
    if (bytes > root.maxPasteBytes) return
    var insertText = root.sanitize(pasteStdout.text)
    var start = Math.min(root._pasteSelectionStart, root._pasteSelectionEnd)
    var end = Math.max(root._pasteSelectionStart, root._pasteSelectionEnd)
    var room = root.maximumLength - (edit.length - (end - start))
    if (room <= 0) return
    insertText = insertText.slice(0, room)
    if (!insertText) return
    if (end > start) edit.remove(start, end)
    edit.insert(start, insertText)
    edit.cursorPosition = start + insertText.length
  }

  function isPasteKey(event) {
    if (event.matches(StandardKey.Paste) || event.key === Qt.Key_Paste) return true
    var mods = event.modifiers
    if (event.key === Qt.Key_V && (mods & (Qt.ControlModifier | Qt.MetaModifier))) return true
    if (event.key === Qt.Key_Insert && (mods & Qt.ShiftModifier)) return true
    return false
  }

  function ensureCursorVisible() {
    var r = edit.cursorRectangle
    var x = edit.x
    if (r.x + x < 0) x = -r.x
    else if (r.x + r.width + x > root.width) x = root.width - r.x - r.width
    edit.x = Math.max(Math.min(0, x), root.width - edit.width)
  }

  implicitWidth: edit.implicitWidth
  implicitHeight: edit.implicitHeight
  clip: true

  TextEdit {
    id: edit
    focus: true
    y: 0
    width: Math.max(root.width, implicitWidth + 2)
    height: root.height
    wrapMode: TextEdit.NoWrap
    textFormat: TextEdit.PlainText
    persistentSelection: false

    onCursorRectangleChanged: root.ensureCursorVisible()
    onWidthChanged: root.ensureCursorVisible()
    onEditingFinished: root.editingFinished()

    onTextChanged: {
      if (root._sanitizing) return
      var clean = root.sanitize(text).slice(0, root.maximumLength)
      if (clean === text) return
      root._sanitizing = true
      var pos = Math.min(cursorPosition, clean.length)
      text = clean
      cursorPosition = pos
      root._sanitizing = false
    }

    Keys.onPressed: function(event) {
      if (root.isPasteKey(event)) {
        root.requestPaste(false)
        event.accepted = true
      } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
        root.accepted()
        event.accepted = true
      }
    }
  }

  // Middle-click would paste the primary selection natively; route it through
  // the bounded reader. Right-click is swallowed so no native edit menu opens.
  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.MiddleButton | Qt.RightButton
    onPressed: function(mouse) {
      edit.forceActiveFocus()
      mouse.accepted = true
    }
    onClicked: function(mouse) {
      if (mouse.button === Qt.MiddleButton) {
        edit.cursorPosition = edit.positionAt(mouse.x - edit.x, mouse.y - edit.y)
        root.requestPaste(true)
      }
    }
  }

  // Accept and discard drags so TextEdit never reads dropped MIME data.
  DropArea {
    anchors.fill: parent
  }

  Process {
    id: pasteProcess
    stdout: StdioCollector {
      id: pasteStdout
      waitForEnd: true
    }
    onExited: function(exitCode) { root.finishPaste(exitCode) }
  }

  Timer {
    id: pasteDeadline
    interval: root.pasteTimeoutMs + 500
    onTriggered: pasteProcess.running = false
  }
}
