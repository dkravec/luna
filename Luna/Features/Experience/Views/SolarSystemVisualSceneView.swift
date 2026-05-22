import SceneKit
import SwiftUI
import simd

#if os(iOS)
import UIKit
private typealias PlatformImage = UIImage
private typealias PlatformColor = UIColor
#elseif os(macOS)
import AppKit
private typealias PlatformImage = NSImage
private typealias PlatformColor = NSColor
#endif

struct SolarSystemVisualSceneView: View {
    let bodies: [CelestialBody]
    let settings: ExperienceSceneSettings
    var content: ExperienceSceneContent = .solarSystem
    var simulationTimeDays: Double = 0
    var simulationDate: Date = Date()
    var focusedBodyID: String?
    var onSceneReady: () -> Void = {}
    var onSelectBody: (CelestialBody) -> Void = { _ in }

    var body: some View {
        VisualSceneContainer(
            snapshot: ExperienceSceneEngine.snapshot(
                for: bodies,
                settings: settings,
                content: content,
                simulationTimeDays: simulationTimeDays,
                simulationDate: simulationDate
            ),
            settings: settings,
            showsLabels: settings.showLabels,
            focusedBodyID: focusedBodyID,
            onSceneReady: onSceneReady,
            onSelectBody: onSelectBody
        )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: Radii.card, style: .continuous))
    }
}

#if os(iOS)
private struct VisualSceneContainer: UIViewRepresentable {
    let snapshot: ExperienceSceneSnapshot
    let settings: ExperienceSceneSettings
    let showsLabels: Bool
    let focusedBodyID: String?
    let onSceneReady: () -> Void
    let onSelectBody: (CelestialBody) -> Void

    func makeCoordinator() -> VisualSceneCameraCoordinator {
        VisualSceneCameraCoordinator()
    }

    func makeUIView(context: Context) -> SCNView {
        makeSceneView(coordinator: context.coordinator)
    }

    func updateUIView(_ view: SCNView, context: Context) {
        configure(view)
    }

    static func dismantleUIView(_ view: SCNView, coordinator: VisualSceneCameraCoordinator) {
        coordinator.teardown(view)
    }
}
#elseif os(macOS)
private struct VisualSceneContainer: NSViewRepresentable {
    let snapshot: ExperienceSceneSnapshot
    let settings: ExperienceSceneSettings
    let showsLabels: Bool
    let focusedBodyID: String?
    let onSceneReady: () -> Void
    let onSelectBody: (CelestialBody) -> Void

    func makeCoordinator() -> VisualSceneCameraCoordinator {
        VisualSceneCameraCoordinator()
    }

    func makeNSView(context: Context) -> SCNView {
        makeSceneView(coordinator: context.coordinator)
    }

    func updateNSView(_ view: SCNView, context: Context) {
        configure(view)
    }

    static func dismantleNSView(_ view: SCNView, coordinator: VisualSceneCameraCoordinator) {
        coordinator.teardown(view)
    }
}
#endif

private extension VisualSceneContainer {
    func makeSceneView(coordinator: VisualSceneCameraCoordinator) -> SCNView {
#if os(macOS)
        let view = VisualSceneSCNView()
        view.selectedCameraInputHandler = coordinator
#else
        let view = SCNView()
#endif
        view.allowsCameraControl = true
        view.autoenablesDefaultLighting = false
        view.isPlaying = false
        view.preferredFramesPerSecond = 30
        view.delegate = coordinator
        view.backgroundColor = platformColor(red: 0.015, green: 0.016, blue: 0.024, alpha: 1)
        view.defaultCameraController.automaticTarget = false
        view.defaultCameraController.inertiaEnabled = false
        view.defaultCameraController.worldUp = SCNVector3(0, 1, 0)
#if os(iOS)
        let tapRecognizer = UITapGestureRecognizer(target: coordinator, action: #selector(VisualSceneCameraCoordinator.handleTap(_:)))
        tapRecognizer.cancelsTouchesInView = false
        view.addGestureRecognizer(tapRecognizer)
        coordinator.installSelectedCameraRecognizers(in: view)
#elseif os(macOS)
        let clickRecognizer = NSClickGestureRecognizer(target: coordinator, action: #selector(VisualSceneCameraCoordinator.handleClick(_:)))
        view.addGestureRecognizer(clickRecognizer)
        coordinator.installSelectedCameraRecognizers(in: view)
#endif
        configure(view)
        return view
    }

    func configure(_ view: SCNView) {
        if let coordinator = view.delegate as? VisualSceneCameraCoordinator {
            coordinator.onSelectBody = onSelectBody
            coordinator.apply(
                snapshot: snapshot,
                settings: settings,
                showsLabels: showsLabels,
                focusedBodyID: focusedBodyID,
                to: view,
                onSceneReady: onSceneReady
            )
        }
    }
}

#if os(macOS)
private final class VisualSceneSCNView: SCNView {
    weak var selectedCameraInputHandler: VisualSceneCameraCoordinator?

    override func scrollWheel(with event: NSEvent) {
        guard selectedCameraInputHandler?.handleSelectedCameraScroll(deltaY: event.scrollingDeltaY, in: self) == true else {
            super.scrollWheel(with: event)
            return
        }
    }
}
#endif

private final class VisualSceneCameraCoordinator: NSObject, SCNSceneRendererDelegate {
    private let stateLock = NSLock()
    private var cameraLimit = SceneCameraLimit.default
    private var structureKey: String?
    private var activeFocusID: String?
    private var snapshot = ExperienceSceneSnapshot(bodies: [], orbitPaths: [], bounds: .empty)
    private var settings = ExperienceSceneSettings.defaults
    private var bodyNodes: [String: SCNNode] = [:]
    private var bodyTiltNodes: [String: SCNNode] = [:]
    private var bodySpinNodes: [String: SCNNode] = [:]
    private var orbitNodes: [String: SCNNode] = [:]
    private var labelNodes: [String: SCNNode] = [:]
    private var bodyLookup: [String: CelestialBody] = [:]
    private var selectedCameraState: VisualSceneSelectedCameraState?
    private var hasInstalledSelectedCameraRecognizers = false
    private var lastOrbitThicknessKey: String?
    private var pendingOrbitThicknessKey: String?
    var onSelectBody: (CelestialBody) -> Void = { _ in }

    func renderer(_ renderer: any SCNSceneRenderer, updateAtTime time: TimeInterval) {
        guard let pointOfView = renderer.pointOfView,
              let camera = pointOfView.camera,
              camera.usesOrthographicProjection else {
            return
        }

        let state = lockedState()

        camera.orthographicScale = max(camera.orthographicScale, state.cameraLimit.minimumOrthographicScale)
        camera.orthographicScale = min(camera.orthographicScale, state.cameraLimit.maximumOrthographicScale)

        let target = state.activeFocusID.flatMap { state.focusTargets[$0] } ?? state.cameraLimit.subjectCenter
        let offset = pointOfView.position - target
        let distance = offset.length
        if state.activeFocusID == nil, distance > state.cameraLimit.maximumCameraDistance, distance > 0 {
            pointOfView.position = target + offset.normalized * state.cameraLimit.maximumCameraDistance
        }
        if state.activeFocusID == nil {
            SolarSystemSceneCameraMetrics.updateClippingPlanes(
                for: camera,
                snapshot: state.snapshot,
                settings: state.settings,
                cameraPosition: pointOfView.position
            )
        }

        updateOrbitAndLabelScale(for: renderer)
    }

    func update(_ cameraLimit: SceneCameraLimit) {
        stateLock.lock()
        self.cameraLimit = cameraLimit
        stateLock.unlock()
    }

    func teardown(_ view: SCNView) {
        view.delegate = nil
        view.isPlaying = false
        view.scene?.rootNode.childNodes.forEach { $0.removeFromParentNode() }
        view.scene = nil

        stateLock.lock()
        snapshot = ExperienceSceneSnapshot(bodies: [], orbitPaths: [], bounds: .empty)
        bodyNodes.removeAll()
        bodyTiltNodes.removeAll()
        bodySpinNodes.removeAll()
        orbitNodes.removeAll()
        labelNodes.removeAll()
        bodyLookup.removeAll()
        activeFocusID = nil
        lastOrbitThicknessKey = nil
        pendingOrbitThicknessKey = nil
        stateLock.unlock()

        selectedCameraState = nil
        hasInstalledSelectedCameraRecognizers = false
        structureKey = nil
    }

    func apply(
        snapshot: ExperienceSceneSnapshot,
        settings: ExperienceSceneSettings,
        showsLabels: Bool,
        focusedBodyID: String?,
        to view: SCNView,
        onSceneReady: @escaping () -> Void
    ) {
        let nextStructureKey = Self.structureKey(for: snapshot, settings: settings, showsLabels: showsLabels)
        let nextCameraLimit = SceneCameraLimit(snapshot: snapshot, settings: settings)
        stateLock.lock()
        bodyLookup = Dictionary(uniqueKeysWithValues: snapshot.bodies.map { ($0.id, $0.body) })
        self.snapshot = snapshot
        self.settings = settings
        stateLock.unlock()

        if view.scene == nil || structureKey != nextStructureKey {
            let scene = SolarSystemSceneFactory.scene(
                for: snapshot,
                settings: settings,
                showsLabels: showsLabels
            )
            view.scene = scene
            view.pointOfView = scene.rootNode.childNode(withName: "sceneCamera", recursively: false)
            view.defaultCameraController.automaticTarget = false
            view.defaultCameraController.inertiaEnabled = false
            view.defaultCameraController.stopInertia()
            view.defaultCameraController.target = nextCameraLimit.subjectCenter
            captureNodes(from: scene)
            structureKey = nextStructureKey
            stateLock.lock()
            lastOrbitThicknessKey = nil
            pendingOrbitThicknessKey = nil
            stateLock.unlock()
        } else {
            updateExistingNodes(
                with: snapshot,
                cameraScale: view.pointOfView?.camera?.orthographicScale ?? nextCameraLimit.preferredOrthographicScale,
                cameraPosition: view.pointOfView?.presentation.position
            )
        }

        update(nextCameraLimit)
        applyCameraFocus(focusedBodyID, cameraLimit: nextCameraLimit, to: view)

        if view.scene != nil, !snapshot.bodies.isEmpty {
            DispatchQueue.main.async {
                onSceneReady()
            }
        }
    }

    private func updateExistingNodes(with snapshot: ExperienceSceneSnapshot, cameraScale: Double, cameraPosition: SCNVector3?) {
        SCNTransaction.begin()
        SCNTransaction.disableActions = true

        for placement in snapshot.bodies {
            bodyNodes[placement.id]?.position = SCNVector3(
                placement.position.x,
                placement.position.y,
                placement.position.z
            )
            bodyTiltNodes[placement.id]?.eulerAngles = SolarSystemSceneRotation.tiltEuler(for: placement)
            bodySpinNodes[placement.id]?.eulerAngles = SolarSystemSceneRotation.spinEuler(for: placement)
            if let labelNode = labelNodes[placement.id] {
                labelNode.position = SolarSystemSceneFactory.labelPosition(for: placement.displayRadius)
                labelNode.scale = SolarSystemSceneLabelScale.scaleVector(
                    for: cameraScale
                )
            }
        }

        for orbitPath in snapshot.orbitPaths {
            orbitNodes[orbitPath.id]?.geometry = SolarSystemSceneFactory.orbitGeometry(
                path: orbitPath,
                cameraScale: cameraScale,
                viewportHeight: 800,
                cameraPosition: cameraPosition
            )
        }

        SCNTransaction.commit()
    }

    private func captureNodes(from scene: SCNScene) {
        var nextBodyNodes: [String: SCNNode] = [:]
        var nextBodyTiltNodes: [String: SCNNode] = [:]
        var nextBodySpinNodes: [String: SCNNode] = [:]
        var nextOrbitNodes: [String: SCNNode] = [:]
        var nextLabelNodes: [String: SCNNode] = [:]

        scene.rootNode.enumerateChildNodes { node, _ in
            guard let name = node.name else { return }

            if name.hasPrefix("body:") {
                nextBodyNodes[String(name.dropFirst(5))] = node
            } else if name.hasPrefix("bodyTilt:") {
                nextBodyTiltNodes[String(name.dropFirst(9))] = node
            } else if name.hasPrefix("bodySpin:") {
                nextBodySpinNodes[String(name.dropFirst(9))] = node
            } else if name.hasPrefix("orbit:") {
                nextOrbitNodes[String(name.dropFirst(6))] = node
            } else if name.hasPrefix("label:") {
                nextLabelNodes[String(name.dropFirst(6))] = node
            }
        }

        stateLock.lock()
        bodyNodes = nextBodyNodes
        bodyTiltNodes = nextBodyTiltNodes
        bodySpinNodes = nextBodySpinNodes
        orbitNodes = nextOrbitNodes
        labelNodes = nextLabelNodes
        stateLock.unlock()
    }

#if os(iOS)
    func installSelectedCameraRecognizers(in view: SCNView) {
        guard !hasInstalledSelectedCameraRecognizers else { return }

        let panRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handleSelectedCameraPan(_:)))
        panRecognizer.name = "LunaSelectedCameraPan"
        panRecognizer.cancelsTouchesInView = false
        panRecognizer.delegate = self
        view.addGestureRecognizer(panRecognizer)

        let pinchRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(handleSelectedCameraPinch(_:)))
        pinchRecognizer.name = "LunaSelectedCameraPinch"
        pinchRecognizer.cancelsTouchesInView = false
        pinchRecognizer.delegate = self
        view.addGestureRecognizer(pinchRecognizer)

