// Node self-check for OtoruModel.js normalization helpers.
// Run: node tests/normalize.test.js
const fs = require("fs")
const path = require("path")

const src = fs
  .readFileSync(path.join(__dirname, "..", "OtoruModel.js"), "utf8")
  .replace(/^\.pragma library\s*/, "")

const { cleanUrlText, looksLikeUrl, isSearchQuery, parseInfo } = new Function(
  src + "\nreturn { cleanUrlText, looksLikeUrl, isSearchQuery, parseInfo }"
)()

function eq(name, got, want) {
  if (got !== want) {
    console.error("FAIL " + name + ": got " + JSON.stringify(got) + ", want " + JSON.stringify(want))
    process.exit(1)
  }
  console.log("ok " + name)
}

eq("bare host prefixed", cleanUrlText("youtube.com/watch?v=abc"), "https://youtube.com/watch?v=abc")
eq("www bare host", cleanUrlText("www.example.com/x"), "https://www.example.com/x")
eq("scheme-less youtu.be", cleanUrlText("youtu.be/abc"), "https://youtu.be/abc")
eq("already https", cleanUrlText("https://youtu.be/abc"), "https://youtu.be/abc")
eq("prose extraction", cleanUrlText("watch this https://youtu.be/abc !!"), "https://youtu.be/abc")
eq("trailing period", cleanUrlText("https://youtu.be/abc."), "https://youtu.be/abc")
eq("trailing close paren", cleanUrlText("see (https://x.com/a)"), "https://x.com/a")
eq("trailing comma+period", cleanUrlText("https://x.com/a,."), "https://x.com/a")
eq("query string kept", cleanUrlText("https://x.com/a?t=30"), "https://x.com/a?t=30")
eq("empty", cleanUrlText(""), "")
eq("spaces only", cleanUrlText("   "), "")
eq("plain text", cleanUrlText("never gonna give you up"), "")
eq("ytsearch passthrough", cleanUrlText("ytsearch1:never gonna"), "ytsearch1:never gonna")
eq("looksLikeUrl bare", looksLikeUrl("youtu.be/abc"), true)
eq("looksLikeUrl prose", looksLikeUrl("check https://x.com/a now"), true)
eq("looksLikeUrl query", looksLikeUrl("never gonna"), false)
eq("isSearchQuery plain", isSearchQuery("never gonna give you up"), true)
eq("isSearchQuery url", isSearchQuery("https://x.com"), false)
eq("isSearchQuery explicit ytsearch", isSearchQuery("ytsearch1:never gonna"), false)
eq("isSearchQuery empty", isSearchQuery(""), false)

eq("parseInfo single full entry unwraps", (function() {
  var raw = JSON.stringify({
    _type: "playlist",
    title: "ado",
    playlist_count: 1,
    entries: [{
      id: "4IKHox-DKrM",
      title: "Monstruo",
      duration: 180,
      thumbnail: "https://i.ytimg.com/vi_webp/4IKHox-DKrM/maxresdefault.webp",
      webpage_url: "https://www.youtube.com/watch?v=4IKHox-DKrM",
      formats: [{ height: 1080, vcodec: "avc1", acodec: "mp4a" }]
    }]
  })
  var r = parseInfo(raw)
  return r && !r.isPlaylist && r.title === "Monstruo" && r.webpage_url === "https://www.youtube.com/watch?v=4IKHox-DKrM"
})(), true)

eq("parseInfo stub playlist stays playlist", (function() {
  var raw = JSON.stringify({
    _type: "playlist",
    title: "Mix",
    playlist_count: 10,
    entries: [{ id: "a", url: "https://youtu.be/a" }, { id: "b", url: "https://youtu.be/b" }]
  })
  var r = parseInfo(raw)
  return r && r.isPlaylist && r.count === 10 && r.title === "Mix"
})(), true)

eq("parseInfo single video direct", (function() {
  var raw = JSON.stringify({ id: "x", title: "Direct", thumbnail: "https://x.com/t.jpg", formats: [{ height: 720, vcodec: "vp9", acodec: "opus" }] })
  var r = parseInfo(raw)
  return r && !r.isPlaylist && r.title === "Direct" && r.thumbnail === "https://x.com/t.jpg" && r.maxHeight === 720
})(), true)

eq("parseInfo garbage", parseInfo("not json"), null)

eq("parseInfo webp thumbnail rewritten", (function() {
  var raw = JSON.stringify({ id: "x", title: "T", thumbnail: "https://i.ytimg.com/vi_webp/x/maxresdefault.webp", formats: [] })
  var r = parseInfo(raw)
  return r && r.thumbnail === "https://i.ytimg.com/vi/x/maxresdefault.jpg"
})(), true)

console.log("all pass")
