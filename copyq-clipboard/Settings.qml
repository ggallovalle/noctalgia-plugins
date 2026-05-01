import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
    id: root
    spacing: Style.marginM

    property var pluginApi: null

    property int valueMaxHistorySize: pluginApi?.pluginSettings?.maxHistorySize ?? 100
    property bool valueShowImagePreviews: pluginApi?.pluginSettings?.showImagePreviews ?? true
    property string valueDensity: pluginApi?.pluginSettings?.density ?? "comfortable"
    
    property bool valueInlineActionPin: pluginApi?.pluginSettings?.inlineActions?.pin ?? true
    property bool valueInlineActionDelete: pluginApi?.pluginSettings?.inlineActions?.delete ?? true
    property bool valueInlineActionEdit: pluginApi?.pluginSettings?.inlineActions?.edit ?? false
    property bool valueInlineActionOpenExternal: pluginApi?.pluginSettings?.inlineActions?.openExternal ?? true
    property bool valueInlineActionExpand: pluginApi?.pluginSettings?.inlineActions?.expand ?? false

    NSpinBox {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.max-history-size")
        description: pluginApi?.tr("settings.max-history-size-description")
        from: 20
        to: 500
        stepSize: 10
        value: root.valueMaxHistorySize
        onValueChanged: root.valueMaxHistorySize = value
    }

    NToggle {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.show-image-previews")
        description: pluginApi?.tr("settings.show-image-previews-description")
        checked: root.valueShowImagePreviews
        onToggled: checked => { root.valueShowImagePreviews = checked; }
    }

    NComboBox {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.density")
        description: pluginApi?.tr("settings.density-description")
        model: [
            { "key": "compact",     "name": pluginApi?.tr("settings.density-compact") },
            { "key": "comfortable", "name": pluginApi?.tr("settings.density-comfortable") },
            { "key": "spacious",    "name": pluginApi?.tr("settings.density-spacious") }
        ]
        currentKey: root.valueDensity
        onSelected: key => { root.valueDensity = key; }
    }

    NText {
        Layout.fillWidth: true
        text: pluginApi?.tr("settings.inline-actions")
        pointSize: Style.fontSizeM
        font.weight: Style.fontWeightBold
        color: Color.mOnSurface
    }

    NText {
        Layout.fillWidth: true
        text: pluginApi?.tr("settings.inline-actions-description")
        pointSize: Style.fontSizeS
        color: Color.mOnSurfaceVariant
        wrapMode: Text.Wrap
    }

    NToggle {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.inline-action-pin")
        checked: root.valueInlineActionPin
        onToggled: checked => { root.valueInlineActionPin = checked; }
    }

    NToggle {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.inline-action-delete")
        checked: root.valueInlineActionDelete
        onToggled: checked => { root.valueInlineActionDelete = checked; }
    }

    NToggle {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.inline-action-edit")
        checked: root.valueInlineActionEdit
        onToggled: checked => { root.valueInlineActionEdit = checked; }
    }

    NToggle {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.inline-action-open")
        checked: root.valueInlineActionOpenExternal
        onToggled: checked => { root.valueInlineActionOpenExternal = checked; }
    }

    NToggle {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.inline-action-expand")
        checked: root.valueInlineActionExpand
        onToggled: checked => { root.valueInlineActionExpand = checked; }
    }

    function saveSettings() {
        if (!pluginApi) {
            return;
        }
        pluginApi.pluginSettings.maxHistorySize = root.valueMaxHistorySize;
        pluginApi.pluginSettings.showImagePreviews = root.valueShowImagePreviews;
        pluginApi.pluginSettings.density = root.valueDensity;
        pluginApi.pluginSettings.inlineActions = {
            pin: root.valueInlineActionPin,
            delete: root.valueInlineActionDelete,
            edit: root.valueInlineActionEdit,
            openExternal: root.valueInlineActionOpenExternal,
            expand: root.valueInlineActionExpand
        };
        pluginApi.saveSettings();
    }
}