        hasInstalledSelectedCameraRecognizers = true
    }

    @objc private func handleSelectedCameraPan(_ recognizer: UIPanGestureRecognizer) {
        guard let view = recognizer.view as? SCNView else { return }
        let translation = recognizer.translation(in: view)
        recognizer.setTranslation(.zero, in: view)
        applySelectedCameraOrbitDelta(
            yawDelta: Float(-translation.x) * 0.006,
            pitchDelta: Float(-translation.y) * 0.006,
            scaleMultiplier: 1,
            in: view
        )
    }

    @objc private func handleSelectedCameraPinch(_ recognizer: UIPinchGestureRecognizer) {
        guard let view = recognizer.view as? SCNView else { return }
        let scaleMultiplier = recognizer.scale > 0 ? 1 / Double(recognizer.scale) : 1
        recognizer.scale = 1
        applySelectedCameraOrbitDelta(
            yawDelta: 0,
            pitchDelta: 0,
            scaleMultiplier: scaleMultiplier,
            in: view
        )
    }

    @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
        guard let view = recognizer.view as? SCNView else { return }
        selectBody(at: recognizer.location(in: view), in: view)
    }
#elseif os(macOS)
    func installSelectedCameraRecognizers(in view: SCNView) {
        guard !hasInstalledSelectedCameraRecognizers else { return }

        let panRecognizer = NSPanGestureRecognizer(target: self, action: #selector(handleSelectedCameraPan(_:)))
        panRecognizer.delegate = self
        view.addGestureRecognizer(panRecognizer)

        let magnificationRecognizer = NSMagnificationGestureRecognizer(target: self, action: #selector(handleSelectedCameraMagnification(_:)))
        magnificationRecognizer.delegate = self
        view.addGestureRecognizer(magnificationRecognizer)

        hasInstalledSelectedCameraRecognizers = true
    }

    @objc private func handleSelectedCameraPan(_ recognizer: NSPanGestureRecognizer) {
        guard let view = recognizer.view as? SCNView else { return }
        let translation = recognizer.translation(in: view)
        recognizer.setTranslation(.zero, in: view)
        applySelectedCameraOrbitDelta(
            yawDelta: Float(-translation.x) * 0.006,
            pitchDelta: Float(translation.y) * 0.006,
            scaleMultiplier: 1,
            in: view
        )
    }

    @objc private func handleSelectedCameraMagnification(_ recognizer: NSMagnificationGestureRecognizer) {
        guard let view = recognizer.view as? SCNView else { return }
        let scaleMultiplier = 1 / max(0.12, 1 + Double(recognizer.magnification))
        recognizer.magnification = 0
        applySelectedCameraOrbitDelta(
            yawDelta: 0,
            pitchDelta: 0,
            scaleMultiplier: scaleMultiplier,
            in: view
        )
    }

    func handleSelectedCameraScroll(deltaY: CGFloat, in view: SCNView) -> Bool {
        guard activeFocusID != nil else { return false }

        let scaleMultiplier = pow(0.998, Double(deltaY))
        applySelectedCameraOrbitDelta(
            yawDelta: 0,
            pitchDelta: 0,
            scaleMultiplier: scaleMultiplier,
            in: view
        )
        return true
    }

    @objc func handleClick(_ recognizer: NSClickGestureRecognizer) {
        guard let view = recognizer.view as? SCNView else { return }
        selectBody(at: recognizer.location(in: view), in: view)
    }
#endif

    private func selectBody(at point: CGPoint, in view: SCNView) {
        let hits = view.hitTest(point, options: [.boundingBoxOnly: false])
        let selectedBodyID = nearestBodyID(to: point, in: view)
            ?? hits.compactMap { bodyID(from: $0.node) }.first
            ?? nearestOrbitBodyID(to: point, in: view)

        guard let selectedBodyID,
              let body = bodyLookup[selectedBodyID] else {
            return
        }

        onSelectBody(body)
    }

    private func bodyID(from node: SCNNode) -> String? {
        var currentNode: SCNNode? = node
        while let node = currentNode {
            if let name = node.name {
                if name.hasPrefix("label:") {
                    return nil
                }
                if name.hasPrefix("body:") {
                    return String(name.dropFirst(5))
                }
                if name.hasPrefix("bodyVisual:") {
                    return String(name.dropFirst(11))
                }
                if name.hasPrefix("bodyHit:") {
                    return String(name.dropFirst(8))
                }
                if name.hasPrefix("orbit:") {
                    return orbitBodyID(from: String(name.dropFirst(6)))
                }
                if name.hasPrefix("orbitHit:") {
                    return String(name.dropFirst(9))
                }
            }
            currentNode = node.parent
        }
        return nil
    }

    private func nearestBodyID(to point: CGPoint, in view: SCNView) -> String? {
        snapshot.bodies
            .compactMap { placement -> (bodyID: String, distance: CGFloat)? in
                guard let node = bodyNodes[placement.id]?.presentation else { return nil }

                let worldPoint = node.convertPosition(SCNVector3Zero, to: nil)
                let projected = view.projectPoint(worldPoint)
                guard projected.z >= 0, projected.z <= 1 else { return nil }

                let center = CGPoint(x: CGFloat(projected.x), y: CGFloat(projected.y))
                let edgeWorld = node.convertPosition(SCNVector3(placement.interactionRadius, 0, 0), to: nil)
                let edgeProjected = view.projectPoint(edgeWorld)
                let projectedRadius = hypot(CGFloat(edgeProjected.x) - center.x, CGFloat(edgeProjected.y) - center.y)
                let threshold = max(CGFloat(14), min(CGFloat(54), projectedRadius + 8))
                let distance = hypot(center.x - point.x, center.y - point.y)

                return distance <= threshold ? (placement.id, distance) : nil
            }
            .min { $0.distance < $1.distance }?
            .bodyID
    }

    private func nearestOrbitBodyID(to point: CGPoint, in view: SCNView) -> String? {
        let threshold: CGFloat = 12

        return snapshot.orbitPaths
            .compactMap { path -> (bodyID: String, distance: CGFloat)? in
                let orbitNode = orbitNodes[path.id]?.presentation
                let distance = path.points
                    .map { scenePoint in
                        let localPoint = SCNVector3(scenePoint.x, scenePoint.y, scenePoint.z)
                        let worldPoint = orbitNode?.convertPosition(localPoint, to: nil) ?? localPoint
                        let projected = view.projectPoint(worldPoint)
                        return hypot(CGFloat(projected.x) - point.x, CGFloat(projected.y) - point.y)
                    }
                    .min() ?? .greatestFiniteMagnitude

                return distance <= threshold ? (path.bodyId, distance) : nil
            }
            .min { $0.distance < $1.distance }?
            .bodyID
    }

    private func orbitBodyID(from orbitID: String) -> String {
        orbitID.hasSuffix("-orbit") ? String(orbitID.dropLast(6)) : orbitID
    }

    private func applyCameraFocus(_ focusedBodyID: String?, cameraLimit: SceneCameraLimit, to view: SCNView) {
        guard let pointOfView = view.pointOfView else { return }

        guard let focusedBodyID else {
            restoreCameraFocusIfNeeded(to: view)
            return
        }

        guard let focusCenter = focusTarget(for: focusedBodyID) else {
            return
        }

        let focusChanged = VisualSceneSelectedCameraMath.selectionDidChange(
            current: selectedCameraState,
            nextBodyID: focusedBodyID
        ) || activeFocusID != focusedBodyID
        let desiredFocusScale = focusedOrthographicScale(for: focusedBodyID)
        let selectedLimit = VisualSceneSelectedCameraLimit(focusedScale: desiredFocusScale)
        view.defaultCameraController.automaticTarget = false
        view.defaultCameraController.inertiaEnabled = false
        view.defaultCameraController.stopInertia()
        view.allowsCameraControl = false

        var nextState: VisualSceneSelectedCameraState
        if focusChanged {
            let idealOffset = SolarSystemSceneFocusMetrics.cameraOffset(for: focusedBodyID, in: snapshot, settings: settings)
            nextState = VisualSceneSelectedCameraState(
                bodyID: focusedBodyID,
                target: focusCenter,
                offset: idealOffset,
                orthographicScale: desiredFocusScale,
                limit: selectedLimit
            )
            stopCameraAnimations(pointOfView)
        } else {
            nextState = selectedCameraState?.following(target: focusCenter, limit: selectedLimit)
                ?? VisualSceneSelectedCameraState(
                    bodyID: focusedBodyID,
                    target: focusCenter,
                    offset: pointOfView.position - focusCenter,
                    orthographicScale: pointOfView.camera?.orthographicScale ?? desiredFocusScale,
                    limit: selectedLimit
                )
        }

        selectedCameraState = nextState
        applySelectedCameraState(
            nextState,
            to: view,
            animated: focusChanged,
            updatesOrientation: focusChanged
        )
        updateFocusedClippingPlanes(
            for: pointOfView,
            cameraPosition: nextState.cameraPosition,
            focusCenter: focusCenter,
            focusScale: nextState.orthographicScale,
            focusRadius: selectedFocusRadius(for: focusedBodyID)
        )

        view.defaultCameraController.target = focusCenter
        updateActiveFocusID(focusedBodyID)
    }

    private func applySelectedCameraOrbitDelta(
        yawDelta: Float,
        pitchDelta: Float,
        scaleMultiplier: Double,
        in view: SCNView
    ) {
        guard let bodyID = activeFocusID,
              let target = focusTarget(for: bodyID) else { return }

        let desiredFocusScale = focusedOrthographicScale(for: bodyID)
        let selectedLimit = VisualSceneSelectedCameraLimit(focusedScale: desiredFocusScale)
        var nextState = selectedCameraState?.following(target: target, limit: selectedLimit)
            ?? VisualSceneSelectedCameraState(
                bodyID: bodyID,
                target: target,
                offset: (view.pointOfView?.position ?? target + SCNVector3(0, 0, Float(desiredFocusScale))) - target,
                orthographicScale: view.pointOfView?.camera?.orthographicScale ?? desiredFocusScale,
                limit: selectedLimit
            )

        nextState.applyInput(
            yawDelta: yawDelta,
            pitchDelta: pitchDelta,
            scaleMultiplier: scaleMultiplier,
            limit: selectedLimit
        )
        selectedCameraState = nextState
        applySelectedCameraState(nextState, to: view, animated: false, updatesOrientation: true)
        if let pointOfView = view.pointOfView {
            updateFocusedClippingPlanes(
                for: pointOfView,
                cameraPosition: nextState.cameraPosition,
                focusCenter: target,
                focusScale: nextState.orthographicScale,
                focusRadius: selectedFocusRadius(for: bodyID)
            )
        }
    }

    private func applySelectedCameraState(
        _ state: VisualSceneSelectedCameraState,
        to view: SCNView,
        animated: Bool,
        updatesOrientation: Bool
    ) {
        guard let pointOfView = view.pointOfView else { return }

        SCNTransaction.begin()
        SCNTransaction.animationDuration = animated ? 0.26 : 0
        SCNTransaction.disableActions = !animated
        pointOfView.position = state.cameraPosition
        if updatesOrientation {
            pointOfView.look(at: state.target)
        }
        pointOfView.camera?.orthographicScale = state.orthographicScale
        SCNTransaction.commit()
    }

    private func updateActiveFocusID(_ focusedBodyID: String?) {
        stateLock.lock()
        activeFocusID = focusedBodyID
        stateLock.unlock()
    }

    private func updateFocusedClippingPlanes(
        for pointOfView: SCNNode,
        cameraPosition: SCNVector3,
        focusCenter: SCNVector3,
        focusScale: Double,
        focusRadius: Float
    ) {
        guard let camera = pointOfView.camera else { return }

        SolarSystemSceneCameraMetrics.updateClippingPlanes(
            for: camera,
            snapshot: snapshot,
            settings: settings,
            cameraPosition: cameraPosition
        )
        widenFocusedClippingPlanes(
            for: camera,
            cameraPosition: cameraPosition,
            focusCenter: focusCenter,
            focusScale: focusScale,
            focusRadius: focusRadius,
            sceneSpan: snapshot.bounds.span
        )
    }

    private func widenFocusedClippingPlanes(
        for camera: SCNCamera,
        cameraPosition: SCNVector3,
        focusCenter: SCNVector3,
        focusScale: Double,
        focusRadius: Float,
        sceneSpan: Float
    ) {
        let range = VisualSceneSelectedCameraMath.focusedClippingRange(
            baseNear: camera.zNear,
            baseFar: camera.zFar,
            cameraPosition: cameraPosition,
            focusCenter: focusCenter,
            focusScale: focusScale,
            focusRadius: focusRadius,
            sceneSpan: sceneSpan
        )
        camera.zNear = range.zNear
        camera.zFar = range.zFar
    }

    private func stopCameraAnimations(_ pointOfView: SCNNode) {
        pointOfView.removeAllActions()
        pointOfView.removeAllAnimations()
        pointOfView.camera?.removeAllAnimations()
    }

    private func restoreCameraFocusIfNeeded(to view: SCNView) {
        guard activeFocusID != nil || selectedCameraState != nil else {
            view.allowsCameraControl = true
            return
        }

        guard let pointOfView = view.pointOfView else {
            stateLock.lock()
            activeFocusID = nil
            stateLock.unlock()
            selectedCameraState = nil
            view.allowsCameraControl = true
            return
        }

        let restoreTarget = cameraLimit.subjectCenter
        let offset = SolarSystemSceneCameraMetrics.defaultCameraOffset(
            for: cameraLimit.preferredOrthographicScale
        )
        stopCameraAnimations(pointOfView)
        view.defaultCameraController.stopInertia()
        view.defaultCameraController.automaticTarget = false
        view.defaultCameraController.inertiaEnabled = false
        view.defaultCameraController.target = restoreTarget
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.22
        pointOfView.position = restoreTarget + offset
        pointOfView.look(at: restoreTarget)
        pointOfView.camera?.orthographicScale = cameraLimit.preferredOrthographicScale
        if let camera = pointOfView.camera {
            SolarSystemSceneCameraMetrics.updateClippingPlanes(
                for: camera,
                snapshot: snapshot,
                settings: settings,
                cameraPosition: restoreTarget + offset
            )
        }
        SCNTransaction.commit()

        view.defaultCameraController.target = restoreTarget
        view.allowsCameraControl = true
        selectedCameraState = nil
        stateLock.lock()
        activeFocusID = nil
        stateLock.unlock()
    }

    private func focusedOrthographicScale(for bodyID: String) -> Double {
        SolarSystemSceneFocusMetrics.focusedOrthographicScale(for: bodyID, in: snapshot, settings: settings)
    }

    private func selectedFocusRadius(for bodyID: String) -> Float {
        guard let placement = snapshot.bodies.first(where: { $0.id == bodyID }) else {
            return 0.2
        }

        let ringRadius = placement.body.id == "saturn"
            ? placement.displayRadius * SaturnRingGeometry.outerRadiusRatio
            : placement.displayRadius
        return max(ringRadius, placement.interactionRadius * 0.35, 0.2)
    }

    private func focusTarget(for bodyID: String) -> SCNVector3? {
        guard let node = bodyNodes[bodyID]?.presentation else { return nil }
        if let visualNode = node.childNode(withName: "bodyVisual:\(bodyID)", recursively: true)?.presentation {
            return visualNode.worldBoundingBoxCenter() ?? visualNode.convertPosition(SCNVector3Zero, to: nil)
        }
        return node.worldBoundingBoxCenter() ?? node.convertPosition(SCNVector3Zero, to: nil)
    }

    private func updateOrbitAndLabelScale(for renderer: any SCNSceneRenderer) {
        guard let pointOfView = renderer.pointOfView,
              let cameraScale = pointOfView.camera?.orthographicScale else { return }
        let cameraPosition = pointOfView.presentation.position
        let viewportHeight = max(Double(renderer.currentViewport.height), 1)
        let distanceBucket = Int((cameraPosition.length * 10).rounded())
        let orbitThicknessKey = "\(Int((cameraScale * 100).rounded())):\(distanceBucket):\(Int(viewportHeight.rounded()))"

        let refresh: (orbitPaths: [ExperienceOrbitPath], orbitNodes: [String: SCNNode], labelNodes: [SCNNode])? = stateLock.withLock {
            guard orbitThicknessKey != lastOrbitThicknessKey,
                  orbitThicknessKey != pendingOrbitThicknessKey else {
                return nil
            }

            pendingOrbitThicknessKey = orbitThicknessKey
            return (snapshot.orbitPaths, orbitNodes, Array(labelNodes.values))
        }

        guard let refresh else { return }

        let labelScale = SolarSystemSceneLabelScale.scaleVector(
            for: cameraScale
        )

        DispatchQueue.main.async { [weak self] in
            SCNTransaction.begin()
            SCNTransaction.disableActions = true
            for orbitPath in refresh.orbitPaths {
                guard let node = refresh.orbitNodes[orbitPath.id] else { continue }
                node.geometry = SolarSystemSceneFactory.orbitGeometry(
                    path: orbitPath,
                    cameraScale: cameraScale,
                    viewportHeight: viewportHeight,
                    cameraPosition: cameraPosition
                )
            }

            for node in refresh.labelNodes {
                node.scale = labelScale
            }
            SCNTransaction.commit()

            self?.stateLock.withLock {
                self?.lastOrbitThicknessKey = orbitThicknessKey
                self?.pendingOrbitThicknessKey = nil
            }
        }
    }

    private func lockedState() -> (
        cameraLimit: SceneCameraLimit,
        activeFocusID: String?,
        bodyNodes: [String: SCNNode],
        focusTargets: [String: SCNVector3],
        snapshot: ExperienceSceneSnapshot,
        settings: ExperienceSceneSettings
    ) {
        stateLock.lock()
        defer { stateLock.unlock() }

        return (
            cameraLimit,
            activeFocusID,
            bodyNodes,
            Dictionary(uniqueKeysWithValues: bodyNodes.map { id, node in
                let presentationNode = node.presentation
                let center = presentationNode.worldBoundingBoxCenter()
                    ?? presentationNode.convertPosition(SCNVector3Zero, to: nil)
                return (id, center)
            }),
            snapshot,
            settings
        )
    }

    private static func structureKey(for snapshot: ExperienceSceneSnapshot, settings: ExperienceSceneSettings, showsLabels: Bool) -> String {
        let bodyKey = snapshot.bodies
            .map { body in
                let radius = Int((body.displayRadius * 1_000).rounded())
                return "\(body.id):\(body.body.type.rawValue):\(radius):\(body.body.textureName ?? ""):\(body.body.modelName ?? ""):\(body.body.thumbnailName ?? "")"
            }
            .joined(separator: "|")
        let orbitKey = snapshot.orbitPaths
            .map { "\($0.id):\($0.points.count)" }
            .joined(separator: "|")

        return "\(showsLabels)-\(settings.renderDetail.rawValue)-\(bodyKey)-\(orbitKey)"
    }
}

#if os(iOS)
extension VisualSceneCameraCoordinator: UIGestureRecognizerDelegate {
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer.name == "LunaSelectedCameraPan"
            || gestureRecognizer.name == "LunaSelectedCameraPinch" else {
            return true
        }

        return activeFocusID != nil
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        false
    }
}
#elseif os(macOS)
extension VisualSceneCameraCoordinator: NSGestureRecognizerDelegate {
    func gestureRecognizerShouldBegin(_ gestureRecognizer: NSGestureRecognizer) -> Bool {
        activeFocusID != nil
    }

