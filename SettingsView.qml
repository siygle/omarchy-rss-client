import QtQuick
import qs.Commons
import qs.Ui
import "Model.js" as Model

Item {
  id: root

  property var hostWidget: null
  property var subscriptions: []
  property int pollIntervalMinutes: 15
  property int maxItemsPerFeed: 10
  property int itemsPerPage: 10
  property string barSection: "right"
  property bool unreadOnlyDefault: false
  property string shareStatus: ""
  property color contentForeground: Color.foreground
  property string contentFontFamily: Style.font.family

  signal backRequested()
  signal manageSubscriptionsRequested()
  signal importOpmlRequested()
  signal shareFeedsRequested()

  function applySettings() {
    if (root.hostWidget && typeof root.hostWidget.saveConfig === "function") {
      root.hostWidget.saveConfig(
        root.subscriptions,
        root.pollIntervalMinutes,
        root.maxItemsPerFeed,
        root.itemsPerPage,
        root.barSection,
        root.unreadOnlyDefault
      )
    }
  }

  Column {
    anchors.fill: parent
    spacing: Style.space(12)

    // Header Bar
    Row {
      width: parent.width
      height: Style.space(32)
      spacing: Style.space(8)

      Rectangle {
        width: Style.space(28)
        height: Style.space(28)
        radius: Style.space(4)
        color: backHover.containsMouse ? Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.08) : "transparent"

        Text {
          anchors.centerIn: parent
          text: "󰁍"
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.subtitle
          color: root.contentForeground
        }

        MouseArea {
          id: backHover
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.backRequested()
        }
      }

      Text {
        text: "Settings"
        font.family: root.contentFontFamily
        font.pixelSize: Style.font.subtitle
        font.bold: true
        color: root.contentForeground
        verticalAlignment: Text.AlignVCenter
      }
    }

    // Status Banner (if import or export result present)
    Rectangle {
      visible: Boolean(root.shareStatus)
      width: parent.width
      height: Style.space(30)
      radius: Style.space(4)
      color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.12)
      border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.25)
      border.width: 1

      Row {
        anchors.fill: parent
        anchors.leftMargin: Style.space(8)
        anchors.rightMargin: Style.space(8)
        spacing: Style.space(6)

        Text {
          text: "󰄬"
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
          color: Color.accent
        }

        Text {
          width: parent.width - Style.space(24)
          text: root.shareStatus
          elide: Text.ElideRight
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
          color: root.contentForeground
        }
      }
    }

    // Scrollable Settings Groups
    Flickable {
      width: parent.width
      height: parent.height - Style.space(40) - (root.shareStatus ? Style.space(38) : 0)
      contentHeight: settingsColumn.implicitHeight
      clip: true

      Column {
        id: settingsColumn
        width: parent.width
        spacing: Style.space(14)

        // 1. Group: SUBSCRIPTIONS
        Column {
          width: parent.width
          spacing: Style.space(6)

          Row {
            width: parent.width
            spacing: Style.space(6)

            Text {
              text: "SUBSCRIPTIONS"
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.4)
            }

            Rectangle {
              height: Style.space(16)
              width: subBadgeText.implicitWidth + Style.space(8)
              radius: height / 2
              color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.15)

              Text {
                id: subBadgeText
                anchors.centerIn: parent
                text: String((root.subscriptions || []).length)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                color: Color.accent
              }
            }
          }

          // Card Container
          Rectangle {
            width: parent.width
            height: Style.space(108)
            radius: Style.space(6)
            color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.03)
            border.color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.08)
            border.width: 1

            Column {
              anchors.fill: parent

              // Row: Manage Feeds
              Rectangle {
                width: parent.width
                height: Style.space(36)
                color: manageHover.containsMouse ? Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.05) : "transparent"

                Row {
                  anchors.fill: parent
                  anchors.leftMargin: Style.space(10)
                  anchors.rightMargin: Style.space(10)
                  spacing: Style.space(8)

                  Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰑫"
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.body
                    color: Color.accent
                  }

                  Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - Style.space(50)
                    text: "Manage feeds"
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.body
                    color: root.contentForeground
                  }

                  Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰅂"
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption
                    color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.4)
                  }
                }

                MouseArea {
                  id: manageHover
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.manageSubscriptionsRequested()
                }
              }

              // Divider
              Rectangle {
                width: parent.width
                height: 1
                color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.06)
              }

              // Row: Import OPML
              Rectangle {
                width: parent.width
                height: Style.space(35)
                color: importHover.containsMouse ? Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.05) : "transparent"

                Row {
                  anchors.fill: parent
                  anchors.leftMargin: Style.space(10)
                  anchors.rightMargin: Style.space(10)
                  spacing: Style.space(8)

                  Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰉋"
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.body
                    color: Color.accent
                  }

                  Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - Style.space(50)
                    text: "Import OPML file"
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.body
                    color: root.contentForeground
                  }

                  Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰅂"
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption
                    color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.4)
                  }
                }

                MouseArea {
                  id: importHover
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.importOpmlRequested()
                }
              }

              // Divider
              Rectangle {
                width: parent.width
                height: 1
                color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.06)
              }

              // Row: Export OPML / Copy
              Rectangle {
                width: parent.width
                height: Style.space(35)
                color: shareHover.containsMouse ? Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.05) : "transparent"

                Row {
                  anchors.fill: parent
                  anchors.leftMargin: Style.space(10)
                  anchors.rightMargin: Style.space(10)
                  spacing: Style.space(8)

                  Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰜎"
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.body
                    color: Color.accent
                  }

                  Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - Style.space(50)
                    text: "Export OPML to clipboard"
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.body
                    color: root.contentForeground
                  }

                  Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰅂"
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption
                    color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.4)
                  }
                }

                MouseArea {
                  id: shareHover
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.shareFeedsRequested()
                }
              }
            }
          }
        }

        // 2. Group: READING OPTIONS
        Column {
          width: parent.width
          spacing: Style.space(6)

          Text {
            text: "READING"
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
            color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.4)
          }

          Rectangle {
            width: parent.width
            height: Style.space(144)
            radius: Style.space(6)
            color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.03)
            border.color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.08)
            border.width: 1

            Column {
              anchors.fill: parent

              // Refresh Interval Row
              Row {
                width: parent.width
                height: Style.space(36)
                anchors.leftMargin: Style.space(10)
                anchors.rightMargin: Style.space(10)
                spacing: Style.space(8)

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  width: parent.width - Style.space(170)
                  text: "Refresh interval"
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.body
                  color: root.contentForeground
                }

                Row {
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: Style.space(4)
                  Repeater {
                    model: [5, 15, 30, 60]
                    Rectangle {
                      width: Style.space(34)
                      height: Style.space(24)
                      radius: Style.space(4)
                      color: root.pollIntervalMinutes === modelData
                        ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2)
                        : Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.05)
                      border.color: root.pollIntervalMinutes === modelData ? Color.accent : "transparent"
                      border.width: 1

                      Text {
                        anchors.centerIn: parent
                        text: modelData + "m"
                        font.family: root.contentFontFamily
                        font.pixelSize: Style.font.caption
                        font.bold: root.pollIntervalMinutes === modelData
                        color: root.pollIntervalMinutes === modelData ? Color.accent : root.contentForeground
                      }

                      MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                          root.pollIntervalMinutes = modelData
                          root.applySettings()
                        }
                      }
                    }
                  }
                }
              }

              Rectangle { width: parent.width; height: 1; color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.06) }

              // Articles per feed
              Row {
                width: parent.width
                height: Style.space(35)
                anchors.leftMargin: Style.space(10)
                anchors.rightMargin: Style.space(10)
                spacing: Style.space(8)

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  width: parent.width - Style.space(170)
                  text: "Articles per feed"
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.body
                  color: root.contentForeground
                }

                Row {
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: Style.space(4)
                  Repeater {
                    model: [10, 20, 30, 50]
                    Rectangle {
                      width: Style.space(34)
                      height: Style.space(24)
                      radius: Style.space(4)
                      color: root.maxItemsPerFeed === modelData
                        ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2)
                        : Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.05)
                      border.color: root.maxItemsPerFeed === modelData ? Color.accent : "transparent"
                      border.width: 1

                      Text {
                        anchors.centerIn: parent
                        text: String(modelData)
                        font.family: root.contentFontFamily
                        font.pixelSize: Style.font.caption
                        font.bold: root.maxItemsPerFeed === modelData
                        color: root.maxItemsPerFeed === modelData ? Color.accent : root.contentForeground
                      }

                      MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                          root.maxItemsPerFeed = modelData
                          root.applySettings()
                        }
                      }
                    }
                  }
                }
              }

              Rectangle { width: parent.width; height: 1; color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.06) }

              // Items per page
              Row {
                width: parent.width
                height: Style.space(35)
                anchors.leftMargin: Style.space(10)
                anchors.rightMargin: Style.space(10)
                spacing: Style.space(8)

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  width: parent.width - Style.space(170)
                  text: "Items per page"
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.body
                  color: root.contentForeground
                }

                Row {
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: Style.space(4)
                  Repeater {
                    model: [10, 20, 50]
                    Rectangle {
                      width: Style.space(34)
                      height: Style.space(24)
                      radius: Style.space(4)
                      color: root.itemsPerPage === modelData
                        ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2)
                        : Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.05)
                      border.color: root.itemsPerPage === modelData ? Color.accent : "transparent"
                      border.width: 1

                      Text {
                        anchors.centerIn: parent
                        text: String(modelData)
                        font.family: root.contentFontFamily
                        font.pixelSize: Style.font.caption
                        font.bold: root.itemsPerPage === modelData
                        color: root.itemsPerPage === modelData ? Color.accent : root.contentForeground
                      }

                      MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                          root.itemsPerPage = modelData
                          root.applySettings()
                        }
                      }
                    }
                  }
                }
              }

              Rectangle { width: parent.width; height: 1; color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.06) }

              // Unread-only default
              Row {
                width: parent.width
                height: Style.space(35)
                anchors.leftMargin: Style.space(10)
                anchors.rightMargin: Style.space(10)
                spacing: Style.space(8)

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  width: parent.width - Style.space(70)
                  text: "Unread-only default"
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.body
                  color: root.contentForeground
                }

                Rectangle {
                  anchors.verticalCenter: parent.verticalCenter
                  width: Style.space(36)
                  height: Style.space(20)
                  radius: Style.space(10)
                  color: root.unreadOnlyDefault
                    ? Color.accent
                    : Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.15)

                  Rectangle {
                    width: Style.space(16)
                    height: Style.space(16)
                    radius: width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    x: root.unreadOnlyDefault ? parent.width - width - Style.space(2) : Style.space(2)
                    color: Color.background
                    Behavior on x { NumberAnimation { duration: 100 } }
                  }

                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      root.unreadOnlyDefault = !root.unreadOnlyDefault
                      root.applySettings()
                    }
                  }
                }
              }
            }
          }
        }

        // 3. Group: APPEARANCE
        Column {
          width: parent.width
          spacing: Style.space(6)

          Text {
            text: "APPEARANCE"
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
            color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.4)
          }

          Rectangle {
            width: parent.width
            height: Style.space(46)
            radius: Style.space(6)
            color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.03)
            border.color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.08)
            border.width: 1

            Row {
              anchors.fill: parent
              anchors.leftMargin: Style.space(10)
              anchors.rightMargin: Style.space(10)
              spacing: Style.space(8)

              Text {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - Style.space(190)
                text: "Bar position"
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.body
                color: root.contentForeground
              }

              Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(4)
                Repeater {
                  model: [
                    { id: "left", label: "Left" },
                    { id: "center", label: "Center" },
                    { id: "right", label: "Right" }
                  ]

                  Rectangle {
                    width: Style.space(52)
                    height: Style.space(26)
                    radius: Style.space(4)
                    color: root.barSection === modelData.id
                      ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2)
                      : Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.05)
                    border.color: root.barSection === modelData.id ? Color.accent : "transparent"
                    border.width: 1

                    Text {
                      anchors.centerIn: parent
                      text: modelData.label
                      font.family: root.contentFontFamily
                      font.pixelSize: Style.font.caption
                      font.bold: root.barSection === modelData.id
                      color: root.barSection === modelData.id ? Color.accent : root.contentForeground
                    }

                    MouseArea {
                      anchors.fill: parent
                      cursorShape: Qt.PointingHandCursor
                      onClicked: {
                        root.barSection = modelData.id
                        root.applySettings()
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
