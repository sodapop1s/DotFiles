import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import QtQuick.Shapes 1.15
import Quickshell.Io
//import QtQuick.QDateTime


//Start of Status Bar
PanelWindow {

    //Defining Colours
    property color textColour: "#cdd6f4"
    property color surface: "#313244"
    property color blue: "#89b4fa"
    property color lavender: "#b4befe"
    property color red: "#f38ba8"
    property color green: "#a6e3a1"
    property color none: "transparent"
    property string nwsStation: "KHEF"
    property string tempUnit: "F"
    property string nwsUserAgent: "(quickshell-bar, noreply@example.com)"

    //anchoring
    anchors.top: true
    anchors.left: true
    anchors.right: true
    implicitHeight: 32
    color: none
    RowLayout{
      anchors.fill: parent
      spacing: 8

//--------------------------------------
//|         workspaces island           |
//---------------------------------------

      Shape {
        id: leftIsland
        Layout.preferredHeight: 30
        Layout.preferredWidth: contentRow.implicitWidth + 24
        Layout.alignment: Qt.AlignTop

        property real radius: 24

        layer.enabled: true
        layer.samples: 4

        ShapePath { //Makes the silly round shape
        strokeColor: none
          fillColor: surface

          PathMove { x: 0; y: 0 }
          PathLine { x: leftIsland.width; y: 0 }
          PathLine { x: leftIsland.width; y: leftIsland.height - leftIsland.radius }
          PathArc {
              x: leftIsland.width - leftIsland.radius
              y: leftIsland.height
              radiusX: leftIsland.radius
              radiusY: leftIsland.radius
              direction: PathArc.Clockwise
            }
          PathLine { x: leftIsland.radius; y: leftIsland.height }
          PathLine { x: 0; y: leftIsland.height}
          PathLine { x: 0; y: 0 }
        }
      //Contents of the Island(s)
        RowLayout {
          id: contentRow
          x: 8
          y: (leftIsland.height - height) / 2
          spacing: 8

          Image {     //Arch Logo
            Layout.preferredWidth: 20
            Layout.preferredHeight: 18
            Layout.alignment: Qt.AlignVCenter
            horizontalAlignment: Image.AlignLeft

            source: "https://raw.githubusercontent.com/sodapop1s/DotFiles/refs/heads/main/quickshell/images/ArchLinuxCappi.png"

          }

          Repeater {  //Workspace Numbers
          model: 9

            Text {
            Layout.alignment: Qt.AlignVCenter
            verticalAlignment: Text.AlignVCenter

          // Data from Hyprland

            property var ws: Hyprland.workspaces.values.find(w => w.id === index + 1)
            property bool isActive: Hyprland.focusedWorkspace?.id === (index + 1)

          //Displaying Data

            text: index + 1
            color: isActive ? blue : (ws ? lavender : textColour)
            font.pixelSize: 25
            font.weight: Font.Black
            font.family: "nunito"

          // Switch workspaces:workspaces
            MouseArea {
              anchors.fill: parent
             onClicked: Hyprland.dispatch("workspace" + (index + 1))
            }
          }
        }
      }
    }
  Item { Layout.fillWidth: true } //filler
    // Temp island
  Shape {
	  id: leftishIsland
	  Layout.preferredHeight: 22
    Layout.preferredWidth: 56
	  Layout.alignment: Qt.AlignTop

	  property real radius: 11

	  layer.enabled: true
    layer.samples: 4
    ShapePath {
  strokeColor: "transparent"
  fillColor: surface

  PathMove { x: 0; y: 0 }
  PathLine { x: leftishIsland.width; y: 0 }
  PathLine { x: leftishIsland.width; y: leftishIsland.height - leftishIsland.radius }
  PathArc {
    x: leftishIsland.width - leftishIsland.radius; y: leftishIsland.height
    radiusX: leftishIsland.radius; radiusY: leftishIsland.radius
    direction: PathArc.Clockwise
  }
  PathLine { x: leftishIsland.radius; y: leftishIsland.height }
  PathArc {
    x: 0; y: leftishIsland.height - leftishIsland.radius
    radiusX: leftishIsland.radius; radiusY: leftishIsland.radius
    direction: PathArc.Clockwise
  }
  PathLine { x: 0; y: 0 }
}
Text {
  id: leftishText
  anchors.centerIn: parent
  text: "--°"
  color: textColour
  font.pixelSize: 14
  font.family: "nunito"
  font.weight: Font.Bold
}
Process {
  id: weatherProc
  command: [
    "curl", "-s",
    "-H", "User-Agent: " + nwsUserAgent,
    "https://api.weather.gov/stations/" + nwsStation + "/observations/latest"
  ]
  running: true
  stdout: StdioCollector {
    onStreamFinished: {
      try {
        const data = JSON.parse(text)
        const tempC = data.properties.temperature.value
        if (tempC === null) {
          leftishText.text = "--°"
          return
        }
        const temp = tempUnit === "F"
          ? Math.round(tempC * 9/5 + 32)
          : Math.round(tempC)
        leftishText.text = temp + "°" + tempUnit
      } catch (e) {
        leftishText.text = "err"
      }
    }
  }
}

Timer {
  interval: 10 * 60 * 1000
  running: true
  repeat: true
  onTriggered: weatherProc.running = true
}

}
// Clock island
Shape {
  id: centerIsland
  Layout.preferredHeight: 30
  Layout.preferredWidth: centerText.contentWidth + 40
  Layout.alignment: Qt.AlignTop
  property real radius: 11
  layer.enabled: true
  layer.samples: 4

  ShapePath {
    strokeColor: "transparent"
    fillColor: surface
    PathMove { x: 0; y: 0 }
    PathLine { x: centerIsland.width; y: 0 }
    PathLine { x: centerIsland.width; y: centerIsland.height - centerIsland.radius }
    PathArc {
      x: centerIsland.width - centerIsland.radius; y: centerIsland.height
      radiusX: centerIsland.radius; radiusY: centerIsland.radius
      direction: PathArc.Clockwise
    }
    PathLine { x: centerIsland.radius; y: centerIsland.height }
    PathArc {
      x: 0; y: centerIsland.height - centerIsland.radius
      radiusX: centerIsland.radius; radiusY: centerIsland.radius
      direction: PathArc.Clockwise
    }
    PathLine { x: 0; y: 0 }
  }

  Text {
    id: centerText
    x: 8
    y: (centerIsland.height - height) / 2
    text: "--:--"
    color: textColour
    font.pixelSize: 25
    font.family: "nunito"
    font.weight: Font.Bold
    anchors.centerIn: parent
      font.letterSpacing: 8
  }

  Timer {
    interval: 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      const now = new Date()
      const h = now.getHours().toString().padStart(2, "0")
      const m = now.getMinutes().toString().padStart(2, "0")
      centerText.text = h + ":" + m
    }
  }
}   // ← closes centerIsland

// Tray island (placeholder)
Shape {
  id: rightIsland
  Layout.preferredHeight: 22
  Layout.preferredWidth: rightText.contentWidth + 16
  Layout.alignment: Qt.AlignTop
  property real radius: 11
  layer.enabled: true
  layer.samples: 4

  ShapePath {
    strokeColor: "transparent"
    fillColor: surface
    PathMove { x: 0; y: 0 }
    PathLine { x: rightIsland.width; y: 0 }
    PathLine { x: rightIsland.width; y: rightIsland.height - rightIsland.radius }
    PathArc {
      x: rightIsland.width - rightIsland.radius; y: rightIsland.height
      radiusX: rightIsland.radius; radiusY: rightIsland.radius
      direction: PathArc.Clockwise
    }
    PathLine { x: rightIsland.radius; y: rightIsland.height }
    PathArc {
      x: 0; y: rightIsland.height - rightIsland.radius
      radiusX: rightIsland.radius; radiusY: rightIsland.radius
      direction: PathArc.Clockwise
    }
    PathLine { x: 0; y: 0 }
  }

  Text {
    id: rightText
    x: 8
    y: (rightIsland.height - height) / 2
    text: "XX%"
    color: textColour
    font.pixelSize: 14
    font.family: "nunito"
    font.weight: Font.Bold
  }
}

Item { Layout.fillWidth: true }   // pushes everything left for now
//  }   // closes RowLayout
//}// closes PanelWindow

// Tray island (placeholder)
Shape {
  id: finalIsland
  Layout.preferredHeight: 30
  Layout.preferredWidth: 250
  Layout.alignment: Qt.AlignTop
  property real radius: 11
  layer.enabled: true
  layer.samples: 4

  ShapePath {
    strokeColor: "transparent"
    fillColor: surface
    PathMove { x: 0; y: 0 }
    PathLine { x: finalIsland.width; y: 0 }
    PathLine { x: finalIsland.width; y: finalIsland.height - finalIsland.radius }
    PathArc {
      x: finalIsland.width - finalIsland.radius; y: finalIsland.height
      radiusX: finalIsland.radius; radiusY: finalIsland.radius
      direction: PathArc.Clockwise
    }
    PathLine { x: finalIsland.radius; y: finalIsland.height }
    PathArc {
      x: 0; y: finalIsland.height - finalIsland.radius
      radiusX: finalIsland.radius; radiusY: finalIsland.radius
      direction: PathArc.Clockwise
    }
    PathLine { x: 0; y: 0 }
  }

  Text {
    id: finalText
    x: 8
    y: (finalIsland.height - height) / 2
    text: "hello World"
    color: textColour
    font.pixelSize: 14
    font.family: "nunito"
    font.weight: Font.Bold
  }
}
}
}
