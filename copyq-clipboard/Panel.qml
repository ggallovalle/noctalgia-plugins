import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Services.UI
import qs.Widgets

Item {
    id: root

    focus: true

    property var pluginApi: null

    readonly property var geometryPlaceholder: mainContainer
    readonly property bool allowAttach: true

    property real contentPreferredWidth: 440 * Style.uiScaleRatio

    property var contentPreferredHeight: {
        const _rev = pluginApi?.mainInstance?.itemsRevision ?? 0;
        const count = root.filteredItems.length;
        const scale = Style.uiScaleRatio;
        const overhead = Math.round(180 * scale);
        const maxH = Math.round(560 * scale);
        if (count === 0)
            return Math.min(overhead + Math.round(120 * scale), maxH);
        let contentH;
        if (root.currentTypeFilter === 1 && root.showImagePreviews) {
            const cellW = Math.floor((root.contentPreferredWidth - Math.round(Style.marginL * 2 + Style.marginS)) / 2);
            const rows = Math.ceil(count / 2);
            contentH = rows * Math.floor(cellW * 0.65);
        } else {
            contentH = count * Math.round(44 * scale);
        }
        return Math.min(overhead + contentH + Math.round(8 * scale), maxH);
    }

    property color panelBackgroundColor: Color.mSurface

    readonly property bool showImagePreviews: pluginApi?.pluginSettings?.showImagePreviews ?? true
    readonly property real densitySpacing: {
        const d = pluginApi?.pluginSettings?.density ?? "comfortable";
        if (d === "compact") return Style.marginXS;
        if (d === "spacious") return Style.marginM;
        return Style.marginS;
    }

    property int currentTypeFilter: 0

    property int selectedIndex: -1
    property int _pendingClampIndex: -1

    onFilteredItemsChanged: {
        if (root._pendingClampIndex >= 0) {
            const n = root.filteredItems.length;
            if (n === 0) {
                root.selectedIndex = -1;
            } else {
                root.selectedIndex = Math.min(root._pendingClampIndex, n - 1);
                _positionActiveView();
            }
            root._pendingClampIndex = -1;
            return;
        }
        root.selectedIndex = -1;
    }

    function _positionActiveView() {
        if (root.selectedIndex < 0)
            return;
        if (root.currentTypeFilter === 1) {
            imageGrid.positionViewAtIndex(root.selectedIndex, GridView.Contain);
        } else {
            historyList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
        }
    }

    function _pageStep() {
        if (root.currentTypeFilter === 1) {
            const rows = Math.max(1, Math.floor(imageGrid.height / imageGrid.cellHeight));
            return rows * 2;
        }
        const rowH = Math.max(1, Math.round(44 * Style.uiScaleRatio));
        return Math.max(1, Math.floor(historyList.height / rowH));
    }

    function navigateDown() {
        const n = root.filteredItems.length;
        if (n === 0)
            return;
        if (root.selectedIndex < 0) {
            root.selectedIndex = 0;
        } else {
            root.selectedIndex = Math.min(root.selectedIndex + 1, n - 1);
        }
        _positionActiveView();
    }

    function navigateUp() {
        const n = root.filteredItems.length;
        if (n === 0)
            return;
        if (root.selectedIndex < 0)
            return;
        root.selectedIndex = Math.max(root.selectedIndex - 1, 0);
        _positionActiveView();
    }

    function navigateHome() {
        if (root.filteredItems.length === 0)
            return;
        root.selectedIndex = 0;
        _positionActiveView();
    }

    function navigateEnd() {
        const n = root.filteredItems.length;
        if (n === 0)
            return;
        root.selectedIndex = n - 1;
        _positionActiveView();
    }

    function navigatePageDown() {
        const n = root.filteredItems.length;
        if (n === 0)
            return;
        const step = _pageStep();
        const base = root.selectedIndex < 0 ? -1 : root.selectedIndex;
        root.selectedIndex = Math.min(base + step, n - 1);
        _positionActiveView();
    }

    function navigatePageUp() {
        if (root.filteredItems.length === 0)
            return;
        if (root.selectedIndex < 0)
            return;
        const step = _pageStep();
        root.selectedIndex = Math.max(root.selectedIndex - step, 0);
        _positionActiveView();
    }

    function activateSelection() {
        const n = root.filteredItems.length;
        if (n === 0)
            return;
        const idx = root.selectedIndex >= 0 ? root.selectedIndex : 0;
        const entry = root.filteredItems[idx];
        if (!entry || !entry.id) {
            Logger.w("CopyQ Clipboard Plugin", "activateSelection: no entry at index", idx);
            return;
        }
        root.pluginApi?.mainInstance?.copy(entry.id);
        const typeSlug = entry.type === "file" ? "file"
                       : entry.type === "image" ? "image"
                       : "text";
        ToastService.showNotice(
            root.pluginApi?.tr("toast.item-copied-" + typeSlug + "-title"),
            root.pluginApi?.tr("toast.item-copied-" + typeSlug + "-body")
        );
        closePanelTimer.restart();
    }

    function togglePinSelection() {
        if (root.selectedIndex < 0)
            return;
        const entry = root.filteredItems[root.selectedIndex];
        if (!entry) {
            Logger.w("CopyQ Clipboard Plugin", "togglePinSelection: no entry at index", root.selectedIndex);
            return;
        }
        const main = root.pluginApi?.mainInstance;
        if (!main)
            return;
        if (entry.pinned) {
            if (typeof entry.pinnedIndex === "number" && entry.pinnedIndex >= 0) {
                main.unpin(entry.pinnedIndex);
            } else {
                main.unpinByEntry(entry.preview, entry.type);
            }
            ToastService.showNotice(root.pluginApi?.tr("toast.item-unpinned"));
        } else {
            if (!entry.preview || !entry.type)
                return;
            main.pin({ preview: entry.preview, type: entry.type });
            ToastService.showNotice(root.pluginApi?.tr("toast.item-pinned"));
        }
    }

    function deleteSelection() {
        if (root.selectedIndex < 0)
            return;
        const entry = root.filteredItems[root.selectedIndex];
        if (!entry || !entry.id) {
            Logger.w("CopyQ Clipboard Plugin", "deleteSelection: no entry at index", root.selectedIndex);
            return;
        }
        if (entry.pinned) {
            if (typeof entry.pinnedIndex === "number" && entry.pinnedIndex >= 0) {
                root._pendingClampIndex = root.selectedIndex;
                root.pluginApi?.mainInstance?.unpin(entry.pinnedIndex);
            }
            return;
        }
        root._pendingClampIndex = root.selectedIndex;
        root.pluginApi?.mainInstance?.remove(entry.id);
    }

    function countForType(typeIndex) {
        const _rev = pluginApi?.mainInstance?.itemsRevision ?? 0;
        const _prev = pluginApi?.mainInstance?.pinnedRevision ?? 0;
        const all = pluginApi?.mainInstance?.items ?? [];
        const pinned = pluginApi?.mainInstance?.pinnedItems ?? [];
        const typeMap = ["text", "image", "file"];
        const t = typeMap[typeIndex];
        if (!t)
            return 0;
        return all.filter(item => item.type === t).length
             + pinned.filter(item => item.type === t).length;
    }

    property string searchQuery: ""

    function fuzzyMatch(query, candidate) {
        if (!query || query.length === 0)
            return { matched: true, score: 0 };
        if (!candidate || candidate.length === 0)
            return { matched: false, score: 0 };

        const q = String(query).toLowerCase();
        const c = String(candidate).toLowerCase();

        const idx = c.indexOf(q);
        if (idx !== -1) {
            const offsetPenalty = Math.min(idx, 100);
            const lengthPenalty = Math.min(c.length - q.length, 200) * 0.1;
            return { matched: true, score: 1000 - offsetPenalty - lengthPenalty };
        }

        let score = 0;
        let qi = 0;
        let lastMatchIdx = -2;
        let firstMatchIdx = -1;
        const wordBreak = /[\s\-_\/.]/;

        for (let ci = 0; ci < c.length && qi < q.length; ci++) {
            if (c[ci] === q[qi]) {
                if (firstMatchIdx === -1)
                    firstMatchIdx = ci;
                score += 10;
                if (ci === lastMatchIdx + 1)
                    score += 20;
                if (ci > 0 && wordBreak.test(c[ci - 1]))
                    score += 15;
                lastMatchIdx = ci;
                qi++;
            }
        }

        if (qi < q.length)
            return { matched: false, score: 0 };

        const startPenalty = Math.min(firstMatchIdx, 30);
        return { matched: true, score: score - startPenalty };
    }

    readonly property var filteredItems: {
        const _rev = pluginApi?.mainInstance?.itemsRevision ?? 0;
        const _prev = pluginApi?.mainInstance?.pinnedRevision ?? 0;
        const all = pluginApi?.mainInstance?.items ?? [];
        const pinned = pluginApi?.mainInstance?.pinnedItems ?? [];
        const typeMap = ["text", "image", "file"];
        const t = typeMap[root.currentTypeFilter];
        if (!t)
            return [];
        const pinnedTyped = [];
        for (let i = 0; i < pinned.length; i++) {
            if (pinned[i].type !== t)
                continue;
            pinnedTyped.push({
                id: "pinned:" + i,
                preview: pinned[i].preview,
                type: pinned[i].type,
                pinned: true,
                pinnedIndex: i
            });
        }
        const historyTyped = all
            .filter(item => item.type === t)
            .map(item => ({
                id: item.id,
                preview: item.preview,
                type: item.type,
                pinned: false,
                pinnedIndex: -1
            }));
        const merged = pinnedTyped.concat(historyTyped);
        const q = root.searchQuery;
        if (!q)
            return merged;
        const scored = [];
        for (let i = 0; i < merged.length; i++) {
            const m = root.fuzzyMatch(q, merged[i].preview || "");
            if (m.matched)
                scored.push({ item: merged[i], score: m.score, idx: i });
        }
        scored.sort((a, b) => {
            if (b.score !== a.score)
                return b.score - a.score;
            return a.idx - b.idx;
        });
        return scored.map(e => e.item);
    }

    onVisibleChanged: {
        if (visible) {
            pluginApi?.mainInstance?.refresh();
            searchFocusTimer.restart();
        } else {
            searchDebounceTimer.stop();
            root.searchQuery = "";
            if (searchInput)
                searchInput.text = "";
            root.selectedIndex = -1;
        }
    }

    Timer {
        id: searchFocusTimer
        interval: 0
        repeat: false
        onTriggered: {
            if (!root.visible)
                return;
            if (searchInput && searchInput.visible && searchInput.inputItem)
                searchInput.inputItem.forceActiveFocus();
            else
                root.forceActiveFocus();
        }
    }

    Timer {
        id: searchDebounceTimer
        interval: 150
        repeat: false
        onTriggered: {
            if (searchInput)
                root.searchQuery = searchInput.text;
        }
    }

    Timer {
        id: closePanelTimer
        interval: 50
        repeat: false
        onTriggered: {
            if (!root.pluginApi?.closePanel) {
                Logger.w("CopyQ Clipboard Plugin", "closePanel unavailable");
                return;
            }
            var targetScreen = root.pluginApi.panelOpenScreen;
            var ok = root.pluginApi.closePanel(targetScreen);
            if (!ok) {
                Logger.w("CopyQ Clipboard Plugin", "closePanel returned false");
            }
        }
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_P && (event.modifiers & Qt.ControlModifier)) {
            root.togglePinSelection();
            event.accepted = true;
            return;
        }

        if (searchInput.visible && searchInput.inputItem && !searchInput.inputItem.activeFocus && event.text.length === 1 && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) {
            searchInput.text = event.text;
            searchInput.inputItem.forceActiveFocus();
            event.accepted = true;
            return;
        }

        switch (event.key) {
        case Qt.Key_Down:
            root.navigateDown();
            event.accepted = true;
            return;
        case Qt.Key_Up:
            root.navigateUp();
            event.accepted = true;
            return;
        case Qt.Key_Home:
            root.navigateHome();
            event.accepted = true;
            return;
        case Qt.Key_End:
            root.navigateEnd();
            event.accepted = true;
            return;
        case Qt.Key_PageDown:
            root.navigatePageDown();
            event.accepted = true;
            return;
        case Qt.Key_PageUp:
            root.navigatePageUp();
            event.accepted = true;
            return;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            root.activateSelection();
            event.accepted = true;
            return;
        case Qt.Key_Delete:
            root.deleteSelection();
            event.accepted = true;
            return;
        }

        if (event.key === Qt.Key_Escape) {
            if (root.searchQuery.length > 0 || searchInput.text.length > 0) {
                searchDebounceTimer.stop();
                searchInput.text = "";
                root.searchQuery = "";
                event.accepted = true;
                return;
            }
            closePanelTimer.restart();
            event.accepted = true;
        }
    }

    Item {
        id: mainContainer
        anchors.fill: parent

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Style.marginL
            spacing: Style.marginM

            NBox {
                id: headerBox
                Layout.fillWidth: true
                implicitHeight: headerColumn.implicitHeight + Style.margin2M

                ColumnLayout {
                    id: headerColumn
                    anchors.fill: parent
                    anchors.margins: Style.marginM
                    spacing: Style.marginM

                    RowLayout {
                        id: header
                        Layout.fillWidth: true
                        spacing: Style.marginM

                        NIcon {
                            icon: "clipboard"
                            pointSize: Style.fontSizeXXL
                            color: Color.mPrimary
                        }

                        NText {
                            Layout.fillWidth: true
                            text: root.pluginApi?.tr("panel.title")
                            pointSize: Style.fontSizeL
                            font.weight: Style.fontWeightBold
                            color: Color.mOnSurface
                        }

                        NIconButton {
                            icon: "trash"
                            tooltipText: root.pluginApi?.tr("panel.wipe")
                            baseSize: Style.baseWidgetSize * 0.8
                            enabled: {
                                const _rev = root.pluginApi?.mainInstance?.itemsRevision ?? 0;
                                const items = root.pluginApi?.mainInstance?.items ?? [];
                                return items.length > 0;
                            }
                            onClicked: {
                                root.pluginApi?.mainInstance?.wipe();
                                ToastService.showNotice(root.pluginApi?.tr("toast.history-cleared"));
                                closePanelTimer.restart();
                            }
                        }

                        NIconButton {
                            icon: "settings"
                            tooltipText: root.pluginApi?.tr("panel.settings")
                            baseSize: Style.baseWidgetSize * 0.8
                            onClicked: {
                                BarService.openPluginSettings(root.pluginApi?.panelOpenScreen, root.pluginApi?.manifest);
                            }
                        }
                    }

                    NTabBar {
                        id: typeFilterBar
                        Layout.fillWidth: true
                        visible: {
                            const _rev = pluginApi?.mainInstance?.itemsRevision ?? 0;
                            return (pluginApi?.mainInstance?.items?.length ?? 0) > 0;
                        }
                        currentIndex: root.currentTypeFilter
                        tabHeight: Style.toOdd(Style.baseWidgetSize * 0.8)
                        spacing: Style.marginXS
                        distributeEvenly: true

                        NTabButton {
                            tabIndex: 0
                            text: root.pluginApi?.tr("panel.filter-text-count", { count: root.countForType(0) })
                            checked: typeFilterBar.currentIndex === 0
                            onClicked: root.currentTypeFilter = 0
                            pointSize: Style.fontSizeXS
                        }
                        NTabButton {
                            tabIndex: 1
                            text: root.pluginApi?.tr("panel.filter-images-count", { count: root.countForType(1) })
                            checked: typeFilterBar.currentIndex === 1
                            onClicked: root.currentTypeFilter = 1
                            pointSize: Style.fontSizeXS
                        }
                        NTabButton {
                            tabIndex: 2
                            text: root.pluginApi?.tr("panel.filter-files-count", { count: root.countForType(2) })
                            checked: typeFilterBar.currentIndex === 2
                            onClicked: root.currentTypeFilter = 2
                            pointSize: Style.fontSizeXS
                        }
                    }
                }
            }

            NBox {
                id: copyqWarningBox
                Layout.fillWidth: true
                visible: {
                    const _rev = pluginApi?.mainInstance?.copyQAvailable ?? false;
                    return !(pluginApi?.mainInstance?.copyQAvailable ?? true);
                }
                radius: Style.radiusS
                color: Qt.alpha(Color.mError, 0.15)
                border.color: Color.mError
                border.width: Style.borderS

                NText {
                    anchors.centerIn: parent
                    text: root.pluginApi?.tr("panel.copyq-unavailable")
                    pointSize: Style.fontSizeS
                    color: Color.mError
                }
            }

            NTextInput {
                id: searchInput
                Layout.fillWidth: true
                visible: {
                    const _rev = pluginApi?.mainInstance?.itemsRevision ?? 0;
                    return (pluginApi?.mainInstance?.items?.length ?? 0) > 0;
                }
                label: ""
                description: ""
                inputIconName: "search"
                placeholderText: root.pluginApi?.tr("panel.search-placeholder")
                showClearButton: true

                onTextChanged: searchDebounceTimer.restart()
                onAccepted: {
                    searchDebounceTimer.stop();
                    root.searchQuery = searchInput.text;
                }
                onEditingFinished: {
                    searchDebounceTimer.stop();
                    root.searchQuery = searchInput.text;
                }

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_P && (event.modifiers & Qt.ControlModifier)) {
                        root.togglePinSelection();
                        event.accepted = true;
                        return;
                    }
                    if (event.key === Qt.Key_Escape) {
                        if (searchInput.text.length > 0) {
                            searchDebounceTimer.stop();
                            searchInput.text = "";
                            root.searchQuery = "";
                            event.accepted = true;
                        }
                        return;
                    }
                    if (event.key === Qt.Key_Home) {
                        root.navigateHome();
                        event.accepted = true;
                        return;
                    }
                    if (event.key === Qt.Key_End) {
                        root.navigateEnd();
                        event.accepted = true;
                        return;
                    }
                    if (event.key === Qt.Key_PageUp) {
                        root.navigatePageUp();
                        event.accepted = true;
                        return;
                    }
                    if (event.key === Qt.Key_PageDown) {
                        root.navigatePageDown();
                        event.accepted = true;
                        return;
                    }
                }

                Keys.onUpPressed: event => {
                    root.navigateUp();
                    event.accepted = true;
                }
                Keys.onDownPressed: event => {
                    root.navigateDown();
                    event.accepted = true;
                }
                Keys.onReturnPressed: event => {
                    searchDebounceTimer.stop();
                    root.searchQuery = searchInput.text;
                    root.activateSelection();
                    event.accepted = true;
                }
                Keys.onEnterPressed: event => {
                    searchDebounceTimer.stop();
                    root.searchQuery = searchInput.text;
                    root.activateSelection();
                    event.accepted = true;
                }
            }

            NBox {
                id: emptyBox
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.filteredItems.length === 0

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Style.marginM
                    spacing: Style.marginM

                    Item {
                        Layout.fillHeight: true
                    }

                    RowLayout {
                        spacing: Style.marginM
                        anchors.horizontalCenter: parent.horizontalCenter

                        NIcon {
                            icon: root.searchQuery.length > 0 ? "search-off" : "clipboard-data"
                            pointSize: Style.fontSizeXXL
                            color: Color.mOnSurfaceVariant
                        }

                        NText {
                            text: root.searchQuery.length > 0
                                ? root.pluginApi?.tr("panel.no-matches")
                                : root.pluginApi?.tr("panel.empty")
                            pointSize: Style.fontSizeL
                            color: Color.mOnSurfaceVariant
                        }
                    }

                    Item {
                        Layout.fillHeight: true
                    }
                }
            }

            ListView {
                id: historyList
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.currentTypeFilter !== 1
                model: root.filteredItems
                clip: true
                reuseItems: true

                delegate: ClipboardItem {
                    pluginApi: root.pluginApi
                    entryId: modelData.id
                    previewText: modelData.preview
                    itemType: modelData.type
                    pinned: modelData.pinned
                    pinnedIndex: modelData.pinnedIndex
                    compact: false
                    selected: index === root.selectedIndex
                    width: historyList.width

                    onCopied: closePanelTimer.restart()
                    onDeleted: {}
                }
            }

            GridView {
                id: imageGrid
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.currentTypeFilter === 1 && root.showImagePreviews
                model: root.filteredItems
                clip: true
                reuseItems: true
                cellWidth: Math.floor((root.contentPreferredWidth - Math.round(Style.marginL * 2 + Style.marginS)) / 2)
                cellHeight: Math.floor(cellWidth * 0.65)

                delegate: ClipboardItem {
                    pluginApi: root.pluginApi
                    entryId: modelData.id
                    previewText: modelData.preview
                    itemType: modelData.type
                    pinned: modelData.pinned
                    pinnedIndex: modelData.pinnedIndex
                    compact: true
                    selected: index === root.selectedIndex
                    width: imageGrid.cellWidth
                    height: imageGrid.cellHeight

                    onCopied: closePanelTimer.restart()
                    onDeleted: {}
                }
            }
        }
    }
}