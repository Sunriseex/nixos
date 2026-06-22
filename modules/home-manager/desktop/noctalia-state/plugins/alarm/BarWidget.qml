import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons

Item {
  id: root

  property var pluginApi: null
  property var mainInstance: null

  implicitHeight: 24
  implicitWidth: nextAlarmLabel.implicitWidth + 8

  onPluginApiChanged: {
    if (pluginApi) {
      mainInstance = pluginApi.mainInstance
    }
  }

  RowLayout {
    anchors.fill: parent
    spacing: 4

    Text {
      id: icon
      text: "⏰"
      font.pixelSize: 12
      verticalAlignment: Text.AlignVCenter
    }

    Text {
      id: nextAlarmLabel
      text: {
        if (!mainInstance) return ""
        var next = mainInstance.getNextAlarm()
        if (!next) return ""
        return next.time + " " + (next.message || "")
      }
      font.pixelSize: 12
      color: "#f5f5f7"
      verticalAlignment: Text.AlignVCenter
      elide: Text.ElideRight
      maximumLineCount: 1
    }
  }

  Timer {
    interval: 60000
    repeat: true
    running: true
    triggeredOnStart: true

    onTriggered: {
      nextAlarmLabel.text = Qt.binding(function() {
        if (!mainInstance) return ""
        var next = mainInstance.getNextAlarm()
        if (!next) return ""
        return next.time + " " + (next.message || "")
      })
    }
  }
}
