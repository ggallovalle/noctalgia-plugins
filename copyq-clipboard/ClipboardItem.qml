import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Services.UI
import qs.Widgets

Item {
    id: card

    property var pluginApi: null
    property string entryId: ""
    property string previewText: ""
    property string itemType: "text"
    property bool pinned: false
    property int pinnedIndex: -1
    property bool compact: false
    property bool selected: false

    readonly property bool renderAsImage: card.itemType === "image"
        && !card.pinned
        && (card.pluginApi?.pluginSettings?.showImagePreviews ?? true)

    readonly property bool renderAsFile: card.itemType === "file" && !card.compact

    readonly property string relativeTimeText: {
        const _rev = card.pluginApi?.mainInstance?.timeRevision ?? 0;
        const _irev = card.pluginApi?.mainInstance?.itemsRevision ?? 0;
        const main = card.pluginApi?.mainInstance;
        if (!main || !card.entryId)
            return "";
        if (card.pinned)
            return "";
        const iso = main.copiedAt?.[card.entryId];
        if (!iso)
            return "";
        return main.formatRelativeTime(iso);
    }

    readonly property var fileMeta: {
        const _rev = card.pluginApi?.mainInstance?.fileMetaRevision ?? 0;
        const cached = card.pluginApi?.mainInstance?.fileMetaCache?.[card.entryId];
        if (cached)
            return cached;
        const main = card.pluginApi?.mainInstance;
        if (!main || !card.previewText)
            return { filename: "", parentDir: "", sizeBytes: -1, sizeHuman: "" };
        const path = main.fileUriToPath(card.previewText);
        if (!path)
            return { filename: card.previewText, parentDir: "", sizeBytes: -1, sizeHuman: "" };
        const parts = main.splitPath(path);
        return {
            filename: parts.filename,
            parentDir: parts.parentDir,
            sizeBytes: -1,
            sizeHuman: ""
        };
    }

    function _requestDecode() {
        if (card.pinned)
            return;
        if (card.renderAsImage && card.entryId) {
            card.pluginApi?.mainInstance?.getImage(card.entryId);
        }
        if (card.renderAsFile && card.entryId) {
            card.pluginApi?.mainInstance?.getFileMeta(card.entryId);
        }
    }
    onEntryIdChanged: _requestDecode()
    onRenderAsImageChanged: _requestDecode()
    onRenderAsFileChanged: _requestDecode()

    signal copied()
    signal deleted()
    signal requestContextMenu(var itemData, point position, var anchorItem)

    property bool pressed: false
    property bool expanded: false
    property bool showContextMenu: false
    property point contextMenuPosition: Qt.point(0, 0)

    readonly property bool canExpand: card.itemType === "text" && !card.renderAsImage && !card.renderAsFile && !card.compact

    readonly property real contentHeight: {
        const baseHeight = Math.round(44 * Style.uiScaleRatio);
        if (!card.expanded || !card.canExpand)
            return baseHeight;
        const lineHeight = Style.fontSizeM * 1.5;
        const lines = Math.min(10, Math.ceil(previewLabel.paintedHeight / lineHeight));
        const extraHeight = (lines - 1) * lineHeight;
        return baseHeight + extraHeight;
    }

    function toggleExpand() {
        if (card.canExpand) {
            card.expanded = !card.expanded;
        }
    }

    function handleAction(action) {
        const main = card.pluginApi?.mainInstance;
        if (!main) return;
        
        switch(action) {
            case "copy":
                if (card.pinned && card.pinnedIndex >= 0) {
                    main.copyPinned(card.pinnedIndex);
                } else {
                    main.copy(card.entryId);
                }
                const typeSlug = card.itemType === "file" ? "file"
                               : card.itemType === "image" ? "image"
                               : "text";
                ToastService.showNotice(
                    card.pluginApi?.tr("toast.item-copied-" + typeSlug + "-title"),
                    card.pluginApi?.tr("toast.item-copied-" + typeSlug + "-body")
                );
                card.copied();
                break;
                
            case "copy-close":
                if (card.pinned && card.pinnedIndex >= 0) {
                    main.copyPinned(card.pinnedIndex);
                } else {
                    main.copy(card.entryId);
                }
                card.copied();
                if (!card.pluginApi?.closePanel) return;
                var targetScreen = card.pluginApi.panelOpenScreen;
                card.pluginApi.closePanel(targetScreen);
                break;
                
            case "pin":
                main.pin({ preview: card.previewText, type: card.itemType });
                break;
                
            case "unpin":
                if (card.pinnedIndex >= 0) {
                    main.unpin(card.pinnedIndex);
                }
                card.deleted();
                break;
                
            case "edit":
                if (card.entryId) {
                    main.editItem(card.entryId, card.previewText);
                }
                break;
                
            case "open":
                if (card.entryId) {
                    main.openImage(card.entryId);
                }
                break;
                
            case "location":
                if (card.entryId) {
                    main.openFileLocation(card.entryId);
                }
                break;
                
            case "delete":
                if (!card.entryId) return;
                main.remove(card.entryId);
                card.deleted();
                break;
        }
    }

    function showContextMenuAt(anchor) {
        const itemData = {
            id: card.entryId,
            preview: card.previewText,
            type: card.itemType,
            pinned: card.pinned,
            pinnedIndex: card.pinnedIndex
        };
        card.requestContextMenu(itemData, anchor);
    }

    HoverHandler { id: cardHover }

    NBox {
        anchors.fill: parent
        forceOpaque: true
        radius: Style.radiusM
        color: card.pressed
            ? Qt.alpha(Color.mPrimary, 0.12)
            : (card.selected ? Color.mSecondaryContainer : Color.mSurfaceVariant)
        border.color: (cardHover.hovered || card.pressed || card.selected)
            ? Color.mPrimary
            : Qt.alpha(Color.mOutline, Style.opacityHeavy)
        border.width: Style.borderS
    }

    RowLayout {
        id: rowLayout
        visible: !card.compact
        anchors.fill: parent
        anchors.margins: Style.marginM
        spacing: Style.marginM

        Image {
            id: previewImage
            visible: card.renderAsImage
            Layout.fillWidth: true
            Layout.preferredHeight: Style.baseWidgetSize * 2
            fillMode: Image.PreserveAspectFit
            horizontalAlignment: Image.AlignLeft
            asynchronous: true
            cache: true
            smooth: true
            source: {
                const _rev = card.pluginApi?.mainInstance?.imageCacheRevision ?? 0;
                return card.pluginApi?.mainInstance?.imageCache?.[card.entryId] ?? "";
            }
        }

        NIconButton {
            id: openImageButton
            visible: card.renderAsImage && (card.pluginApi?.pluginSettings?.inlineActions?.openExternal ?? true)
            icon: "external-link"
            tooltipText: card.pluginApi?.tr("panel.open-external")
            baseSize: Style.baseWidgetSize * 0.6
            onClicked: {
                if (!card.entryId)
                    return;
                card.pluginApi?.mainInstance?.openImage(card.entryId);
            }
        }

        RowLayout {
            id: textRow
            visible: !card.renderAsImage && !card.renderAsFile && card.itemType !== "image"
            Layout.fillWidth: true
            spacing: Style.marginXS

            NText {
                id: previewLabel
                Layout.fillWidth: true
                text: card.previewText
                pointSize: Style.fontSizeM
                font.weight: Font.Normal
                color: Color.mOnSurface
                elide: card.expanded ? Text.ElideNone : Text.ElideRight
                maximumLineCount: card.expanded ? 10 : 1
                wrapMode: card.expanded ? Text.Wrap : Text.NoWrap
            }

            NIconButton {
                id: expandButton
                visible: card.canExpand && card.previewText.length > 80 && (card.pluginApi?.pluginSettings?.inlineActions?.expand ?? false)
                rotation: card.expanded ? 180 : 0
                icon: "chevron-down"
                tooltipText: card.expanded
                    ? card.pluginApi?.tr("panel.collapse")
                    : card.pluginApi?.tr("panel.expand")
                baseSize: Style.baseWidgetSize * 0.6
                onClicked: card.toggleExpand()
            }
        }

        RowLayout {
            id: imageBranch
            visible: card.itemType === "image" && !card.renderAsImage && !card.compact
            enabled: false
            Layout.fillWidth: true
            spacing: Style.marginM

            NIcon {
                icon: "image"
                pointSize: Style.fontSizeXXL
                color: Color.mOnSurface
            }

            NText {
                Layout.fillWidth: true
                text: card.previewText
                pointSize: Style.fontSizeM
                color: Color.mOnSurface
                elide: Text.ElideRight
                maximumLineCount: 1
                wrapMode: Text.NoWrap
            }
        }

        RowLayout {
            id: fileBranch
            visible: card.renderAsFile
            enabled: false
            Layout.fillWidth: true
            spacing: Style.marginM

            NIcon {
                icon: "file"
                pointSize: Style.fontSizeXXL
                color: Color.mOnSurface
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                NText {
                    id: fileName
                    Layout.fillWidth: true
                    text: card.fileMeta.filename || card.previewText
                    pointSize: Style.fontSizeM
                    font.weight: Style.fontWeightBold
                    color: Color.mOnSurface
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    wrapMode: Text.NoWrap
                }

                NText {
                    id: fileParent
                    Layout.fillWidth: true
                    visible: text.length > 0
                    text: card.fileMeta.parentDir
                    pointSize: Style.fontSizeS
                    color: Color.mOnSurfaceVariant
                    elide: Text.ElideMiddle
                    maximumLineCount: 1
                    wrapMode: Text.NoWrap
                }
            }

            NText {
                id: fileSize
                visible: text.length > 0
                text: card.fileMeta.sizeHuman
                pointSize: Style.fontSizeS
                color: Color.mOnSurfaceVariant
                horizontalAlignment: Text.AlignRight
            }
        }

        Item {
            id: trailingSection
            visible: !card.compact
            Layout.preferredWidth: card.pinned
                ? Style.baseWidgetSize * 0.7
                : Style.baseWidgetSize * 0.7 * 2 + Style.marginS
            Layout.fillHeight: true

            NText {
                id: relativeTimeLabel
                anchors.centerIn: parent
                visible: !cardHover.hovered && !card.pinned && card.relativeTimeText.length > 0
                text: card.relativeTimeText
                pointSize: Style.fontSizeS
                color: Color.mOnSurfaceVariant
                horizontalAlignment: Text.AlignRight
            }

            Row {
                id: hoverButtons
                anchors.centerIn: parent
                visible: cardHover.hovered && !card.pinned
                spacing: Style.marginS

                NIconButton {
                    icon: "pin"
                    tooltipText: card.pluginApi?.tr("panel.pin")
                    baseSize: Style.baseWidgetSize * 0.7
                    visible: card.pluginApi?.pluginSettings?.inlineActions?.pin ?? true
                    onClicked: {
                        const main = card.pluginApi?.mainInstance;
                        if (!main)
                            return;
                        main.pin({ preview: card.previewText, type: card.itemType });
                    }
                }

                NIconButton {
                    icon: "trash"
                    tooltipText: card.pluginApi?.tr("panel.delete")
                    baseSize: Style.baseWidgetSize * 0.7
                    visible: card.pluginApi?.pluginSettings?.inlineActions?.delete ?? true
                    onClicked: {
                        if (!card.entryId)
                            return;
                        card.pluginApi?.mainInstance?.remove(card.entryId);
                        card.deleted();
                    }
                }
            }

            NIconButton {
                id: unpinButton
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: card.pinned
                icon: "unpin"
                tooltipText: card.pluginApi?.tr("panel.unpin")
                baseSize: Style.baseWidgetSize * 0.7
                onClicked: {
                    const main = card.pluginApi?.mainInstance;
                    if (!main || card.pinnedIndex < 0)
                        return;
                    main.unpin(card.pinnedIndex);
                    card.deleted();
                }
            }

            NIconButton {
                id: menuButton
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                icon: "more-vertical"
                tooltipText: card.pluginApi?.tr("panel.actions")
                baseSize: Style.baseWidgetSize * 0.7
                onClicked: {
                    card.showContextMenuAt(menuButton);
                }
            }
        }
    }

    Item {
        id: compactContent
        visible: card.compact
        anchors.fill: parent

        Image {
            anchors.centerIn: parent
            width: Math.min(parent.width - Style.marginS * 2, sourceSize.width)
            height: Math.min(parent.height - Style.marginS * 2, sourceSize.height)
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            cache: true
            smooth: true
            source: {
                const _rev = card.pluginApi?.mainInstance?.imageCacheRevision ?? 0;
                return card.pluginApi?.mainInstance?.imageCache?.[card.entryId] ?? "";
            }
        }

        NBox {
            anchors.fill: parent
            anchors.margins: Style.marginXS
            radius: Style.radiusS
            color: Qt.alpha(Color.mSurfaceVariant, 0.5)
            visible: !card.pluginApi?.mainInstance?.imageCache?.[card.entryId]
        }

        NIcon {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.margins: Style.marginS
            visible: card.pinned
            icon: "pin"
            pointSize: Style.fontSizeL
            color: Color.mPrimary
        }

        NIconButton {
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            anchors.margins: Style.marginS
            visible: card.renderAsImage && (card.pluginApi?.pluginSettings?.inlineActions?.openExternal ?? true)
            icon: "external-link"
            tooltipText: card.pluginApi?.tr("panel.open-external")
            baseSize: Style.baseWidgetSize * 0.5
            onClicked: {
                if (!card.entryId)
                    return;
                card.pluginApi?.mainInstance?.openImage(card.entryId);
            }
        }

        NIconButton {
            id: compactMenuButton
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: Style.marginS
            icon: "more-vertical"
            tooltipText: card.pluginApi?.tr("panel.actions")
            baseSize: Style.baseWidgetSize * 0.5
            onClicked: {
                card.showContextMenuAt(compactMenuButton);
            }
        }
    }

    MouseArea {
        id: rowArea
        z: -1
        anchors.fill: parent
        anchors.rightMargin: expandButton.visible ? expandButton.width + Style.marginXS : 0
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onPressed: card.pressed = true
        onReleased: card.pressed = false
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                card.showContextMenuAt(rowArea);
                return;
            }
            if (!card.entryId)
                return;
            const main = card.pluginApi?.mainInstance;
            if (!main)
                return;
            if (card.pinned && card.pinnedIndex >= 0) {
                main.copyPinned(card.pinnedIndex);
            } else {
                main.copy(card.entryId);
            }
            const typeSlug = card.itemType === "file" ? "file"
                           : card.itemType === "image" ? "image"
                           : "text";
            ToastService.showNotice(
                card.pluginApi?.tr("toast.item-copied-" + typeSlug + "-title"),
                card.pluginApi?.tr("toast.item-copied-" + typeSlug + "-body")
            );
            card.copied();
        }
    }
}