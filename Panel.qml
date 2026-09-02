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

  readonly property color contentForeground: bar ? bar.foreground : Color.foreground
  readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family

  readonly property string home: Quickshell.env("HOME")
  readonly property string pluginDir: home + "/.config/omarchy/plugins/ussego.otoru"
  readonly property string settingsPath: home + "/.config/omarchy/ussego.otoru.json"
  readonly property string notifyScript: pluginDir + "/notify-done.sh"

  property bool popoutSwitchClosing: false

// Settings-list row: default-property children are the expander body.
component OptionRow: Column {
  id: optRow

  property string glyph: ""
  property string label: ""
  property string valueText: ""
  property bool chevron: true
  property bool open: false
  property color fg: Color.foreground
  property string fam: Style.font.family
  property color background: "transparent"
  property bool hasBackground: false

  default property alias expanderContent: expanderSlot.data
  property alias trailing: trailingSlot.data
  signal rowClicked()

  width: parent ? parent.width : 0
  spacing: Style.spacing.lg

  BorderSurface {
    width: parent.width
    height: contentTopInset + optionBody.implicitHeight + contentBottomInset
    radius: Style.cornerRadius
    color: optRow.hasBackground
      ? optRow.background
      : (optRow.open ? Style.normalFillFor(optRow.fg, Color.accent) : "transparent")
    borderSpec: Border.none()

    Column {
      id: optionBody
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.topMargin: parent.contentTopInset
      anchors.leftMargin: parent.contentLeftInset
      anchors.rightMargin: parent.contentRightInset
      spacing: 0

      CursorSurface {
        id: header
        width: parent.width
        radius: Style.cornerRadius
        foreground: optRow.fg
        hasCursor: hoverHandler.hovered
        height: Math.max(glyphItem.height, headerLabel.implicitHeight) + Style.spacing.huge + Style.spacing.lg

    readonly property bool hasValue: optRow.valueText !== ""
    readonly property real chevWidth: optRow.chevron ? chevronText.implicitWidth + Style.spacing.lg : 0
    readonly property real valWidth: hasValue ? Math.min(valueText.implicitWidth, width * 0.5) + Style.spacing.lg : 0

    HoverHandler { id: hoverHandler }

    MouseArea {
      anchors.fill: parent
      cursorShape: optRow.chevron ? Qt.PointingHandCursor : Qt.ArrowCursor
      onClicked: {
        optRow.rowClicked()
        if (optRow.chevron) {
          // Accordion: opening a row collapses the others.
          var next = !optRow.open
          var p = optRow.parent
          for (var i = 0; i < p.children.length; i++) {
            var c = p.children[i]
            if (c !== optRow && c.chevron === true && c.open === true) c.open = false
          }
          optRow.open = next
        }
      }
    }

    OpticalGlyph {
      id: glyphItem
      anchors.left: parent.left
      anchors.leftMargin: Style.spacing.xl
      anchors.verticalCenter: parent.verticalCenter
      width: Style.space(24)
      height: width
      text: optRow.glyph
      fontFamily: optRow.fam
      fontSize: Style.font.body
      color: optRow.fg
    }

    Text {
      textFormat: Text.PlainText
      id: headerLabel
      anchors.left: glyphItem.right
      anchors.leftMargin: Style.spacing.lg
      anchors.verticalCenter: parent.verticalCenter
      width: Math.max(0, header.width - Style.spacing.xl - Style.space(24) - Style.spacing.lg - header.chevWidth - header.valWidth)
      text: optRow.label
      color: optRow.fg
      font.family: optRow.fam
      font.pixelSize: Style.font.body
      elide: Text.ElideRight
    }

    Text {
      textFormat: Text.PlainText
      id: valueText
      visible: header.hasValue && trailingSlot.width === 0
      x: header.width - Style.spacing.xl - header.chevWidth - width - (trailingSlot.width ? trailingSlot.width + Style.spacing.lg : 0)
      anchors.verticalCenter: parent.verticalCenter
      width: Math.min(implicitWidth, header.width * 0.5)
      text: optRow.valueText
      color: Qt.darker(optRow.fg, 1.5)
      font.family: optRow.fam
      font.pixelSize: Style.font.bodySmall
      horizontalAlignment: Text.AlignRight
      elide: Text.ElideMiddle
    }

    // Optional trailing control (e.g. a ToggleSwitch). Takes the chevron spot;
    // pair it with `chevron: false`.
    Item {
      id: trailingSlot
      anchors.right: parent.right
      anchors.rightMargin: Style.spacing.xl
      anchors.verticalCenter: parent.verticalCenter
      width: childrenRect.width
      height: childrenRect.height
    }

    Text {
      textFormat: Text.PlainText
      id: chevronText
      visible: optRow.chevron && trailingSlot.width === 0
      anchors.right: parent.right
      anchors.rightMargin: Style.spacing.xl
      anchors.verticalCenter: parent.verticalCenter
      text: optRow.open ? "\udb80\udd43" : "\udb80\udd40"
      color: Qt.darker(optRow.fg, 1.2)
      font.family: optRow.fam
      font.pixelSize: Style.font.body
    }
  }

      BorderSurface {
        visible: optRow.open
        width: parent.width
        height: contentTopInset + expanderSlot.implicitHeight + contentBottomInset
        radius: Style.cornerRadius
        color: Style.normalFillFor(optRow.fg, Color.accent)
        borderSpec: Border.none()
        padding: Style.spacing.lg

        Column {
          id: expanderSlot
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.topMargin: parent.contentTopInset
          anchors.leftMargin: parent.contentLeftInset
          anchors.rightMargin: parent.contentRightInset
          spacing: Style.spacing.lg
        }
      }
    }
  }
}

component FooterButton: BorderSurface {
  id: fbtn

  property string glyph: ""
  property string labelText: ""
  property string valueText: ""
  property bool primary: false
  property color fg: Color.foreground
  property string fam: Style.font.family
  signal act()

  height: footRow.implicitHeight + Style.spacing.huge
  implicitWidth: footRow.implicitWidth + Style.spacing.huge
  radius: Style.cornerRadius
  color: footArea.pressed ? Style.pressedFillFor(fbtn.fg, Color.accent)
    : fbtn.primary ? Style.selectedFillFor(fbtn.fg, Color.accent)
    : Style.controlFill(false, false, fbtn.fg, Color.accent)
  borderSpec: fbtn.primary ? Border.none() : Border.controlSpec("normal", fbtn.fg, Color.accent)

  Row {
    id: footRow
    anchors.centerIn: parent
    spacing: Style.spacing.controlGap

    OpticalGlyph {
      anchors.verticalCenter: parent.verticalCenter
      text: fbtn.glyph
      fontFamily: fbtn.fam
      fontSize: Style.font.body
      color: fbtn.fg
      width: Style.space(18)
      height: width
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      textFormat: Text.PlainText
      text: fbtn.labelText
      color: fbtn.fg
      font.family: fbtn.fam
      font.pixelSize: Style.font.body
      font.bold: fbtn.primary
    }

    Text {
      visible: fbtn.valueText !== ""
      anchors.verticalCenter: parent.verticalCenter
      textFormat: Text.PlainText
      text: fbtn.valueText
      color: Qt.darker(fbtn.fg, 1.3)
      font.family: fbtn.fam
      font.pixelSize: Style.font.bodySmall
    }
  }

  MouseArea {
    id: footArea
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: fbtn.act()
  }
}

