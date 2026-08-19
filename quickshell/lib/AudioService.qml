pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

Scope {
    id: root

    property var outputs: []
    property var inputs: []
    property var snapshot: []
    property var pendingRoute: null
    property var pendingDefault: null
    property int pendingAttempts: 0
    property int volumeNodeId: -1
    property string status: ""
    property bool statusError: false
    readonly property int defaultOutputId: Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.id : -1
    readonly property int defaultInputId: Pipewire.defaultAudioSource ? Pipewire.defaultAudioSource.id : -1

    function refresh() {
        dump.running = false
        dump.running = true
    }

    function props(object) {
        return object.info && object.info.props ? object.info.props : {}
    }

    function params(object) {
        return object.info && object.info.params ? object.info.params : {}
    }

    function routeInfo(route) {
        var info = route.info || []
        var result = {}
        for (var i = 1; i + 1 < info.length; i += 2)
            result[info[i]] = info[i + 1]
        return result
    }

    function findNode(cardId, deviceIndex, mediaClass) {
        for (var i = 0; i < root.snapshot.length; i++) {
            var node = root.snapshot[i]
            var nodeProps = root.props(node)
            if (node.type === "PipeWire:Interface:Node"
                && nodeProps["media.class"] === mediaClass
                && String(nodeProps["device.id"]) === String(cardId)
                && String(nodeProps["card.profile.device"]) === String(deviceIndex))
                return node
        }
        return null
    }

    function updateVolumeNode() {
        root.volumeNodeId = -1
        for (var i = 0; i < root.snapshot.length; i++) {
            var node = root.snapshot[i]
            if (node.id !== root.defaultOutputId) continue
            root.volumeNodeId = node.id
            var driver = Number(root.props(node)["node.driver-id"])
            if (root.props(node)["node.virtual"] && driver > 0)
                root.volumeNodeId = driver
            return
        }
    }

    function bestProfile(route, profiles, input, activeProfile) {
        var fallback = null
        var activeOutput = String(activeProfile && activeProfile.name || "").split("+")[0]
        for (var i = 0; i < (route.profiles || []).length; i++) {
            var profile = profiles[route.profiles[i]]
            if (!profile || profile.available === "no") continue
            var name = String(profile.name || "")
            if (input) {
                if (activeOutput && name.indexOf(activeOutput + "+input:") === 0) return profile
                if (name.indexOf("+input:") !== -1) return profile
                if (!fallback && name.indexOf("input:") !== -1) fallback = profile
            } else if (name.indexOf("output:") === 0) {
                if (name.indexOf("+input:") !== -1) return profile
                if (!fallback) fallback = profile
            }
        }
        return fallback
    }

    function description(card, route) {
        var info = root.routeInfo(route)
        var device = info["device.product.name"] || root.props(card)["device.description"]
        var label = String(route.description || route.name || "Unknown device")
        return device ? String(device) + " — " + label : label
    }

    function deviceLabel(device) {
        return String(device && (device.description || device.name) || "audio device")
    }

    function uniqueDescriptions(devices) {
        var counts = {}
        for (var i = 0; i < devices.length; i++)
            counts[devices[i].description] = (counts[devices[i].description] || 0) + 1
        return devices.map(function(device) {
            if (counts[device.description] < 2) return device
            var copy = {}
            for (var key in device) copy[key] = device[key]
            copy.description += " — " + (device.routeName || device.name)
            return copy
        })
    }

    function routeIsActive(activeRoutes, route) {
        for (var i = 0; i < activeRoutes.length; i++) {
            var active = activeRoutes[i]
            if (String(active.direction) === String(route.direction)
                && Number(active.index) === Number(route.index))
                return true
        }
        return false
    }

    function routesShareDevice(first, second) {
        for (var i = 0; i < (first.devices || []).length; i++) {
            for (var j = 0; j < (second.devices || []).length; j++) {
                if (Number(first.devices[i]) === Number(second.devices[j])) return true
            }
        }
        return false
    }

    function routeIsVisible(route, routes, activeRoutes) {
        if (route.available !== "no" || root.routeIsActive(activeRoutes, route)) return true
        for (var i = 0; i < routes.length; i++) {
            var other = routes[i]
            if (other === route || other.direction !== route.direction || other.available === "no") continue
            if (root.routesShareDevice(route, other)
                && Number(route.priority || 0) > Number(other.priority || 0))
                return true
        }
        return false
    }

    function rebuildDevices() {
        var outs = []
        var ins = []
        var representedOutputs = {}
        var representedInputs = {}

        for (var i = 0; i < root.snapshot.length; i++) {
            var card = root.snapshot[i]
            if (root.props(card)["media.class"] !== "Audio/Device") continue

            var profileMap = {}
            for (var p = 0; p < (root.params(card).EnumProfile || []).length; p++) {
                var profile = root.params(card).EnumProfile[p]
                profileMap[profile.index] = profile
            }
            var activeProfile = (root.params(card).Profile || [])[0]
            var activeRoutes = root.params(card).Route || []
            var routes = root.params(card).EnumRoute || []

            for (var r = 0; r < routes.length; r++) {
                var route = routes[r]
                if (!root.routeIsVisible(route, routes, activeRoutes)) continue
                var input = route.direction === "Input"
                var profile = root.bestProfile(route, profileMap, input, activeProfile)
                var deviceIndex = (route.devices || [])[0]
                if (!profile || deviceIndex === undefined) continue

                var physical = root.findNode(card.id, deviceIndex, input ? "Audio/Source" : "Audio/Sink")
                var nodeId = physical ? physical.id : -1
                var option = {
                    kind: "route",
                    cardId: card.id,
                    profileIndex: profile.index,
                    routeIndex: route.index,
                    deviceIndex: deviceIndex,
                    nodeId: nodeId,
                    routeName: route.name,
                    active: root.routeIsActive(activeRoutes, route),
                    description: root.description(card, route)
                }
                if (input) {
                    ins.push(option)
                    if (physical) representedInputs[physical.id] = true
                } else {
                    outs.push(option)
                    if (physical) representedOutputs[physical.id] = true
                }
            }
        }

        for (var n = 0; n < root.snapshot.length; n++) {
            var node = root.snapshot[n]
            var nodeProps = root.props(node)
            var mediaClass = nodeProps["media.class"]
            if (mediaClass === "Audio/Sink" && !representedOutputs[node.id])
                outs.push({ kind: "node", nodeId: node.id, name: nodeProps["node.name"], description: nodeProps["node.description"] || nodeProps["node.name"] })
            if (mediaClass === "Audio/Source" && !representedInputs[node.id])
                ins.push({ kind: "node", nodeId: node.id, name: nodeProps["node.name"], description: nodeProps["node.description"] || nodeProps["node.name"] })
        }

        root.outputs = root.uniqueDescriptions(outs)
        root.inputs = root.uniqueDescriptions(ins)
        root.updateVolumeNode()
        root.finishPendingRoute()
    }

    function setOutput(device) {
        root.select(device, false)
    }

    function setInput(device) {
        root.select(device, true)
    }

    function select(device, input) {
        if (root.pendingRoute || root.pendingDefault) return
        if (!device) {
            root.status = "Choose an audio device."
            root.statusError = true
            return
        }
        var label = root.deviceLabel(device)
        root.statusError = false
        root.volumeNodeId = -1
        root.status = "Switching to " + label + "…"
        if (device.kind === "node") {
            root.setDefault(device.nodeId, label, input)
            return
        }
        root.pendingRoute = { device: device, input: input, label: label }
        profileAction.errorText = ""
        profileAction.command = ["pw-cli", "set-param", String(device.cardId), "Profile", JSON.stringify({ index: device.profileIndex })]
        profileAction.running = true
    }

    function finishPendingRoute() {
        if (!root.pendingRoute || root.pendingDefault) return
        var pending = root.pendingRoute
        var node = root.findNode(pending.device.cardId, pending.device.deviceIndex, pending.input ? "Audio/Source" : "Audio/Sink")
        if (node) {
            root.pendingRoute = null
            root.setDefault(node.id, pending.label, pending.input)
            return
        }
        root.pendingAttempts++
        if (root.pendingAttempts < 8) {
            refreshTimer.restart()
            return
        }
        root.status = "PipeWire did not create " + pending.label + "."
        root.statusError = true
        root.pendingRoute = null
    }

    function setDefault(nodeId, description, input) {
        if (nodeId < 0) {
            root.status = "PipeWire output is not ready."
            root.statusError = true
            return
        }
        root.pendingDefault = { description: String(description || "audio device"), input: input }
        defaultAction.errorText = ""
        defaultAction.command = ["wpctl", "set-default", String(nodeId)]
        defaultAction.running = true
    }

    Process {
        id: dump
        command: ["pw-dump"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.snapshot = JSON.parse(this.text || "[]")
                    root.rebuildDevices()
                } catch (error) {
                    root.snapshot = []
                    root.outputs = []
                    root.inputs = []
                    root.status = "Could not read PipeWire devices."
                    root.statusError = true
                }
            }
        }
    }

    Process {
        id: profileAction
        property string errorText: ""
        stderr: StdioCollector { onStreamFinished: profileAction.errorText = this.text.trim() }
        onExited: function(exitCode) {
            if (exitCode !== 0) {
                root.status = profileAction.errorText || "PipeWire rejected the audio profile."
                root.statusError = true
                root.pendingRoute = null
                return
            }
            var pending = root.pendingRoute
            routeAction.errorText = ""
            routeAction.command = ["pw-cli", "set-param", String(pending.device.cardId), "Route",
                JSON.stringify({ index: pending.device.routeIndex, device: pending.device.deviceIndex })]
            routeAction.running = true
        }
    }

    Process {
        id: routeAction
        property string errorText: ""
        stderr: StdioCollector { onStreamFinished: routeAction.errorText = this.text.trim() }
        onExited: function(exitCode) {
            if (exitCode !== 0) {
                root.status = routeAction.errorText || "PipeWire rejected the audio route."
                root.statusError = true
                root.pendingRoute = null
                return
            }
            root.pendingAttempts = 0
            refreshTimer.restart()
        }
    }

    Process {
        id: defaultAction
        property string errorText: ""
        stderr: StdioCollector { onStreamFinished: defaultAction.errorText = this.text.trim() }
        onExited: function(exitCode) {
            var pending = root.pendingDefault
            root.pendingDefault = null
            if (exitCode !== 0) {
                root.status = defaultAction.errorText || "WirePlumber rejected the default device."
                root.statusError = true
                return
            }
            root.status = "Selected " + pending.description + "."
            root.statusError = false
            refreshTimer.restart()
        }
    }

    Connections {
        target: Pipewire
        function onDefaultAudioSinkChanged() {
            root.updateVolumeNode()
            refreshTimer.restart()
        }
    }

    Timer {
        id: refreshTimer
        interval: 200
        onTriggered: root.refresh()
    }
    // ponytail: 1.5s polling; use a stable PipeWire event API if lower hotplug latency matters.
    Timer {
        interval: 1500
        repeat: true
        running: true
        onTriggered: root.refresh()
    }

    Component.onCompleted: root.refresh()
}