    func gestureRecognizer(
        _ gestureRecognizer: NSGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: NSGestureRecognizer
    ) -> Bool {
        false
    }
}
#endif

private extension NSLock {
    func withLock<T>(_ body: () -> T) -> T {
        lock()
        defer { unlock() }
        return body()
    }
}

struct VisualSceneSelectedCameraLimit {
    let minimumScale: Double
    let maximumScale: Double
    let minimumDistance: Float
    let maximumDistance: Float

    init(focusedScale: Double) {
        let trueScaleInspection = focusedScale < 0.12
        minimumScale = trueScaleInspection ? max(0.000_45, focusedScale * 0.42) : max(0.22, focusedScale * 0.38)
        maximumScale = trueScaleInspection ? max(focusedScale * 7.0, focusedScale + 0.03) : max(focusedScale * 3.2, focusedScale + 2.2)
        minimumDistance = trueScaleInspection ? max(Float(focusedScale * 1.1), 0.006) : max(Float(focusedScale * 0.62), 0.7)
        maximumDistance = trueScaleInspection ? max(Float(focusedScale * 18.0), minimumDistance + 0.08) : max(Float(focusedScale * 4.2), minimumDistance + 0.9)
    }
}

struct VisualSceneSelectedCameraState {
    let bodyID: String
    private(set) var target: SCNVector3
    private(set) var yaw: Float
    private(set) var pitch: Float
    private(set) var distance: Float
    private(set) var orthographicScale: Double

