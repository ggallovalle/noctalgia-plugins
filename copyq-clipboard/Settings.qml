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
    property var valueInlineActions: {
        const defaults = {
            pin: true,
            delete: true,
            edit: false,
            openExternal: true,
            expand: false
        };
        const saved = pluginApi?.pluginSettings?.inlineActions;
        if (!saved) return defaults;
        return {
            pin: saved.pin ?? defaults.pin,
            delete: saved.delete ?? defaults.delete,
            edit: saved.edit ?? defaults.edit,
            openExternal: saved.openExternal ?? defaults.openExternal,
            expand: saved.expand ?? defaults.expand
        };
    }

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
        checked: root.valueInlineActions.pin
        onToggled: checked => { root.valueInlineActions.pin = checked; }
    }

    NToggle {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.inline-action-delete")
        checked: root.valueInlineActions.delete
        onToggled: checked => { root.valueInlineActions.delete = checked; }
    }

    NToggle {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.inline-action-edit")
        checked: root.valueInlineActions.edit
        onToggled: checked => { root.valueInlineActions.edit = checked; }
    }

    NToggle {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.inline-action-open")
        checked: root.valueInlineActions.openExternal
        onToggled: checked => { root.valueInlineActions.openExternal = checked; }
    }

    NToggle {
        Layout.fillWidth: true
        label: pluginApi?.tr("settings.inline-action-expand")
        checked: root.valueInlineActions.expand
        onToggled: checked => { root.valueInlineActions.expand = checked; }
    }

    function saveSettings() {
        if (!pluginApi) {
            return;
        }
        pluginApi.pluginSettings.maxHistorySize = root.valueMaxHistorySize;
        pluginApi.pluginSettings.showImagePreviews = root.valueShowImagePreviews;
        pluginApi.pluginSettings.density = root.valueDensity;
        pluginApi.pluginSettings.inlineActions = root.valueInlineActions;
        pluginApi.saveSettings();
    }
}