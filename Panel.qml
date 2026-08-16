import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "OtoruModel.js" as Otoru

Panel {
  id: root
  moduleName: "ussego.otoru"
  ipcTarget: "ussego.otoru"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  readonly property string home: Quickshell.env("HOME")
  readonly property string pluginDir: home + "/.config/omarchy/plugins/ussego.otoru"
  readonly property string settingsPath: home + "/.config/omarchy/ussego.otoru.json"
  readonly property string notifyScript: pluginDir + "/notify-done.sh"

  function open() {
    root.openedFromHotkey = false
    root.controller.show()
    root.onOpened()
  }

  function openFromHotkey() {
    root.openedFromHotkey = true
    root.controller.show()
    root.onOpened()
  }

  function close() {
    root.controller.hide()
  }

  function toggle() {
    root.opened ? root.close() : root.openFromHotkey()
  }

  function closeForPopoutSwitch() {
    root.popoutSwitchClosing = true
    root.close()
    Qt.callLater(function() { root.popoutSwitchClosing = false })
  }

  property bool openedFromHotkey: false
  property bool popoutSwitchClosing: false

  // ------------------------------------------------------------------
  // Settings
  // ------------------------------------------------------------------

  function defaultSettings() {
    return {
      downloadDir: home + "/Downloads",
      autoClipboard: true,
      audioFormat: "best",
      quality: "best",
      advancedVisible: false,
      outputTemplate: "%(title)s.%(ext)s",
      cookies: "",
      cookiesFromBrowser: "",
      cookiesProfile: "",
      proxy: "",
      rateLimit: "",
      concurrentFragments: "",
      customFormatSelector: "",
      customArgs: ""
    }
  }

  property bool settingsLoaded: false

  Component.onCompleted: {
    if (!root.settingsLoaded) {
      root.settings = root.defaultSettings()
      root.settingsLoaded = true
    }
    settingsFile.reload()
  }

  FileView {
    id: settingsFile
    path: root.settingsPath
    watchChanges: false
    atomicWrites: true
    printErrors: false
    onLoaded: root.loadSettings(text())
    onLoadFailed: root.loadSettings("")
  }

  Timer {
    id: settingsSaveTimer
    interval: 200
    repeat: false
    onTriggered: root.flushSettings()
  }

  function scheduleSettingsSave() {
    if (!root.settingsLoaded) return
    settingsSaveTimer.restart()
  }

  function loadSettings(raw) {
    var next = root.defaultSettings()
    try {
      var parsed = JSON.parse(String(raw || "{}"))
      for (var key in next) {
        if (parsed[key] !== undefined && parsed[key] !== null) next[key] = parsed[key]
      }
    } catch (e) { }
    root.settings = next
    root.settingsLoaded = true
  }

  function flushSettings() {
    settingsFile.setText(JSON.stringify(root.settings, null, 2) + "\n")
  }

  function setSetting(key, value) {
    if (root.settings[key] === value) return
    var next = {}
    for (var k in root.settings) next[k] = root.settings[k]
    next[key] = value
    root.settings = next
    root.scheduleSettingsSave()
  }

  IpcHandler {
    target: root.ipcTarget

    function open() { root.openFromHotkey() }
    function close() { root.close() }
    function show() { root.openFromHotkey() }
    function hide() { root.close() }
    function toggle() { root.toggle() }

    function extract(url: string): string {
      if (url) root.currentUrl = url
      if (!Otoru.looksLikeUrl(root.currentUrl)) return "error: invalid URL"
      root.openFromHotkey()
      root.startExtraction()
      return "extracting"
    }

    function download(): string {
      if (!root.mediaInfo) return "error: no media information"
      root.startDownload()
      return "downloading"
    }

    function cancel(): string { root.cancelActive(); return "ok" }
    function retry(): string { root.retryWithWebClient(); return "ok" }
    function clear(): string { root.clearActive(); root.resetInput(); return "ok" }
    function refresh(): string { root.detectTools(); return "ok" }
    function status(): string { return root.activeStatus || "idle" }
    function progress(): string { return root.activeProgressPercent || "" }
  }

  // ------------------------------------------------------------------
  // Lifecycle
  // ------------------------------------------------------------------

  function onOpened() {
    root.detectTools()
    root.errorMessage = ""
    if (root.settingsLoaded) {
      Qt.callLater(function() {
        if (urlField) {
          urlField.forceActiveFocus()
          urlField.selectAll()
        }
        if (root.setting("autoClipboard", false)) root.readClipboard()
      })
    }
  }

  function detectTools() {
    if (!ytDlpVersionProc.running) ytDlpVersionProc.running = true
    if (!ffmpegVersionProc.running) ffmpegVersionProc.running = true
  }

  // ------------------------------------------------------------------
  // Tool detection
  // ------------------------------------------------------------------

  property string ytDlpVersion: ""
  property bool ytDlpOk: false
  property string ffmpegVersion: ""
  property bool ffmpegOk: false

  Process {
    id: ytDlpVersionProc
    command: Otoru.versionCommand()
    stdout: SplitParser {
      onRead: function(data) { root.ytDlpVersion = String(data).trim() }
    }
    onExited: function(exitCode) {
      root.ytDlpOk = exitCode === 0 && root.ytDlpVersion !== ""
    }
  }

  Process {
    id: ffmpegVersionProc
    command: Otoru.ffmpegVersionCommand()
    stdout: SplitParser {
      onRead: function(data) {
        if (root.ffmpegVersion !== "") return
        var line = String(data).trim()
        if (line) root.ffmpegVersion = line.split(" ")[2] || line
      }
    }
    onExited: function(exitCode) {
      root.ffmpegOk = exitCode === 0 && root.ffmpegVersion !== ""
    }
  }

  // ------------------------------------------------------------------
  // Clipboard
  // ------------------------------------------------------------------

  function readClipboard() {
    if (clipProc.running) return
    if (root.currentUrl !== "") return
    clipProc.running = true
  }

  Process {
    id: clipProc
    command: Otoru.clipCommand()
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var text = String(this.text || "").trim()
        if (Otoru.looksLikeUrl(text) && !root.isKnownUrl(text)) {
          root.currentUrl = text
          root.startExtraction()
        }
      }
    }
  }

  // ------------------------------------------------------------------
  // URL / extraction
  // ------------------------------------------------------------------

  property string currentUrl: ""
  onCurrentUrlChanged: root.useWebClient = false
  property var mediaInfo: null
  property bool useWebClient: false
  readonly property bool canRetryAsWebClient: root.activeStatus === "error" && !root.useWebClient &&
    /403|forbidden|access denied|sign in|unable to download|blocked|geo/i.test(root.activeError || root.errorMessage || "")
  property bool extracting: false
  property string errorMessage: ""
  property string rawLog: ""
  property bool showRawLog: false

  function appendRawLog(data) {
    var line = String(data || "")
    if (!line) return
    root.rawLog += line + "\n"
    if (root.activeJob) root.activeJob.log = (root.activeJob.log || "") + line + "\n"
  }

  // URLs successfully downloaded this session. Prevents auto-clipboard from
  // pasting the same link again after the user has already downloaded it.
  property var history: []

  function rememberUrl(url) {
    var u = String(url).trim()
    if (!u || root.history.indexOf(u) >= 0) return
    var next = root.history.slice()
    next.push(u)
    if (next.length > 50) next = next.slice(-50)
    root.history = next
  }

  function isKnownUrl(url) {
    return root.history.indexOf(String(url).trim()) >= 0
  }

  function startExtraction() {
    var url = String(root.currentUrl).trim()
    if (!Otoru.looksLikeUrl(url)) {
      root.errorMessage = "Invalid URL."
      return
    }
    root.extracting = true
    root.mediaInfo = null
    root.errorMessage = ""
    root.rawLog = ""
    root.downloadMode = "best"
    root.videoQuality = "best"
    root.audioFormat = String(root.setting("audioFormat", "best") || "best")
    infoProc.command = Otoru.infoCommand(url, root.setting("proxy", ""), root.useWebClient, root.settings, root.home)
    infoProc.running = true
  }

  Process {
    id: infoProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var raw = String(this.text || "").trim()
        root.handleInfo(raw)
      }
    }
    stderr: SplitParser {
      onRead: function(data) { root.rawLog += data + "\n" }
    }
    onExited: function(exitCode, exitStatus) {
      root.extracting = false
      if (exitCode !== 0 || exitStatus !== 0) {
        root.errorMessage = Otoru.friendlyError(root.rawLog, exitCode, exitStatus)
      }
    }
  }

  function handleInfo(raw) {
    var info = Otoru.parseInfo(raw)
    if (!info) {
      root.errorMessage = "Could not parse media information."
      return
    }
    root.mediaInfo = info
    root.availableQualities = Otoru.availableVideoQualities(info.maxHeight)
    if (!info.hasAudio && root.downloadMode === "audio") root.downloadMode = "best"
    if (root.availableQualities.indexOf(root.videoQuality) < 0) root.videoQuality = "best"
    Qt.callLater(function() { if (downloadButton) downloadButton.forceActiveFocus() })
  }

  // ------------------------------------------------------------------
  // Download modes and state
  // ------------------------------------------------------------------

  property string downloadMode: "best"
  property string videoQuality: "best"
  property string audioFormat: "best"
  property var availableQualities: []

  ListModel { id: queueModel }

  property var activeJob: null
  property string activeTitle: ""
  property string activeStatus: ""
  property string activeProgressPercent: ""
  property real activeProgressPercentValue: 0
  property string activeProgressSize: ""
  property string activeProgressSpeed: ""
  property string activeProgressEta: ""
  property string activeError: ""
  property string activeOutputPath: ""
  property string activeOutputDir: ""

  function makeJob() {
    return {
      url: String(root.currentUrl).trim(),
      title: root.mediaInfo ? root.mediaInfo.title : "",
      mode: root.downloadMode,
      quality: root.videoQuality,
      audioFormat: root.audioFormat,
      info: root.mediaInfo
    }
  }

  function startDownload() {
    if (!root.mediaInfo && !Otoru.looksLikeUrl(root.currentUrl)) {
      root.errorMessage = "Enter a URL first."
      return
    }
    if (root.activeStatus === "downloading") {
      queueModel.append(root.makeJob())
      root.resetInput()
      return
    }
    root.startJob(root.makeJob())
  }

  function enqueueCurrent() {
    if (!root.mediaInfo) return
    queueModel.append(root.makeJob())
    root.resetInput()
  }

  function startJob(job) {
    root.activeJob = job
    root.activeTitle = job.title || "Downloading"
    root.activeStatus = "preparing"
    root.activeProgressPercent = ""
    root.activeProgressPercentValue = 0
    root.activeProgressSize = ""
    root.activeProgressSpeed = ""
    root.activeProgressEta = ""
    root.activeError = ""
    root.activeOutputPath = ""
    root.activeOutputDir = ""
    mkdirProc.command = Otoru.mkdirCommand(root.setting("downloadDir", ""), root.home)
    mkdirProc.running = true
  }

  Process {
    id: mkdirProc
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        root.activeStatus = "error"
        root.activeError = "Could not create download directory."
        root.notifyError()
        return
      }
      root.beginDownload()
    }
  }

  function beginDownload() {
    if (!root.activeJob) return
    downloadProc.command = Otoru.buildDownloadArgs(root.activeJob, root.settings, root.home, root.useWebClient)
    downloadProc.running = true
    root.activeStatus = "downloading"
  }

  Process {
    id: downloadProc
    // yt-dlp progress is merged into stdout by the sh wrapper in buildDownloadArgs.
    stdout: SplitParser {
      onRead: function(data) {
        var p = Otoru.parseProgressLine(data)
        if (p) {
          root.activeProgressPercent = p.percentText
          root.activeProgressPercentValue = p.percent
          root.activeProgressSize = p.sizeText
          root.activeProgressSpeed = p.speed
          root.activeProgressEta = p.eta
        } else {
          root.appendRawLog(data)
        }
      }
    }
    onExited: function(exitCode, exitStatus) {
      root.handleDownloadFinished(exitCode, exitStatus)
    }
  }

  function handleDownloadFinished(exitCode, exitStatus) {
    var job = root.activeJob
    if (!job) return

    if (exitCode !== 0 || exitStatus !== 0) {
      if (exitStatus !== 0) {
        root.activeStatus = "cancelled"
      } else {
        root.activeStatus = "error"
        root.activeError = Otoru.friendlyError(job.log || "", exitCode, exitStatus)
        root.errorMessage = root.activeError
        root.notifyError()
      }
    } else {
      root.activeStatus = "completed"
      root.activeOutputPath = Otoru.guessOutputPath(root.settings, job, job.info, root.home)
      root.activeOutputDir = Otoru.expandHome(root.setting("downloadDir", ""), root.home)
      root.activeProgressPercent = "100%"
      root.activeProgressPercentValue = 100
      root.activeProgressSpeed = ""
      root.activeProgressEta = ""
      root.rememberUrl(job.url)
      root.notifyComplete()
    }

    root.activeJob = null
    Qt.callLater(root.processQueue)
  }

  function processQueue() {
    if (root.activeStatus === "downloading" || queueModel.count === 0) return
    var queued = queueModel.get(0)
    // Copy the roles out before removing the item. Keeping a reference to a
    // ListModel element after it has been removed can cause crashes when the
    // download process later writes to job.log.
    var job = {
      url: queued.url,
      title: queued.title,
      mode: queued.mode,
      quality: queued.quality,
      audioFormat: queued.audioFormat,
      info: queued.info
    }
    queueModel.remove(0)
    root.startJob(job)
  }

  function cancelActive() {
    if (downloadProc.running) downloadProc.running = false
  }

  function removeQueued(index) {
    if (index >= 0 && index < queueModel.count) queueModel.remove(index)
  }

  function resetInput() {
    root.currentUrl = ""
    if (urlField) urlField.text = ""
    root.mediaInfo = null
    root.downloadMode = "best"
    root.videoQuality = "best"
    root.audioFormat = String(root.setting("audioFormat", "best") || "best")
    root.errorMessage = ""
    Qt.callLater(function() { if (urlField) urlField.forceActiveFocus() })
  }

  function clearActive() {
    root.activeStatus = ""
    root.activeTitle = ""
    root.activeProgressPercent = ""
    root.activeProgressPercentValue = 0
    root.activeProgressSize = ""
    root.activeProgressSpeed = ""
    root.activeProgressEta = ""
    root.activeError = ""
    root.activeOutputPath = ""
    root.activeOutputDir = ""
  }

  function retryWithWebClient() {
    root.useWebClient = true
    root.errorMessage = ""
    root.activeError = ""
    if (root.mediaInfo) root.startDownload()
    else if (Otoru.looksLikeUrl(root.currentUrl)) root.startExtraction()
  }

  function openFolder(path) {
    if (!path) return
    Quickshell.execDetached(["uwsm-app", "--", "nautilus", "--new-window", path])
  }

  // ------------------------------------------------------------------
  // Notifications
  // ------------------------------------------------------------------

  function notifyComplete() {
    var title = root.activeTitle || "Download complete"
    var body = "Saved to " + root.setting("downloadDir", "")
    var folder = Otoru.expandHome(root.setting("downloadDir", ""), root.home)
    notifyProc.command = [root.notifyScript, title, body, folder]
    notifyProc.running = true
  }

  function notifyError() {
    var title = root.activeTitle || "Download failed"
    var body = String(root.activeError || root.errorMessage || "Unknown error")
    notifyProc.command = ["/usr/share/omarchy/bin/omarchy-notification-send", "-a", "otoru", "-i", "dialog-error", "-u", "normal", title, body]
    notifyProc.running = true
  }

  Process { id: notifyProc }

  // ------------------------------------------------------------------
  // UI helpers
  // ------------------------------------------------------------------

  function modeButtonLabel(mode) {
    if (mode === "best") return "Best Quality"
    if (mode === "video") return "Video"
    if (mode === "audio") return "Audio"
    if (mode === "custom") return "Custom"
    return mode
  }

  function percentValue(text) {
    var n = parseFloat(String(text).replace("%", ""))
    return isNaN(n) ? 0 : Math.max(0, Math.min(100, n))
  }

  function anyFieldFocused() {
    return urlField.activeFocus ||
           downloadDirField.activeFocus ||
           outputTemplateField.activeFocus ||
           cookiesField.activeFocus ||
           proxyField.activeFocus ||
           rateLimitField.activeFocus ||
           concurrentFragmentsField.activeFocus ||
           customFormatField.activeFocus ||
           customArgsField.activeFocus
  }

  // ------------------------------------------------------------------
  // Panel UI
  // ------------------------------------------------------------------

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: false
    focusTarget: urlField
    contentWidth: panel.fittedContentWidth(Style.space(420))
    contentHeight: panel.fittedContentHeight(contentColumn.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: root.anyFieldFocused()
      onReturnRequested: {
        if (root.mediaInfo && root.activeStatus !== "downloading") root.startDownload()
        else if (!root.mediaInfo && !root.extracting) root.startExtraction()
      }
      onCloseRequested: root.close()
    }

    Flickable {
      id: scroller
      anchors.fill: parent
      contentWidth: width
      contentHeight: contentColumn.implicitHeight
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      interactive: contentHeight > height

      Column {
        id: contentColumn
        width: scroller.width
        spacing: Style.space(12)

        // Header
        Row {
          spacing: Style.space(8)

          Text {
            text: "\uf019"
            color: root.bar ? root.bar.foreground : Color.foreground
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.title
            anchors.verticalCenter: parent.verticalCenter
          }

          Text {
            text: "otoru"
            color: root.bar ? root.bar.foreground : Color.foreground
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.title
            font.bold: true
            anchors.verticalCenter: parent.verticalCenter
          }
        }

        // Error banner
        Rectangle {
          visible: root.errorMessage !== ""
          width: parent.width
          height: errorColumn.implicitHeight + Style.space(16)
          radius: Style.cornerRadius
          color: Util.alpha(Color.urgent, 0.12)
          border.color: Util.alpha(Color.urgent, 0.35)
          border.width: Style.normalBorderWidth

          Column {
            id: errorColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: Style.space(12)
            anchors.rightMargin: Style.space(12)
            spacing: Style.space(6)

            Text {
              width: parent.width
              text: root.errorMessage
              color: Color.urgent
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.body
              wrapMode: Text.WordWrap
            }

            Button {
              visible: root.rawLog !== ""
              text: root.showRawLog ? "Hide raw log" : "View raw log"
              focusable: true
              fontSize: Style.font.bodySmall
              onClicked: root.showRawLog = !root.showRawLog
            }
          }
        }

        // Raw log view
        Rectangle {
          visible: root.showRawLog && root.rawLog !== ""
          width: parent.width
          height: Math.min(Style.space(160), rawLogText.implicitHeight + Style.space(16))
          radius: Style.cornerRadius
          color: Util.alpha(root.bar ? root.bar.foreground : Color.foreground, 0.06)
          clip: true

          Text {
            id: rawLogText
            anchors.fill: parent
            anchors.margins: Style.space(8)
            text: root.rawLog
            color: root.bar ? root.bar.foreground : Color.foreground
            font.family: "monospace"
            font.pixelSize: Style.font.caption
            wrapMode: Text.WrapAnywhere
            elide: Text.ElideNone
          }
        }

        // URL input
        TextField {
          id: urlField
          width: parent.width
          placeholderText: "Paste a media URL…"
          text: root.currentUrl
          onTextChanged: root.currentUrl = text
          onAccepted: root.startExtraction()

          Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
              root.close()
              event.accepted = true
            }
          }
        }

        // Extracting state
        Text {
          id: extractingLabel
          visible: root.extracting
          text: "Extracting media information…"
          color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.5)
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.body

          SequentialAnimation {
            running: root.extracting
            loops: Animation.Infinite
            onRunningChanged: if (!running && extractingLabel) extractingLabel.opacity = 1.0
            NumberAnimation { target: extractingLabel; property: "opacity"; to: 0.45; duration: 600; easing.type: Easing.InOutQuad }
            NumberAnimation { target: extractingLabel; property: "opacity"; to: 1.0; duration: 600; easing.type: Easing.InOutQuad }
          }
        }

        // Metadata
        Rectangle {
          visible: root.mediaInfo !== null
          width: parent.width
          height: metadataRow.implicitHeight + Style.space(16)
          radius: Style.cornerRadius
          color: Util.alpha(root.bar ? root.bar.foreground : Color.foreground, 0.06)

          Row {
            id: metadataRow
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: Style.space(12)
            anchors.rightMargin: Style.space(12)
            spacing: Style.space(12)

            Rectangle {
              visible: root.mediaInfo && root.mediaInfo.thumbnail !== ""
              width: Style.space(96)
              height: Style.space(72)
              radius: Style.cornerRadius
              color: Util.alpha(root.bar ? root.bar.foreground : Color.foreground, 0.1)
              clip: true

              Image {
                anchors.fill: parent
                source: root.mediaInfo ? root.mediaInfo.thumbnail : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
              }
            }

            Column {
              width: parent.width - (thumbnailPlaceholder.visible ? Style.space(96) + Style.space(12) : 0)
              spacing: Style.space(4)
              anchors.verticalCenter: parent.verticalCenter

              Text {
                width: parent.width
                text: root.mediaInfo ? root.mediaInfo.title : ""
                color: root.bar ? root.bar.foreground : Color.foreground
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.body
                font.bold: true
                elide: Text.ElideRight
              }

              Text {
                visible: root.mediaInfo && root.mediaInfo.uploader !== ""
                width: parent.width
                text: root.mediaInfo ? root.mediaInfo.uploader : ""
                color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.5)
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.bodySmall
                elide: Text.ElideRight
              }

              Text {
                visible: root.mediaInfo && root.mediaInfo.duration > 0
                text: root.mediaInfo ? Otoru.formatDuration(root.mediaInfo.duration) : ""
                color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.5)
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.bodySmall
              }
            }

            Item { id: thumbnailPlaceholder; visible: !root.mediaInfo || root.mediaInfo.thumbnail === ""; width: 0; height: 0 }
          }
        }

        // Mode selector
        Column {
          visible: root.mediaInfo !== null
          width: parent.width
          spacing: Style.space(8)

          Text {
            text: "Mode"
            color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.5)
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.caption
            font.bold: true
          }

          Row {
            spacing: Style.space(6)

            Repeater {
              model: ["best", "video", "audio", "custom"]

              Button {
                required property string modelData
                text: root.modeButtonLabel(modelData)
                selected: root.downloadMode === modelData
                focusable: true
                fontSize: Style.font.bodySmall
                onClicked: root.downloadMode = modelData
              }
            }
          }

          // Video qualities
          Row {
            visible: root.downloadMode === "video" && root.availableQualities.length > 0
            spacing: Style.space(6)

            Button {
              text: "Best"
              selected: root.videoQuality === "best"
              focusable: true
              fontSize: Style.font.bodySmall
              onClicked: root.videoQuality = "best"
            }

            Repeater {
              model: root.availableQualities

              Button {
                required property string modelData
                text: modelData + "p"
                selected: root.videoQuality === modelData
                focusable: true
                fontSize: Style.font.bodySmall
                onClicked: root.videoQuality = modelData
              }
            }
          }

          // Audio format
          Row {
            visible: root.downloadMode === "audio"
            spacing: Style.space(6)

            Repeater {
              model: ["best", "mp3", "opus", "m4a"]

              Button {
                required property string modelData
                text: modelData === "best" ? "Best" : modelData.toUpperCase()
                selected: root.audioFormat === modelData
                focusable: true
                fontSize: Style.font.bodySmall
                onClicked: root.audioFormat = modelData
              }
            }
          }

          // Custom format selector
          TextField {
            id: customFormatField
            visible: root.downloadMode === "custom"
            width: parent.width
            placeholderText: "yt-dlp format selector (e.g. bestvideo[height<=1080]+bestaudio)"
            text: root.setting("customFormatSelector", "")
            onTextChanged: root.setSetting("customFormatSelector", text)

            Keys.onPressed: function(event) {
              if (event.key === Qt.Key_Escape) {
                keyCatcher.forceActiveFocus()
                event.accepted = true
              }
            }
          }
        }

        // Download location
        Column {
          width: parent.width
          spacing: Style.space(4)

          Text {
            text: "Save to"
            color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.5)
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.caption
            font.bold: true
          }

          TextField {
            id: downloadDirField
            width: parent.width
            text: root.setting("downloadDir", "")
            placeholderText: "~/Downloads"
            onEditingFinished: root.setSetting("downloadDir", text)

            Keys.onPressed: function(event) {
              if (event.key === Qt.Key_Escape) {
                keyCatcher.forceActiveFocus()
                event.accepted = true
              }
            }
          }
        }

        // Auto-clipboard toggle
        Toggle {
          width: parent.width
          label: "Read URL from clipboard"
          description: "Automatically paste a URL when opening otoru"
          checked: root.setting("autoClipboard", false)
          foreground: root.bar ? root.bar.foreground : Color.foreground
          onClicked: root.setSetting("autoClipboard", !root.setting("autoClipboard", false))
        }

        // Advanced section
        Button {
          text: root.setting("advancedVisible", false) ? "Hide advanced" : "Advanced"
          focusable: true
          fontSize: Style.font.bodySmall
          bordered: true
          onClicked: root.setSetting("advancedVisible", !root.setting("advancedVisible", false))
        }

        Column {
          visible: root.setting("advancedVisible", false)
          width: parent.width
          spacing: Style.space(10)

          TextField {
            id: outputTemplateField
            width: parent.width
            placeholderText: "Output template (default: %(title)s.%(ext)s)"
            text: root.setting("outputTemplate", "")
            onEditingFinished: root.setSetting("outputTemplate", text)
            Keys.onPressed: function(event) {
              if (event.key === Qt.Key_Escape) { keyCatcher.forceActiveFocus(); event.accepted = true }
            }
          }

          Dropdown {
            id: cookiesFromBrowserDropdown
            width: parent.width
            label: "Cookies from browser"
            foreground: root.bar ? root.bar.foreground : Color.foreground
            background: root.bar ? root.bar.background : Color.background
            popupBorder: root.bar ? root.bar.foreground : Color.foreground
            value: root.setting("cookiesFromBrowser", "")
            options: [
              { value: "", label: "None" },
              { value: "brave", label: "Brave" },
              { value: "chrome", label: "Chrome" },
              { value: "chromium", label: "Chromium" },
              { value: "edge", label: "Edge" },
              { value: "firefox", label: "Firefox" },
              { value: "opera", label: "Opera" },
              { value: "safari", label: "Safari" },
              { value: "vivaldi", label: "Vivaldi" },
              { value: "whale", label: "Whale" }
            ]
            onChanged: function(value) { root.setSetting("cookiesFromBrowser", value) }
          }

          TextField {
            id: cookiesProfileField
            width: parent.width
            visible: root.setting("cookiesFromBrowser", "") !== ""
            placeholderText: "Profile name or full config path (optional)"
            text: root.setting("cookiesProfile", "")
            onEditingFinished: root.setSetting("cookiesProfile", text)
            Keys.onPressed: function(event) {
              if (event.key === Qt.Key_Escape) { keyCatcher.forceActiveFocus(); event.accepted = true }
            }
          }

          TextField {
            id: cookiesField
            width: parent.width
            placeholderText: "Cookies file path (Netscape format)"
            text: root.setting("cookies", "")
            onEditingFinished: root.setSetting("cookies", text)
            Keys.onPressed: function(event) {
              if (event.key === Qt.Key_Escape) { keyCatcher.forceActiveFocus(); event.accepted = true }
            }
          }

          TextField {
            id: proxyField
            width: parent.width
            placeholderText: "Proxy URL"
            text: root.setting("proxy", "")
            onEditingFinished: root.setSetting("proxy", text)
            Keys.onPressed: function(event) {
              if (event.key === Qt.Key_Escape) { keyCatcher.forceActiveFocus(); event.accepted = true }
            }
          }

          Row {
            spacing: Style.space(8)
            width: parent.width

            TextField {
              id: rateLimitField
              width: (parent.width - parent.spacing) / 2
              placeholderText: "Rate limit"
              text: root.setting("rateLimit", "")
              onEditingFinished: root.setSetting("rateLimit", text)
              Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Escape) { keyCatcher.forceActiveFocus(); event.accepted = true }
              }
            }

            TextField {
              id: concurrentFragmentsField
              width: (parent.width - parent.spacing) / 2
              placeholderText: "Concurrent fragments"
              text: root.setting("concurrentFragments", "")
              onEditingFinished: root.setSetting("concurrentFragments", text)
              Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Escape) { keyCatcher.forceActiveFocus(); event.accepted = true }
              }
            }
          }

          TextField {
            id: customArgsField
            width: parent.width
            placeholderText: "Extra yt-dlp arguments (space separated)"
            text: root.setting("customArgs", "")
            onEditingFinished: root.setSetting("customArgs", text)
            Keys.onPressed: function(event) {
              if (event.key === Qt.Key_Escape) { keyCatcher.forceActiveFocus(); event.accepted = true }
            }
          }
        }

        // Active / completed download
        Rectangle {
          visible: root.activeStatus !== ""
          width: parent.width
          height: activeColumn.implicitHeight + Style.space(20)
          radius: Style.cornerRadius
          color: Util.alpha(root.bar ? root.bar.foreground : Color.foreground, 0.06)

          Column {
            id: activeColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: Style.space(12)
            anchors.rightMargin: Style.space(12)
            spacing: Style.space(10)

            Text {
              width: parent.width
              text: root.activeStatus === "downloading" ? "Downloading" :
                    root.activeStatus === "completed" ? "Finished" :
                    root.activeStatus === "error" ? "Error" :
                    root.activeStatus === "cancelled" ? "Cancelled" : "Preparing"
              color: root.bar ? root.bar.foreground : Color.foreground
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.body
              font.bold: true
            }

            Text {
              visible: root.activeTitle !== ""
              width: parent.width
              text: root.activeTitle
              color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.3)
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.bodySmall
              elide: Text.ElideRight
            }

            // Progress bar
            Rectangle {
              visible: root.activeStatus === "downloading" || root.activeStatus === "completed"
              width: parent.width
              height: Style.space(10)
              radius: Style.cornerRadius
              color: Util.alpha(root.bar ? root.bar.foreground : Color.foreground, 0.12)

              Rectangle {
                width: parent.width * (root.activeProgressPercentValue / 100)
                height: parent.height
                radius: parent.radius
                color: Color.accent

                Behavior on width { NumberAnimation { duration: 50; easing.type: Easing.Linear } }
              }
            }

            Text {
              visible: root.activeProgressPercent !== ""
              text: root.activeProgressPercent
              color: root.bar ? root.bar.foreground : Color.foreground
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.body
              font.bold: true
            }

            Text {
              visible: root.activeProgressSize !== "" || root.activeProgressSpeed !== ""
              text: [
                root.activeProgressSize,
                root.activeProgressSpeed,
                root.activeProgressEta ? "· " + root.activeProgressEta + " remaining" : ""
              ].filter(Boolean).join(" ")
              color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.5)
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.bodySmall
            }

            Text {
              visible: root.activeStatus === "error" && root.activeError !== ""
              width: parent.width
              text: root.activeError
              color: Color.urgent
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.bodySmall
              wrapMode: Text.WordWrap
            }

            Button {
              visible: root.canRetryAsWebClient
              text: "Retry as web client"
              focusable: true
              fontSize: Style.font.bodySmall
              bordered: true
              onClicked: root.retryWithWebClient()
            }

            Text {
              visible: root.activeStatus === "completed" && root.activeOutputPath !== ""
              width: parent.width
              text: root.activeOutputPath
              color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.5)
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.bodySmall
              elide: Text.ElideRight
            }

            Row {
              spacing: Style.space(8)

              Button {
                visible: root.activeStatus === "downloading"
                text: "Cancel"
                focusable: true
                fontSize: Style.font.bodySmall
                onClicked: root.cancelActive()
              }

              Button {
                visible: root.activeStatus === "completed" && root.activeOutputDir !== ""
                text: "Open folder"
                focusable: true
                fontSize: Style.font.bodySmall
                onClicked: root.openFolder(root.activeOutputDir)
              }

              Button {
                visible: root.activeStatus !== "downloading"
                text: "Clear"
                focusable: true
                fontSize: Style.font.bodySmall
                onClicked: root.clearActive()
              }
            }
          }
        }

        // Queue
        Column {
          visible: queueModel.count > 0
          width: parent.width
          spacing: Style.space(8)

          Text {
            text: "Queue"
            color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.5)
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.caption
            font.bold: true
          }

          Repeater {
            model: queueModel

            Rectangle {
              required property int index
              required property string url
              required property string title
              required property string mode

              width: parent.width
              height: queueRow.implicitHeight + Style.space(12)
              radius: Style.cornerRadius
              color: Util.alpha(root.bar ? root.bar.foreground : Color.foreground, 0.06)

              Row {
                id: queueRow
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Style.space(10)
                anchors.rightMargin: Style.space(10)
                spacing: Style.space(8)

                Column {
                  width: parent.width - removeButton.width - parent.spacing
                  spacing: Style.space(2)
                  anchors.verticalCenter: parent.verticalCenter

                  Text {
                    width: parent.width
                    text: title || url
                    color: root.bar ? root.bar.foreground : Color.foreground
                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                    font.pixelSize: Style.font.bodySmall
                    elide: Text.ElideRight
                  }

                  Text {
                    width: parent.width
                    text: mode
                    color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.6)
                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                    font.pixelSize: Style.font.caption
                  }
                }

                Button {
                  id: removeButton
                  text: "✕"
                  focusable: true
                  fontSize: Style.font.bodySmall
                  anchors.verticalCenter: parent.verticalCenter
                  onClicked: root.removeQueued(index)
                }
              }
            }
          }
        }

        // Actions
        Row {
          spacing: Style.space(8)
          visible: !root.extracting

          Button {
            id: extractButton
            visible: root.mediaInfo === null && root.activeStatus !== "downloading"
            text: "Extract"
            focusable: true
            active: true
            onClicked: root.startExtraction()
          }

          Button {
            id: downloadButton
            visible: root.mediaInfo !== null && root.activeStatus !== "downloading"
            text: "Download"
            focusable: true
            active: true
            onClicked: root.startDownload()
          }

          Button {
            visible: root.mediaInfo !== null && root.activeStatus !== "downloading"
            text: "+ Queue"
            focusable: true
            onClicked: root.enqueueCurrent()
          }
        }
      }
    }
  }
}