    init(
        bodyID: String,
        target: SCNVector3,
        offset: SCNVector3,
        orthographicScale: Double,
        limit: VisualSceneSelectedCameraLimit
    ) {
        self.bodyID = bodyID
        self.target = target
        let clampedOffset = VisualSceneSelectedCameraMath.clampedOffset(offset, limit: limit)
        let spherical = VisualSceneSelectedCameraMath.sphericalComponents(for: clampedOffset)
        yaw = spherical.yaw
        pitch = spherical.pitch
        distance = spherical.distance
        self.orthographicScale = VisualSceneSelectedCameraMath.clampedScale(orthographicScale, limit: limit)
    }

    var cameraOffset: SCNVector3 {
        VisualSceneSelectedCameraMath.offset(yaw: yaw, pitch: pitch, distance: distance)
    }

    var cameraPosition: SCNVector3 {
        target + cameraOffset
    }

    func following(target nextTarget: SCNVector3, limit: VisualSceneSelectedCameraLimit) -> VisualSceneSelectedCameraState {
        var copy = self
        copy.target = nextTarget
        copy.distance = min(max(copy.distance, limit.minimumDistance), limit.maximumDistance)
        copy.orthographicScale = VisualSceneSelectedCameraMath.clampedScale(copy.orthographicScale, limit: limit)
        return copy
    }

    mutating func applyInput(
        yawDelta: Float,
        pitchDelta: Float,
        scaleMultiplier: Double,
        limit: VisualSceneSelectedCameraLimit
    ) {
        yaw += yawDelta
        pitch = VisualSceneSelectedCameraMath.clampedPitch(pitch + pitchDelta)
        orthographicScale = VisualSceneSelectedCameraMath.clampedScale(
            orthographicScale * scaleMultiplier,
            limit: limit
        )
        distance = VisualSceneSelectedCameraMath.distance(
            forScale: orthographicScale,
            currentDistance: distance,
            limit: limit
        )
    }
}

enum VisualSceneSelectedCameraMath {
    static func selectionDidChange(current: VisualSceneSelectedCameraState?, nextBodyID: String?) -> Bool {
        current?.bodyID != nextBodyID
    }

    static func sphericalComponents(for offset: SCNVector3) -> (yaw: Float, pitch: Float, distance: Float) {
        let safeOffset = offset.length > 0 ? offset : SCNVector3(0, 0, 1)
        let distance = max(safeOffset.length, 0.001)
        let xValue = Float(safeOffset.x)
        let yValue = Float(safeOffset.y)
        let zValue = Float(safeOffset.z)
        let horizontalDistance = max(sqrtf(xValue * xValue + zValue * zValue), 0.001)
        return (
            yaw: atan2f(xValue, zValue),
            pitch: clampedPitch(atan2f(yValue, horizontalDistance)),
            distance: distance
        )
    }

