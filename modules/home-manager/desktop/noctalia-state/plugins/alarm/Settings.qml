import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root

  property var pluginApi: null
  property var editAlarms: []

  spacing: Style.marginM

  onPluginApiChanged: {
    if (pluginApi) {
      loadAlarms()
    }
  }

  Component.onCompleted: {
    if (pluginApi) {
      loadAlarms()
    }
  }

  function loadAlarms() {
    if (pluginApi && pluginApi.pluginSettings && pluginApi.pluginSettings.alarms) {
      root.editAlarms = pluginApi.pluginSettings.alarms.slice()
    } else {
      root.editAlarms = []
    }
  }

  function saveAlarms() {
    if (!pluginApi) return
    pluginApi.pluginSettings.alarms = root.editAlarms
    pluginApi.saveSettings()
    if (pluginApi.mainInstance) {
      pluginApi.mainInstance.loadAlarms()
    }
  }

  function addAlarm() {
    root.editAlarms.push({
      time: "12:00",
      message: "",
      enabled: true,
      repeat: true
    })
    saveAlarms()
  }

  function removeAlarm(index) {
    root.editAlarms.splice(index, 1)
    saveAlarms()
  }

  NLabel {
    label: "Alarms"
    description: "Set time-based reminders"
    Layout.fillWidth: true
  }

  Repeater {
    id: alarmsRepeater
    model: root.editAlarms

    delegate: ColumnLayout {
      id: alarmItem
      required property int index
      required property var modelData
      spacing: Style.marginS

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginM

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 4

          RowLayout {
            spacing: Style.marginS

            NSpinBox {
              id: hourSpin
              from: 0
              to: 23
              value: parseInt(modelData.time.split(":")[0]) || 12
              onValueChanged: {
                var m = parseInt(modelData.time.split(":")[1]) || 0
                modelData.time = ("00" + value).slice(-2) + ":" + ("00" + m).slice(-2)
                root.saveAlarms()
              }
            }

            NLabel {
              label: ":"
              Layout.alignment: Qt.AlignCenter
            }

            NSpinBox {
              id: minSpin
              from: 0
              to: 59
              value: parseInt(modelData.time.split(":")[1]) || 0
              onValueChanged: {
                var h = parseInt(modelData.time.split(":")[0]) || 12
                modelData.time = ("00" + h).slice(-2) + ":" + ("00" + value).slice(-2)
                root.saveAlarms()
              }
            }
          }

          NTextField {
            Layout.fillWidth: true
            placeholderText: "Message (optional)"
            text: modelData.message || ""
            onTextChanged: {
              modelData.message = text
              root.saveAlarms()
            }
          }
        }

        ColumnLayout {
          spacing: Style.marginS

          NToggle {
            id: enabledToggle
            checked: modelData.enabled
            onCheckedChanged: {
              modelData.enabled = checked
              root.saveAlarms()
            }
          }

          NButton {
            text: "✕"
            onClicked: root.removeAlarm(index)
          }
        }
      }

      Item {
        Layout.fillWidth: true
        Layout.preferredHeight: Style.marginS

        NToggle {
          id: repeatToggle
          label: "Repeat daily"
          checked: modelData.repeat !== false
          onCheckedChanged: {
            modelData.repeat = checked
            root.saveAlarms()
          }
        }
      }

      NDivider { Layout.fillWidth: true }
    }
  }

  NButton {
    text: "+ Add Alarm"
    Layout.fillWidth: true
    onClicked: root.addAlarm()
  }
}
