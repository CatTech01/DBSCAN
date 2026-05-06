import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Dialogs
import QtQuick.Layouts

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
    property int selectedClusterId: 0
    property int selectedNoisePointIndex: -1
    property real selectedClusterCenterX: -1
    property real selectedClusterCenterY: -1
    property var selectedItems: []
    property var clusterInfoCache: ({})
    property var distanceInfoCache: ({})
    property string selectedInfoText: "Выберите кластер или аномальную точку"
    property string selectedClusterMetricMode: "center"
    property bool showPairDistanceLine: false
    property bool editLocked: false
    property string warningTitle: ""
    property string warningText: ""
    property string pendingWarningAction: ""
    property bool doNotAskHeavyDbscan: false
    property bool doNotAskHeavyCluster: false
    property real pendingSelectionX: 0
    property real pendingSelectionY: 0
    property bool pendingSelectionAdd: false
    property real currentEpsilon: 20
    property real currentEpsilonPixelX: 20
    property real currentEpsilonPixelY: 20
    property real coordinatePixelScaleX: 1
    property real coordinatePixelScaleY: 1
    property string epsilonUnit: "единицы"
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
        var scale = Math.min(Math.max(1, workspace.width) / coordinateWidth,
                             Math.max(1, workspace.height) / coordinateHeight)
        coordinatePixelScaleX = scale
        coordinatePixelScaleY = scale
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

    function clearSelection() {
        selectedClusterId = 0
        selectedNoisePointIndex = -1
        selectedClusterCenterX = -1
        selectedClusterCenterY = -1
        selectedItems = []
        selectedInfoText = "Выберите кластер или аномальную точку"
        selectedClusterMetricMode = "center"
        showPairDistanceLine = false
    }

    function resetAnalysisCache() {
        clusterInfoCache = ({})
        distanceInfoCache = ({})
    }

    function clusterCacheKey(clusterId) {
        return epsilonUnit + ":cluster:" + clusterId
    }

    function countClusterPoints(clusterId) {
        var count = 0

        for (var i = 0; i < points.length; ++i) {
            if (points[i].cluster === clusterId)
                count += 1
        }

        return count
    }

    function showWarning(title, text, action) {
        warningTitle = title
        warningText = text
        pendingWarningAction = action
        doNotAskAgainCheck.checked = false
        waitWarningPopup.open()
    }

    function continuePendingAction() {
        var action = pendingWarningAction
        pendingWarningAction = ""

        if (doNotAskAgainCheck.checked) {
            if (action === "dbscan")
                doNotAskHeavyDbscan = true
            else if (action === "clusterSelection")
                doNotAskHeavyCluster = true
        }

        waitWarningPopup.close()

        if (action === "dbscan") {
            startDbscan(true)
        } else if (action === "clusterSelection") {
            selectClusterAt(pendingSelectionX, pendingSelectionY, pendingSelectionAdd, true)
        }
    }

    function stopDbscan() {
        if (dbscanTimer.running)
            dbscanTimer.stop()

        dbscanRunning = false
        dbscanSteps = []
        dbscanStepIndex = 0
        currentPointIndex = -1
        currentClusterId = 0
        clearSelection()
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
        clearSelection()
        statusText = "Готово"
    }

    function pushAction(action) {
        undoStack = undoStack.concat([action])
        redoStack = []
    }

    function addPoint(x, y, remember) {
        stopDbscan()
        resetAnalysisCache()

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
        resetAnalysisCache()

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
        resetAnalysisCache()

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

    function getClusterInfo(clusterId) {
        var key = clusterCacheKey(clusterId)

        if (clusterInfoCache[key] === undefined)
            clusterInfoCache[key] = clusterAnalyzer.clusterInfo(points, clusterId, epsilonUnit, pixelsPerCentimeter)

        return clusterInfoCache[key]
    }

    function distanceXForPoint(point) {
        if (epsilonUnit === "пиксели")
            return point.x

        if (epsilonUnit === "см")
            return point.x / pixelsPerCentimeter

        return point.dataX
    }

    function distanceYForPoint(point) {
        if (epsilonUnit === "пиксели")
            return point.y

        if (epsilonUnit === "см")
            return point.y / pixelsPerCentimeter

        return point.dataY
    }

    function makeClusterSelection(clusterId) {
        var info = getClusterInfo(clusterId)

        if (!info.found)
            return null

        return {
            "type": "cluster",
            "id": clusterId,
            "x": info.distanceX,
            "y": info.distanceY,
            "screenX": info.screenX,
            "screenY": info.screenY
        }
    }

    function makeNoiseSelection(index) {
        if (index < 0 || index >= points.length)
            return null

        return {
            "type": "noise",
            "id": index,
            "x": distanceXForPoint(points[index]),
            "y": distanceYForPoint(points[index]),
            "screenX": points[index].x,
            "screenY": points[index].y
        }
    }

    function selectionKey(item) {
        return item.type + ":" + item.id
    }

    function pairKey(first, second) {
        var firstKey = selectionKey(first)
        var secondKey = selectionKey(second)
        return epsilonUnit + ":" + (firstKey < secondKey ? firstKey + "|" + secondKey : secondKey + "|" + firstKey)
    }

    function distanceBetween(first, second) {
        var key = pairKey(first, second)

        if (distanceInfoCache[key] === undefined) {
            var dx = first.x - second.x
            var dy = first.y - second.y
            distanceInfoCache[key] = Math.sqrt(dx * dx + dy * dy)
        }

        return distanceInfoCache[key]
    }

    function updateSelectionState() {
        selectedClusterId = 0
        selectedNoisePointIndex = -1
        selectedClusterCenterX = -1
        selectedClusterCenterY = -1
        showPairDistanceLine = false

        for (var i = 0; i < selectedItems.length; ++i) {
            if (selectedItems[i].type === "cluster" && selectedClusterId === 0) {
                selectedClusterId = selectedItems[i].id
                selectedClusterCenterX = selectedItems[i].screenX
                selectedClusterCenterY = selectedItems[i].screenY
            } else if (selectedItems[i].type === "noise" && selectedNoisePointIndex === -1) {
                selectedNoisePointIndex = selectedItems[i].id
            }
        }

        if (selectedItems.length === 1) {
            if (selectedItems[0].type === "cluster")
                selectedInfoText = clusterInfoText(getClusterInfo(selectedItems[0].id))
            else
                selectedInfoText = noiseInfoText(selectedItems[0].id)
        } else if (selectedItems.length === 2) {
            selectedInfoText = pairInfoText(selectedItems[0], selectedItems[1])
        } else {
            selectedInfoText = "Выберите кластер или аномальную точку"
        }

        if (selectedItems.length !== 1 || selectedItems[0].type !== "cluster")
            selectedClusterMetricMode = "center"
    }

    function rebuildSelectedItemsForCurrentUnit() {
        if (selectedItems.length === 0)
            return

        var rebuiltItems = []

        for (var i = 0; i < selectedItems.length; ++i) {
            var item = selectedItems[i].type === "cluster"
                    ? makeClusterSelection(selectedItems[i].id)
                    : makeNoiseSelection(selectedItems[i].id)

            if (item !== null)
                rebuiltItems.push(item)
        }

        selectedItems = rebuiltItems
        updateSelectionState()
        refreshCanvas()
    }

    function selectClusterAt(x, y, addToSelection, skipWarning) {
        var index = findPointIndex(x, y)

        if (index === -1)
            return false

        var item = null

        if (points[index].cluster > 0) {
            var clusterId = points[index].cluster
            var key = clusterCacheKey(clusterId)

            if (!skipWarning && !doNotAskHeavyCluster && clusterInfoCache[key] === undefined && countClusterPoints(clusterId) > animatedPointLimit) {
                pendingSelectionX = x
                pendingSelectionY = y
                pendingSelectionAdd = addToSelection
                showWarning(
                    "Нужно немного подождать",
                    "В выбранном кластере много точек. Чтобы найти центр, диагональ и расстояния, программе нужно время. Ничего страшного не случится, просто нужно немного подождать. Продолжить?",
                    "clusterSelection"
                )
                return true
            }

            item = makeClusterSelection(points[index].cluster)
            statusText = "Выбран кластер " + points[index].cluster
        } else if (points[index].cluster === -1 || points[index].noise) {
            item = makeNoiseSelection(index)
            statusText = "Выбрана аномалия"
        } else {
            return false
        }

        if (item === null)
            return false

        if (addToSelection) {
            var nextItems = selectedItems.slice()
            var key = selectionKey(item)
            var alreadySelected = false

            for (var i = 0; i < nextItems.length; ++i) {
                if (selectionKey(nextItems[i]) === key) {
                    alreadySelected = true
                    break
                }
            }

            if (!alreadySelected)
                nextItems.push(item)

            if (nextItems.length > 2)
                nextItems = nextItems.slice(nextItems.length - 2)

            selectedItems = nextItems
        } else {
            selectedItems = [item]
        }

        selectedClusterMetricMode = "center"
        showPairDistanceLine = false
        updateSelectionState()
        refreshCanvas()
        return true
    }

    function selectedClusterBounds(clusterId) {
        if (clusterId <= 0)
            return { "found": false }

        var minX = 0
        var minY = 0
        var maxX = 0
        var maxY = 0
        var found = false

        for (var i = 0; i < points.length; ++i) {
            if (points[i].cluster !== clusterId)
                continue

            if (!found) {
                minX = points[i].x
                maxX = points[i].x
                minY = points[i].y
                maxY = points[i].y
                found = true
            } else {
                minX = Math.min(minX, points[i].x)
                maxX = Math.max(maxX, points[i].x)
                minY = Math.min(minY, points[i].y)
                maxY = Math.max(maxY, points[i].y)
            }
        }

        if (!found)
            return { "found": false }

        var padding = 16
        minX = Math.max(0, minX - padding)
        minY = Math.max(0, minY - padding)
        maxX = Math.min(workspace.width, maxX + padding)
        maxY = Math.min(workspace.height, maxY + padding)

        return {
            "found": true,
            "x": minX,
            "y": minY,
            "width": Math.max(1, maxX - minX),
            "height": Math.max(1, maxY - minY)
        }
    }

    function formatNumber(value) {
        if (value === undefined || !isFinite(value))
            return "—"

        return Number(value).toFixed(3)
    }

    function selectedNoisePoint(index) {
        if (index < 0 || index >= points.length)
            return null

        return points[index]
    }

    function clusterInfoText(info) {
        if (selectedClusterId <= 0)
            return ""

        if (!info.found)
            return ""

        return "Кластер " + selectedClusterId
                + "    Точек: " + info.count
                + "    Центр: (" + formatNumber(info.centerX) + "; " + formatNumber(info.centerY) + ")"
                + "    Мин. расстояние (" + epsilonUnit + "): " + formatNumber(info.minDistance)
                + "    Макс. расстояние (" + epsilonUnit + "): " + formatNumber(info.maxDistance)
                + "    Диагональ (" + epsilonUnit + "): " + formatNumber(info.diagonal)
    }

    function hasSingleClusterSelection() {
        return selectedItems.length === 1 && selectedItems[0].type === "cluster"
    }

    function hasPairSelection() {
        return selectedItems.length === 2
    }

    function selectedClusterInfo() {
        if (!hasSingleClusterSelection())
            return ({ "found": false })

        return getClusterInfo(selectedItems[0].id)
    }

    function selectClusterCenter() {
        selectedClusterMetricMode = "center"
        refreshCanvas()
    }

    function selectClusterDiagonal() {
        selectedClusterMetricMode = "diagonal"
        refreshCanvas()
    }

    function selectClusterMinDistance() {
        selectedClusterMetricMode = "minDistance"
        refreshCanvas()
    }

    function selectClusterMaxDistance() {
        selectedClusterMetricMode = "maxDistance"
        refreshCanvas()
    }

    function togglePairDistanceLine() {
        showPairDistanceLine = !showPairDistanceLine
        refreshCanvas()
    }

    function noiseInfoText(index) {
        var point = selectedNoisePoint(index)

        if (point === null)
            return ""

        return "Аномалия    Координаты: (" + formatNumber(point.dataX) + "; " + formatNumber(point.dataY) + ")"
    }

    function pairInfoText(first, second) {
        var distance = distanceBetween(first, second)

        if (first.type === "cluster" && second.type === "cluster") {
            return "Расстояние между центрами кластеров "
                    + first.id + " и " + second.id + " (" + epsilonUnit + "): " + formatNumber(distance)
        }

        if (first.type === "cluster" && second.type === "noise") {
            return "Расстояние между центром кластера "
                    + first.id + " и аномалией (" + epsilonUnit + "): " + formatNumber(distance)
        }

        if (first.type === "noise" && second.type === "cluster") {
            return "Расстояние между аномалией и центром кластера "
                    + second.id + " (" + epsilonUnit + "): " + formatNumber(distance)
        }

        return "Расстояние между аномалиями (" + epsilonUnit + "): " + formatNumber(distance)
    }

    function selectedClusterBaseText() {
        if (!hasSingleClusterSelection())
            return ""

        var info = selectedClusterInfo()

        if (!info.found)
            return ""

        return "Кластер " + selectedItems[0].id + "    Точек: " + info.count
    }

    function selectedClusterCenterText() {
        var info = selectedClusterInfo()

        if (!info.found)
            return "Центр: —"

        return "Центр: (" + formatNumber(info.centerX) + "; " + formatNumber(info.centerY) + ")"
    }

    function selectedClusterMinDistanceText() {
        var info = selectedClusterInfo()

        if (!info.found)
            return "Мин. расстояние: —"

        return "Мин. расстояние (" + epsilonUnit + "): " + formatNumber(info.minDistance)
    }

    function selectedClusterMaxDistanceText() {
        var info = selectedClusterInfo()

        if (!info.found)
            return "Макс. расстояние: —"

        return "Макс. расстояние (" + epsilonUnit + "): " + formatNumber(info.maxDistance)
    }

    function selectedClusterDiagonalText() {
        var info = selectedClusterInfo()

        if (!info.found)
            return "Диагональ: —"

        return "Диагональ (" + epsilonUnit + "): " + formatNumber(info.diagonal)
    }

    function pairDistanceCaption() {
        if (!hasPairSelection())
            return ""

        var first = selectedItems[0]
        var second = selectedItems[1]

        if (first.type === "cluster" && second.type === "cluster")
            return "Расстояние между центрами кластеров " + first.id + " и " + second.id + " (" + epsilonUnit + "):"

        if (first.type === "cluster" && second.type === "noise")
            return "Расстояние между центром кластера " + first.id + " и аномалией (" + epsilonUnit + "):"

        if (first.type === "noise" && second.type === "cluster")
            return "Расстояние между аномалией и центром кластера " + second.id + " (" + epsilonUnit + "):"

        return "Расстояние между аномалиями (" + epsilonUnit + "):"
    }

    function pairDistanceValueText() {
        if (!hasPairSelection())
            return "—"

        return formatNumber(distanceBetween(selectedItems[0], selectedItems[1]))
    }

    function isNoiseSelected(index) {
        for (var i = 0; i < selectedItems.length; ++i) {
            if (selectedItems[i].type === "noise" && selectedItems[i].id === index)
                return true
        }

        return false
    }

    function isSelectedClusterCenter(point) {
        for (var i = 0; i < selectedItems.length; ++i) {
            if (selectedItems[i].type !== "cluster")
                continue

            if (Math.abs(point.x - selectedItems[i].screenX) < 0.001
                    && Math.abs(point.y - selectedItems[i].screenY) < 0.001)
                return true
        }

        return false
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
        resetAnalysisCache()

        var action = undoStack[undoStack.length - 1]
        undoStack = undoStack.slice(0, undoStack.length - 1)
        revertAction(action)
        redoStack = redoStack.concat([action])
    }

    function redo() {
        if (redoStack.length === 0)
            return

        stopDbscan()
        resetAnalysisCache()

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

    function epsilonToPixelSize(epsilon) {
        if (epsilonUnit === "единицы") {
            var scale = Math.min(coordinatePixelScaleX, coordinatePixelScaleY)
            return {
                "x": epsilon * scale,
                "y": epsilon * scale
            }
        }

        if (epsilonUnit === "см") {
            var centimeters = epsilon * pixelsPerCentimeter
            return { "x": centimeters, "y": centimeters }
        }

        return { "x": epsilon, "y": epsilon }
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
            clearSelection()
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

    function startDbscan(skipWarning) {
        if (points.length === 0) {
            statusText = "Сначала добавьте точки"
            return
        }

        if (!skipWarning && !doNotAskHeavyDbscan && points.length > animatedPointLimit) {
            showWarning(
                "Нужно немного подождать",
                "Точек много, поэтому DBSCAN будет считаться без анимации и может занять время. Ничего страшного не случится, просто нужно немного подождать. Продолжить?",
                "dbscan"
            )
            return
        }

        stopDbscan()
        resetAnalysisCache()
        resetPointStates()

        currentEpsilon = Math.max(0.01, parseNumber(epsilonField.text, 20))
        var epsilonPixels = epsilonToPixelSize(currentEpsilon)
        currentEpsilonPixelX = epsilonPixels.x
        currentEpsilonPixelY = epsilonPixels.y
        var minPts = parsePositiveInt(minPtsField.text, 4)

        if (points.length > animatedPointLimit) {
            statusText = "Много точек, считаю без анимации..."
            var result = dbscanAlgorithm.runImmediately(points, currentEpsilon, minPts, epsilonUnit, coordinatePixelScaleX, coordinatePixelScaleY, pixelsPerCentimeter)
            setPoints(result.points)
            currentPointIndex = -1
            currentClusterId = 0
            clearSelection()
            dbscanRunning = false
            dbscanSteps = []
            dbscanStepIndex = 0
            statusText = "Готово без анимации: кластеров " + result.clusters
            return
        }

        dbscanSteps = dbscanAlgorithm.buildSteps(points, currentEpsilon, minPts, epsilonUnit, coordinatePixelScaleX, coordinatePixelScaleY, pixelsPerCentimeter)
        dbscanStepIndex = 0
        dbscanRunning = true
        statusText = "DBSCAN запущен"
        dbscanTimer.start()
    }

    function generateRandomPoints() {
        stopDbscan()
        resetAnalysisCache()
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
        resetAnalysisCache()

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

    function drawWhiteConnection(context, x1, y1, x2, y2) {
        context.beginPath()
        context.moveTo(x1, y1)
        context.lineTo(x2, y2)
        context.lineWidth = 2.2
        context.strokeStyle = "#ffffff"
        context.globalAlpha = 0.95
        context.stroke()
        context.globalAlpha = 1
    }

    function drawHighlightedPoint(context, x, y) {
        context.beginPath()
        context.arc(x, y, pointRadius * 1.8, 0, Math.PI * 2)
        context.lineWidth = 2.4
        context.fillStyle = "rgba(255, 255, 255, 0)"
        context.strokeStyle = "#ffffff"
        context.stroke()
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
        nameFilters: ["Файлы с точками (*.xlsx *.xls *.txt *.csv *.tsv)", "Файлы Excel (*.xlsx *.xls)", "Текстовые файлы (*.txt *.csv *.tsv)", "Все файлы (*)"]
        onAccepted: root.loadPointsFromFile(selectedFile)
    }

    Popup {
        id: waitWarningPopup

        anchors.centerIn: parent
        width: Math.min(root.width - 40, 460)
        modal: true
        closePolicy: Popup.NoAutoClose
        padding: 18

        background: Rectangle {
            radius: 8
            color: "#101010"
            border.color: "#565656"
            border.width: 1
        }

        contentItem: ColumnLayout {
            spacing: 14

            Label {
                Layout.fillWidth: true
                color: "#ffffff"
                text: root.warningTitle
                font.pixelSize: 18
                font.bold: true
                wrapMode: Text.WordWrap
            }

            Label {
                Layout.fillWidth: true
                color: "#d8d8d8"
                text: root.warningText
                font.pixelSize: 14
                wrapMode: Text.WordWrap
            }

            CheckBox {
                id: doNotAskAgainCheck

                Layout.fillWidth: true
                text: "Больше не спрашивать"
                font.pixelSize: 14

                indicator: Rectangle {
                    implicitWidth: 18
                    implicitHeight: 18
                    x: 0
                    y: parent.height / 2 - height / 2
                    radius: 4
                    color: "#050505"
                    border.color: doNotAskAgainCheck.checked ? "#ffffff" : "#6a6a6a"
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        color: "#ffffff"
                        text: doNotAskAgainCheck.checked ? "✓" : ""
                        font.pixelSize: 14
                    }
                }

                contentItem: Text {
                    leftPadding: doNotAskAgainCheck.indicator.width + 8
                    color: "#d8d8d8"
                    text: doNotAskAgainCheck.text
                    font: doNotAskAgainCheck.font
                    verticalAlignment: Text.AlignVCenter
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Item {
                    Layout.fillWidth: true
                }

                ToolButton {
                    text: "Отказаться"
                    onClicked: {
                        root.pendingWarningAction = ""
                        waitWarningPopup.close()
                    }
                }

                ToolButton {
                    text: "Продолжить"
                    onClicked: root.continuePendingAction()
                }
            }
        }
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

                    ToolButton {
                        text: "Отменить"
                        enabled: root.undoStack.length > 0 && !root.dbscanRunning
                        onClicked: root.undo()
                    }

                    ToolButton {
                        text: "Вернуть"
                        enabled: root.redoStack.length > 0 && !root.dbscanRunning
                        onClicked: root.redo()
                    }

                    ToolButton {
                        text: "Очистить"
                        enabled: root.points.length > 0 && !root.dbscanRunning
                        onClicked: root.clearPoints(true)
                    }

                    ToolButton {
                        text: "Ускорить"
                        enabled: root.dbscanRunning
                        onClicked: root.finishDbscanImmediately()
                    }

                    ToolButton {
                        Layout.preferredWidth: 112
                        text: root.editLocked ? "Разморозить" : "Заморозить"
                        enabled: !root.dbscanRunning
                        onClicked: {
                            root.editLocked = !root.editLocked
                            root.statusText = root.editLocked ? "Поле заморожено" : "Поле разморожено"
                        }
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

                                var noiseSelected = root.isNoiseSelected(i)

                                if (noiseSelected)
                                    radius = root.pointRadius * 1.8

                                context.beginPath()
                                context.arc(point.x, point.y, radius, 0, Math.PI * 2)
                                context.lineWidth = noiseSelected ? 2.4 : point.core ? 2.2 : 1.6

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

                            for (var selectionIndex = 0; selectionIndex < root.selectedItems.length; ++selectionIndex) {
                                if (root.selectedItems[selectionIndex].type !== "cluster")
                                    continue

                                var bounds = root.selectedClusterBounds(root.selectedItems[selectionIndex].id)

                                if (bounds.found) {
                                    var selectedColors = root.colorForCluster(root.selectedItems[selectionIndex].id)
                                    context.beginPath()
                                    context.rect(bounds.x, bounds.y, bounds.width, bounds.height)
                                    context.lineWidth = 2.4
                                    context.strokeStyle = selectedColors ? selectedColors.ring : "#ffffff"
                                    context.globalAlpha = 0.9
                                    context.stroke()
                                    context.globalAlpha = 1
                                }
                            }

                            if (root.hasSingleClusterSelection() && root.selectedClusterMetricMode === "diagonal") {
                                var diagonalInfo = root.selectedClusterInfo()

                                if (diagonalInfo.found) {
                                    root.drawWhiteConnection(context,
                                                             diagonalInfo.diagonalStartX,
                                                             diagonalInfo.diagonalStartY,
                                                             diagonalInfo.diagonalEndX,
                                                             diagonalInfo.diagonalEndY)
                                    root.drawHighlightedPoint(context, diagonalInfo.diagonalStartX, diagonalInfo.diagonalStartY)
                                    root.drawHighlightedPoint(context, diagonalInfo.diagonalEndX, diagonalInfo.diagonalEndY)
                                }
                            }

                            if (root.hasSingleClusterSelection() && root.selectedClusterMetricMode === "minDistance") {
                                var minDistanceInfo = root.selectedClusterInfo()

                                if (minDistanceInfo.found) {
                                    root.drawWhiteConnection(context,
                                                             minDistanceInfo.screenX,
                                                             minDistanceInfo.screenY,
                                                             minDistanceInfo.minDistancePointX,
                                                             minDistanceInfo.minDistancePointY)
                                    root.drawHighlightedPoint(context, minDistanceInfo.screenX, minDistanceInfo.screenY)
                                    root.drawHighlightedPoint(context, minDistanceInfo.minDistancePointX, minDistanceInfo.minDistancePointY)
                                }
                            }

                            if (root.hasSingleClusterSelection() && root.selectedClusterMetricMode === "maxDistance") {
                                var maxDistanceInfo = root.selectedClusterInfo()

                                if (maxDistanceInfo.found) {
                                    root.drawWhiteConnection(context,
                                                             maxDistanceInfo.screenX,
                                                             maxDistanceInfo.screenY,
                                                             maxDistanceInfo.maxDistancePointX,
                                                             maxDistanceInfo.maxDistancePointY)
                                    root.drawHighlightedPoint(context, maxDistanceInfo.screenX, maxDistanceInfo.screenY)
                                    root.drawHighlightedPoint(context, maxDistanceInfo.maxDistancePointX, maxDistanceInfo.maxDistancePointY)
                                }
                            }

                            if (root.showPairDistanceLine && root.selectedItems.length === 2) {
                                root.drawWhiteConnection(context,
                                                         root.selectedItems[0].screenX,
                                                         root.selectedItems[0].screenY,
                                                         root.selectedItems[1].screenX,
                                                         root.selectedItems[1].screenY)
                            }

                            for (var centerIndex = 0; centerIndex < root.points.length; ++centerIndex) {
                                var centerPoint = root.points[centerIndex]

                                if (root.hasSingleClusterSelection() && root.selectedClusterMetricMode !== "center")
                                    continue

                                if (!root.isSelectedClusterCenter(centerPoint))
                                    continue

                                var centerColors = root.colorForCluster(centerPoint.cluster)
                                context.beginPath()
                                context.arc(centerPoint.x, centerPoint.y, root.pointRadius * 1.9, 0, Math.PI * 2)
                                context.lineWidth = 2.6
                                context.fillStyle = centerColors ? centerColors.fill : "#ffffff"
                                context.strokeStyle = "#ffffff"
                                context.fill()
                                context.stroke()
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
                                var addToSelection = (mouse.modifiers & Qt.ShiftModifier) !== 0

                                if (root.selectClusterAt(mouse.x, mouse.y, addToSelection, false))
                                    return

                                if (root.editLocked) {
                                    root.statusText = "Поле заморожено: новые точки не ставятся"
                                    return
                                }

                                root.addPoint(mouse.x, mouse.y, true)
                            } else if (mouse.button === Qt.RightButton) {
                                if (root.editLocked) {
                                    root.statusText = "Поле заморожено: точки не удаляются"
                                    return
                                }

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

                                onCurrentTextChanged: {
                                    root.epsilonUnit = currentText
                                    root.rebuildSelectedItemsForCurrentUnit()
                                }
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

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 46
                color: "#080808"
                border.color: selectedClusterId > 0
                              ? (colorForCluster(selectedClusterId) ? colorForCluster(selectedClusterId).ring : "#3a3a3a")
                              : selectedNoisePointIndex >= 0 ? noiseStroke : "#242424"
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    spacing: 12

                    Label {
                        visible: !root.hasSingleClusterSelection() && !root.hasPairSelection()
                        Layout.fillWidth: true
                        color: "#f2f2f2"
                        text: root.selectedInfoText
                        font.pixelSize: 14
                        elide: Text.ElideRight
                    }

                    Label {
                        visible: root.hasSingleClusterSelection()
                        color: "#f2f2f2"
                        text: root.selectedClusterBaseText()
                        font.pixelSize: 14
                        elide: Text.ElideRight
                    }

                    InfoValueButton {
                        visible: root.hasSingleClusterSelection()
                        text: root.selectedClusterCenterText()
                        checked: root.selectedClusterMetricMode === "center"
                        onClicked: root.selectClusterCenter()
                    }

                    InfoValueButton {
                        visible: root.hasSingleClusterSelection()
                        text: root.selectedClusterMinDistanceText()
                        checked: root.selectedClusterMetricMode === "minDistance"
                        onClicked: root.selectClusterMinDistance()
                    }

                    InfoValueButton {
                        visible: root.hasSingleClusterSelection()
                        text: root.selectedClusterMaxDistanceText()
                        checked: root.selectedClusterMetricMode === "maxDistance"
                        onClicked: root.selectClusterMaxDistance()
                    }

                    Item {
                        visible: root.hasSingleClusterSelection()
                        Layout.fillWidth: true
                    }

                    InfoValueButton {
                        visible: root.hasSingleClusterSelection()
                        text: root.selectedClusterDiagonalText()
                        checked: root.selectedClusterMetricMode === "diagonal"
                        onClicked: root.selectClusterDiagonal()
                    }

                    Label {
                        visible: root.hasPairSelection()
                        color: "#f2f2f2"
                        text: root.pairDistanceCaption()
                        font.pixelSize: 14
                        elide: Text.ElideRight
                    }

                    InfoValueButton {
                        visible: root.hasPairSelection()
                        text: root.pairDistanceValueText()
                        checked: root.showPairDistanceLine
                        onClicked: root.togglePairDistanceLine()
                    }

                    Item {
                        visible: root.hasPairSelection()
                        Layout.fillWidth: true
                    }
                }
            }
        }
    }

    component ToolButton: Button {
        id: control

        implicitWidth: 86
        implicitHeight: 34
        font.pixelSize: 14
        focusPolicy: Qt.NoFocus

        contentItem: Text {
            color: control.enabled ? "#ffffff" : "#777777"
            text: control.text
            font: control.font
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        background: Rectangle {
            radius: 6
            color: control.enabled ? (control.down ? "#2a2a2a" : control.hovered ? "#222222" : "#141414") : "#0d0d0d"
            border.color: control.enabled ? "#4a4a4a" : "#242424"
            border.width: 1
        }
    }

    component InfoValueButton: Button {
        id: control

        implicitHeight: 28
        implicitWidth: Math.max(84, contentItem.implicitWidth + 18)
        padding: 0
        font.pixelSize: 14
        focusPolicy: Qt.NoFocus

        contentItem: Text {
            color: "#ffffff"
            text: control.text
            font: control.font
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }

        background: Rectangle {
            radius: 6
            color: control.checked ? "#262626" : control.hovered ? "#1b1b1b" : "#101010"
            border.color: control.checked ? "#ffffff" : "#555555"
            border.width: 1
        }
    }

    component SideButton: Button {
        id: control

        implicitHeight: 40
        font.pixelSize: 14
        focusPolicy: Qt.NoFocus

        contentItem: Text {
            color: control.enabled ? "#ffffff" : "#777777"
            text: control.text
            font: control.font
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        background: Rectangle {
            radius: 6
            color: control.enabled ? (control.down ? "#2a2a2a" : control.hovered ? "#202020" : "#111111") : "#0d0d0d"
            border.color: control.enabled ? "#454545" : "#252525"
            border.width: 1
        }
    }

    component UnitSelector: ComboBox {
        id: control

        implicitHeight: 36
        font.pixelSize: 13
        focusPolicy: Qt.NoFocus

        contentItem: Text {
            leftPadding: 10
            rightPadding: 24
            color: control.enabled ? "#ffffff" : "#777777"
            text: control.displayText
            font: control.font
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }

        indicator: Text {
            x: control.width - width - 9
            y: control.topPadding + (control.availableHeight - height) / 2
            color: control.enabled ? "#ffffff" : "#777777"
            text: "v"
            font.pixelSize: 11
        }

        background: Rectangle {
            radius: 6
            color: control.enabled ? "#050505" : "#0d0d0d"
            border.color: control.activeFocus ? "#ffffff" : "#3a3a3a"
            border.width: 1
        }

        popup: Popup {
            y: control.height + 4
            width: control.width
            implicitHeight: contentItem.implicitHeight
            padding: 1

            contentItem: ListView {
                clip: true
                implicitHeight: contentHeight
                model: control.popup.visible ? control.delegateModel : null
                currentIndex: control.highlightedIndex
            }

            background: Rectangle {
                radius: 6
                color: "#080808"
                border.color: "#3a3a3a"
                border.width: 1
            }
        }

        delegate: ItemDelegate {
            width: control.width
            height: 34
            highlighted: control.highlightedIndex === index

            contentItem: Text {
                text: modelData
                color: "#ffffff"
                font: control.font
                verticalAlignment: Text.AlignVCenter
            }

            background: Rectangle {
                color: highlighted ? "#262626" : "#080808"
            }
        }
    }

    component FieldEditor: ColumnLayout {
        id: fieldRoot

        property alias label: fieldLabel.text
        property alias text: fieldInput.text
        property bool enabled: true

        spacing: 6

        Label {
            id: fieldLabel

            color: fieldRoot.enabled ? "#d5d5d5" : "#747474"
            font.pixelSize: 13
        }

        TextField {
            id: fieldInput

            Layout.fillWidth: true
            implicitHeight: 36
            enabled: fieldRoot.enabled
            color: "#ffffff"
            selectedTextColor: "#000000"
            selectionColor: "#ffffff"
            font.pixelSize: 14
            inputMethodHints: Qt.ImhFormattedNumbersOnly

            background: Rectangle {
                radius: 6
                color: fieldInput.enabled ? "#050505" : "#0d0d0d"
                border.color: fieldInput.activeFocus ? "#ffffff" : "#3a3a3a"
                border.width: 1
            }
        }
    }
}