    static func offset(yaw: Float, pitch: Float, distance: Float) -> SCNVector3 {
        let horizontalDistance = cosf(pitch) * distance
        return SCNVector3(
            sinf(yaw) * horizontalDistance,
            sinf(pitch) * distance,
            cosf(yaw) * horizontalDistance
        )
    }

    static func clampedOffset(_ offset: SCNVector3, limit: VisualSceneSelectedCameraLimit) -> SCNVector3 {
        let distance = offset.length
        guard distance > 0 else {
            return SCNVector3(0, 0, limit.minimumDistance)
        }

        if distance < limit.minimumDistance {
            return offset.normalized * limit.minimumDistance
        }
        if distance > limit.maximumDistance {
            return offset.normalized * limit.maximumDistance
        }
        return offset
    }

    static func clampedPitch(_ pitch: Float) -> Float {
        min(max(pitch, -1.535), 1.535)
    }

    static func clampedScale(_ scale: Double, limit: VisualSceneSelectedCameraLimit) -> Double {
        min(max(scale, limit.minimumScale), limit.maximumScale)
    }

    static func distance(
        forScale scale: Double,
        currentDistance: Float,
        limit: VisualSceneSelectedCameraLimit
    ) -> Float {
        let normalizedScale = (scale - limit.minimumScale) / max(limit.maximumScale - limit.minimumScale, 0.001)
        let nextDistance = limit.minimumDistance + Float(normalizedScale) * (limit.maximumDistance - limit.minimumDistance)
        return min(max(nextDistance, limit.minimumDistance), max(limit.maximumDistance, currentDistance))
    }

    static func focusedClippingRange(
        baseNear: Double,
        baseFar: Double,
        cameraPosition: SCNVector3,
        focusCenter: SCNVector3,
        focusScale: Double,
        focusRadius: Float,
        sceneSpan: Float
    ) -> (zNear: Double, zFar: Double) {
        let focusDistance = Double((cameraPosition - focusCenter).length)
        let radius = Double(max(focusRadius, 0.2))
        let spanMargin = Double(max(sceneSpan, 1)) * 0.35
        return (
            zNear: min(baseNear, 0.001),
            zFar: max(baseFar, focusDistance + focusScale * 10.0 + radius * 12.0 + spanMargin + 120)
        )
    }
}

private enum SaturnRingGeometry {
    static let outerRadiusRatio: Float = 2.33

    static let bands: [(innerRadiusRatio: Float, outerRadiusRatio: Float, alpha: CGFloat)] = [
        (1.24, 1.50, 0.34),
        (1.52, 1.95, 0.56),
        (2.03, 2.27, 0.42),
        (2.31, outerRadiusRatio, 0.30)
    ]
}

private enum SolarSystemSceneFactory {
    static func scene(for snapshot: ExperienceSceneSnapshot, settings: ExperienceSceneSettings, showsLabels: Bool) -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = SceneBackgroundTexture.image(for: settings.renderDetail.usesFullBackgroundTexture ? .full : .mini)
            ?? platformColor(red: 0.015, green: 0.016, blue: 0.024, alpha: 1)

        scene.rootNode.addChildNode(cameraNode(for: snapshot, settings: settings))
        scene.rootNode.addChildNode(ambientLightNode())
        scene.rootNode.addChildNode(keyLightNode())

        let root = SCNNode()
        root.eulerAngles.x = -.pi / 10
        scene.rootNode.addChildNode(root)

        let cameraMetrics = SolarSystemSceneCameraMetrics(snapshot: snapshot, settings: settings)

        for orbitPath in snapshot.orbitPaths {
            root.addChildNode(orbitNode(
                path: orbitPath,
                cameraScale: cameraMetrics.orthographicScale,
                cameraPosition: cameraMetrics.position
            ))
        }

        for placement in snapshot.bodies {
            let bodyNode = node(
                for: placement,
                renderDetail: settings.renderDetail,
                isObjectSnapshot: SolarSystemSceneCameraMetrics.isArtifactObjectSnapshot(snapshot)
            )
            root.addChildNode(bodyNode)

            if showsLabels {
                bodyNode.addChildNode(labelNode(
                    for: placement.body,
                    radius: placement.displayRadius,
                    cameraScale: cameraMetrics.orthographicScale
                ))
            }
        }

