.pragma library

function looksLikeUrl(text) {
  return /^https?:\/\/\S+/i.test(String(text || ""))
}

function expandHome(path, home) {
  var p = String(path || "")
  if (p.indexOf("~") === 0) {
    return (home || "") + p.substring(1)
  }
  return p
}

function cookiesFromBrowserArg(settings) {
  var browser = String(settings.cookiesFromBrowser || "").trim().toLowerCase()
  if (!browser) return null
  var profile = String(settings.cookiesProfile || "").trim()
  if (profile) return browser + ":" + profile
  return browser
}

function formatDuration(totalSeconds) {
  var s = Math.max(0, Math.floor(Number(totalSeconds) || 0))
  var h = Math.floor(s / 3600)
  var m = Math.floor((s % 3600) / 60)
  var r = s % 60
  var parts = []
  if (h > 0) parts.push(String(h))
  parts.push(String(h > 0 ? m : m).padStart(h > 0 ? 2 : 1, "0"))
  parts.push(String(r).padStart(2, "0"))
  return parts.join(":")
}

function parseInfo(raw) {
  try {
    var info = JSON.parse(String(raw || "{}"))
    if (!info || typeof info !== "object") return null

    var formats = Array.isArray(info.formats) ? info.formats : []
    var heights = []
    var hasAudio = false
    for (var i = 0; i < formats.length; i++) {
      var f = formats[i]
      if (f && f.height && Number(f.height) > 0) heights.push(Number(f.height))
      if (f && f.acodec && String(f.acodec).toLowerCase() !== "none") hasAudio = true
    }

    var thumbnail = ""
    if (info.thumbnail) {
      thumbnail = String(info.thumbnail)
    } else if (Array.isArray(info.thumbnails) && info.thumbnails.length > 0) {
      var last = info.thumbnails[info.thumbnails.length - 1]
      thumbnail = last && last.url ? String(last.url) : ""
    }

    return {
      title: String(info.title || "Unknown title"),
      thumbnail: thumbnail,
      duration: Number(info.duration) || 0,
      uploader: String(info.uploader || info.channel || info.artist || ""),
      formats: formats,
      hasAudio: hasAudio,
      maxHeight: heights.length > 0 ? Math.max.apply(null, heights) : 0,
      extractor: String(info.extractor || "")
    }
  } catch (e) {
    return null
  }
}

function availableVideoQualities(maxHeight) {
  var thresholds = [1080, 720, 480]
  var out = []
  for (var i = 0; i < thresholds.length; i++) {
    if (maxHeight >= thresholds[i]) out.push(String(thresholds[i]))
  }
  return out
}

function progressTemplate() {
  // Use a non-default prefix ("progress:") because yt-dlp treats the literal
  // string "download:" as the default [download] prefix and strips it.
  return "progress:%(progress._percent_str)s|%(progress._speed_str)s|%(progress._eta_str)s|%(progress._downloaded_bytes_str)s|%(progress._total_bytes_str)s|%(progress._total_bytes_estimate_str)s"
}

