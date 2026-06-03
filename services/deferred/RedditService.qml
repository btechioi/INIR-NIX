pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.services
import "root:"

/**
 * RedditService - Reddit public JSON API
 * No auth required for public subreddits
 */
Singleton {
    id: root

    // Rate limiting: ~60 requests/minute without auth
    property int requestDelay: 1000
    property bool _canRequest: true
    
    // Data
    property var posts: []
    property string currentSubreddit: "unixporn"
    property string currentSort: "hot"  // hot, new, top
    
    // State
    property bool loading: false
    property string lastError: ""
    
    // Cache
    property var _cache: ({})
    property var _cacheTimestamps: ({})
    readonly property int cacheValidityMs: 5 * 60 * 1000  // 5 minutes
    
    // Config - use function to always get fresh value
    readonly property var defaultSubreddits: ["unixporn", "linux", "archlinux", "kde", "gnome"]

    // Cookie file for Cloudflare bypass (export cookies from browser)
    readonly property string _cookieFile: Config.options?.services?.reddit?.cookieFile
        ?? Directories.shellConfig + "/services/deferred/reddit_cookies.txt"

    property var _pendingCallbacks: []
    property Process _proc: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                const cb = root._pendingCallbacks.shift()
                if (!cb) return
                root._canRequest = true
                if (text.length === 0) {
                    cb(null, "Empty response")
                    return
                }
                try {
                    const response = JSON.parse(text)
                    cb(response.data?.children ?? [], null)
                } catch (e) {
                    cb(null, "Parse error")
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.length > 0 && root._pendingCallbacks.length > 0) {
                    const cb = root._pendingCallbacks.shift()
                    root._canRequest = true
                    cb(null, text.trim())
                }
            }
        }
    }

    Timer {
        id: _timeoutTimer
        interval: 20000
        onTriggered: {
            if (root._pendingCallbacks.length > 0) {
                const cb = root._pendingCallbacks.shift()
                root._canRequest = true
                if (cb) cb(null, "Request timed out")
            }
        }
    }
    
    function getSubreddits() {
        return Config.options?.sidebar?.reddit?.subreddits ?? root.defaultSubreddits
    }
    
    function _makeRequest(url, callback) {
        if (!root._canRequest) {
            Qt.callLater(() => root._makeRequest(url, callback))
            return
        }
        
        root._canRequest = false
        root._pendingCallbacks.push(callback)
        _timeoutTimer.restart()

        const ua = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36"
        root._proc.command = [
            "/usr/bin/curl", "-s", "-L", "--max-time", "15",
            "--cookie", root._cookieFile,
            "-H", "User-Agent: " + ua,
            "-H", "Accept: application/json, text/plain, */*",
            "-H", "Accept-Language: en-US,en;q=0.9",
            "-H", "Referer: https://www.reddit.com/",
            url
        ]
        root._proc.running = true
    }
    
    function _isCacheValid(key) {
        const timestamp = root._cacheTimestamps[key]
        if (!timestamp) return false
        return (Date.now() - timestamp) < root.cacheValidityMs
    }
    
    function fetchPosts(subreddit, sort) {
        const sub = subreddit ?? root.currentSubreddit
        const s = sort ?? root.currentSort
        const cacheKey = sub + "_" + s
        
        if (root._isCacheValid(cacheKey) && root._cache[cacheKey]) {
            root.posts = root._cache[cacheKey]
            root.currentSubreddit = sub
            root.currentSort = s
            return
        }
        
        root.loading = true
        root.lastError = ""
        root.currentSubreddit = sub
        root.currentSort = s
        
        const limit = Config.options?.sidebar?.reddit?.limit ?? 25
        const url = `https://www.reddit.com/r/${sub}/${s}.json?limit=${limit}&raw_json=1`
        
        root._makeRequest(url, (children, error) => {
            root.loading = false
            if (error) {
                root.lastError = error
                return
            }
            
            const normalized = children.map(child => root._normalizePost(child.data))
            root._cache[cacheKey] = normalized
            root._cacheTimestamps[cacheKey] = Date.now()
            root.posts = normalized
        })
    }
    
    function _normalizePost(post) {
        // Get best thumbnail - use raw thumbnail first, then preview
        let thumbnail = ""
        
        // First try the direct thumbnail (usually works better)
        if (post.thumbnail && post.thumbnail.startsWith("http")) {
            thumbnail = post.thumbnail
        }
        // Then try preview images
        else if (post.preview?.images?.[0]?.resolutions) {
            const resolutions = post.preview.images[0].resolutions
            const medium = resolutions.find(r => r.width >= 320) ?? resolutions[resolutions.length - 1]
            thumbnail = medium?.url ?? ""
        }
        
        // Decode any HTML entities just in case
        thumbnail = root._decodeHtml(thumbnail)
        
        return {
            id: post.id,
            title: root._decodeHtml(post.title),
            author: post.author,
            subreddit: post.subreddit,
            score: post.score,
            numComments: post.num_comments,
            created: post.created_utc,
            url: post.url,
            permalink: "https://reddit.com" + post.permalink,
            thumbnail: thumbnail,
            isVideo: post.is_video,
            isNsfw: post.over_18,
            isSelf: post.is_self,
            selftext: post.selftext ?? "",
            flair: post.link_flair_text ?? "",
            domain: post.domain
        }
    }
    
    function _decodeHtml(html) {
        if (!html) return ""
        return html.replace(/&amp;/g, "&").replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, '"').replace(/&#39;/g, "'")
    }
    
    function formatScore(score) {
        if (score >= 1000000) return (score / 1000000).toFixed(1) + "M"
        if (score >= 1000) return (score / 1000).toFixed(1) + "k"
        return score.toString()
    }
    
    function formatTime(timestamp) {
        const now = Date.now() / 1000
        const diff = now - timestamp
        if (diff < 3600) return Math.floor(diff / 60) + "m"
        if (diff < 86400) return Math.floor(diff / 3600) + "h"
        if (diff < 604800) return Math.floor(diff / 86400) + "d"
        return Math.floor(diff / 604800) + "w"
    }
    
    function refresh() {
        root._cache = {}
        root._cacheTimestamps = {}
        root.fetchPosts()
    }
    
    function openPost(post) {
        root._openUrlFocusBrowser(post.permalink)
    }
    
    function openImage(post) {
        root._openUrlFocusBrowser(post.url)
    }
    
    function _openUrlFocusBrowser(url) {
        // Try to focus existing browser window first
        if (typeof NiriService !== "undefined" && NiriService.windows) {
            const browserPatterns = ["firefox", "chromium", "chrome", "brave", "zen", "librewolf", "vivaldi", "opera"]
            const windows = NiriService.windows ?? []
            for (let i = 0; i < windows.length; i++) {
                const win = windows[i]
                const appId = (win.app_id ?? "").toLowerCase()
                if (browserPatterns.some(p => appId.includes(p))) {
                    NiriService.focusWindow(win.id)
                    break
                }
            }
        }
        Qt.openUrlExternally(url)
    }
}