        return scene
    }

    private static func node(
        for placement: ExperienceSceneBody,
        renderDetail: SceneRenderDetail,
        isObjectSnapshot: Bool
    ) -> SCNNode {
        let root = SCNNode()
        root.name = "body:\(placement.id)"
        root.position = SCNVector3(placement.position.x, placement.position.y, placement.position.z)

        let tiltNode = SCNNode()
        tiltNode.name = "bodyTilt:\(placement.id)"
        tiltNode.eulerAngles = SolarSystemSceneRotation.tiltEuler(for: placement)

        let spinNode = SCNNode()
        spinNode.name = "bodySpin:\(placement.id)"
        spinNode.eulerAngles = SolarSystemSceneRotation.spinEuler(for: placement)

        let visualNode: SCNNode

        let modelTargetAxis = bundledModelTargetAxis(for: placement, isObjectSnapshot: isObjectSnapshot)
        switch resolvedAsset(for: placement.body, isObjectSnapshot: isObjectSnapshot) {
        case .model:
            if let modelNode = BundledSceneModelLoader.fittedNode(
                named: placement.body.modelName,
                targetLongestAxis: modelTargetAxis
            ) {
                visualNode = modelNode
            } else {
                visualNode = fallbackNode(for: placement, renderDetail: renderDetail)
            }
        case .thumbnail, .fallback:
            visualNode = fallbackNode(for: placement, renderDetail: renderDetail)
        }

        visualNode.name = "bodyVisual:\(placement.id)"
        spinNode.addChildNode(visualNode)
        if placement.body.id == "saturn" {
            spinNode.addChildNode(saturnRingNode(for: placement.displayRadius))
        }
        tiltNode.addChildNode(spinNode)
        root.addChildNode(tiltNode)

        if placement.interactionRadius > placement.displayRadius {
            root.addChildNode(interactionNode(for: placement))
        }
        return root
    }

    private static func fallbackNode(for placement: ExperienceSceneBody, renderDetail: SceneRenderDetail) -> SCNNode {
        if placement.body.type == .satellite {
            let visualNode = satelliteNode()
            let satelliteScale = max(0.22, placement.displayRadius * 5.5)
            visualNode.scale = SCNVector3(
                satelliteScale,
                satelliteScale,
                satelliteScale
            )
            return visualNode
        } else {
            let sphere = SCNSphere(radius: CGFloat(max(placement.displayRadius, 0.0001)))
            sphere.segmentCount = placement.body.type == .star ? renderDetail.starSegmentCount : renderDetail.planetSegmentCount
            sphere.firstMaterial = material(for: placement.body)
            return SCNNode(geometry: sphere)
        }
    }

    private static func bundledModelTargetAxis(for placement: ExperienceSceneBody, isObjectSnapshot: Bool) -> Float {
        if isObjectSnapshot {
            return max(1.24, placement.displayRadius * 10.5)
        }

        return max(0.82, placement.displayRadius * 7.2)
    }

    private static func resolvedAsset(for body: CelestialBody, isObjectSnapshot: Bool) -> SceneObjectAsset {
        guard isObjectSnapshot || body.usesObjectAssetResolver else {
            return .fallback
        }

        return SceneObjectAssetResolver.resolve(for: body)
    }

    private static func interactionNode(for placement: ExperienceSceneBody) -> SCNNode {
        let sphere = SCNSphere(radius: CGFloat(placement.interactionRadius))
        sphere.segmentCount = 12
        let material = SCNMaterial()
        material.diffuse.contents = platformColor(red: 1, green: 1, blue: 1, alpha: 0.01)
        material.transparency = 0.01
        material.lightingModel = .constant
        sphere.firstMaterial = material
        let node = SCNNode(geometry: sphere)
        node.name = "bodyHit:\(placement.id)"
        return node
    }

    static func rotationEuler(for placement: ExperienceSceneBody) -> SCNVector3 {
        SolarSystemSceneRotation.combinedEuler(for: placement)
    }

    private static func satelliteNode() -> SCNNode {
        let root = SCNNode()

        let body = SCNBox(width: 0.12, height: 0.08, length: 0.08, chamferRadius: 0.01)
        body.firstMaterial?.diffuse.contents = platformColor(red: 0.82, green: 0.84, blue: 0.88, alpha: 1)
        root.addChildNode(SCNNode(geometry: body))

        let panelMaterial = SCNMaterial()
        panelMaterial.diffuse.contents = platformColor(red: 0.12, green: 0.28, blue: 0.58, alpha: 1)
        panelMaterial.emission.contents = platformColor(red: 0.03, green: 0.08, blue: 0.18, alpha: 1)

        let leftPanel = SCNBox(width: 0.22, height: 0.008, length: 0.08, chamferRadius: 0.002)
        leftPanel.firstMaterial = panelMaterial
        let leftNode = SCNNode(geometry: leftPanel)
        leftNode.position.x = -0.18
        root.addChildNode(leftNode)

        let rightPanel = SCNBox(width: 0.22, height: 0.008, length: 0.08, chamferRadius: 0.002)
        rightPanel.firstMaterial = panelMaterial
        let rightNode = SCNNode(geometry: rightPanel)
        rightNode.position.x = 0.18
        root.addChildNode(rightNode)

        return root
    }

    private static func saturnRingNode(for radius: Float) -> SCNNode {
        let root = SCNNode()
        root.name = "saturnRings"

        for band in SaturnRingGeometry.bands {
            let node = SCNNode(geometry: ringGeometry(
                innerRadius: CGFloat(radius * band.innerRadiusRatio),
                outerRadius: CGFloat(radius * band.outerRadiusRatio)
            ))
            node.geometry?.firstMaterial = ringMaterial(alpha: band.alpha)
            node.renderingOrder = -1
            root.addChildNode(node)
        }

        return root
    }

    private static func ringGeometry(innerRadius: CGFloat, outerRadius: CGFloat) -> SCNGeometry {
        let segments = 144
        var vertices: [SCNVector3] = []
        var indices: [Int32] = []

        for index in 0...segments {
            let angle = CGFloat(index) / CGFloat(segments) * .pi * 2
            let x = cos(angle)
            let z = sin(angle)
            vertices.append(SCNVector3(x * innerRadius, 0, z * innerRadius))
            vertices.append(SCNVector3(x * outerRadius, 0, z * outerRadius))
        }

        for index in 0..<segments {
            let innerCurrent = Int32(index * 2)
            let outerCurrent = innerCurrent + 1
            let innerNext = innerCurrent + 2
            let outerNext = innerCurrent + 3
            indices.append(contentsOf: [
                innerCurrent, outerCurrent, innerNext,
                outerCurrent, outerNext, innerNext
            ])
        }

        let source = SCNGeometrySource(vertices: vertices)
        let element = SCNGeometryElement(indices: indices, primitiveType: .triangles)
        return SCNGeometry(sources: [source], elements: [element])
    }

    private static func ringMaterial(alpha: CGFloat) -> SCNMaterial {
        let material = SCNMaterial()
        let color = platformColor(red: 0.86, green: 0.78, blue: 0.58, alpha: alpha)
        material.diffuse.contents = color
        material.emission.contents = platformColor(red: 0.22, green: 0.18, blue: 0.11, alpha: alpha * 0.42)
        material.lightingModel = .constant
        material.isDoubleSided = true
        material.transparency = alpha
        material.readsFromDepthBuffer = true
        material.writesToDepthBuffer = false
        return material
    }

    private static func material(for body: CelestialBody) -> SCNMaterial {
        let material = SCNMaterial()
        material.diffuse.contents = textureImage(for: body) ?? fallbackColor(for: body)
        material.roughness.contents = 0.85

        if body.type == .star {
            material.emission.contents = fallbackColor(for: body)
        }

        return material
    }

    private static func textureImage(for body: CelestialBody) -> PlatformImage? {
        guard let textureName = body.textureName,
              let url = Bundle.main.url(
                forResource: textureName,
                withExtension: "jpg",
                subdirectory: "Planets"
              ) else {
            return nil
        }

#if os(iOS)
        return PlatformImage(contentsOfFile: url.path)
#elseif os(macOS)
        return PlatformImage(contentsOf: url)
#endif
    }

    private static func fallbackColor(for body: CelestialBody) -> PlatformColor {
        switch body.id {
        case "sun":
            return platformColor(red: 1, green: 0.74, blue: 0.20, alpha: 1)
        case "mercury", "moon":
            return platformColor(red: 0.55, green: 0.54, blue: 0.52, alpha: 1)
        case "venus":
            return platformColor(red: 0.86, green: 0.67, blue: 0.38, alpha: 1)
        case "earth":
            return platformColor(red: 0.16, green: 0.38, blue: 0.84, alpha: 1)
        case "mars":
            return platformColor(red: 0.78, green: 0.32, blue: 0.18, alpha: 1)
        case "jupiter", "saturn":
            return platformColor(red: 0.73, green: 0.58, blue: 0.42, alpha: 1)
        case "uranus", "neptune":
            return platformColor(red: 0.28, green: 0.62, blue: 0.84, alpha: 1)
        default:
            return platformColor(red: 0.78, green: 0.80, blue: 0.84, alpha: 1)
        }
    }

    static func labelPosition(for radius: Float) -> SCNVector3 {
        SCNVector3(0, radius + max(0.30, min(0.54, radius * 0.55)), 0)
    }

    private static func labelNode(for body: CelestialBody, radius: Float, cameraScale: Double) -> SCNNode {
        let text = SCNText(string: body.name, extrusionDepth: 0.006)
        text.font = .systemFont(ofSize: 1.0, weight: .bold)
        text.flatness = 0.02
        text.firstMaterial?.diffuse.contents = platformColor(red: 1, green: 1, blue: 1, alpha: 0.92)
        text.firstMaterial?.emission.contents = platformColor(red: 1, green: 1, blue: 1, alpha: 0.18)
        text.alignmentMode = CATextLayerAlignmentMode.center.rawValue

        let node = SCNNode(geometry: text)
        node.name = "label:\(body.id)"
        node.scale = SolarSystemSceneLabelScale.scaleVector(for: cameraScale)
        node.position = labelPosition(for: radius)
        node.constraints = [SCNBillboardConstraint()]

        let (minVector, maxVector) = text.boundingBox
        node.pivot = SCNMatrix4MakeTranslation(
            (maxVector.x - minVector.x) / 2,
            minVector.y,
            0
        )

        return node
    }

    private static func orbitNode(path: ExperienceOrbitPath, cameraScale: Double, cameraPosition: SCNVector3) -> SCNNode {
        let node = SCNNode(geometry: orbitGeometry(
            path: path,
            cameraScale: cameraScale,
            viewportHeight: 800,
            cameraPosition: cameraPosition
        ))
        node.name = "orbit:\(path.id)"

        for point in path.points.enumerated() where point.offset.isMultiple(of: 8) {
            let hitNode = SCNNode(geometry: orbitHitGeometry())
            hitNode.name = "orbitHit:\(path.bodyId)"
            hitNode.position = SCNVector3(point.element.x, point.element.y, point.element.z)
            node.addChildNode(hitNode)
        }

        return node
    }

    static func orbitGeometry(
        path: ExperienceOrbitPath,
        cameraScale: Double,
        viewportHeight: Double,
        cameraPosition: SCNVector3? = nil
    ) -> SCNGeometry {
        let mesh = SolarSystemSceneOrbitRibbon.mesh(
            points: path.points,
            cameraScale: cameraScale,
            viewportHeight: viewportHeight,
            cameraPosition: cameraPosition.map(SIMD3<Float>.init),
            isMoon: path.bodyId == "moon"
        )
        let source = SCNGeometrySource(vertices: mesh.vertices.map { SCNVector3($0.x, $0.y, $0.z) })
        let element = SCNGeometryElement(indices: mesh.indices, primitiveType: .triangles)
        let geometry = SCNGeometry(sources: [source], elements: [element])
        geometry.firstMaterial?.diffuse.contents = platformColor(red: 1, green: 1, blue: 1, alpha: path.bodyId == "moon" ? 0.22 : 0.13)
        geometry.firstMaterial?.emission.contents = platformColor(red: 1, green: 1, blue: 1, alpha: 0.10)
        geometry.firstMaterial?.lightingModel = .constant
        geometry.firstMaterial?.isDoubleSided = true
        return geometry
    }

    private static func orbitHitGeometry() -> SCNGeometry {
        let sphere = SCNSphere(radius: 0.09)
        sphere.segmentCount = 8
        let material = SCNMaterial()
        material.diffuse.contents = platformColor(red: 1, green: 1, blue: 1, alpha: 0.01)
        material.transparency = 0.01
        material.lightingModel = .constant
        sphere.firstMaterial = material
        return sphere
    }

    private static func cameraNode(for snapshot: ExperienceSceneSnapshot, settings: ExperienceSceneSettings) -> SCNNode {
        let metrics = SolarSystemSceneCameraMetrics(snapshot: snapshot, settings: settings)
        let camera = SCNCamera()
        camera.usesOrthographicProjection = true
        camera.orthographicScale = metrics.orthographicScale
        camera.zNear = metrics.zNear
        camera.zFar = metrics.zFar

        let node = SCNNode()
        node.name = "sceneCamera"
        node.camera = camera
        node.position = metrics.position
        node.look(at: metrics.subjectCenter)
        return node
    }

    private static func ambientLightNode() -> SCNNode {
        let light = SCNLight()
        light.type = .ambient
        light.intensity = 520
        light.color = platformColor(red: 0.60, green: 0.64, blue: 0.72, alpha: 1)

        let node = SCNNode()
        node.light = light
        return node
    }

    private static func keyLightNode() -> SCNNode {
        let light = SCNLight()
        light.type = .omni
        light.intensity = 820

        let node = SCNNode()
        node.light = light
        node.position = SCNVector3(-3, 6, 8)
        return node
    }
}

struct SolarSystemSceneFocusMetrics {
    static func focusedOrthographicScale(for bodyID: String, in snapshot: ExperienceSceneSnapshot) -> Double {
        guard let placement = snapshot.bodies.first(where: { $0.id == bodyID }) else {
            return 2.2
        }

        let childEnvelope = snapshot.bodies
            .filter { $0.body.parentBodyId == bodyID }
            .map { child in
                length(child.position - placement.position) + child.displayRadius
            }
            .max() ?? 0
        let cappedChildEnvelope = min(childEnvelope, placement.displayRadius * 1.05)
        let cappedInteractionRadius = min(placement.interactionRadius * 0.45, placement.displayRadius * 1.05)
        let ringRadius = placement.body.id == "saturn"
            ? placement.displayRadius * SaturnRingGeometry.outerRadiusRatio
            : placement.displayRadius
        let subjectRadius = max(ringRadius, cappedChildEnvelope, cappedInteractionRadius, 0.20)
        return max(0.82, Double(subjectRadius * 4.3))
    }