component InputGlyphButton: Item {
  id: igb
  property string glyph: ""
  property color fg: Color.foreground
  property string fam: Style.font.family
  signal clicked()
  width: Style.space(26)
  height: Style.space(26)

  Rectangle {
    anchors.fill: parent
    radius: Style.cornerRadius
    color: mouse.containsMouse ? Util.alpha(igb.fg, 0.12) : "transparent"
  }

  OpticalGlyph {
    anchors.centerIn: parent
    text: igb.glyph
    fontFamily: igb.fam
    fontSize: Style.font.bodySmall
    color: Qt.darker(igb.fg, 1.3)
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: igb.clicked()
  }
}

  function open() { root.openFromHotkey() }
  function openFromHotkey() {
    root.controller.show()
    root.onOpened()
  }

  function close() { root.controller.hide() }
  function toggle() { root.opened ? root.close() : root.openFromHotkey() }

  function closeForPopoutSwitch() {
    root.popoutSwitchClosing = true
    root.close()
    Qt.callLater(function() { root.popoutSwitchClosing = false })
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  function defaultSettings() {
    return {
      downloadDir: home + "/Downloads",
      autoClipboard: true,
      autoExtractClipboard: true,
      clearInputAfterDownload: true,
      audioFormat: "best",
      advancedVisible: false,
      outputTemplate: "%(title)s.%(ext)s",
      cookies: "",
      cookiesFromBrowser: "",
      cookiesProfile: "",
      proxy: "",
      rateLimit: "",
      concurrentFragments: "",
      customFormatSelector: "",
      customArgs: "",
      downloadThumbnail: false,
      embedThumbnail: false,
      embedSubs: false,
      includeAutoSubs: false,
      preferDrc: false,
      sponsorBlock: false,
      sponsorBlockCategories: ["sponsor", "selfpromo", "interaction"],
      useArchive: false,
      saveHistory: true,
      history: [],
      subLanguage: "all",
      postDownloadAction: "nothing"
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
    root.history = Array.isArray(next.history) ? next.history : []
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
      if (root.normalizedUrl === "" && !root.isSearchQuery) return "error: invalid URL"
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

  property bool _clipForced: false
  function readClipboard(force) {
    if (clipProc.running) return
    // No currentUrl guard: auto-paste on open replaces whatever stale text
    // the field held from a previous session — the fresh copy is what the
    // user wants. isKnownUrl still filters the auto path (see clipProc).
    root._clipForced = !!force
    clipProc.running = true
  }

  Process {
    id: clipProc
    command: Otoru.clipCommand()
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var text = Otoru.cleanUrlText(String(this.text || ""))
        if (text === "") return
        if (!root._clipForced && root.isKnownUrl(text)) return
        // Reopening the panel mid-flow with the same URL still in the
        // clipboard must not re-extract and wipe the current card (e.g.
        // while a download is running).
        if (!root._clipForced && root.mediaInfo && text === root.extractedUrl) return
        root.currentUrl = text
        // Set after currentUrl so the onTextChanged handler (which clears it
        // on real keystrokes) doesn't undo it — see urlField.
        root.pastedFromClipboard = true
        if (root.setting("autoExtractClipboard", true)) root.startExtraction()
      }
    }
  }

  property string currentUrl: ""
  onCurrentUrlChanged: root.useWebClient = false
  // The exact URL the current mediaInfo was extracted for — when the field
  // text diverges from it, the stale media card is dropped (see urlField).
  property string extractedUrl: ""
  property bool pastedFromClipboard: false
  readonly property string normalizedUrl: Otoru.cleanUrlText(root.currentUrl)
  readonly property bool isSearchQuery: Otoru.isSearchQuery(root.currentUrl)
  property var mediaInfo: null
  property string _fallbackThumb: ""
  onMediaInfoChanged: root._fallbackThumb = ""
  property bool useWebClient: false
  // Extraction failures worth promoting to the download card — these are the
  // ones the "Retry as web client" button can actually fix.
  readonly property string retryableErrorPattern: "403|forbidden|access denied|sign in|authentication|auth required|authenticate|unable to download|blocked|geo|bot"
  readonly property bool canRetryAsWebClient: root.activeStatus === "error" && !root.useWebClient &&
    new RegExp(root.retryableErrorPattern, "i").test(root.activeError || root.errorMessage || "")
  property bool extracting: false
  readonly property bool downloadInProgress: root.activeStatus === "downloading" || root.activeStatus === "preparing" || root.activeStatus === "paused"
  // True while the card shown is the downloading job's own card (nothing to
  // queue); a fresh extraction of another source makes it false → Queue shows.
  readonly property bool showingDownloadedCard: root.downloadInProgress && root.activeJob && root.mediaInfo
    && root.mediaInfo.webpage_url === root.activeJob.url

  property var activeInfoProc: null
  property string errorMessage: ""
  property string rawLog: ""
  property bool showRawLog: false

  function appendRawLog(data) {
    var line = String(data || "")
    if (!line) return
    root.rawLog += line + "\n"
    if (root.activeJob) root.activeJob.log = (root.activeJob.log || "") + line + "\n"
  }

  property var history: []

  function rememberUrl(url) {
    var u = String(url).trim()
    if (!u || root.history.indexOf(u) >= 0) return
    var next = root.history.slice()
    next.push(u)
    if (next.length > 50) next = next.slice(-50)
    root.history = next
    if (root.setting("saveHistory", true)) root.setSetting("history", next)
  }

  function isKnownUrl(url) {
    return root.history.indexOf(String(url).trim()) >= 0
  }

  function startExtraction() {
    var raw = String(root.currentUrl).trim()
    var url = Otoru.cleanUrlText(raw)
    if (url === "" && Otoru.isSearchQuery(raw)) url = "ytsearch1:" + raw
    if (url === "") {
      root.errorMessage = "Enter a URL or search query."
      return
    }
    root.extractedUrl = url
    root.extracting = true
    root.mediaInfo = null
    root.errorMessage = ""
    // Deliberately do NOT clear activeStatus/activeError here: an in-progress
    // download card stays until the user clears it (Clear button / clear IPC).
    root.rawLog = ""
    root.downloadMode = "video"
    root.videoQuality = "best"
    root.audioFormat = String(root.setting("audioFormat", "best") || "best")
    root.audioLanguage = ""

    // Fresh Process per extraction: reusing one races its late finished
    // signals against the next run's StdioCollector (stale/partial output).
    if (root.activeInfoProc) { root.activeInfoProc.destroy(); root.activeInfoProc = null }
    var proc = infoProcFactory.createObject(root)
    root.activeInfoProc = proc
    proc.command = Otoru.infoCommand(url, root.setting("proxy", ""), root.useWebClient, root.settings, root.home)
    proc.running = true
  }

  Component {
    id: infoProcFactory
    Process {
      id: infoProc
      stdout: StdioCollector {
        waitForEnd: true
        onStreamFinished: {
          // Stale proc (superseded by a newer extraction): its output would
          // clobber the fresh card, drop it.
          if (root.activeInfoProc !== infoProc) return
          var raw = String(this.text || "").trim()
          root.handleInfo(raw)
        }
      }
      stderr: SplitParser {
        onRead: function(data) {
          if (root.activeInfoProc === infoProc) root.rawLog += data + "\n"
        }
      }
      onExited: function(exitCode, exitStatus) {
        if (root.activeInfoProc !== infoProc) return
        root.activeInfoProc = null
        root.extracting = false
        if (exitCode !== 0 || exitStatus !== 0) {
          var err = Otoru.friendlyError(root.rawLog, exitCode, exitStatus)
          root.errorMessage = err
          // Extraction failures are explained by the banner above; only
          // promote to the download card when "Retry as web client" applies
          // (and never clobber an in-progress download card).
          if (root.activeStatus !== "downloading" && root.activeStatus !== "preparing"
              && new RegExp(root.retryableErrorPattern, "i").test(err)) {
            root.activeStatus = "error"
            root.activeError = err
          }
        }
        this.destroy()
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
    // Playlists come back flat (no formats), so offer the full quality ladder
    // rather than nothing — otherwise the download falls through to yt-dlp's
    // default selection with no way to pick video/audio or a resolution.
    root.availableQualities = info.isPlaylist === true
      ? Otoru.allVideoQualities()
      : Otoru.availableVideoQualities(info.maxHeight)
    if (!info.hasAudio && root.downloadMode === "audio") root.downloadMode = "video"
    if (root.availableQualities.indexOf(root.videoQuality) < 0) root.videoQuality = "best"
    // Some sites (x.com amplify videos) omit the thumbnail from the yt-dlp
    // dump — scrape the page's og:image as a fallback so the card isn't blank.
    if (info.thumbnail === "" && info.webpage_url) root.scrapeThumbnail(info.webpage_url)
  }

  property string _thumbScrapeUrl: ""
  function scrapeThumbnail(url) {
    if (!url) return
    root._thumbScrapeUrl = String(url)
    if (thumbScrapeProc.running) thumbScrapeProc.running = false // restart for a new URL
    thumbScrapeProc.command = ["curl", "-sL", "--max-time", "15", "--max-filesize", "1048576",
      "-A", "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36",
      String(url)]
    thumbScrapeProc.running = true
  }

  Process {
    id: thumbScrapeProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var html = String(this.text || "")
        var m = /(?:og:image|og:image:secure_url)"\s+content="([^"]+)"/i.exec(html)
        if (!m) return
        var thumb = m[1].replace(/&amp;/g, "&") // HTML entities in the meta tag
        // Vimeo og:image defaults to webp; Qt has no webp plugin — ask for jpg.
        if (/vimeocdn\.com/.test(thumb)) thumb = thumb.replace(/([?&])f=webp/, "$1f=jpg")
        // Only apply to the media card the scrape was started for.
        if (!root.mediaInfo || root.mediaInfo.webpage_url !== root._thumbScrapeUrl) return
        if (root._fallbackThumb !== "") return
        root._fallbackThumb = thumb
      }
    }
  }

  property string downloadMode: "video"
  property string videoQuality: "best"
  property string audioFormat: "best"
  property string audioLanguage: ""
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
  property string _lastOutputPath: ""
  property bool pauseRequested: false

  function makeJob() {
    return {
      // Prefer the resolved page URL (a search result downloads the video,
      // not a re-search); fall back to the normalized field text.
      url: root.mediaInfo && root.mediaInfo.webpage_url
        ? String(root.mediaInfo.webpage_url)
        : Otoru.cleanUrlText(root.currentUrl),
      title: root.mediaInfo ? root.mediaInfo.title : "",
      mode: root.downloadMode,
      quality: root.videoQuality,
      audioFormat: root.audioFormat,
      audioLanguage: root.audioLanguage,
      info: root.mediaInfo
    }
  }

  function startDownload() {
    if (!root.mediaInfo && !Otoru.looksLikeUrl(root.currentUrl)) {
      root.errorMessage = "Enter a URL first."
      return
    }
    if (root.activeStatus === "downloading" || root.activeStatus === "paused") {
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
    root._lastOutputPath = ""
    root.pauseRequested = false
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
    stdout: SplitParser {
      onRead: function(data) {
        var line = String(data).trim()
        // yt-dlp --print after_move:filepath: the real output path.
        if (line.charAt(0) === "/") {
          root._lastOutputPath = line
          return
        }
        var p = Otoru.parseProgressLine(line)
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

    // Pause: keep job + .part files so resume continues where we left off.
    if (root.pauseRequested && exitStatus !== 0) {
      root.pauseRequested = false
      root.activeStatus = "paused"
      return
    }
    root.pauseRequested = false

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
      root.activeOutputPath = root._lastOutputPath !== "" ? root._lastOutputPath : Otoru.guessOutputPath(root.settings, job, job.info, root.home)
      root.activeOutputDir = Otoru.expandHome(root.setting("downloadDir", ""), root.home)
      root.activeProgressPercent = "100%"
      root.activeProgressPercentValue = 100
      root.activeProgressSpeed = ""
      root.activeProgressEta = ""
      root.rememberUrl(job.url)
      var action = root.setting("postDownloadAction", "nothing")
      if (action === "copy" && root.activeOutputPath !== "") {
        copyPathProc.command = ["sh", "-c", "printf %s \"$1\" | wl-copy", "otoru-copy", root.activeOutputPath]
        copyPathProc.running = true
      } else if (action === "open" && root.activeOutputDir !== "") {
        root.openFolder(root.activeOutputDir)
      } else if (action === "openFile") {
        if (root._lastOutputPath !== "") root.openFile(root._lastOutputPath)
        else if (root.activeOutputDir !== "") root.openFolder(root.activeOutputDir)
      }
      root.notifyComplete()
      // Only clear while the panel is visible — a download finishing in the
      // background shouldn't wipe the extracted card before it's been seen.
      if (root.opened && root.setting("clearInputAfterDownload", true)) root.resetInput()
    }

    root.activeJob = null
    Qt.callLater(root.processQueue)
  }

  function processQueue() {
    if (root.activeStatus === "downloading" || root.activeStatus === "paused" || queueModel.count === 0) return
    var queued = queueModel.get(0)
    var job = {
      url: queued.url,
      title: queued.title,
      mode: queued.mode,
      quality: queued.quality,
      audioFormat: queued.audioFormat,
      audioLanguage: queued.audioLanguage,
      info: queued.info
    }
    queueModel.remove(0)
    root.startJob(job)
  }

  function cancelActive() {
    if (downloadProc.running) downloadProc.running = false
  }

  function pauseActive() {
    root.pauseRequested = true
    if (downloadProc.running) downloadProc.running = false
  }

  function resumeActive() {
    if (root.activeJob) root.startJob(root.activeJob)
  }

  function removeQueued(index) {
    if (index >= 0 && index < queueModel.count) queueModel.remove(index)
  }

  function useHistory(url) {
    root.currentUrl = String(url)
    if (urlField) urlField.text = String(url)
    root.startExtraction()
  }

  function resetInput() {
    root.currentUrl = ""
    if (urlField) urlField.text = ""
    root.extractedUrl = ""
    root.mediaInfo = null
    root.downloadMode = "video"
    root.videoQuality = "best"
    root.audioFormat = String(root.setting("audioFormat", "best") || "best")
    root.audioLanguage = ""
    root.errorMessage = ""
    Qt.callLater(function() { if (urlField) urlField.forceActiveFocus() })
  }

  function clearActive() {
    root.activeStatus = ""
    root.activeTitle = ""
    root.activeJob = null
    root.activeProgressPercent = ""
    root.activeProgressPercentValue = 0
    root.activeProgressSize = ""
    root.activeProgressSpeed = ""
    root.activeProgressEta = ""
    root.activeError = ""
    root.activeOutputPath = ""
    root._lastOutputPath = ""
    root.activeOutputDir = ""
  }

  function retryWithWebClient() {
    root.useWebClient = true
    root.errorMessage = ""
    root.activeError = ""
    if (root.mediaInfo) root.startDownload()
    else root.startExtraction() // validates internally (URL or search query)
  }

  function openFolder(path) {
    if (!path) return
    Quickshell.execDetached(["uwsm-app", "--", "nautilus", "--new-window", path])
  }

  function openFile(path) {
    if (!path) return
    Quickshell.execDetached(["uwsm-app", "--", "xdg-open", path])
  }

  function notifyComplete() {
    if (root.opened) return // status is visible in the panel; don't overlap it
    var title = root.activeTitle || "Download complete"
    var body = "Saved to " + root.setting("downloadDir", "")
    var folder = Otoru.expandHome(root.setting("downloadDir", ""), root.home)
    notifyProc.command = [root.notifyScript, title, body, folder]
    notifyProc.running = true
  }

  function notifyError() {
    if (root.opened) return // status is visible in the panel; don't overlap it
    var title = root.activeTitle || "Download failed"
    var body = String(root.activeError || root.errorMessage || "Unknown error")
    notifyProc.command = ["/usr/share/omarchy/bin/omarchy-notification-send", "-a", "otoru", "-i", "dialog-error", "-u", "normal", title, body]
    notifyProc.running = true
  }

  Process { id: notifyProc }
  Process { id: copyPathProc }

  function modeButtonLabel(mode) {
    if (mode === "video") return "Video"
    if (mode === "audio") return "Audio"
    if (mode === "custom") return "Custom"
    return mode
  }

  function modeValueText() {
    var q = root.mediaInfo && root.mediaInfo.maxHeight > 0 ? root.mediaInfo.maxHeight + "p" : ""
    if (root.downloadMode === "video") {
      if (root.videoQuality !== "best") return "Video · " + root.videoQuality + "p"
      return q ? "Video · Best (" + q + ")" : "Video"
    }
    if (root.downloadMode === "audio")
      return "Audio · " + (root.audioFormat === "best" ? "Best" : root.audioFormat.toUpperCase())
    return "Custom"
  }

  function sponsorCategories() {
    var c = root.setting("sponsorBlockCategories", null)
    return Array.isArray(c) ? c : []
  }

  function toggleSponsorCategory(cat) {
    var cur = root.sponsorCategories().slice()
    var i = cur.indexOf(cat)
    if (i >= 0) cur.splice(i, 1)
    else cur.push(cat)
    root.setSetting("sponsorBlockCategories", cur)
  }

  function sponsorCategoryLabel(cat) {
    var names = {
      sponsor: "Sponsor",
      selfpromo: "Self-promo",
      interaction: "Interaction",
      intro: "Intro",
      outro: "Outro",
      preview: "Preview",
      filler: "Filler",
      music_offtopic: "Non-music"
    }
    return names[cat] || cat
  }

  function audioTrackOptions() {
    var opts = [{ value: "", label: "Original" }]
    var langs = root.mediaInfo ? root.mediaInfo.audioLanguages : []
    for (var i = 0; i < langs.length; i++) opts.push({ value: langs[i], label: langs[i] })
    return opts
  }

  function subtitleOptions() {
    var names = {
      aa: "Afar", ab: "Abkhazian", ae: "Avestan", af: "Afrikaans", ak: "Akan",
      am: "Amharic", an: "Aragonese", ar: "Arabic", as: "Assamese", av: "Avaric",
      ay: "Aymara", az: "Azerbaijani",
      ba: "Bashkir", be: "Belarusian", bg: "Bulgarian", bh: "Bihari", bi: "Bislama",
      bm: "Bambara", bn: "Bengali", bo: "Tibetan", br: "Breton", bs: "Bosnian",
      ca: "Catalan", ce: "Chechen", ch: "Chamorro", co: "Corsican", cr: "Cree",
      cs: "Czech", cu: "Church Slavic", cv: "Chuvash", cy: "Welsh",
      da: "Danish", de: "German", dv: "Divehi", dz: "Dzongkha",
      ee: "Ewe", el: "Greek", en: "English", eo: "Esperanto", es: "Spanish",
      et: "Estonian", eu: "Basque",
      fa: "Persian", ff: "Fula", fi: "Finnish", fj: "Fijian", fo: "Faroese",
      fr: "French", fy: "Western Frisian",
      ga: "Irish", gd: "Scottish Gaelic", gl: "Galician", gn: "Guarani",
      gu: "Gujarati", gv: "Manx",
      ha: "Hausa", he: "Hebrew", hi: "Hindi", ho: "Hiri Motu", hr: "Croatian",
      ht: "Haitian", hu: "Hungarian", hy: "Armenian", hz: "Herero",
      ia: "Interlingua", id: "Indonesian", ie: "Interlingue", ig: "Igbo",
      ii: "Sichuan Yi", ik: "Inupiaq", io: "Ido", is: "Icelandic", it: "Italian",
      iu: "Inuktitut",
      ja: "Japanese", jv: "Javanese",
      ka: "Georgian", kg: "Kongo", ki: "Kikuyu", kj: "Kuanyama", kk: "Kazakh",
      kl: "Kalaallisut", km: "Khmer", kn: "Kannada", ko: "Korean", kr: "Kanuri",
      ks: "Kashmiri", ku: "Kurdish", kv: "Komi", kw: "Cornish", ky: "Kirghiz",
      la: "Latin", lb: "Luxembourgish", lg: "Ganda", li: "Limburgan", ln: "Lingala",
      lo: "Lao", lt: "Lithuanian", lu: "Luba-Katanga", lv: "Latvian",
      mg: "Malagasy", mh: "Marshallese", mi: "Maori", mk: "Macedonian",
      ml: "Malayalam", mn: "Mongolian", mr: "Marathi", ms: "Malay", mt: "Maltese",
      my: "Burmese",
      na: "Nauru", nb: "Norwegian Bokmål", nd: "North Ndebele", ne: "Nepali",
      ng: "Ndonga", nl: "Dutch", nn: "Norwegian Nynorsk", no: "Norwegian",
      nr: "South Ndebele", nv: "Navajo", ny: "Chichewa",
      oc: "Occitan", oj: "Ojibwa", om: "Oromo", or: "Oriya", os: "Ossetian",
      pa: "Punjabi", pi: "Pali", pl: "Polish", ps: "Pashto", pt: "Portuguese",
      qu: "Quechua",
      rm: "Romansh", rn: "Kirundi", ro: "Romanian", ru: "Russian", rw: "Kinyarwanda",
      sa: "Sanskrit", sc: "Sardinian", sd: "Sindhi", se: "Northern Sami",
      sg: "Sango", si: "Sinhala", sk: "Slovak", sl: "Slovenian", sm: "Samoan",
      sn: "Shona", so: "Somali", sq: "Albanian", sr: "Serbian", ss: "Swati",
      st: "Southern Sotho", su: "Sundanese", sv: "Swedish", sw: "Swahili",
      ta: "Tamil", te: "Telugu", tg: "Tajik", th: "Thai", ti: "Tigrinya",
      tk: "Turkmen", tl: "Tagalog", tn: "Tswana", to: "Tongan", tr: "Turkish",
      ts: "Tsonga", tt: "Tatar", tw: "Twi", ty: "Tahitian",
      ug: "Uighur", uk: "Ukrainian", ur: "Urdu", uz: "Uzbek",
      ve: "Venda", vi: "Vietnamese", vo: "Volapük",
      wa: "Walloon", wo: "Wolof",
      xh: "Xhosa",
      yi: "Yiddish", yo: "Yoruba",
      za: "Zhuang", zh: "Chinese", zu: "Zulu"
    }
    var opts = [{ value: "all", label: "All" }]
    var langs = root.mediaInfo ? root.mediaInfo.subLanguages : []
    for (var i = 0; i < langs.length; i++) {
      var code = String(langs[i])
      var label = names[code]
      if (!label) {
        // Compound codes like "en-US", "zh-Hans" → "English (US)", "Chinese (Hans)"
        var dash = code.indexOf("-")
        if (dash > 0 && names[code.substring(0, dash)]) {
          label = names[code.substring(0, dash)] + " (" + code.substring(dash + 1) + ")"
        } else {
          label = code
        }
      }
      opts.push({ value: code, label: label })
    }
    return opts
  }

  function qualityButtonLabel(q) {
    var base = q === "best" ? "Best" : q + "p"
    var h = q === "best" ? (root.mediaInfo ? root.mediaInfo.maxHeight : 0) : Number(q)
    var s = Otoru.formatSize(Otoru.estimateQualitySize(root.mediaInfo, h))
    return s ? base + "  ·  " + s : base
  }

  function anyFieldFocused() {
    return urlField.activeFocus ||
           downloadDirField.activeFocus ||
           outputTemplateField.activeFocus ||
           cookiesField.activeFocus ||
           cookiesProfileField.activeFocus ||
           proxyField.activeFocus ||
           rateLimitField.activeFocus ||
           concurrentFragmentsField.activeFocus ||
           customFormatField.activeFocus ||
           customArgsField.activeFocus
  }

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
      blocked: root.anyFieldFocused() || cookiesFromBrowserDropdown.popupOpen
      onReturnRequested: {
        if (resetConfirm.opened) resetConfirm.confirmed()
        else if (root.mediaInfo && root.activeStatus !== "downloading") root.startDownload()
        else if (!root.mediaInfo && !root.extracting) root.startExtraction()
      }
      onCloseRequested: {
        if (resetConfirm.opened) resetConfirm.canceled()
        else root.close()
      }
      onTabRequested: function(direction) {
        if (!resetConfirm.opened) root.switchPanel(direction)
      }
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
        spacing: Style.spacing.xxl

        BorderSurface {
          visible: root.errorMessage !== ""
          width: parent.width
          height: errorColumn.implicitHeight + Style.spacing.huge
          radius: Style.cornerRadius
          color: Util.alpha(Color.urgent, 0.12)
          borderSpec: Border.controlSpec("normal", Color.urgent, Color.urgent)

          PanelActionButton {
            iconText: "\u2715"
            foreground: Color.urgent
            fontFamily: root.contentFontFamily
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: Style.spacing.md
            onClicked: root.errorMessage = ""
          }

          Column {
            id: errorColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: Style.spacing.xxl
            anchors.rightMargin: Style.spacing.xxl
            spacing: Style.spacing.md

            Text {
              width: parent.width
              textFormat: Text.PlainText
              text: root.errorMessage
              color: Color.urgent
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.body
              wrapMode: Text.WordWrap
            }
          }
        }

        Item {
          width: parent.width
          height: urlField.height

          TextField {
            id: urlField
            width: parent.width
            placeholderText: "Paste a URL or search…"
            text: root.currentUrl
            activeFocusOnTab: false
            foreground: root.contentForeground
            font.family: root.contentFontFamily
            // Room for the paste/clear glyph buttons inside the field.
            rightPadding: Style.spacing.controlPaddingX + Style.space(64)
            onTextChanged: {
              root.currentUrl = text
              root.pastedFromClipboard = false
              // Drop the stale media card as soon as the text diverges from
              // what it was extracted for.
              if (root.mediaInfo && Otoru.cleanUrlText(text) !== root.extractedUrl) {
                root.mediaInfo = null
                root._fallbackThumb = ""
              }
            }
            onAccepted: {
              if (resetConfirm.opened) return
              // Context-aware Enter: download when a result is ready,
              // extract otherwise (the README's two-Enter flow).
              if (root.mediaInfo && root.activeStatus !== "downloading") root.startDownload()
              else root.startExtraction()
            }

            Keys.onPressed: function(event) {
              if (resetConfirm.opened && (event.key === Qt.Key_Escape || event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
                event.accepted = true
                return
              }
              if (event.key === Qt.Key_Escape) {
                root.close()
                event.accepted = true
                return
              }
              // Modifier combos work even mid-typing — the field swallows
              // plain letters, so these carry the keyboard-first shortcuts.
              if (!(event.modifiers & Qt.ControlModifier)) return
              switch (event.key) {
              case Qt.Key_Backspace:
                // Force-clear the input (card + field); keep focus for the next URL.
                root.resetInput()
                event.accepted = true
                break
              case Qt.Key_1: root.downloadMode = "video"; event.accepted = true; break
              case Qt.Key_2: root.downloadMode = "audio"; event.accepted = true; break
              case Qt.Key_3: root.downloadMode = "custom"; event.accepted = true; break
              case Qt.Key_R:
                if (root.canRetryAsWebClient) { root.retryWithWebClient(); event.accepted = true }
                break
              case Qt.Key_P:
                if (root.activeStatus === "paused") { root.resumeActive(); event.accepted = true }
                else if (root.activeStatus === "downloading") { root.pauseActive(); event.accepted = true }
                break
              }
            }
          }

          Row {
            anchors.right: parent.right
            anchors.rightMargin: Style.spacing.sm
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.spacing.xs

            InputGlyphButton {
              glyph: "\uf0ea"
              fg: root.contentForeground
              fam: root.contentFontFamily
              onClicked: root.readClipboard(true)
            }
            InputGlyphButton {
              visible: root.currentUrl.trim() !== ""
              glyph: "\u2715"
              fg: root.contentForeground
              fam: root.contentFontFamily
              onClicked: root.resetInput()
            }
          }
        }

        Text {
          textFormat: Text.PlainText
          id: inputHint
          visible: !root.extracting && root.activeStatus !== "downloading" && root.activeStatus !== "preparing"
          width: parent.width
          wrapMode: Text.WordWrap
          color: root.currentUrl.trim() !== "" && root.normalizedUrl === "" && !root.isSearchQuery
              ? Color.urgent
              : root.currentUrl.trim() === "" ? Qt.darker(root.contentForeground, 1.5) : Color.accent
          text: root.currentUrl.trim() === "" ? "Paste a URL or search YouTube — press Enter"
              : root.normalizedUrl === "" && !root.isSearchQuery ? "Not a URL — paste the link or search"
              : root.mediaInfo ? "Press Enter to download"
              : root.pastedFromClipboard ? "Pasted from clipboard — press Enter to extract"
              : root.isSearchQuery ? "Press Enter to search YouTube"
              : "Press Enter to extract"
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.bodySmall
        }

        Text {
          textFormat: Text.PlainText
        id: extractingLabel
          visible: root.extracting
          text: "Extracting media information…"
          color: Qt.darker(root.contentForeground, 1.5)
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.body

          SequentialAnimation {
            running: root.extracting
            loops: Animation.Infinite
            onRunningChanged: if (!running && extractingLabel) extractingLabel.opacity = 1.0
            NumberAnimation { target: extractingLabel; property: "opacity"; to: 0.45; duration: 600; easing.type: Easing.InOutQuad }
            NumberAnimation { target: extractingLabel; property: "opacity"; to: 1.0; duration: 600; easing.type: Easing.InOutQuad }
          }
        }

        BorderSurface {
          visible: root.mediaInfo !== null
          width: parent.width
          height: headerRow.implicitHeight + Style.spacing.huge
          radius: Style.cornerRadius
          color: Style.controlFill(false, false, root.contentForeground, Color.accent)
          borderSpec: Border.controlSpec("normal", root.contentForeground, Color.accent)

          Row {
            id: headerRow
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: Style.spacing.xxl
            anchors.rightMargin: Style.spacing.xxl
            spacing: Style.spacing.xxl

            Item {
              width: Style.space(96)
              height: Style.space(72)
              anchors.verticalCenter: parent.verticalCenter

              BorderSurface {
                anchors.fill: parent
                radius: Style.cornerRadius
                color: Style.controlFill(false, false, root.contentForeground, Color.accent)
                borderSpec: Border.controlSpec("normal", root.contentForeground, Color.accent)
                clip: true
                visible: root.mediaInfo && (root.mediaInfo.thumbnail !== "" || root._fallbackThumb !== "")

                Image {
                  anchors.fill: parent
                  source: root._fallbackThumb !== "" ? root._fallbackThumb : (root.mediaInfo ? root.mediaInfo.thumbnail : "")
                  fillMode: Image.PreserveAspectCrop
                  asynchronous: true

                  // ponytail: yt-dlp lists maxres/sd sizes that 404 on old videos;
                  // fall back to hqdefault. `_fallbackThumb` is a plain property —
                  // assigning it keeps the `source` binding alive (an imperative
                  // source= would kill it and freeze the image on the old video).
                  onStatusChanged: {
                    if (status === Image.Error && root._fallbackThumb === "") {
                      var m = /i\.ytimg\.com\/vi\/([A-Za-z0-9_-]+)\//.exec(root.mediaInfo ? root.mediaInfo.thumbnail : "")
                      if (m) root._fallbackThumb = "https://i.ytimg.com/vi/" + m[1] + "/hqdefault.jpg"
                    }
                  }
                }
              }

              Rectangle {
                visible: root.mediaInfo && root.mediaInfo.duration > 0
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: Style.spacing.sm
                width: durationBadgeText.implicitWidth + Style.spacing.xl
                height: durationBadgeText.implicitHeight + Style.spacing.sm
                radius: height / 2
                color: Qt.rgba(0, 0, 0, 0.65)

                Text {
                  textFormat: Text.PlainText
                  id: durationBadgeText
                  anchors.centerIn: parent
                  text: Otoru.formatDuration(root.mediaInfo ? root.mediaInfo.duration : 0)
                  color: "white"
                  font.family: "monospace"
                  font.pixelSize: Style.font.caption
                }
              }
            }

            Column {
              width: parent.width - Style.space(96) - Style.spacing.xxl
              spacing: Style.spacing.sm
              anchors.verticalCenter: parent.verticalCenter

              Text {
                width: parent.width
                textFormat: Text.PlainText
                text: root.mediaInfo ? root.mediaInfo.title : ""
                color: root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.body
                font.bold: true
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
              }

              Text {
                visible: root.mediaInfo && root.mediaInfo.uploader !== ""
                width: parent.width
                textFormat: Text.PlainText
                text: root.mediaInfo ? root.mediaInfo.uploader : ""
                color: Qt.darker(root.contentForeground, 1.5)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.bodySmall
                elide: Text.ElideRight
              }
            }
          }
        }

        Column {
          width: parent.width
          spacing: Style.spacing.sm

        OptionRow {
          // Summary only — mode/quality selection below applies to every item.
          visible: root.mediaInfo !== null && root.mediaInfo.isPlaylist === true
          glyph: "\udb81\udc11"
          label: "Playlist"
          valueText: (root.mediaInfo ? String(root.mediaInfo.count) : "") + " items"
          chevron: false
          fg: root.contentForeground
          fam: root.contentFontFamily
          hasBackground: true
          background: Style.hoverFillFor(root.contentForeground, Color.accent)
        }

        OptionRow {
          visible: root.mediaInfo !== null
          glyph: "\uf03d"
          label: "Mode"
          valueText: root.modeValueText()
          fg: root.contentForeground
          fam: root.contentFontFamily

          Row {
            spacing: Style.spacing.md

            Repeater {
              model: ["video", "audio", "custom"]

              Button {
                required property string modelData
                text: root.modeButtonLabel(modelData)
                selected: root.downloadMode === modelData
                fontSize: Style.font.bodySmall
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
                onClicked: root.downloadMode = modelData
              }
            }
          }

          Column {
            visible: root.downloadMode === "video" && root.availableQualities.length > 0
            width: parent.width
            spacing: Style.spacing.sm

            Text {
              textFormat: Text.PlainText
              text: "QUALITY"
              color: Qt.darker(root.contentForeground, 1.5)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              font.letterSpacing: 1
            }

            Flow {
              width: parent.width
              spacing: Style.spacing.md

              Button {
                text: root.qualityButtonLabel("best")
                selected: root.videoQuality === "best"
                fontSize: Style.font.bodySmall
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
                onClicked: root.videoQuality = "best"
              }

              Repeater {
                model: root.availableQualities

                Button {
                  required property string modelData
                  text: root.qualityButtonLabel(modelData)
                  selected: root.videoQuality === modelData
                  fontSize: Style.font.bodySmall
                  foreground: root.contentForeground
                  fontFamily: root.contentFontFamily
                  onClicked: root.videoQuality = modelData
                }
              }
            }
          }

          Column {
            visible: root.downloadMode === "audio"
            width: parent.width
            spacing: Style.spacing.sm

            Text {
              textFormat: Text.PlainText
              text: "AUDIO FORMAT"
              color: Qt.darker(root.contentForeground, 1.5)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              font.letterSpacing: 1
            }

            Row {
              spacing: Style.spacing.md

              Repeater {
                model: ["best", "mp3", "opus", "m4a"]

                Button {
                  required property string modelData
                  text: modelData === "best" ? "Best" : modelData.toUpperCase()
                  selected: root.audioFormat === modelData
                  fontSize: Style.font.bodySmall
                  foreground: root.contentForeground
                  fontFamily: root.contentFontFamily
                  onClicked: root.audioFormat = modelData
                }
              }
            }

            Text {
              visible: root.mediaInfo && root.mediaInfo.audioLanguages.length > 0
              textFormat: Text.PlainText
              text: "TRACK"
              color: Qt.darker(root.contentForeground, 1.5)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              font.letterSpacing: 1
            }

            SearchableDropdown {
              visible: root.mediaInfo && root.mediaInfo.audioLanguages.length > 0
              width: parent.width
              label: "Original"
              foreground: root.contentForeground
              background: root.bar ? root.bar.background : Color.background
              popupBorder: root.contentForeground
              fontFamily: root.contentFontFamily
              value: root.audioLanguage
              options: root.audioTrackOptions()
              onChanged: function(value) { root.audioLanguage = value }
            }
          }

          TextField {
            id: customFormatField
            visible: root.downloadMode === "custom"
            width: parent.width
            placeholderText: "yt-dlp format selector (e.g. bestvideo[height<=1080]+bestaudio)"
            text: root.setting("customFormatSelector", "")
            activeFocusOnTab: false
            onTextChanged: root.setSetting("customFormatSelector", text)

            Keys.onPressed: function(event) {
              if (event.key === Qt.Key_Escape) {
                keyCatcher.forceActiveFocus()
                event.accepted = true
              }
            }
          }
        }

        OptionRow {
          visible: root.mediaInfo !== null && (root.mediaInfo.hasSubs || root.mediaInfo.hasAutoSubs)
          glyph: "\udb80\udd5e"
          label: "Subtitles"
          valueText: [root.setting("embedSubs", false) ? "Embed" : "",
                      root.setting("includeAutoSubs", false) ? "Auto" : ""].filter(Boolean).join(" · ") || "Off"
          fg: root.contentForeground
          fam: root.contentFontFamily

          Toggle {
            width: parent.width
            label: "Embed subtitles into video"
            checked: root.setting("embedSubs", false)
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
            onClicked: root.setSetting("embedSubs", !root.setting("embedSubs", false))
          }

          Toggle {
            width: parent.width
            visible: root.mediaInfo && root.mediaInfo.hasAutoSubs
            label: "Include auto-generated captions"
            checked: root.setting("includeAutoSubs", false)
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
            onClicked: root.setSetting("includeAutoSubs", !root.setting("includeAutoSubs", false))
          }

          SearchableDropdown {
            width: parent.width
            label: "Subtitle language"
            foreground: root.contentForeground
            background: root.bar ? root.bar.background : Color.background
            popupBorder: root.contentForeground
            fontFamily: root.contentFontFamily
            value: root.setting("subLanguage", "all")
            options: root.subtitleOptions()
            onChanged: function(value) { root.setSetting("subLanguage", value) }
          }
        }

        OptionRow {
          visible: root.mediaInfo !== null
          glyph: "\uf03e"
          label: "Thumbnail"
          valueText: [root.setting("downloadThumbnail", false) ? "Save" : "",
                      root.setting("embedThumbnail", false) ? "Embed" : ""].filter(Boolean).join(" · ") || "Off"
          fg: root.contentForeground
          fam: root.contentFontFamily

          Toggle {
            width: parent.width
            label: "Save thumbnail image"
            description: "JPG saved next to the download"
            checked: root.setting("downloadThumbnail", false)
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
            onClicked: root.setSetting("downloadThumbnail", !root.setting("downloadThumbnail", false))
          }

          Toggle {
            width: parent.width
            label: "Embed thumbnail into file metadata"
            checked: root.setting("embedThumbnail", false)
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
            onClicked: root.setSetting("embedThumbnail", !root.setting("embedThumbnail", false))
          }
        }

        OptionRow {
          visible: root.mediaInfo !== null
          glyph: "\udb83\udea2"
          label: "Prefer DRC audio"
          chevron: false
          fg: root.contentForeground
          fam: root.contentFontFamily

          trailing: ToggleSwitch {
            checked: root.setting("preferDrc", false)
            foreground: root.contentForeground
            onToggled: root.setSetting("preferDrc", !root.setting("preferDrc", false))
          }
        }

        OptionRow {
          visible: root.mediaInfo !== null
          glyph: "\udb83\udea9"
          label: "SponsorBlock"
          valueText: root.setting("sponsorBlock", false)
                     ? "On \u00b7 " + root.sponsorCategories().length + " types" : "Off"
          fg: root.contentForeground
          fam: root.contentFontFamily

          Column {
            width: parent.width
            spacing: Style.spacing.lg

            OptionRow {
              glyph: "\udb83\udea9"
              label: "Skip sponsor segments"
              chevron: false
              fg: root.contentForeground
              fam: root.contentFontFamily

              trailing: ToggleSwitch {
                checked: root.setting("sponsorBlock", false)
                foreground: root.contentForeground
                onToggled: root.setSetting("sponsorBlock", !root.setting("sponsorBlock", false))
              }
            }

            Text {
              textFormat: Text.PlainText
              text: "SEGMENTS TO REMOVE"
              color: Qt.darker(root.contentForeground, 1.5)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              font.letterSpacing: 1
            }

            Flow {
              width: parent.width
              spacing: Style.spacing.md

              Repeater {
                model: ["sponsor", "selfpromo", "interaction", "intro", "outro", "preview", "filler", "music_offtopic"]

                Button {
                  required property string modelData
                  text: root.sponsorCategoryLabel(modelData)
                  selected: root.sponsorCategories().indexOf(modelData) >= 0
                  fontSize: Style.font.bodySmall
                  foreground: root.contentForeground
                  fontFamily: root.contentFontFamily
                  onClicked: root.toggleSponsorCategory(modelData)
                }
              }
            }
          }
        }

        OptionRow {
          glyph: "\udb80\udcfa"
          label: "After download"
          valueText: [root.setting("postDownloadAction", "nothing") === "copy" ? "Copy path" : "",
                      root.setting("postDownloadAction", "nothing") === "open" ? "Open folder" : "",
                      root.setting("postDownloadAction", "nothing") === "openFile" ? "Open file" : ""].filter(Boolean).join("") || "Nothing"
          fg: root.contentForeground
          fam: root.contentFontFamily

          Row {
            spacing: Style.spacing.md

            Repeater {
              model: [
                { value: "nothing", label: "Nothing" },
                { value: "copy", label: "Copy path" },
                { value: "open", label: "Open folder" },
                { value: "openFile", label: "Open file" }
              ]

              Button {
                required property var modelData
                text: modelData.label
                selected: root.setting("postDownloadAction", "nothing") === modelData.value
                fontSize: Style.font.bodySmall
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
                onClicked: root.setSetting("postDownloadAction", modelData.value)
              }
            }
          }
        }

        OptionRow {
          id: historyRow
          property bool expanded: false

          glyph: "\udb80\udd9d"
          label: "History"
          valueText: root.history.length > 0 ? root.history.length + " URLs" : ""
          fg: root.contentForeground
          fam: root.contentFontFamily
          open: historyRow.expanded
          onOpenChanged: historyRow.expanded = open

          Column {
            width: parent.width
            spacing: Style.spacing.lg

            OptionRow {
              glyph: "\udb80\udd9d"
              label: "Save download history"
              chevron: false
              fg: root.contentForeground
              fam: root.contentFontFamily

              trailing: ToggleSwitch {
                checked: root.setting("saveHistory", true)
                foreground: root.contentForeground
                onToggled: {
                  var wasOn = root.setting("saveHistory", true)
                  root.setSetting("saveHistory", !wasOn)
                  if (wasOn) {
                    root.history = []
                    root.setSetting("history", [])
                  }
                }
              }
            }

            Button {
              visible: root.history.length > 0
              width: parent.width
              text: "Clear history"
              fontSize: Style.font.bodySmall
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
              onClicked: {
                root.history = []
                root.setSetting("history", [])
              }
            }

            Repeater {
              model: root.history.slice().reverse().slice(0, 10)

              Item {
                required property string modelData
                width: parent.width
                height: histLabel.implicitHeight + Style.spacing.sm

                Text {
                  textFormat: Text.PlainText
                  id: histLabel
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  text: modelData
                  color: Qt.darker(root.contentForeground, 1.3)
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.caption
                  elide: Text.ElideMiddle
                }

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.useHistory(modelData)
                }
              }
            }
          }
        }

        OptionRow {
          id: advancedRow
          glyph: "\udb81\udc93"
          label: "Advanced"
          fg: root.contentForeground
          fam: root.contentFontFamily
          open: root.setting("advancedVisible", false)
          onOpenChanged: if (root.settingsLoaded) root.setSetting("advancedVisible", open)

          Column {
            width: parent.width
            spacing: Style.spacing.xl

          OptionRow {
            glyph: "\uf120"
            label: "Show raw log"
            chevron: false
            fg: root.contentForeground
            fam: root.contentFontFamily

            trailing: ToggleSwitch {
              checked: root.showRawLog
              foreground: root.contentForeground
              onToggled: root.showRawLog = !root.showRawLog
            }
          }

          OptionRow {
            glyph: "\udb80\udd4d"
            label: "Read URL from clipboard"
            chevron: false
            fg: root.contentForeground
            fam: root.contentFontFamily

            trailing: ToggleSwitch {
              checked: root.setting("autoClipboard", true)
              foreground: root.contentForeground
              onToggled: root.setSetting("autoClipboard", !root.setting("autoClipboard", true))
            }
          }

          OptionRow {
            glyph: "\udb80\udd4d"
            label: "Extract pasted URL automatically"
            chevron: false
            fg: root.contentForeground
            fam: root.contentFontFamily

            trailing: ToggleSwitch {
              checked: root.setting("autoExtractClipboard", true)
              foreground: root.contentForeground
              onToggled: root.setSetting("autoExtractClipboard", !root.setting("autoExtractClipboard", true))
            }
          }

          OptionRow {
            glyph: "\u2715"
            label: "Clear input after download"
            chevron: false
            fg: root.contentForeground
            fam: root.contentFontFamily

            trailing: ToggleSwitch {
              checked: root.setting("clearInputAfterDownload", true)
              foreground: root.contentForeground
              onToggled: root.setSetting("clearInputAfterDownload", !root.setting("clearInputAfterDownload", true))
            }
          }

          OptionRow {
            glyph: "\udb80\udefe"
            label: "Skip already-downloaded media"
            chevron: false
            fg: root.contentForeground
            fam: root.contentFontFamily

            trailing: ToggleSwitch {
              checked: root.setting("useArchive", false)
              foreground: root.contentForeground
              onToggled: root.setSetting("useArchive", !root.setting("useArchive", false))
            }
          }

          TextField {
            id: outputTemplateField
            width: parent.width
            placeholderText: "Output template (default: %(title)s.%(ext)s)"
            text: root.setting("outputTemplate", "")
            activeFocusOnTab: false
            onEditingFinished: root.setSetting("outputTemplate", text)
            Keys.onPressed: function(event) {
              if (event.key === Qt.Key_Escape) { keyCatcher.forceActiveFocus(); event.accepted = true }
            }
          }

          SearchableDropdown {
            id: cookiesFromBrowserDropdown
            width: parent.width
            label: "Cookies from browser"
            foreground: root.contentForeground
            background: root.bar ? root.bar.background : Color.background
            popupBorder: root.contentForeground
            fontFamily: root.contentFontFamily
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
            activeFocusOnTab: false
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
            activeFocusOnTab: false
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
            activeFocusOnTab: false
            onEditingFinished: root.setSetting("proxy", text)
            Keys.onPressed: function(event) {
              if (event.key === Qt.Key_Escape) { keyCatcher.forceActiveFocus(); event.accepted = true }
            }
          }

          Row {
            spacing: Style.spacing.lg
            width: parent.width

            TextField {
              id: rateLimitField
              width: (parent.width - parent.spacing) / 2
              placeholderText: "Rate limit"
              text: root.setting("rateLimit", "")
              activeFocusOnTab: false
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
              activeFocusOnTab: false
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
            activeFocusOnTab: false
            onEditingFinished: root.setSetting("customArgs", text)
            Keys.onPressed: function(event) {
              if (event.key === Qt.Key_Escape) { keyCatcher.forceActiveFocus(); event.accepted = true }
            }
          }

          Button {
            width: parent.width
            text: "Reset settings to defaults"
            fontSize: Style.font.bodySmall
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
            onClicked: resetConfirm.opened = true
          }
          }
        }
        }

        BorderSurface {
          visible: root.showRawLog && root.rawLog !== ""
          width: parent.width
          height: Math.min(Style.space(160), rawLogText.implicitHeight + Style.spacing.huge)
          radius: Style.cornerRadius
          color: Style.controlFill(false, false, root.contentForeground, Color.accent)
          borderSpec: Border.controlSpec("normal", root.contentForeground, Color.accent)
          clip: true

          Text {
            textFormat: Text.PlainText
            id: rawLogText
            anchors.fill: parent
            anchors.margins: Style.spacing.lg
            text: root.rawLog
            color: root.contentForeground
            font.family: "monospace"
            font.pixelSize: Style.font.caption
            wrapMode: Text.WrapAnywhere
            elide: Text.ElideNone
          }
        }

        BorderSurface {
          id: activeCard
          visible: root.activeStatus !== ""
          width: parent.width
          height: activeColumn.implicitHeight + Style.spacing.xl * 2
          radius: Style.cornerRadius
          color: Style.controlFill(false, false, root.contentForeground, Color.accent)
          borderSpec: Border.controlSpec("normal", root.contentForeground, Color.accent)

          property int phraseIndex: 0
          readonly property var phrases: [
            "Pulling streams",
            "Muxing tracks",
            "Stitching segments",
            "Rewriting parts",
            "Resolving formats",
            "Demuxing audio"
          ]
          readonly property string phrase: phrases[phraseIndex % phrases.length]

          Column {
            id: activeColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: Style.spacing.xl
            anchors.rightMargin: Style.spacing.xl
            spacing: Style.spacing.md

            Row {
              width: parent.width
              spacing: Style.spacing.lg

              Text {
                textFormat: Text.PlainText
              id: activeHero
                width: parent.width - activeActions.implicitWidth - parent.spacing
                text: root.activeTitle !== "" ? root.activeTitle : "Transfer"
                color: root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.body
                font.bold: true
                elide: Text.ElideRight
                anchors.verticalCenter: parent.verticalCenter
              }

              Row {
                id: activeActions
                spacing: Style.spacing.xs

                PanelActionButton {
                  visible: root.canRetryAsWebClient
                  iconText: "\uf01e"
                  tooltipText: "Retry as web client"
                  foreground: root.contentForeground
                  fontFamily: root.contentFontFamily
                  onClicked: root.retryWithWebClient()
                }

                PanelActionButton {
                  visible: root.activeStatus === "downloading"
                  iconText: "\uf04c"
                  tooltipText: "Pause"
                  foreground: root.contentForeground
                  fontFamily: root.contentFontFamily
                  onClicked: root.pauseActive()
                }

                PanelActionButton {
                  visible: root.activeStatus === "paused"
                  iconText: "\uf04b"
                  tooltipText: "Resume"
                  foreground: root.contentForeground
                  fontFamily: root.contentFontFamily
                  onClicked: root.resumeActive()
                }

                PanelActionButton {
                  visible: root.activeStatus === "downloading"
                  iconText: "\uf04d"
                  tooltipText: "Cancel"
                  foreground: root.contentForeground
                  fontFamily: root.contentFontFamily
                  onClicked: root.cancelActive()
                }

                PanelActionButton {
                  visible: root.activeStatus === "completed" && root.activeOutputDir !== ""
                  iconText: "\uf07c"
                  tooltipText: "Open folder"
                  foreground: root.contentForeground
                  fontFamily: root.contentFontFamily
                  onClicked: root.openFolder(root.activeOutputDir)
                }

                PanelActionButton {
                  visible: root.activeStatus !== "downloading"
                  // ✕, not a trash glyph — Clear only dismisses the card.
                  iconText: "\u2715"
                  tooltipText: "Clear"
                  foreground: root.contentForeground
                  fontFamily: root.contentFontFamily
                  onClicked: root.clearActive()
                }
              }
            }

            Text {
              textFormat: Text.PlainText
            id: activeMeta
              width: parent.width
              text: root.activeStatus === "downloading" ? activeCard.phrase.toUpperCase() :
                    root.activeStatus === "paused" ? "PAUSED" :
                    root.activeStatus === "completed" ? "FINISHED" :
                    root.activeStatus === "error" ? "ERROR" :
                    root.activeStatus === "cancelled" ? "CANCELLED" : "PREPARING…"
              color: Qt.darker(root.contentForeground, 1.5)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 1.2
              elide: Text.ElideRight
            }

            Timer {
              id: activePhraseTimer
              interval: 2800
              repeat: true
              running: root.opened && root.activeStatus === "downloading"
              onTriggered: activePhraseSwap.restart()
            }

            SequentialAnimation {
              id: activePhraseSwap
              PropertyAnimation { target: activeMeta; property: "opacity"; to: 0.0; duration: 180; easing.type: Easing.OutQuad }
              ScriptAction { script: activeCard.phraseIndex = (activeCard.phraseIndex + 1) % activeCard.phrases.length }
              PropertyAnimation { target: activeMeta; property: "opacity"; to: 1.0; duration: 260; easing.type: Easing.InQuad }
            }

            Row {
              visible: root.activeProgressPercent !== "" || root.activeProgressSize !== ""
              width: parent.width
              spacing: Style.spacing.lg

              BorderSurface {
                id: progressTrack
                width: parent.width - (percentLabel.visible ? percentLabel.implicitWidth + parent.spacing : 0)
                height: Style.spacing.xl
                radius: Style.cornerRadius
                color: Util.alpha(root.contentForeground, 0.12)
                borderSpec: Border.none()
                anchors.verticalCenter: parent.verticalCenter

                BorderSurface {
                  width: parent.width * (root.activeProgressPercentValue / 100)
                  height: parent.height
                  radius: parent.radius
                  color: Color.accent
                  borderSpec: Border.none()

                  Behavior on width { NumberAnimation { duration: 50; easing.type: Easing.Linear } }
                }
              }

              Text {
                textFormat: Text.PlainText
              id: percentLabel
                visible: root.activeProgressPercent !== ""
                text: root.activeProgressPercent
                color: root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.body
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
              }
            }

            Text {
              visible: root.activeProgressSize !== "" || root.activeProgressSpeed !== ""
              width: parent.width
              textFormat: Text.PlainText
              text: [
                root.activeProgressSize,
                root.activeProgressSpeed ? "at " + root.activeProgressSpeed : "",
                root.activeProgressEta ? "· " + root.activeProgressEta + " remaining" : ""
              ].filter(Boolean).join(" ")
              color: Qt.darker(root.contentForeground, 1.5)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.bodySmall
              elide: Text.ElideRight
            }
          }
        }

        Column {
          visible: queueModel.count > 0
          width: parent.width
          spacing: Style.spacing.md

          Text {
            textFormat: Text.PlainText
            text: "QUEUE"
            color: Qt.darker(root.contentForeground, 1.5)
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.caption
            font.letterSpacing: 1
            font.bold: true
          }

          Repeater {
            model: queueModel

            BorderSurface {
              required property int index
              required property string url
              required property string title
              required property string mode

              width: parent.width
              height: queueRow.implicitHeight + Style.spacing.lg
              radius: Style.cornerRadius
              color: Style.controlFill(false, false, root.contentForeground, Color.accent)
              borderSpec: Border.controlSpec("normal", root.contentForeground, Color.accent)

              Row {
                id: queueRow
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Style.spacing.lg
                anchors.rightMargin: Style.spacing.lg
                spacing: Style.spacing.lg

                Text {
                  width: parent.width - modeText.implicitWidth - removeButton.width - parent.spacing * 2
                  textFormat: Text.PlainText
                  text: title || url
                  color: root.contentForeground
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.bodySmall
                  elide: Text.ElideRight
                  anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                  textFormat: Text.PlainText
                  id: modeText
                  text: mode
                  color: Qt.darker(root.contentForeground, 1.6)
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.caption
                  anchors.verticalCenter: parent.verticalCenter
                }

                PanelActionButton {
                  id: removeButton
                  iconText: "✕"
                  foreground: root.contentForeground
                  fontFamily: root.contentFontFamily
                  anchors.verticalCenter: parent.verticalCenter
                  onClicked: root.removeQueued(index)
                }
              }
            }
          }
        }

        Column {
          visible: root.mediaInfo !== null
          width: parent.width
          spacing: Style.spacing.md

          TextField {
            id: downloadDirField
            width: parent.width
            text: root.setting("downloadDir", "")
            placeholderText: "~/Downloads"
            activeFocusOnTab: false
            onEditingFinished: root.setSetting("downloadDir", text)

            Keys.onPressed: function(event) {
              if (event.key === Qt.Key_Escape) {
                keyCatcher.forceActiveFocus()
                event.accepted = true
              }
            }
          }
        }

        Button {
          id: extractButton
          visible: root.mediaInfo === null && root.activeStatus !== "downloading"
          enabled: !root.extracting
          width: parent.width
          text: root.extracting ? "Extracting…" : "Extract"
          active: !root.extracting
          opacity: root.extracting ? 0.7 : 1.0
          foreground: root.contentForeground
          fontFamily: root.contentFontFamily
          onClicked: root.startExtraction()
        }

        Button {
          visible: root.mediaInfo === null && root.activeStatus !== "downloading" && root.activeStatus !== "paused" && !root.extracting && queueModel.count > 0
          width: parent.width
          text: "Run queue (" + queueModel.count + ")"
          foreground: root.contentForeground
          fontFamily: root.contentFontFamily
          onClicked: root.processQueue()
        }

        Item {
          visible: !root.extracting && root.mediaInfo !== null && !root.showingDownloadedCard
          width: parent.width
          height: footerRow.height

          Row {
            id: footerRow
            anchors.bottom: parent.bottom
            width: parent.width
            spacing: Style.spacing.lg

            FooterButton {
              visible: !root.downloadInProgress
              primary: true
              glyph: "\u2b07"
              labelText: root.mediaInfo && root.mediaInfo.isPlaylist ? "Download all" : "Download"
              valueText: Otoru.formatSize(Otoru.estimateSize(root.mediaInfo, root.makeJob()))
              fg: root.contentForeground
              fam: root.contentFontFamily
              width: parent.width - queueButton.width - parent.spacing
              onAct: root.startDownload()
            }

            FooterButton {
              id: queueButton
              glyph: "+"
              labelText: root.downloadInProgress ? "Queue next" : "Queue"
              // Full width while a download runs — Download is hidden then.
              width: root.downloadInProgress ? parent.width : queueButton.implicitWidth
              fg: root.contentForeground
              fam: root.contentFontFamily
              onAct: root.enqueueCurrent()
            }
          }
        }
      }
    }

    ConfirmDialog {
      id: resetConfirm
      anchors.fill: parent
      message: "Reset all settings to their defaults? This clears your download directory, cookies, and other options."
      confirmText: "Reset"
      foreground: root.contentForeground
      fontFamily: root.contentFontFamily
      onConfirmed: {
        resetConfirm.opened = false
        root.settings = root.defaultSettings()
        root.history = []
        root.flushSettings()
      }
      onCanceled: resetConfirm.opened = false
    }
  }
}
