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

    function saveSettings() {
        if (!pluginApi) {
            return;
        }
        pluginApi.pluginSettings.maxHistorySize = root.valueMaxHistorySize;
        pluginApi.pluginSettings.showImagePreviews = root.valueShowImagePreviews;
        pluginApi.pluginSettings.density = root.valueDensity;
        pluginApi.saveSettings();
    }
}