    static func focusedOrthographicScale(
        for bodyID: String,
        in snapshot: ExperienceSceneSnapshot,
        settings: ExperienceSceneSettings
    ) -> Double {
        guard settings.objectScaleMode == .trueScale,
              let placement = snapshot.bodies.first(where: { $0.id == bodyID }) else {
            return focusedOrthographicScale(for: bodyID, in: snapshot)
        }

        let visibleRadius = placement.body.id == "saturn"
            ? placement.displayRadius * SaturnRingGeometry.outerRadiusRatio
            : placement.displayRadius
        let radius = max(Double(visibleRadius), 0.000_08)
        switch placement.body.type {
        case .star:
            return max(0.05, radius * 5.8)
        case .planet:
            return max(0.0012, radius * 8.4)
        case .moon, .asteroid, .dwarfPlanet:
            return max(0.0009, radius * 10.0)
        case .satellite, .rocket, .spacecraft, .station, .astronaut:
            return max(0.001, radius * 9.0)
        }
    }

    static func cameraOffset(for bodyID: String, in snapshot: ExperienceSceneSnapshot) -> SCNVector3 {
        let scale = Float(focusedOrthographicScale(for: bodyID, in: snapshot))
        let bodyPosition = snapshot.bodies.first { $0.id == bodyID }?.position ?? .zero
        let sunPosition = snapshot.bodies.first { $0.id == "sun" }?.position ?? .zero
        var radial = bodyPosition - sunPosition
        radial.y = 0
        if simd_length_squared(radial) > 0.000_001 {
            radial = simd_normalize(radial)
        } else {
            radial = SIMD3<Float>(1, 0, 0)
        }

        return SCNVector3(
            radial.x * scale * 0.16,
            max(scale * 0.58, 0.86),
            max(scale * 1.18, 1.45) + radial.z * scale * 0.18
        )
    }

    static func cameraOffset(
        for bodyID: String,
        in snapshot: ExperienceSceneSnapshot,
        settings: ExperienceSceneSettings
    ) -> SCNVector3 {
        guard settings.objectScaleMode == .trueScale else {
            return cameraOffset(for: bodyID, in: snapshot)
        }

        let scale = Float(focusedOrthographicScale(for: bodyID, in: snapshot, settings: settings))
        let bodyPosition = snapshot.bodies.first { $0.id == bodyID }?.position ?? .zero
        let sunPosition = snapshot.bodies.first { $0.id == "sun" }?.position ?? .zero
        var radial = bodyPosition - sunPosition
        radial.y = 0
        if simd_length_squared(radial) > 0.000_001 {
            radial = simd_normalize(radial)
        } else {
            radial = SIMD3<Float>(1, 0, 0)
        }

        let minimumDistance = max(scale * 1.4, 0.012)
        return SCNVector3(
            radial.x * scale * 0.22,
            max(scale * 0.66, minimumDistance * 0.46),
            max(scale * 1.35, minimumDistance) + radial.z * scale * 0.22
        )
    }
}

struct SolarSystemSceneOrbitRibbon {
    struct Mesh {
        let vertices: [SIMD3<Float>]
        let indices: [Int32]
    }

    static func thickness(
        cameraScale: Double,
        viewportHeight: Double,
        cameraDistance: Double? = nil,
        isMoon: Bool = false
    ) -> Float {
        let pixels = isMoon ? 2.4 : 1.8
        let worldPerPixel = cameraScale / max(viewportHeight, 1)
        let referenceDistance = max(cameraScale * 1.6, 1)
        let distanceFactor = cameraDistance.map { distance in
            min(max(distance / referenceDistance, 0.78), isMoon ? 2.6 : 2.15)
        } ?? 1
        let maximum = isMoon ? 0.075 : 0.058
        return Float(min(max(worldPerPixel * pixels * distanceFactor, 0.006), maximum))
    }

    static func mesh(points: [SIMD3<Float>], thickness: Float) -> Mesh {
        mesh(points: points, thicknesses: Array(repeating: thickness, count: points.count))
    }

    static func mesh(
        points: [SIMD3<Float>],
        cameraScale: Double,
        viewportHeight: Double,
        cameraPosition: SIMD3<Float>?,
        isMoon: Bool = false
    ) -> Mesh {
        let thicknesses = points.map { point in
            thickness(
                cameraScale: cameraScale,
                viewportHeight: viewportHeight,
                cameraDistance: cameraPosition.map { Double(simd_distance($0, point)) },
                isMoon: isMoon
            )
        }
        return mesh(points: points, thicknesses: thicknesses)
    }

    private static func mesh(points: [SIMD3<Float>], thicknesses: [Float]) -> Mesh {
        guard points.count > 2 else {
            return Mesh(vertices: [], indices: [])
        }

        var vertices: [SIMD3<Float>] = []
        var indices: [Int32] = []

        for index in points.indices {
            let halfThickness = (thicknesses.indices.contains(index) ? thicknesses[index] : 0.006) / 2
            let side = sideVector(for: points, at: index, halfThickness: halfThickness)
            vertices.append(points[index] - side)
            vertices.append(points[index] + side)
        }

        for index in points.indices {
            let current = Int32(index * 2)
            let next = Int32(((index + 1) % points.count) * 2)
            indices.append(contentsOf: [
                current, current + 1, next,
                current + 1, next + 1, next
            ])
        }

        return Mesh(vertices: vertices, indices: indices)
    }

    static func sideVector(for points: [SIMD3<Float>], at index: Int, halfThickness: Float) -> SIMD3<Float> {
        guard points.count > 2, points.indices.contains(index) else {
            return SIMD3<Float>(halfThickness, 0, 0)
        }

        let previous = points[(index - 1 + points.count) % points.count]
        let next = points[(index + 1) % points.count]
        var tangent = next - previous
        if simd_length_squared(tangent) < 0.000_001 {
            tangent = SIMD3<Float>(1, 0, 0)
        }
        tangent = simd_normalize(tangent)

        let referenceAxes = [
            SIMD3<Float>(0, 1, 0),
            SIMD3<Float>(0, 0, 1),
            SIMD3<Float>(1, 0, 0)
        ]

        for axis in referenceAxes {
            let side = simd_cross(tangent, axis)
            if simd_length_squared(side) >= 0.000_001 {
                return simd_normalize(side) * halfThickness
            }
        }

        return SIMD3<Float>(halfThickness, 0, 0)
    }
}

struct SolarSystemSceneLabelScale {
    static func scale(for cameraScale: Double) -> Float {
        let scale = cameraScale * 0.028
        let minimumScale = cameraScale < 0.12 ? max(cameraScale * 0.08, 0.002) : 0.055
        return Float(min(max(scale, minimumScale), 0.28))
    }

    static func scaleVector(for cameraScale: Double) -> SCNVector3 {
        let value = scale(for: cameraScale)
        return SCNVector3(value, value, value)
    }
}

struct SolarSystemSceneRotation {
    static let axialTiltAxis = SIMD3<Float>(0, 0, 1)

    static func tiltEuler(for placement: ExperienceSceneBody) -> SCNVector3 {
        SCNVector3(0, 0, placement.axialTiltRadians)
    }

    static func spinEuler(for placement: ExperienceSceneBody) -> SCNVector3 {
        SCNVector3(0, placement.rotationAngleRadians, 0)
    }

    static func combinedEuler(for placement: ExperienceSceneBody) -> SCNVector3 {
        SCNVector3(0, placement.rotationAngleRadians, placement.axialTiltRadians)
    }
}

struct SolarSystemSceneCameraMetrics {
    let position: SCNVector3
    let orthographicScale: Double
    let zNear: Double
    let zFar: Double
    let cameraDistance: Double
    let subjectCenter: SCNVector3

    init(snapshot: ExperienceSceneSnapshot, settings: ExperienceSceneSettings = .defaults) {
        let center = Self.initialSubjectCenter(for: snapshot)
        let objectSnapshot = Self.isArtifactObjectSnapshot(snapshot)
        let trueScaleScene = settings.distanceScaleMode == .trueScale || settings.sceneScaleProfile == .trueSize
        let span = objectSnapshot
            ? Double(max(snapshot.bounds.span, 0.2))
            : Double(max(snapshot.bounds.span, 1))
        subjectCenter = center
        orthographicScale = Self.initialOrthographicScale(for: snapshot, settings: settings)
        cameraDistance = objectSnapshot
            ? max(6, span * 4.0 + 6)
            : max(22, span * 1.8 + 28)
        zNear = 0.001
        zFar = objectSnapshot
            ? max(80, cameraDistance + span * 8.0 + 40)
            : max(trueScaleScene ? 900 : 250, cameraDistance + span * (trueScaleScene ? 7.0 : 4.8) + (trueScaleScene ? 260 : 140))
        position = objectSnapshot
            ? center + SCNVector3(0, 0, Float(cameraDistance))
            : center + Self.defaultCameraOffset(for: orthographicScale, cameraDistance: cameraDistance)
    }

