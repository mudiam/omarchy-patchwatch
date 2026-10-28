import QtQuick
import qs.Commons

// A clickable line of text in the panel. Flush with the panel's content edge
// so actions line up with the text above them; the hover highlight reaches a
// little past that edge, the way a menu highlight does.
Item {
  id: root

  property string label: ""
  property color foreground: Color.foreground
  property string fontFamily: Style.font.family
  property bool compact: false

  signal clicked()

  implicitHeight: Style.space(compact ? 20 : 26)
  height: implicitHeight
  implicitWidth: labelText.implicitWidth

  Rectangle {
    anchors.fill: parent
    anchors.leftMargin: -Style.space(6)
    anchors.rightMargin: -Style.space(6)
    radius: Style.cornerRadius
    color: mouse.containsMouse
           ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08)
           : "transparent"
  }

  Text {
    id: labelText
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    text: root.label
    textFormat: Text.PlainText
    elide: Text.ElideRight
    color: root.foreground
    font.family: root.fontFamily
    font.pixelSize: root.compact ? Style.font.caption : Style.font.body
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.clicked()
  }
}
