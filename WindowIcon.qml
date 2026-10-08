import QtQuick

// One window's bar icon: the web app's own icon when a cached image is
// available, otherwise the Nerd Font glyph.
Item {
  id: icon
  property string glyph: ""
  property string imageSource: ""
  property color color: "white"
  property string fontFamily: ""
  property real size: 14

  readonly property bool showImage: imageSource !== "" && img.status === Image.Ready
  implicitWidth: showImage ? img.width : label.implicitWidth
  implicitHeight: Math.max(label.implicitHeight, img.height)

  Image {
    id: img
    anchors.verticalCenter: parent.verticalCenter
    visible: icon.showImage
    source: icon.imageSource
    width: Math.round(icon.size * 1.2); height: width
    sourceSize.width: width * 2; sourceSize.height: width * 2
    smooth: true; mipmap: true
    fillMode: Image.PreserveAspectFit
  }
  Text {
    id: label
    anchors.verticalCenter: parent.verticalCenter
    visible: !icon.showImage
    text: icon.glyph
    color: icon.color
    font.family: icon.fontFamily
    font.pixelSize: icon.size
  }
}
