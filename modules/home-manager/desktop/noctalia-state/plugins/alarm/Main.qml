import QtQuick
import Quickshell
import qs.Commons
import qs.Services.System
import qs.Services.UI
import Quickshell.Io

Item {
  id: root

  readonly property string alarmSoundFile: Qt.resolvedUrl("alarm.mp3").toString().replace("file://", "")

  property var pluginApi: null
  property var alarms: []
  property var triggeredToday: ({})
  property string today: ""

  onPluginApiChanged: {
    if (pluginApi) {
      loadAlarms()
    }
  }

  function loadAlarms() {
    if (pluginApi && pluginApi.pluginSettings && pluginApi.pluginSettings.alarms) {
      root.alarms = pluginApi.pluginSettings.alarms
      updateToday()
    }
  }

  function updateToday() {
    var d = new Date()
    root.today = d.getFullYear() + "-" + (d.getMonth() + 1) + "-" + d.getDate()
  }

  Timer {
    id: checkTimer
    interval: 60000
    repeat: true
    running: true
    triggeredOnStart: true

    onTriggered: {
      var now = new Date()
      var currentTime = ("00" + now.getHours()).slice(-2) + ":" + ("00" + now.getMinutes()).slice(-2)
      var currentToday = now.getFullYear() + "-" + (now.getMonth() + 1) + "-" + now.getDate()

      if (currentToday !== root.today) {
        root.triggeredToday = ({})
        root.today = currentToday
      }

      for (var i = 0; i < root.alarms.length; i++) {
        var alarm = root.alarms[i]
        if (!alarm.enabled) continue
        if (alarm.time !== currentTime) continue

        var key = (alarm.repeat ? "daily:" : "") + i
        if (root.triggeredToday[key]) continue

        root.triggeredToday[key] = true

        ToastService.showNotice(
          "Alarm",
          alarm.message || "Alarm at " + alarm.time,
          "alarm"
        )

        SoundService.playSound(root.alarmSoundFile, {
          repeat: false,
          volume: 0.4
        })

        if (!alarm.repeat) {
          alarm.enabled = false
          if (pluginApi) {
            pluginApi.pluginSettings.alarms[i] = alarm
            pluginApi.saveSettings()
          }
        }
      }
    }
  }

  function getNextAlarm() {
    var now = new Date()
    var currentMinutes = now.getHours() * 60 + now.getMinutes()
    var nextAlarm = null
    var nextDiff = Infinity

    for (var i = 0; i < root.alarms.length; i++) {
      var alarm = root.alarms[i]
      if (!alarm.enabled) continue

      var parts = alarm.time.split(":")
      var alarmMinutes = parseInt(parts[0]) * 60 + parseInt(parts[1])
      var diff = alarmMinutes - currentMinutes

      if (diff < 0 && alarm.repeat) {
        diff += 1440
      }

      if (diff > 0 && diff < nextDiff) {
        nextDiff = diff
        nextAlarm = alarm
      }
    }

    return nextAlarm
  }

  IpcHandler {
    target: "plugin:alarm"

    function addAlarm() {
      root.loadAlarms()
    }

    function reload() {
      root.loadAlarms()
    }
  }
}