function stripAnsi(s) {
  return String(s || "").replace(/\x1b\[[0-9;]*m/g, "")
}

function parseProgressLine(line) {
  var prefix = "progress:"
  var s = stripAnsi(line || "")
  if (!s.startsWith(prefix)) return null
  var parts = s.substring(prefix.length).split("|")

  function field(i) {
    var v = parts[i] ? parts[i].trim() : ""
    if (!v || v === "NA" || v.indexOf("Unknown") >= 0) return ""
    return v
  }

  var percentText = field(0)
  var percent = 0
  if (percentText) {
    var n = parseFloat(percentText.replace("%", ""))
    if (!isNaN(n)) percent = Math.max(0, Math.min(100, n))
  }

  var downloaded = field(3)
  var total = field(4) || field(5) // prefer known total, fallback to estimate

  return {
    percent: percent,
    percentText: percentText,
    speed: field(1),
    eta: field(2),
    downloaded: downloaded,
    total: total,
    sizeText: downloaded && total ? downloaded + " / " + total : downloaded
  }
}

function infoCommand(url, proxy, useWebClient, settings, home) {
  var args = ["yt-dlp", "--no-warnings", "--dump-single-json", "--skip-download"]
  if (useWebClient) args.push("--extractor-args", "youtube:player_client=web")
  if (proxy && String(proxy).trim()) args.push("--proxy", String(proxy).trim())
  var browserCookies = cookiesFromBrowserArg(settings)
  if (browserCookies) {
    args.push("--cookies-from-browser", browserCookies)
  } else if (settings && settings.cookies && String(settings.cookies).trim()) {
    args.push("--cookies", expandHome(String(settings.cookies).trim(), home))
  }
  args.push(String(url))
  return args
}

function versionCommand() {
  return ["yt-dlp", "--version"]
}

function ffmpegVersionCommand() {
  return ["ffmpeg", "-version"]
}

function clipCommand() {
  return ["wl-paste", "--no-newline"]
}

function mkdirCommand(dir, home) {
  return ["mkdir", "-p", expandHome(dir, home)]
}

function splitCustomArgs(argString) {
  var s = String(argString || "").trim()
  if (!s) return []
  return s.split(/\s+/).filter(function(t) { return t !== "" })
}

function buildDownloadArgs(job, settings, home, useWebClient) {
  // yt-dlp writes progress to stderr. We wrap it with sh so stderr is merged
  // into stdout, and set PYTHONUNBUFFERED=1 so output is flushed live.
  // This way the panel reads progress lines from the same stdout SplitParser
  // that already works for the info process.
  var args = ["yt-dlp", "--newline", "--no-warnings", "--no-colors", "--progress", "--progress-delta", "0.3", "--progress-template", progressTemplate()]
  if (useWebClient) args.push("--extractor-args", "youtube:player_client=web")

  var outDir = expandHome(settings.downloadDir, home)
  args.push("-P", outDir)

  if (settings.outputTemplate && String(settings.outputTemplate).trim()) {
    args.push("-o", String(settings.outputTemplate).trim())
  }
  if (settings.proxy && String(settings.proxy).trim()) {
    args.push("--proxy", String(settings.proxy).trim())
  }
  var browserCookies = cookiesFromBrowserArg(settings)
  if (browserCookies) {
    args.push("--cookies-from-browser", browserCookies)
  } else if (settings.cookies && String(settings.cookies).trim()) {
    args.push("--cookies", expandHome(String(settings.cookies).trim(), home))
  }
  if (settings.rateLimit && String(settings.rateLimit).trim()) {
    args.push("--limit-rate", String(settings.rateLimit).trim())
  }
  if (settings.concurrentFragments && String(settings.concurrentFragments).trim()) {
    args.push("--concurrent-fragments", String(settings.concurrentFragments).trim())
  }
  if (settings.customArgs && String(settings.customArgs).trim()) {
    args = args.concat(splitCustomArgs(settings.customArgs))
  }

  var mode = job.mode || "best"
  if (mode === "audio") {
    args.push("-x")
    var af = job.audioFormat || settings.audioFormat || "best"
    if (af && String(af) !== "best") args.push("--audio-format", String(af))
  } else if (mode === "custom") {
    var sel = settings.customFormatSelector ? String(settings.customFormatSelector).trim() : ""
    if (sel) args.push("-f", sel)
  } else if (mode === "video") {
    var q = job.quality || "best"
    if (q !== "best") {
      args.push("-f", "bestvideo[height<=" + q + "]+bestaudio/best[height<=" + q + "]")
    }
  }

  args.push(String(job.url))

  return ["sh", "-c", "exec env PYTHONUNBUFFERED=1 \"$@\" 2>&1", "otoru-dl"].concat(args)
}

function friendlyError(stderr, exitCode, exitStatus) {
  var s = String(stderr || "")
  if (exitStatus !== 0) return "Download cancelled."
  if (exitCode === 127 || s.toLowerCase().indexOf("command not found") >= 0 || s.indexOf("yt-dlp: not found") >= 0) {
    return "yt-dlp is not installed or not on PATH."
  }
  if (s.toLowerCase().indexOf("ffmpeg") >= 0) {
    return "ffmpeg is required for this download. Please install ffmpeg."
  }
  if (s.indexOf("Unsupported URL") >= 0) {
    return "Unsupported website or URL."
  }
  if (/sign in|login|authentication|auth required|authenticate/i.test(s)) {
    return "Authentication required."
  }
  if (/private|removed|unavailable|not available|blocked|copyright|age restricted/i.test(s)) {
    return "Media unavailable."
  }
  if (/requested format|format not available/i.test(s)) {
    return "Selected format unavailable."
  }
  if (/403|forbidden|access denied/i.test(s)) {
    return "Access denied (HTTP 403). Try updating yt-dlp, using cookies, or retry as web client."
  }
  if (/not available in your country|geo.*restrict|this content is not available/i.test(s)) {
    return "Geo-blocked in your region."
  }
  if (/certificate verify failed|ssl/i.test(s)) {
    return "SSL/TLS certificate error."
  }
  if (/http error|timed out|temporary failure|network|could not send|connection/i.test(s)) {
    return "Network error."
  }
  var first = s.split("\n")[0] || ""
  return "Download failed" + (first ? ": " + first : "")
}

function guessOutputPath(settings, job, info, home) {
  var dir = expandHome(settings.downloadDir, home)
  var title = info && info.title ? String(info.title).replace(/[\/\\?%*:|"<>]/g, "_") : "download"
  var ext = ""
  if (job.mode === "audio") {
    var af = job.audioFormat || settings.audioFormat || "best"
    ext = af === "best" ? ".%(ext)s" : "." + af
  } else {
    ext = ".%(ext)s"
  }
  return dir + "/" + title + ext
}
