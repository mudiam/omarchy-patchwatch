import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui

// Patchwatch: says when an Omarchy update undid a PR patch you installed by
// hand, or when that PR merged.
//
// The bar shows one glyph. It stays in the bar's own colour while every
// tracked patch is in place, turns urgent with a badge when an update has
// overwritten one, and takes the accent colour for notes (a merged PR to
// re-test, a hand edit nobody is tracking). The panel lists the findings and
// the few things you can do about them.
Panel {
  id: root

  moduleName: "io.github.mudiam.patchwatch"
  ipcTarget: "io.github.mudiam.patchwatch"

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color accent: Color.accent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property color dimmer: Qt.darker(foreground, 2.2)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  // Written as an escape: a private-use glyph typed literally does not always
  // survive an editor, and the failure is an invisible icon.
  readonly property string glyph: ""  // wrench

  readonly property color barIconColor: {
    if (PatchwatchStore.warnCount > 0 || PatchwatchStore.error !== "") return urgent
    if (PatchwatchStore.infoCount > 0) return accent
    if (PatchwatchStore.patches.length === 0) return Qt.darker(barForeground, 1.9)
    return barForeground
  }

  // Colour alone is not enough to carry "something is wrong" on a bar full
  // of coloured glyphs, so a warning also gets a mark.
  readonly property bool showBadge: PatchwatchStore.warnCount > 0
  readonly property int badgeSize: showBadge ? Style.space(9) : 0
  readonly property int barContentWidth:
    Style.bar.iconFont + (showBadge ? badgeSize - Style.space(3) : 0)
  readonly property int barSlot: barContentWidth + Style.space(10)
  readonly property real openPanelIndicatorWidth: barContentWidth
  readonly property real openPanelIndicatorHeight: barContentWidth

  // Panel has no size of its own; without these the bar gives the widget
  // zero width and it cannot be clicked.
  implicitWidth: bar && bar.vertical ? (bar ? bar.barSize : Style.bar.sizeHorizontal) : barSlot
  implicitHeight: bar && bar.vertical ? barSlot : (bar ? bar.barSize : Style.bar.sizeHorizontal)

  onOpenedChanged: if (opened) PatchwatchStore.refreshIfStale()

  function levelColor(level) {
    if (level === "warn") return root.urgent
    if (level === "info") return root.accent
    return root.foreground
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    slotSize: root.barSlot
    opticalSize: root.barContentWidth
    // The bar tooltip is a shell component whose text format is not ours.
    tooltipText: PatchwatchStore.plain(PatchwatchStore.tooltip)

    iconComponent: Component {
      Item {
        Text {
          anchors.centerIn: parent
          text: root.glyph
          textFormat: Text.PlainText
          font.family: root.fontFamily
          font.pixelSize: Style.bar.iconFont
          renderType: Text.NativeRendering
          color: root.barIconColor
          opacity: PatchwatchStore.checking ? 0.6 : 1.0
        }

        Rectangle {
          visible: root.showBadge
          width: root.badgeSize
          height: root.badgeSize
          radius: width / 2
          color: root.urgent
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.horizontalCenterOffset: Style.bar.iconFont / 2
          anchors.verticalCenter: parent.verticalCenter
          anchors.verticalCenterOffset: -Style.bar.iconFont / 2.6

          Text {
            anchors.centerIn: parent
            text: "!"
            textFormat: Text.PlainText
            color: Color.background
            font.family: root.fontFamily
            font.pixelSize: Math.round(root.badgeSize * 0.8)
            font.bold: true
            renderType: Text.NativeRendering
          }
        }
      }
    }

    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton) PatchwatchStore.refresh()
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher

    readonly property int desiredWidth: Style.space(360)
    contentWidth: Math.min(desiredWidth,
                           panel.availableCardWidth > 0 ? panel.availableCardWidth : desiredWidth)
    contentHeight: panel.fittedContentHeight(mainColumn.implicitHeight, Style.space(560))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Flickable {
        id: scroll
        anchors.fill: parent
        contentWidth: width
        contentHeight: mainColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: mainColumn
          width: scroll.width
          spacing: 0

          // --- status ---------------------------------------------------

          Text {
            width: parent.width
            bottomPadding: Style.space(8)
            text: {
              if (PatchwatchStore.error !== "") return "Patchwatch could not check: " + PatchwatchStore.error
              if (!PatchwatchStore.loaded) return "Checking your patches"
              if (PatchwatchStore.warnCount > 0) return "An update undid a patch"
              if (PatchwatchStore.infoCount > 0) return "Patches: something to note"
              if (PatchwatchStore.patches.length === 0) return "No patches tracked yet"
              return "Every tracked patch is in place"
            }
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            color: (PatchwatchStore.warnCount > 0 || PatchwatchStore.error !== "") ? root.urgent : root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }

          Text {
            width: parent.width
            visible: PatchwatchStore.loaded && PatchwatchStore.patches.length === 0 && PatchwatchStore.error === ""
            bottomPadding: visible ? Style.space(8) : 0
            text: "When you install a PR's version of an Omarchy file to test it, track it here and patchwatch will tell you when an update puts the packaged file back."
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }

          // --- findings -------------------------------------------------

          Column {
            width: parent.width
            spacing: Style.space(10)
            bottomPadding: PatchwatchStore.findings.length > 0 ? Style.space(10) : 0

            Repeater {
              model: PatchwatchStore.findings

              Column {
                width: parent.width
                spacing: Style.space(2)

                Text {
                  width: parent.width
                  text: modelData.title + (modelData.acked ? "  (acknowledged)" : "")
                  textFormat: Text.PlainText
                  wrapMode: Text.WordWrap
                  maximumLineCount: 3
                  elide: Text.ElideRight
                  color: modelData.acked ? root.dim : root.levelColor(modelData.level)
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                }

                Text {
                  width: parent.width
                  visible: modelData.details !== ""
                  text: modelData.details
                  textFormat: Text.PlainText
                  elide: Text.ElideMiddle
                  color: root.dimmer
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }

                Text {
                  width: parent.width
                  visible: modelData.advice !== "" && !modelData.acked
                  text: modelData.advice
                  textFormat: Text.PlainText
                  wrapMode: Text.WordWrap
                  maximumLineCount: 6
                  elide: Text.ElideRight
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }

                Text {
                  width: parent.width
                  visible: modelData.command !== "" && !modelData.acked
                  text: "$ " + modelData.command
                  textFormat: Text.PlainText
                  wrapMode: Text.WrapAnywhere
                  maximumLineCount: 4
                  elide: Text.ElideRight
                  color: root.foreground
                  font.family: "monospace"
                  font.pixelSize: Style.font.caption
                }

                Row {
                  spacing: Style.space(14)
                  visible: !modelData.acked && (modelData.command !== "" || modelData.level !== "ok")

                  ActionRow {
                    visible: modelData.command !== ""
                    compact: true
                    label: "Copy command"
                    foreground: root.accent
                    fontFamily: root.fontFamily
                    onClicked: PatchwatchStore.copyCommand(modelData.key)
                  }

                  ActionRow {
                    visible: modelData.level !== "ok"
                    compact: true
                    label: "It's fine"
                    foreground: root.dim
                    fontFamily: root.fontFamily
                    onClicked: PatchwatchStore.acknowledge(modelData.key)
                  }
                }
              }
            }
          }

          // --- actions --------------------------------------------------

          PanelSeparator { width: parent.width; foreground: root.foreground }

          ActionRow {
            width: parent.width
            label: PatchwatchStore.checking ? "Checking…" : "Check Now"
            foreground: root.foreground
            fontFamily: root.fontFamily
            onClicked: PatchwatchStore.refresh()
          }

          ActionRow {
            width: parent.width
            visible: PatchwatchStore.pending.length > 0
            label: "Go Through It With My Agent…"
            foreground: root.foreground
            fontFamily: root.fontFamily
            onClicked: {
              PatchwatchStore.openAgent()
              root.close()
            }
          }

          ActionRow {
            width: parent.width
            label: "How to Track a Patch…"
            foreground: root.foreground
            fontFamily: root.fontFamily
            onClicked: {
              PatchwatchStore.openReadme()
              root.close()
            }
          }
        }
      }
    }
  }
}
