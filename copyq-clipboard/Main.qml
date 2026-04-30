import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

Item {
    id: root

    property var pluginApi: null

    property var items: []
    property int itemsRevision: 0

    property var pinnedItems: []
    property int pinnedRevision: 0

    readonly property string dataDir: (Quickshell.env("HOME") || "") + "/.cache/noctalia/plugins/copyq-clipboard"
    readonly property string pinnedPath: root.dataDir + "/pinned.json"

    property var imageCache: ({})
    property var imageCacheOrder: []
    property int imageCacheRevision: 0
    readonly property int maxImageCacheSize: 50
    property string decodingId: ""
    property var decodeQueue: []

    property var fileMetaCache: ({})
    property var fileMetaOrder: []
    property int fileMetaRevision: 0
    property string metaFetchingId: ""
    property var metaQueue: []

    property var copiedAt: ({})
    property int timeRevision: 0
    property bool copiedAtLoaded: false

    property bool copyQAvailable: false

    function addFileMeta(key, meta) {
        const existing = root.fileMetaOrder.indexOf(key);
        if (existing !== -1) {
            root.fileMetaOrder = root.fileMetaOrder.filter((_, i) => i !== existing);
        }
        while (root.fileMetaOrder.length >= root.maxImageCacheSize) {
            const oldest = root.fileMetaOrder[0];
            root.fileMetaOrder = root.fileMetaOrder.slice(1);
            const next = Object.assign({}, root.fileMetaCache);
            delete next[oldest];
            root.fileMetaCache = next;
        }
        root.fileMetaCache = Object.assign({}, root.fileMetaCache, { [key]: meta });
        root.fileMetaOrder = [...root.fileMetaOrder, key];
        root.fileMetaRevision++;
    }

    function addToImageCache(key, value) {
        const existing = root.imageCacheOrder.indexOf(key);
        if (existing !== -1) {
            root.imageCacheOrder = root.imageCacheOrder.filter((_, i) => i !== existing);
        }
        while (root.imageCacheOrder.length >= root.maxImageCacheSize) {
            const oldest = root.imageCacheOrder[0];
            root.imageCacheOrder = root.imageCacheOrder.slice(1);
            const newCache = Object.assign({}, root.imageCache);
            delete newCache[oldest];
            root.imageCache = newCache;
        }
        root.imageCache = Object.assign({}, root.imageCache, { [key]: value });
        root.imageCacheOrder = [...root.imageCacheOrder, key];
        root.imageCacheRevision++;
    }

    FileView {
        id: copiedAtFile
        path: root.dataDir + "/copied-at.json"
        watchChanges: false
        printErrors: false

        onLoaded: {
            try {
                const txt = String(copiedAtFile.text());
                if (txt.length > 0) {
                    const parsed = JSON.parse(txt);
                    if (parsed && typeof parsed === "object" && !Array.isArray(parsed)) {
                        root.copiedAt = parsed;
                    }
                }
            } catch (e) {
                Logger.w("CopyQ Clipboard Plugin", "copied-at.json parse failed:", e);
            }
            root.copiedAtLoaded = true;
        }

        onLoadFailed: {
            root.copiedAtLoaded = true;
        }
    }

    Process {
        id: copiedAtWriteProc
        stdout: StdioCollector {}
        stderr: StdioCollector {}
    }

    function saveCopiedAt() {
        if (!root.copiedAtLoaded)
            return;
        if (copiedAtWriteProc.running)
            return;
        const payload = JSON.stringify(root.copiedAt || {});
        const target = root.dataDir + "/copied-at.json";
        copiedAtWriteProc.command = ["bash", "-c", 'printf %s "$1" > "$2"', "--", payload, target];
        copiedAtWriteProc.running = true;
    }

    Process {
        id: listProc
        stdout: StdioCollector {}
        stderr: StdioCollector {}

        onExited: exitCode => {
            if (exitCode !== 0) {
                root.items = [];
                root.itemsRevision++;
                return;
            }
            try {
                const raw = String(listProc.stdout.text);
                const lines = raw.length > 0 ? raw.split("\n") : [];
                const parsed = [];
                for (let i = 0; i < lines.length; i++) {
                    const line = lines[i];
                    if (!line)
                        continue;
                    const tab = line.indexOf("\t");
                    if (tab === -1)
                        continue;
                    const idx = line.substring(0, tab);
                    const rest = line.substring(tab + 1);
                    const colon = rest.indexOf("\t");
                    const mime = colon !== -1 ? rest.substring(0, colon) : "text/plain";
                    const preview = colon !== -1 ? rest.substring(colon + 1) : rest;

                    const type = mime.startsWith("image/") ? "image"
                               : (mime.startsWith("text/uri-list") || preview.startsWith("file://") || preview.startsWith("/")) ? "file"
                               : "text";

                    parsed.push({
                        id: idx,
                        preview: preview,
                        type: type
                    });
                }
                root.items = parsed;

                const now = new Date().toISOString();
                const nextCopiedAt = {};
                const prior = root.copiedAt || {};
                for (let j = 0; j < parsed.length; j++) {
                    const id = parsed[j].id;
                    nextCopiedAt[id] = prior[id] || now;
                }
                root.copiedAt = nextCopiedAt;
                root.saveCopiedAt();
            } catch (e) {
                root.items = [];
            }
            root.itemsRevision++;
        }
    }

    Process {
        id: copyProc
        stdout: StdioCollector {}
        stderr: StdioCollector {}
    }

    Process {
        id: removeProc
        stdout: StdioCollector {}
        stderr: StdioCollector {}

        onExited: exitCode => {
            if (exitCode === 0) {
                root.refresh();
            }
        }
    }

    Process {
        id: wipeProc
        stdout: StdioCollector {}
        stderr: StdioCollector {}

        onExited: exitCode => {
            if (exitCode === 0) {
                root.refresh();
            }
        }
    }

    Process {
        id: pinnedDirProc
        stdout: StdioCollector {}
        stderr: StdioCollector {}
    }

    FileView {
        id: pinnedFile
        path: root.pinnedPath
        watchChanges: true
        atomicWrites: true

        onLoaded: {
            try {
                const raw = pinnedFile.text();
                if (!raw || raw.length === 0) {
                    root.pinnedItems = [];
                } else {
                    const data = JSON.parse(raw);
                    if (Array.isArray(data)) {
                        root.pinnedItems = data;
                    } else if (data && Array.isArray(data.items)) {
                        root.pinnedItems = data.items;
                    } else {
                        root.pinnedItems = [];
                    }
                }
            } catch (e) {
                Logger.w("CopyQ Clipboard Plugin", "pinned.json parse failed:", e);
            }
            root.pinnedRevision++;
        }

        onLoadFailed: error => {
            if (error !== 2) {
                Logger.w("CopyQ Clipboard Plugin", "pinned.json load failed:", error);
            }
            root.pinnedItems = [];
            root.pinnedRevision++;
        }
    }

    Process {
        id: metaProc
        stdout: StdioCollector {}
        stderr: StdioCollector {}

        property string pendingPath: ""
        property string pendingFilename: ""
        property string pendingParent: ""

        onExited: exitCode => {
            const id = root.metaFetchingId;
            root.metaFetchingId = "";

            if (id) {
                if (exitCode === 0) {
                    const raw = String(metaProc.stdout.text).trim();
                    const bytes = parseInt(raw, 10);
                    const safeBytes = isNaN(bytes) ? -1 : bytes;
                    root.addFileMeta(id, {
                        filename: metaProc.pendingFilename,
                        parentDir: metaProc.pendingParent,
                        sizeBytes: safeBytes,
                        sizeHuman: safeBytes >= 0 ? root.humanSize(safeBytes) : ""
                    });
                } else {
                    root.addFileMeta(id, {
                        filename: metaProc.pendingFilename,
                        parentDir: metaProc.pendingParent,
                        sizeBytes: -1,
                        sizeHuman: ""
                    });
                }
            }
            root._processNextMeta();
        }
    }

    Process {
        id: decodeProc
        stdout: StdioCollector {}
        stderr: StdioCollector {}

        onExited: exitCode => {
            const id = root.decodingId;
            root.decodingId = "";
            if (exitCode === 0 && id) {
                root.addToImageCache(id, "file:///tmp/copyq-clipboard-" + id + ".png");
            }
            root._processNextDecode();
        }
    }

    Timer {
        id: timeRevisionTimer
        interval: 60000
        repeat: true
        running: true
        onTriggered: root.timeRevision++
    }

    function checkCopyQAvailable() {
        checkProc.command = ["copyq", "size"];
        checkProc.running = true;
    }

    Process {
        id: checkProc
        stdout: StdioCollector {}
        stderr: StdioCollector {}

        onExited: exitCode => {
            root.copyQAvailable = (exitCode === 0);
        }
    }

    function refresh() {
        if (!root.copyQAvailable) {
            checkCopyQAvailable();
            return;
        }
        if (listProc.running)
            return;
        const cap = pluginApi?.pluginSettings?.maxHistorySize ?? 100;
        listProc.command = ["bash", "-c",
            "copyq eval 'var s = size(); var limit = " + cap + "; for (var i = 0; i < s && i < limit; i++) { var img = read(i, \"image/png\"); if (img && img.length > 0) { print(i + \"\\timage/png\\t[[binary \" + img.length + \"]]\"); } else { var txt = str(read(i)); print(i + \"\\ttext/plain\\t\" + txt); } }'"];
        listProc.running = true;
    }

    function copy(id) {
        if (!id)
            return;
        const sid = String(id);
        copyProc.command = ["copyq", "select", sid];
        copyProc.running = true;
    }

    function remove(id) {
        if (!id)
            return;
        const sid = String(id);
        removeProc.command = ["copyq", "remove", sid];
        removeProc.running = true;
    }

    function wipe() {
        wipeProc.command = ["bash", "-c", "copyq eval 'while(size() > 0) remove(0)'"];
        wipeProc.running = true;
    }

    IpcHandler {
        target: "plugin:copyq-clipboard"

        function toggle() {
            root.pluginApi?.withCurrentScreen(screen => {
                root.pluginApi?.togglePanel(screen);
            });
        }

        function wipe() {
            root.wipe();
        }
    }

    function isPinned(preview, type) {
        const list = root.pinnedItems || [];
        for (let i = 0; i < list.length; i++) {
            if (list[i].preview === preview && list[i].type === type)
                return true;
        }
        return false;
    }

    function _savePinned() {
        const body = JSON.stringify({ items: root.pinnedItems }, null, 2);
        pinnedFile.setText(body);
    }

    function pin(entry) {
        if (!entry || !entry.preview || !entry.type)
            return;
        if (root.isPinned(entry.preview, entry.type))
            return;

        let content = entry.preview;
        if (entry.type === "image") {
            const cachedPath = root.imageCache[entry.id];
            if (cachedPath) {
                content = cachedPath;
            } else {
                content = entry.preview;
            }
        } else if (entry.type === "file") {
            const uri = entry.preview.indexOf("file://") === 0 ? entry.preview : "file://" + entry.preview;
            content = uri;
        }

        const record = { preview: entry.preview, type: entry.type, content: content };
        root.pinnedItems = [...root.pinnedItems, record];
        root.pinnedRevision++;
        root._savePinned();
    }

    function unpin(index) {
        const list = root.pinnedItems || [];
        if (index < 0 || index >= list.length)
            return;
        root.pinnedItems = list.filter((_, i) => i !== index);
        root.pinnedRevision++;
        root._savePinned();
    }

    function unpinByEntry(preview, type) {
        const list = root.pinnedItems || [];
        for (let i = 0; i < list.length; i++) {
            if (list[i].preview === preview && list[i].type === type) {
                root.unpin(i);
                return;
            }
        }
    }

    function copyPinned(index) {
        const list = root.pinnedItems || [];
        if (index < 0 || index >= list.length)
            return;
        const entry = list[index];
        const preview = String(entry.preview || "");
        const type = String(entry.type || "text");
        const content = String(entry.content || "");

        if (type === "image") {
            const path = content.startsWith("file://") ? content.substring(7) : content;
            copyProc.command = ["bash", "-c", 'copyq copy image/png - < "$1"', "--", path];
        } else if (type === "file") {
            const uri = preview.indexOf("file://") === 0 ? preview : "file://" + preview;
            copyProc.command = ["bash", "-c",
                'printf "copy\n%s\n" "$1" | copyq write -', "--", uri];
        } else {
            copyProc.command = ["bash", "-c", 'copyq copy - <<< "$1"', "--", content];
        }
        copyProc.running = true;
    }

    function getImage(id) {
        if (!pluginApi?.pluginSettings?.showImagePreviews)
            return;
        if (root.imageCache[id])
            return;
        if (root.decodeQueue.indexOf(id) !== -1 || root.decodingId === id)
            return;
        root.decodeQueue = [...root.decodeQueue, id];
        root._processNextDecode();
    }

    function _processNextDecode() {
        if (decodeProc.running || root.decodeQueue.length === 0)
            return;
        const sid = root.decodeQueue[0];
        root.decodeQueue = root.decodeQueue.slice(1);
        root.decodingId = sid;
        decodeProc.command = ["bash", "-c",
            "copyq read " + sid + " image/png > /tmp/copyq-clipboard-" + sid + ".png 2>/dev/null || true"];
        decodeProc.running = true;
    }

    function getFileMeta(id) {
        if (root.fileMetaCache[id])
            return;
        if (root.metaQueue.indexOf(id) !== -1 || root.metaFetchingId === id)
            return;
        root.metaQueue = [...root.metaQueue, id];
        root._processNextMeta();
    }

    function _processNextMeta() {
        if (metaProc.running || root.metaQueue.length === 0)
            return;
        const sid = root.metaQueue[0];
        root.metaQueue = root.metaQueue.slice(1);

        let entry = null;
        for (let i = 0; i < root.items.length; i++) {
            if (root.items[i].id === sid) {
                entry = root.items[i];
                break;
            }
        }
        if (!entry) {
            root._processNextMeta();
            return;
        }

        const path = root.fileUriToPath(entry.preview);
        if (!path) {
            root.addFileMeta(sid, { filename: "", parentDir: "", sizeBytes: -1, sizeHuman: "" });
            root._processNextMeta();
            return;
        }

        const parts = root.splitPath(path);
        root.metaFetchingId = sid;
        root.metaProc.pendingPath = path;
        root.metaProc.pendingFilename = parts.filename;
        root.metaProc.pendingParent = parts.parentDir;
        metaProc.command = ["stat", "-c", "%s", "--", path];
        metaProc.running = true;
    }

    function fileUriToPath(uri) {
        if (!uri || typeof uri !== "string")
            return "";
        if (uri.indexOf("/") === 0)
            return uri;
        const prefix = "file://";
        if (uri.indexOf(prefix) !== 0)
            return "";
        let rest = uri.substring(prefix.length);
        const slash = rest.indexOf("/");
        if (slash > 0) {
            rest = rest.substring(slash);
        }
        try {
            return decodeURIComponent(rest);
        } catch (e) {
            return rest;
        }
    }

    function splitPath(path) {
        if (!path)
            return { filename: "", parentDir: "" };
        const last = path.lastIndexOf("/");
        if (last === -1)
            return { filename: path, parentDir: "" };
        const filename = path.substring(last + 1);
        let parent = path.substring(0, last);
        if (parent === "")
            parent = "/";
        const home = Quickshell.env("HOME") || "";
        if (home && parent === home) {
            parent = "~";
        } else if (home && parent.indexOf(home + "/") === 0) {
            parent = "~" + parent.substring(home.length);
        }
        return { filename: filename, parentDir: parent };
    }

    function formatRelativeTime(iso) {
        if (!iso || typeof iso !== "string")
            return "";
        const t = Date.parse(iso);
        if (isNaN(t))
            return "";
        const now = Date.now();
        const diffSec = Math.floor((now - t) / 1000);
        if (diffSec < 60)
            return root.pluginApi?.tr("time.just-now");
        if (diffSec < 3600) {
            const mins = Math.floor(diffSec / 60);
            return root.pluginApi?.tr("time.minutes-ago", { minutes: mins });
        }
        const then = new Date(t);
        const nowDate = new Date(now);
        const sameDay = then.getFullYear() === nowDate.getFullYear()
                     && then.getMonth() === nowDate.getMonth()
                     && then.getDate() === nowDate.getDate();
        if (sameDay) {
            const hours = Math.floor(diffSec / 3600);
            return root.pluginApi?.tr("time.hours-ago", { hours: hours });
        }
        const yesterday = new Date(nowDate.getFullYear(), nowDate.getMonth(), nowDate.getDate() - 1);
        const isYesterday = then.getFullYear() === yesterday.getFullYear()
                         && then.getMonth() === yesterday.getMonth()
                         && then.getDate() === yesterday.getDate();
        if (isYesterday)
            return root.pluginApi?.tr("time.yesterday");
        const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                        "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
        const monStr = months[then.getMonth()];
        const dayStr = String(then.getDate());
        if (then.getFullYear() === nowDate.getFullYear())
            return monStr + " " + dayStr;
        return monStr + " " + dayStr + ", " + then.getFullYear();
    }

    function humanSize(bytes) {
        if (bytes < 0)
            return "";
        if (bytes < 1024)
            return bytes + " B";
        const units = ["KB", "MB", "GB", "TB"];
        let value = bytes / 1024;
        let i = 0;
        while (value >= 1024 && i < units.length - 1) {
            value /= 1024;
            i++;
        }
        const formatted = value < 10 ? value.toFixed(1) : Math.round(value).toString();
        return formatted + " " + units[i];
    }

    Component.onDestruction: {
        listProc.running = false;
        copyProc.running = false;
        removeProc.running = false;
        wipeProc.running = false;
        decodeProc.running = false;
        metaProc.running = false;
    }

    onPluginApiChanged: {
        if (pluginApi) {
            pinnedDirProc.command = ["bash", "-c", "mkdir -p \"" + root.dataDir + "\""];
            pinnedDirProc.running = true;
            checkCopyQAvailable();
        }
    }
}