    static func updateClippingPlanes(
        for camera: SCNCamera,
        snapshot: ExperienceSceneSnapshot,
        settings: ExperienceSceneSettings,
        cameraPosition: SCNVector3
    ) {
        let metrics = SolarSystemSceneCameraMetrics(snapshot: snapshot, settings: settings)
        let cameraDistanceFromCenter = Double((cameraPosition - metrics.subjectCenter).length)
        let span = Double(max(snapshot.bounds.span, 1))
        let objectSnapshot = isArtifactObjectSnapshot(snapshot)
        let margin = objectSnapshot ? span * 8 + 40 : span * 7 + 220

        camera.zNear = objectSnapshot ? 0.001 : 0.01
        camera.zFar = max(metrics.zFar, cameraDistanceFromCenter + margin)
    }

    static func defaultCameraOffset(for orthographicScale: Double, cameraDistance: Double? = nil) -> SCNVector3 {
        let distance = Float(cameraDistance ?? max(22, orthographicScale * 1.8 + 28))
        let scale = Float(orthographicScale)
        return SCNVector3(
            max(3.5, scale * 0.18),
            max(distance * 0.64, scale * 1.12),
            max(distance * 0.52, scale * 0.82)
        )
    }

    private static func initialSubjectCenter(for snapshot: ExperienceSceneSnapshot) -> SCNVector3 {
        if let sun = snapshot.bodies.first(where: { $0.id == "sun" }) {
            return SCNVector3(sun.position.x, sun.position.y, sun.position.z)
        }

        return SCNVector3(snapshot.bounds.center.x, snapshot.bounds.center.y, snapshot.bounds.center.z)
    }

    private static func initialOrthographicScale(for snapshot: ExperienceSceneSnapshot, settings: ExperienceSceneSettings) -> Double {
        if isArtifactObjectSnapshot(snapshot) {
            let largestBodyRadius = snapshot.bodies.map(\.displayRadius).max() ?? 0.16
            let largestInteractionRadius = snapshot.bodies.map(\.interactionRadius).max() ?? largestBodyRadius
            let subjectRadius = max(largestBodyRadius, largestInteractionRadius, 0.16)
            return max(0.95, Double(subjectRadius) * 5.8)
        }

        let span = Double(max(snapshot.bounds.span, 1))

        switch settings.sceneScaleProfile {
        case .scaledRecommended:
            return max(7, min(19, span * 0.90 + 2.8))
        case .uniform:
            return max(7, min(21, span * 0.96 + 3.0))
        case .trueSize:
            return max(7, span + 2.6)
        case .custom:
            switch settings.distanceScaleMode {
            case .trueScale:
                return max(7, span + 2.6)
            case .educational:
                return max(7, min(21, span * 0.98 + 3.0))
            case .compressed:
                return max(7, min(25, span * 1.05 + 3.2))
            }
        }
    }

    static func isArtifactObjectSnapshot(_ snapshot: ExperienceSceneSnapshot) -> Bool {
        guard snapshot.bodies.count == 1,
              snapshot.orbitPaths.isEmpty,
              let body = snapshot.bodies.first?.body else {
            return false
        }

        switch body.type {
        case .satellite, .rocket, .spacecraft, .station, .astronaut:
            return true
        case .star, .planet, .moon, .asteroid, .dwarfPlanet:
            return false
        }
    }
}

struct SceneCameraLimit {
    static let `default` = SceneCameraLimit(
        subjectCenter: SCNVector3Zero,
        preferredOrthographicScale: 7,
        maximumOrthographicScale: 14,
        maximumCameraDistance: 34
    )

    let subjectCenter: SCNVector3
    let minimumOrthographicScale: Double
    let preferredOrthographicScale: Double
    let maximumOrthographicScale: Double
    let maximumCameraDistance: Float

    init(snapshot: ExperienceSceneSnapshot, settings: ExperienceSceneSettings = .defaults) {
        let placements = snapshot.bodies
        guard !placements.isEmpty else {
            self = .default
            return
        }

        let cameraMetrics = SolarSystemSceneCameraMetrics(snapshot: snapshot, settings: settings)
        let center = cameraMetrics.subjectCenter
        let sceneSpan = snapshot.bounds.span
        let subjectRadius = max(4, sceneSpan / 2 + 2)
        let largestBodyRadius = placements.map(\.displayRadius).max() ?? 1
        let initialCameraDistance = (cameraMetrics.position - center).length
        let initialOrthographicScale = cameraMetrics.orthographicScale
        let trueScaleScene = settings.distanceScaleMode == .trueScale || settings.sceneScaleProfile == .trueSize
        let minimumOrthographicScale = trueScaleScene
            ? max(0.12, min(Double(largestBodyRadius) * 0.55, initialOrthographicScale * 0.08))
            : max(0.65, Double(largestBodyRadius) * 2.25)

        self.init(
            subjectCenter: center,
            minimumOrthographicScale: minimumOrthographicScale,
            preferredOrthographicScale: initialOrthographicScale,
            maximumOrthographicScale: initialOrthographicScale * 2.1,
            maximumCameraDistance: max(initialCameraDistance * 2.5, subjectRadius * 7.0)
        )
    }

    private init(
        subjectCenter: SCNVector3,
        minimumOrthographicScale: Double = 0.7,
        preferredOrthographicScale: Double,
        maximumOrthographicScale: Double,
        maximumCameraDistance: Float
    ) {
        self.subjectCenter = subjectCenter
        self.minimumOrthographicScale = minimumOrthographicScale
        self.preferredOrthographicScale = preferredOrthographicScale
        self.maximumOrthographicScale = maximumOrthographicScale
        self.maximumCameraDistance = maximumCameraDistance
    }
}

private extension SCNNode {
    func worldBoundingBoxCenter() -> SCNVector3? {
        var minimum: SCNVector3?
        var maximum: SCNVector3?

        func include(_ point: SCNVector3) {
            if let currentMinimum = minimum, let currentMaximum = maximum {
                minimum = SCNVector3(
                    min(currentMinimum.x, point.x),
                    min(currentMinimum.y, point.y),
                    min(currentMinimum.z, point.z)
                )
                maximum = SCNVector3(
                    max(currentMaximum.x, point.x),
                    max(currentMaximum.y, point.y),
                    max(currentMaximum.z, point.z)
                )
            } else {
                minimum = point
                maximum = point
            }
        }

        func includeGeometry(from sourceNode: SCNNode) {
            guard let geometry = sourceNode.geometry else { return }
            let bounds = geometry.boundingBox
            let minVector = bounds.min
            let maxVector = bounds.max
            let corners = [
                SCNVector3(minVector.x, minVector.y, minVector.z),
                SCNVector3(minVector.x, minVector.y, maxVector.z),
                SCNVector3(minVector.x, maxVector.y, minVector.z),
                SCNVector3(minVector.x, maxVector.y, maxVector.z),
                SCNVector3(maxVector.x, minVector.y, minVector.z),
                SCNVector3(maxVector.x, minVector.y, maxVector.z),
                SCNVector3(maxVector.x, maxVector.y, minVector.z),
                SCNVector3(maxVector.x, maxVector.y, maxVector.z)
            ]
            corners
                .map { sourceNode.convertPosition($0, to: nil) }
                .forEach(include)
        }

        includeGeometry(from: self)
        enumerateChildNodes { node, _ in
            includeGeometry(from: node.presentation)
        }

        guard let minimum, let maximum else { return nil }
        return SCNVector3(
            (minimum.x + maximum.x) / 2,
            (minimum.y + maximum.y) / 2,
            (minimum.z + maximum.z) / 2
        )
    }
}

private extension SCNVector3 {
    static func + (lhs: SCNVector3, rhs: SCNVector3) -> SCNVector3 {
        SCNVector3(lhs.x + rhs.x, lhs.y + rhs.y, lhs.z + rhs.z)
    }

    static func - (lhs: SCNVector3, rhs: SCNVector3) -> SCNVector3 {
        SCNVector3(lhs.x - rhs.x, lhs.y - rhs.y, lhs.z - rhs.z)
    }

    static func * (lhs: SCNVector3, rhs: Float) -> SCNVector3 {
        SCNVector3(Float(lhs.x) * rhs, Float(lhs.y) * rhs, Float(lhs.z) * rhs)
    }

    var length: Float {
        let xValue = Float(x)
        let yValue = Float(y)
        let zValue = Float(z)
        return sqrtf(xValue * xValue + yValue * yValue + zValue * zValue)
    }

    var normalized: SCNVector3 {
        let vectorLength = length
        guard vectorLength > 0 else { return SCNVector3Zero }
        return SCNVector3(Float(x) / vectorLength, Float(y) / vectorLength, Float(z) / vectorLength)
    }

    var normalizedOrDefault: SCNVector3 {
        length > 0 ? normalized : SCNVector3(0, 0, 1)
    }

    func distance(to other: SCNVector3) -> Float {
        (self - other).length
    }
}

private extension SIMD3<Float> {
    init(_ vector: SCNVector3) {
        self.init(Float(vector.x), Float(vector.y), Float(vector.z))
    }
}

private func platformColor(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) -> PlatformColor {
#if os(iOS)
    PlatformColor(red: red, green: green, blue: blue, alpha: alpha)
#elseif os(macOS)
    PlatformColor(calibratedRed: red, green: green, blue: blue, alpha: alpha)
#endif
}
