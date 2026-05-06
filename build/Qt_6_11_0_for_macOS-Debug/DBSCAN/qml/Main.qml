import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Dialogs
import QtQuick.Layouts
import "components"

Window {
    id: root

    width: 1100
    height: 720
    minimumWidth: 820
    minimumHeight: 520
    visible: true
    color: "#000000"
    title: qsTr("Визуализатор DBSCAN")

    property var points: []
    property var undoStack: []
    property var redoStack: []
    property var dbscanSteps: []
    property var clusterColors: [
        { "fill": "#6e2aa8", "stroke": "#2b0f45", "ring": "#c89cff" },
        { "fill": "#0f766e", "stroke": "#063b37", "ring": "#75fff0" },
        { "fill": "#b45309", "stroke": "#4a2100", "ring": "#ffd08a" },
        { "fill": "#1d4ed8", "stroke": "#0b1f59", "ring": "#93c5fd" },
        { "fill": "#be123c", "stroke": "#4c0519", "ring": "#fda4af" },
        { "fill": "#4d7c0f", "stroke": "#1a2e05", "ring": "#bef264" }
    ]
    property int dbscanStepIndex: 0
    property int currentPointIndex: -1
    property int currentClusterId: 0
    property real currentEpsilon: 20
    property real currentEpsilonPixelX: 20
    property real currentEpsilonPixelY: 20
    property real coordinatePixelScaleX: 1
    property real coordinatePixelScaleY: 1
    property string epsilonUnit: "ед."
    property bool dbscanRunning: false
    property string statusText: "Готово"
    readonly property int pointDiameter: 8
    readonly property int pointRadius: pointDiameter / 2
    readonly property int animatedPointLimit: 1500
    readonly property real coordinateWidth: 100
    readonly property real coordinateHeight: 100
    readonly property real pixelsPerCentimeter: 37.7952755906
    readonly property string noiseFill: "#cfcfcf"
    readonly property string noiseStroke: "#f7f7f7"

    function refreshCanvas() {
        workspaceCanvas.requestPaint()
    }

    function makePoint(x, y, dataX, dataY) {
        var coordinateX = dataX === undefined ? x / Math.max(1, coordinatePixelScaleX) : dataX
        var coordinateY = dataY === undefined ? y / Math.max(1, coordinatePixelScaleY) : dataY
        return { "x": x, "y": y, "dataX": coordinateX, "dataY": coordinateY, "cluster": 0, "core": false, "noise": false }
    }

    function useDefaultCoordinateScale() {
        coordinatePixelScaleX = Math.max(1, workspace.width) / coordinateWidth
        coordinatePixelScaleY = Math.max(1, workspace.height) / coordinateHeight
    }

    function copyPoint(point) {
        return {
            "x": point.x,
            "y": point.y,
            "dataX": point.dataX === undefined ? point.x : point.dataX,
            "dataY": point.dataY === undefined ? point.y : point.dataY,
            "cluster": point.cluster || 0,
            "core": point.core || false,
            "noise": point.noise || false
        }
    }

    function setPoints(nextPoints) {
        points = nextPoints
        refreshCanvas()
    }

    function stopDbscan() {
        if (dbscanTimer.running)
            dbscanTimer.stop()

        dbscanRunning = false
        dbscanSteps = []
        dbscanStepIndex = 0
        currentPointIndex = -1
        currentClusterId = 0
        statusText = "Готово"
        refreshCanvas()
    }

    function resetPointStates() {
        var nextPoints = []

        for (var i = 0; i < points.length; ++i)
            nextPoints.push(makePoint(points[i].x, points[i].y, points[i].dataX, points[i].dataY))

        setPoints(nextPoints)
        currentPointIndex = -1
        currentClusterId = 0
        statusText = "Готово"
    }

    function pushAction(action) {
        undoStack = undoStack.concat([action])
        redoStack = []
    }

    function addPoint(x, y, remember) {
        stopDbscan()

        if (points.length === 0)
            useDefaultCoordinateScale()

        var point = makePoint(x, y)
        setPoints(points.concat([point]))

        if (remember)
            pushAction({ "type": "add", "point": copyPoint(point) })
    }

    function removePoint(index, remember) {
        if (index < 0 || index >= points.length)
            return

        stopDbscan()

        var removedPoint = copyPoint(points[index])
        var nextPoints = points.slice(0, index).concat(points.slice(index + 1))
        setPoints(nextPoints)

        if (remember)
            pushAction({ "type": "remove", "point": removedPoint, "index": index })
    }

    function clearPoints(remember) {
        if (points.length === 0)
            return

        stopDbscan()

        var previousPoints = []

        for (var i = 0; i < points.length; ++i)
            previousPoints.push(copyPoint(points[i]))

        setPoints([])

        if (remember)
            pushAction({ "type": "clear", "points": previousPoints })
    }

    function findPointIndex(x, y) {
        var hitRadius = Math.max(pointRadius + 4, 8)

        for (var i = points.length - 1; i >= 0; --i) {
            var dx = points[i].x - x
            var dy = points[i].y - y

            if (Math.sqrt(dx * dx + dy * dy) <= hitRadius)
                return i
        }

        return -1
    }

    function applyAction(action) {
        if (action.type === "add") {
            setPoints(points.concat([copyPoint(action.point)]))
        } else if (action.type === "remove") {
            var insertIndex = Math.max(0, Math.min(action.index, points.length))
            setPoints(points.slice(0, insertIndex).concat([copyPoint(action.point)], points.slice(insertIndex)))
        } else if (action.type === "clear") {
            setPoints([])
        } else if (action.type === "generate") {
            var generated = []

            for (var i = 0; i < action.points.length; ++i)
                generated.push(copyPoint(action.points[i]))

            setPoints(generated)
        }
    }

    function revertAction(action) {
        if (action.type === "add") {
            var index = points.length - 1

            for (var i = points.length - 1; i >= 0; --i) {
                if (points[i].x === action.point.x && points[i].y === action.point.y) {
                    index = i
                    break
                }
            }

            var nextPoints = points.slice(0, index).concat(points.slice(index + 1))
            setPoints(nextPoints)
        } else if (action.type === "remove") {
            var insertIndex = Math.max(0, Math.min(action.index, points.length))
            setPoints(points.slice(0, insertIndex).concat([copyPoint(action.point)], points.slice(insertIndex)))
        } else if (action.type === "clear") {
            var restoredPoints = []

            for (var j = 0; j < action.points.length; ++j)
                restoredPoints.push(copyPoint(action.points[j]))

            setPoints(restoredPoints)
        } else if (action.type === "generate") {
            var previousPoints = []

            for (var k = 0; k < action.previousPoints.length; ++k)
                previousPoints.push(copyPoint(action.previousPoints[k]))

            setPoints(previousPoints)
        }
    }

    function undo() {
        if (undoStack.length === 0)
            return

        stopDbscan()

        var action = undoStack[undoStack.length - 1]
        undoStack = undoStack.slice(0, undoStack.length - 1)
        revertAction(action)
        redoStack = redoStack.concat([action])
    }

    function redo() {
        if (redoStack.length === 0)
            return

        stopDbscan()

        var action = redoStack[redoStack.length - 1]
        redoStack = redoStack.slice(0, redoStack.length - 1)
        applyAction(action)
        undoStack = undoStack.concat([action])
    }

    function parseNumber(text, fallback) {
        var value = Number(String(text).replace(",", "."))
        return isFinite(value) ? value : fallback
    }

    function parsePositiveInt(text, fallback) {
        var value = Math.floor(parseNumber(text, fallback))
        return value > 0 ? value : fallback
    }

    function distance(first, second) {
        var firstPoint = pointForDistance(first)
        var secondPoint = pointForDistance(second)
        var dx = firstPoint.x - secondPoint.x
        var dy = firstPoint.y - secondPoint.y
        return Math.sqrt(dx * dx + dy * dy)
    }

    function distanceInPreparedPoints(first, second) {
        var dx = first.x - second.x
        var dy = first.y - second.y
        return Math.sqrt(dx * dx + dy * dy)
    }

    function pointForDistance(point) {
        if (epsilonUnit === "ед.") {
            return {
                "x": point.dataX === undefined ? point.x / Math.max(1, coordinatePixelScaleX) : point.dataX,
                "y": point.dataY === undefined ? point.y / Math.max(1, coordinatePixelScaleY) : point.dataY
            }
        }

        if (epsilonUnit === "см") {
            return {
                "x": point.x / pixelsPerCentimeter,
                "y": point.y / pixelsPerCentimeter
            }
        }

        return { "x": point.x, "y": point.y }
    }

    function epsilonToPixelSize(epsilon) {
        if (epsilonUnit === "ед.") {
            return {
                "x": epsilon * coordinatePixelScaleX,
                "y": epsilon * coordinatePixelScaleY
            }
        }

        if (epsilonUnit === "см") {
            var centimeters = epsilon * pixelsPerCentimeter
            return { "x": centimeters, "y": centimeters }
        }

        return { "x": epsilon, "y": epsilon }
    }

    function regionQuery(sourcePoints, index, epsilon) {
        var neighbors = []

        for (var i = 0; i < sourcePoints.length; ++i) {
            if (distance(sourcePoints[index], sourcePoints[i]) <= epsilon)
                neighbors.push(i)
        }

        return neighbors
    }

    function buildDistancePoints(sourcePoints) {
        var preparedPoints = []

        for (var i = 0; i < sourcePoints.length; ++i)
            preparedPoints.push(pointForDistance(sourcePoints[i]))

        return preparedPoints
    }

    function spatialKey(cellX, cellY) {
        return cellX + ":" + cellY
    }

    function buildSpatialIndex(distancePoints, epsilon) {
        var cellSize = Math.max(epsilon, 0.000001)
        var index = { "cellSize": cellSize, "cells": {} }

        for (var i = 0; i < distancePoints.length; ++i) {
            var cellX = Math.floor(distancePoints[i].x / cellSize)
            var cellY = Math.floor(distancePoints[i].y / cellSize)
            var key = spatialKey(cellX, cellY)

            if (index.cells[key] === undefined)
                index.cells[key] = []

            index.cells[key].push(i)
        }

        return index
    }

    function regionQueryIndexed(distancePoints, spatialIndex, pointIndex, epsilon) {
        var neighbors = []
        var point = distancePoints[pointIndex]
        var cellX = Math.floor(point.x / spatialIndex.cellSize)
        var cellY = Math.floor(point.y / spatialIndex.cellSize)

        for (var offsetX = -1; offsetX <= 1; ++offsetX) {
            for (var offsetY = -1; offsetY <= 1; ++offsetY) {
                var cell = spatialIndex.cells[spatialKey(cellX + offsetX, cellY + offsetY)]

                if (cell === undefined)
                    continue

                for (var i = 0; i < cell.length; ++i) {
                    var candidateIndex = cell[i]

                    if (distanceInPreparedPoints(point, distancePoints[candidateIndex]) <= epsilon)
                        neighbors.push(candidateIndex)
                }
            }
        }

        return neighbors
    }

    function containsIndex(indices, value) {
        for (var i = 0; i < indices.length; ++i) {
            if (indices[i] === value)
                return true
        }

        return false
    }

    function buildDbscanSteps(epsilon, minPts) {
        var sourcePoints = []

        for (var i = 0; i < points.length; ++i)
            sourcePoints.push(makePoint(points[i].x, points[i].y, points[i].dataX, points[i].dataY))

        var distancePoints = buildDistancePoints(sourcePoints)
        var spatialIndex = buildSpatialIndex(distancePoints, epsilon)
        var labels = new Array(sourcePoints.length).fill(0)
        var visited = new Array(sourcePoints.length).fill(false)
        var steps = []
        var clusterId = 0

        for (var pointIndex = 0; pointIndex < sourcePoints.length; ++pointIndex) {
            if (visited[pointIndex])
                continue

            visited[pointIndex] = true
            var neighbors = regionQueryIndexed(distancePoints, spatialIndex, pointIndex, epsilon)
            steps.push({ "type": "inspect", "index": pointIndex, "neighbors": neighbors, "cluster": clusterId })

            if (neighbors.length < minPts) {
                labels[pointIndex] = -1
                steps.push({ "type": "noise", "index": pointIndex })
                continue
            }

            clusterId += 1
            labels[pointIndex] = clusterId
            steps.push({ "type": "cluster", "index": pointIndex, "cluster": clusterId, "core": true })

            var seeds = neighbors.slice()
            var inSeeds = new Array(sourcePoints.length).fill(false)

            for (var seedIndex = 0; seedIndex < seeds.length; ++seedIndex)
                inSeeds[seeds[seedIndex]] = true

            for (var queueIndex = 0; queueIndex < seeds.length; ++queueIndex) {
                var neighborIndex = seeds[queueIndex]

                if (!visited[neighborIndex]) {
                    visited[neighborIndex] = true
                    var neighborNeighbors = regionQueryIndexed(distancePoints, spatialIndex, neighborIndex, epsilon)
                    steps.push({ "type": "inspect", "index": neighborIndex, "neighbors": neighborNeighbors, "cluster": clusterId })

                    if (neighborNeighbors.length >= minPts) {
                        for (var addIndex = 0; addIndex < neighborNeighbors.length; ++addIndex) {
                            var candidateSeed = neighborNeighbors[addIndex]

                            if (!inSeeds[candidateSeed]) {
                                seeds.push(candidateSeed)
                                inSeeds[candidateSeed] = true
                            }
                        }
                    }
                }

                if (labels[neighborIndex] <= 0) {
                    var isCore = regionQueryIndexed(distancePoints, spatialIndex, neighborIndex, epsilon).length >= minPts
                    labels[neighborIndex] = clusterId
                    steps.push({ "type": "cluster", "index": neighborIndex, "cluster": clusterId, "core": isCore })
                }
            }
        }

        steps.push({ "type": "finish", "clusters": clusterId })
        return steps
    }

    function runDbscanImmediately(epsilon, minPts) {
        var sourcePoints = []

        for (var i = 0; i < points.length; ++i)
            sourcePoints.push(makePoint(points[i].x, points[i].y, points[i].dataX, points[i].dataY))

        var distancePoints = buildDistancePoints(sourcePoints)
        var spatialIndex = buildSpatialIndex(distancePoints, epsilon)
        var labels = new Array(sourcePoints.length).fill(0)
        var isCorePoint = new Array(sourcePoints.length).fill(false)
        var visited = new Array(sourcePoints.length).fill(false)
        var clusterId = 0

        for (var pointIndex = 0; pointIndex < sourcePoints.length; ++pointIndex) {
            if (visited[pointIndex])
                continue

            visited[pointIndex] = true
            var neighbors = regionQueryIndexed(distancePoints, spatialIndex, pointIndex, epsilon)

            if (neighbors.length < minPts) {
                labels[pointIndex] = -1
                continue
            }

            clusterId += 1
            labels[pointIndex] = clusterId
            isCorePoint[pointIndex] = true

            var seeds = neighbors.slice()
            var inSeeds = new Array(sourcePoints.length).fill(false)

            for (var seedIndex = 0; seedIndex < seeds.length; ++seedIndex)
                inSeeds[seeds[seedIndex]] = true

            for (var queueIndex = 0; queueIndex < seeds.length; ++queueIndex) {
                var neighborIndex = seeds[queueIndex]

                if (!visited[neighborIndex]) {
                    visited[neighborIndex] = true
                    var neighborNeighbors = regionQueryIndexed(distancePoints, spatialIndex, neighborIndex, epsilon)

                    if (neighborNeighbors.length >= minPts) {
                        isCorePoint[neighborIndex] = true

                        for (var addIndex = 0; addIndex < neighborNeighbors.length; ++addIndex) {
                            var candidateSeed = neighborNeighbors[addIndex]

                            if (!inSeeds[candidateSeed]) {
                                seeds.push(candidateSeed)
                                inSeeds[candidateSeed] = true
                            }
                        }
                    }
                }

                if (labels[neighborIndex] <= 0)
                    labels[neighborIndex] = clusterId
            }
        }

        for (var resultIndex = 0; resultIndex < sourcePoints.length; ++resultIndex) {
            sourcePoints[resultIndex].cluster = labels[resultIndex]
            sourcePoints[resultIndex].noise = labels[resultIndex] === -1
            sourcePoints[resultIndex].core = isCorePoint[resultIndex]
        }

        setPoints(sourcePoints)
        currentPointIndex = -1
        currentClusterId = 0
        dbscanRunning = false
        dbscanSteps = []
        dbscanStepIndex = 0
        statusText = "Готово без анимации: кластеров " + clusterId
    }

    function applyDbscanStep(step) {
        if (step.type === "inspect") {
            currentPointIndex = step.index
            currentClusterId = step.cluster || 0
            statusText = "Проверяется точка " + (step.index + 1) + ": соседей " + step.neighbors.length
        } else if (step.type === "noise") {
            points[step.index].cluster = -1
            points[step.index].noise = true
            points[step.index].core = false
            statusText = "Точка " + (step.index + 1) + " — шум"
        } else if (step.type === "cluster") {
            points[step.index].cluster = step.cluster
            points[step.index].noise = false
            points[step.index].core = step.core
            currentClusterId = step.cluster
            statusText = "Точка " + (step.index + 1) + " -> кластер " + step.cluster
        } else if (step.type === "finish") {
            currentPointIndex = -1
            currentClusterId = 0
            dbscanRunning = false
            dbscanTimer.stop()
            statusText = "Готово: кластеров " + step.clusters
        }

        refreshCanvas()
    }

    function finishDbscanImmediately() {
        if (!dbscanRunning)
            return

        dbscanTimer.stop()

        while (dbscanStepIndex < dbscanSteps.length) {
            applyDbscanStep(dbscanSteps[dbscanStepIndex])
            dbscanStepIndex += 1
        }

        dbscanRunning = false
        refreshCanvas()
    }

    function startDbscan() {
        if (points.length === 0) {
            statusText = "Сначала добавьте точки"
            return
        }

        stopDbscan()
        resetPointStates()

        currentEpsilon = Math.max(0.01, parseNumber(epsilonField.text, 20))
        var epsilonPixels = epsilonToPixelSize(currentEpsilon)
        currentEpsilonPixelX = epsilonPixels.x
        currentEpsilonPixelY = epsilonPixels.y
        var minPts = parsePositiveInt(minPtsField.text, 4)

        if (points.length > animatedPointLimit) {
            statusText = "Много точек, считаю без анимации..."
            runDbscanImmediately(currentEpsilon, minPts)
            return
        }

        dbscanSteps = buildDbscanSteps(currentEpsilon, minPts)
        dbscanStepIndex = 0
        dbscanRunning = true
        statusText = "DBSCAN запущен"
        dbscanTimer.start()
    }

    function generateRandomPoints() {
        stopDbscan()
        useDefaultCoordinateScale()

        var count = Math.min(5000, parsePositiveInt(pointCountField.text, 100))
        var margin = pointRadius + 2
        var maxX = Math.max(margin, workspace.width - margin)
        var maxY = Math.max(margin, workspace.height - margin)
        var previousPoints = []
        var generated = []

        for (var i = 0; i < points.length; ++i)
            previousPoints.push(copyPoint(points[i]))

        for (var i = 0; i < count; ++i) {
            var x = margin + Math.random() * Math.max(1, maxX - margin)
            var y = margin + Math.random() * Math.max(1, maxY - margin)
            generated.push(makePoint(x, y))
        }

        setPoints(generated)
        pushAction({ "type": "generate", "points": generated, "previousPoints": previousPoints })
        statusText = "Сгенерировано точек: " + count
    }

    function loadPointsFromFile(fileUrl) {
        stopDbscan()

        var loadedCoordinates = pointLoader.loadPoints(fileUrl)

        if (loadedCoordinates.length === 0) {
            statusText = pointLoader.errorString.length > 0 ? pointLoader.errorString : "Точки не загружены"
            return
        }

        var margin = pointRadius + 8
        var minX = loadedCoordinates[0].x
        var maxX = loadedCoordinates[0].x
        var minY = loadedCoordinates[0].y
        var maxY = loadedCoordinates[0].y
        var previousPoints = []
        var loadedPoints = []

        for (var i = 0; i < points.length; ++i)
            previousPoints.push(copyPoint(points[i]))

        for (var j = 1; j < loadedCoordinates.length; ++j) {
            minX = Math.min(minX, loadedCoordinates[j].x)
            maxX = Math.max(maxX, loadedCoordinates[j].x)
            minY = Math.min(minY, loadedCoordinates[j].y)
            maxY = Math.max(maxY, loadedCoordinates[j].y)
        }

        var drawableWidth = Math.max(1, workspace.width - margin * 2)
        var drawableHeight = Math.max(1, workspace.height - margin * 2)
        var rangeX = Math.max(1, maxX - minX)
        var rangeY = Math.max(1, maxY - minY)
        var scale = Math.min(drawableWidth / rangeX, drawableHeight / rangeY)
        coordinatePixelScaleX = scale
        coordinatePixelScaleY = scale
        var contentWidth = rangeX * scale
        var contentHeight = rangeY * scale
        var offsetX = margin + (drawableWidth - contentWidth) / 2
        var offsetY = margin + (drawableHeight - contentHeight) / 2

        for (var k = 0; k < loadedCoordinates.length; ++k) {
            var dataX = loadedCoordinates[k].x
            var dataY = loadedCoordinates[k].y
            var screenX = offsetX + (dataX - minX) * scale
            var screenY = offsetY + contentHeight - (dataY - minY) * scale
            loadedPoints.push(makePoint(screenX, screenY, dataX, dataY))
        }

        setPoints(loadedPoints)
        pushAction({ "type": "generate", "points": loadedPoints, "previousPoints": previousPoints })
        epsilonUnitSelector.currentIndex = 0
        statusText = "Загружено точек: " + loadedPoints.length
    }

    function colorForCluster(clusterId) {
        if (clusterId <= 0)
            return null

        return clusterColors[(clusterId - 1) % clusterColors.length]
    }

    function drawEpsilonArea(context, x, y, radiusX, radiusY) {
        var segments = 96

        context.beginPath()

        for (var i = 0; i <= segments; ++i) {
            var angle = Math.PI * 2 * i / segments
            var pointX = x + Math.cos(angle) * radiusX
            var pointY = y + Math.sin(angle) * radiusY

            if (i === 0)
                context.moveTo(pointX, pointY)
            else
                context.lineTo(pointX, pointY)
        }
    }

    Timer {
        id: dbscanTimer

        interval: 220
        repeat: true

        onTriggered: {
            if (root.dbscanStepIndex >= root.dbscanSteps.length) {
                root.dbscanRunning = false
                stop()
                return
            }

            root.applyDbscanStep(root.dbscanSteps[root.dbscanStepIndex])
            root.dbscanStepIndex += 1
        }
    }

    FileDialog {
        id: loadFileDialog

        title: "Загрузить точки"
        nameFilters: ["Файлы с точками (*.xlsx *.txt *.csv *.tsv)", "Файлы Excel (*.xlsx)", "Текстовые файлы (*.txt *.csv *.tsv)", "Все файлы (*)"]
        onAccepted: root.loadPointsFromFile(selectedFile)
    }

    Shortcut {
        sequences: [StandardKey.Undo, "Ctrl+Z"]
        onActivated: root.undo()
    }

    Shortcut {
        sequences: [StandardKey.Redo, "Ctrl+Shift+Z", "Ctrl+Y"]
        onActivated: root.redo()
    }

    Rectangle {
        anchors.fill: parent
        color: "#000000"

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 56
                color: "#080808"
                border.color: "#242424"
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    spacing: 10

                    ToolbarButton {
                        text: "Отменить"
                        enabled: root.undoStack.length > 0 && !root.dbscanRunning
                        onClicked: root.undo()
                    }

                    ToolbarButton {
                        text: "Вернуть"
                        enabled: root.redoStack.length > 0 && !root.dbscanRunning
                        onClicked: root.redo()
                    }

                    ToolbarButton {
                        text: "Очистить"
                        enabled: root.points.length > 0 && !root.dbscanRunning
                        onClicked: root.clearPoints(true)
                    }

                    ToolbarButton {
                        text: "Ускорить"
                        enabled: root.dbscanRunning
                        onClicked: root.finishDbscanImmediately()
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    Label {
                        color: "#bdbdbd"
                        text: root.statusText
                        font.pixelSize: 14
                    }

                    Label {
                        color: "#bdbdbd"
                        text: root.points.length + " точек"
                        font.pixelSize: 14
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0

                Rectangle {
                    id: workspace

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: "#000000"
                    border.color: "#2d2d2d"
                    border.width: 1
                    clip: true

                    Canvas {
                        id: workspaceCanvas

                        anchors.fill: parent
                        antialiasing: true

                        onPaint: {
                            var context = getContext("2d")
                            context.reset()
                            context.clearRect(0, 0, width, height)

                            if (root.currentPointIndex >= 0 && root.currentPointIndex < root.points.length) {
                                var activePoint = root.points[root.currentPointIndex]
                                var activeColors = root.colorForCluster(root.currentClusterId)
                                root.drawEpsilonArea(context, activePoint.x, activePoint.y, root.currentEpsilonPixelX, root.currentEpsilonPixelY)
                                context.lineWidth = 1.4
                                context.strokeStyle = activeColors ? activeColors.ring : "#ffffff"
                                context.globalAlpha = 0.55
                                context.stroke()
                                context.globalAlpha = 1
                            }

                            for (var i = 0; i < root.points.length; ++i) {
                                var point = root.points[i]
                                var radius = i === root.currentPointIndex ? root.pointRadius * 2 : root.pointRadius
                                var colors = root.colorForCluster(point.cluster)

                                context.beginPath()
                                context.arc(point.x, point.y, radius, 0, Math.PI * 2)
                                context.lineWidth = point.core ? 2.2 : 1.6

                                if (point.cluster > 0 && colors) {
                                    context.fillStyle = colors.fill
                                    context.strokeStyle = colors.stroke
                                    context.fill()
                                    context.stroke()
                                } else if (point.cluster === -1 || point.noise) {
                                    context.fillStyle = root.noiseFill
                                    context.strokeStyle = root.noiseStroke
                                    context.fill()
                                    context.stroke()
                                } else {
                                    context.fillStyle = "rgba(255, 255, 255, 0)"
                                    context.strokeStyle = "#ffffff"
                                    context.stroke()
                                }
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        hoverEnabled: true

                        onClicked: function(mouse) {
                            if (root.dbscanRunning)
                                return

                            if (mouse.button === Qt.LeftButton) {
                                root.addPoint(mouse.x, mouse.y, true)
                            } else if (mouse.button === Qt.RightButton) {
                                var index = root.findPointIndex(mouse.x, mouse.y)

                                if (index !== -1)
                                    root.removePoint(index, true)
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 280
                    Layout.fillHeight: true
                    color: "#0a0a0a"
                    border.color: "#252525"
                    border.width: 1

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 18
                        spacing: 14

                        SideButton {
                            Layout.fillWidth: true
                            text: root.dbscanRunning ? "Идёт..." : "Запустить DBSCAN"
                            enabled: root.points.length > 0 && !root.dbscanRunning
                            onClicked: root.startDbscan()
                        }

                        SideButton {
                            Layout.fillWidth: true
                            text: "Загрузить файл"
                            enabled: !root.dbscanRunning
                            onClicked: loadFileDialog.open()
                        }

                        SideButton {
                            Layout.fillWidth: true
                            text: "Сгенерировать точки"
                            enabled: !root.dbscanRunning
                            onClicked: root.generateRandomPoints()
                        }

                        Item {
                            Layout.preferredHeight: 8
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            enabled: !root.dbscanRunning

                            FieldEditor {
                                id: epsilonField

                                Layout.fillWidth: true
                                label: "эпсилон"
                                text: "8"
                                enabled: parent.enabled
                            }

                            UnitSelector {
                                id: epsilonUnitSelector

                                Layout.preferredWidth: 86
                                Layout.alignment: Qt.AlignBottom
                                enabled: parent.enabled
                                model: ["единицы", "пиксели", "см"]
                                currentIndex: 0

                                onCurrentTextChanged: root.epsilonUnit = currentText
                                Component.onCompleted: root.epsilonUnit = currentText
                            }
                        }

                        FieldEditor {
                            id: minPtsField

                            Layout.fillWidth: true
                            label: "мин. точек"
                            text: "4"
                            enabled: !root.dbscanRunning
                        }

                        FieldEditor {
                            id: pointCountField

                            Layout.fillWidth: true
                            label: "точек"
                            text: "100"
                            enabled: !root.dbscanRunning
                        }

                        Item {
                            Layout.fillHeight: true
                        }
                    }
                }
            }
        }
    }

}
