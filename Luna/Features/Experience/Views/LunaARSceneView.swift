#if os(iOS)
import ARKit
import Combine
import RealityKit
import SwiftUI
import UIKit

struct LunaARSceneView: UIViewRepresentable {
    let bodies: [CelestialBody]
    let settings: ExperienceSceneSettings
    var content: ExperienceSceneContent = .solarSystem
    var simulationTimeDays: Double = 0
    var simulationDate: Date = Date()
    let recenterTrigger: Int
    var showsDebugSurfaces = false
    var onPlacementStateChange: (ARPlacementState) -> Void = { _ in }
    var onSelectBody: (CelestialBody) -> Void = { _ in }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero)
        view.automaticallyConfigureSession = false
        context.coordinator.configureSession(for: view)
        context.coordinator.installCoachingOverlay(in: view)
        context.coordinator.startPlacementMonitoring(in: view)
        context.coordinator.installSelectionGesture(in: view)
        context.coordinator.update(
            view,
            bodies: bodies,
            settings: settings,
            content: content,
            simulationTimeDays: simulationTimeDays,
            simulationDate: simulationDate,
            recenterTrigger: recenterTrigger,
            showsDebugSurfaces: showsDebugSurfaces,
            onPlacementStateChange: onPlacementStateChange,
            onSelectBody: onSelectBody
        )
        return view
    }

    func updateUIView(_ view: ARView, context: Context) {
        context.coordinator.update(
            view,
            bodies: bodies,
            settings: settings,
            content: content,
            simulationTimeDays: simulationTimeDays,
            simulationDate: simulationDate,
            recenterTrigger: recenterTrigger,
            showsDebugSurfaces: showsDebugSurfaces,
            onPlacementStateChange: onPlacementStateChange,
            onSelectBody: onSelectBody
        )
    }

    final class Coordinator: NSObject, ARCoachingOverlayViewDelegate {
        private var anchor: AnchorEntity?
        private var root: ModelEntity?
        private var rootCenter: SIMD3<Float> = .zero
        private var structureKey: String?
        private var bodyEntities: [String: Entity] = [:]
        private var orbitEntities: [String: Entity] = [:]
        private var installedGestures: [UIGestureRecognizer] = []
        private var lastRecenterTrigger: Int?
        private var placementUpdateSubscription: Cancellable?
        private var lastPlacementState: ARPlacementState?
        private var onPlacementStateChange: (ARPlacementState) -> Void = { _ in }
        private var bodyLookup: [String: CelestialBody] = [:]
        private var onSelectBody: (CelestialBody) -> Void = { _ in }
        private static var textureCache: [String: TextureResource] = [:]

        func configureSession(for view: ARView) {
            guard ARWorldTrackingConfiguration.isSupported else { return }

            let configuration = ARWorldTrackingConfiguration()
            configuration.planeDetection = [.horizontal]
            configuration.environmentTexturing = .none
            view.session.run(configuration)
        }

        func installCoachingOverlay(in view: ARView) {
            guard view.subviews.contains(where: { $0 is ARCoachingOverlayView }) == false else {
                return
            }

            let coachingOverlay = ARCoachingOverlayView()
            coachingOverlay.session = view.session
            coachingOverlay.goal = .horizontalPlane
            coachingOverlay.activatesAutomatically = true
            coachingOverlay.delegate = self
            coachingOverlay.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(coachingOverlay)

            NSLayoutConstraint.activate([
                coachingOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                coachingOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                coachingOverlay.topAnchor.constraint(equalTo: view.topAnchor),
                coachingOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
        }

        func startPlacementMonitoring(in view: ARView) {
            guard placementUpdateSubscription == nil else { return }

            placementUpdateSubscription = view.scene.subscribe(to: SceneEvents.Update.self) { [weak self, weak view] _ in
                guard let self, let view else { return }
                self.publishPlacementState(for: view)
            }
        }

        func installSelectionGesture(in view: ARView) {
            guard view.gestureRecognizers?.contains(where: { $0.name == "LunaARBodySelection" }) != true else {
                return
            }

            let recognizer = UITapGestureRecognizer(target: self, action: #selector(handleBodyTap(_:)))
            recognizer.name = "LunaARBodySelection"
            recognizer.cancelsTouchesInView = false
            view.addGestureRecognizer(recognizer)
        }

        func update(
            _ view: ARView,
            bodies: [CelestialBody],
            settings: ExperienceSceneSettings,
            content: ExperienceSceneContent,
            simulationTimeDays: Double,
            simulationDate: Date,
            recenterTrigger: Int,
            showsDebugSurfaces: Bool,
            onPlacementStateChange: @escaping (ARPlacementState) -> Void,
            onSelectBody: @escaping (CelestialBody) -> Void
        ) {
            self.onPlacementStateChange = onPlacementStateChange
            self.onSelectBody = onSelectBody
            view.debugOptions = showsDebugSurfaces
                ? [.showFeaturePoints, .showAnchorOrigins, .showAnchorGeometry]
                : []
            publishPlacementState(for: view)

            guard recenterTrigger > 0 else {
                if let anchor {
                    view.scene.removeAnchor(anchor)
                    self.anchor = nil
                }
                root = nil
                structureKey = nil
                bodyEntities.removeAll()
                orbitEntities.removeAll()
                lastRecenterTrigger = recenterTrigger
                return
            }

            let snapshot = ExperienceSceneEngine.snapshot(
                for: bodies,
                settings: settings,
                content: content,
                simulationTimeDays: simulationTimeDays,
                simulationDate: simulationDate
            )
            bodyLookup = Dictionary(uniqueKeysWithValues: snapshot.bodies.map { ($0.id, $0.body) })
            let shouldRecenter = anchor == nil || lastRecenterTrigger != recenterTrigger
            if shouldRecenter {
                guard recenter(in: view) else {
                    return
                }
                lastRecenterTrigger = recenterTrigger
                structureKey = nil
            }

            guard let anchor else { return }

            let nextStructureKey = Self.structureKey(for: snapshot, settings: settings)

            if root == nil || structureKey != nextStructureKey {
                installedGestures.forEach { view.removeGestureRecognizer($0) }
                installedGestures.removeAll()
                anchor.children.removeAll()

                let renderTree = Self.gestureRoot(for: snapshot, settings: settings)
                root = renderTree.root
                rootCenter = renderTree.center
                bodyEntities = renderTree.bodyEntities
                orbitEntities = renderTree.orbitEntities
                structureKey = nextStructureKey

                anchor.addChild(renderTree.root)
                installedGestures = view.installGestures([.translation, .rotation, .scale], for: renderTree.root)
            } else {
                updateExistingEntities(with: snapshot, settings: settings)
            }
        }

        private func recenter(in view: ARView) -> Bool {
            guard let surfaceTransform = Self.placementTransform(for: view) else {
                publishPlacementState(for: view)
                return false
            }

            if let anchor {
                view.scene.removeAnchor(anchor)
            }
            root = nil
            structureKey = nil
            bodyEntities.removeAll()
            orbitEntities.removeAll()

            let anchor = AnchorEntity(world: surfaceTransform)
            self.anchor = anchor
            view.scene.addAnchor(anchor)
            return true
        }

        private func publishPlacementState(for view: ARView) {
            let nextState = Self.placementState(for: view)
            guard nextState != lastPlacementState else { return }

            lastPlacementState = nextState
            DispatchQueue.main.async { [onPlacementStateChange] in
                onPlacementStateChange(nextState)
            }
        }

        private func updateExistingEntities(with snapshot: ExperienceSceneSnapshot, settings: ExperienceSceneSettings) {
            let arPlacements = snapshot.bodies.map { placement -> ARBodyPlacement in
                ARBodyPlacement(
                    body: placement.body,
                    displayRadius: max(0.0001, placement.displayRadius * 0.095),
                    position: SIMD3<Float>(
                        placement.position.x * 0.095,
                        placement.position.y * 0.095,
                        placement.position.z * 0.095
                    ),
                    rotationAngleRadians: placement.rotationAngleRadians,
                    axialTiltRadians: placement.axialTiltRadians
                )
            }

            for placement in arPlacements {
                guard let entity = bodyEntities[placement.body.id] else { continue }
                entity.position = placement.position - rootCenter
                entity.orientation = Self.rotationOrientation(for: placement)
            }

            for orbitPath in snapshot.orbitPaths {
                guard let entity = orbitEntities[orbitPath.id] else { continue }
                Self.replaceOrbitContents(in: entity, for: orbitPath, detail: settings.renderDetail, center: rootCenter)
            }
        }

        private static func gestureRoot(
            for snapshot: ExperienceSceneSnapshot,
            settings: ExperienceSceneSettings
        ) -> ARRenderTree {
            let arPlacements = snapshot.bodies.map { placement -> ARBodyPlacement in
                ARBodyPlacement(
                    body: placement.body,
                    displayRadius: max(0.0001, placement.displayRadius * 0.095),
                    position: SIMD3<Float>(
                        placement.position.x * 0.095,
                        placement.position.y * 0.095,
                        placement.position.z * 0.095
                    ),
                    rotationAngleRadians: placement.rotationAngleRadians,
                    axialTiltRadians: placement.axialTiltRadians
                )
            }
            let bounds = ARPlacementBounds(placements: arPlacements)
            let root = ModelEntity()
            root.name = "sceneRoot"
            root.position = bounds.center
            root.collision = CollisionComponent(shapes: [.generateBox(size: bounds.size)])
            var bodyEntities: [String: Entity] = [:]
            var orbitEntities: [String: Entity] = [:]

            for placement in arPlacements {
                let entity = entity(for: placement)
                entity.name = "body:\(placement.body.id)"
                entity.position = placement.position - bounds.center
                entity.orientation = rotationOrientation(for: placement)
                entity.generateCollisionShapes(recursive: true)
                root.addChild(entity)
                bodyEntities[placement.body.id] = entity
            }

            if settings.showOrbits {
                for orbitPath in snapshot.orbitPaths {
                    let orbitEntity = orbitEntity(for: orbitPath, detail: settings.renderDetail, center: bounds.center)
                    root.addChild(orbitEntity)
                    orbitEntities[orbitPath.id] = orbitEntity
                }
            }

            return ARRenderTree(
                root: root,
                center: bounds.center,
                bodyEntities: bodyEntities,
                orbitEntities: orbitEntities
            )
        }

        private static func placementState(for view: ARView) -> ARPlacementState {
            guard ARWorldTrackingConfiguration.isSupported else {
                return .unavailable
            }

            guard let frame = view.session.currentFrame else {
                return .initializing
            }

            guard case .normal = frame.camera.trackingState else {
                return .initializing
            }

            return placementTransform(for: view) == nil ? .findingSurface : .ready
        }

        @objc private func handleBodyTap(_ recognizer: UITapGestureRecognizer) {
            guard let view = recognizer.view as? ARView else { return }

            let hits = view.entities(at: recognizer.location(in: view))
            guard let body = hits.compactMap({ body(for: $0) }).first else { return }

            onSelectBody(body)
        }

        private func body(for entity: Entity) -> CelestialBody? {
            var currentEntity: Entity? = entity
            while let entity = currentEntity {
                if entity.name.hasPrefix("body:") {
                    return bodyLookup[String(entity.name.dropFirst(5))]
                }
                if entity.name.hasPrefix("orbit:") {
                    return bodyLookup[String(entity.name.dropFirst(6))]
                }
                currentEntity = entity.parent
            }
            return nil
        }

        private static func placementTransform(for view: ARView) -> simd_float4x4? {
            let centerPoint = CGPoint(x: view.bounds.midX, y: view.bounds.midY)

            guard let frame = view.session.currentFrame,
                  case .normal = frame.camera.trackingState else {
                return nil
            }

            guard var surfaceTransform = view.raycast(
                from: centerPoint,
                allowing: .existingPlaneGeometry,
                alignment: .horizontal
            ).first?.worldTransform else {
                return nil
            }

            surfaceTransform.columns.3.y += 0.08
            return surfaceTransform
        }

        private static func entity(for placement: ARBodyPlacement) -> Entity {
            if placement.body.type == .satellite {
                return satelliteEntity(scale: placement.displayRadius)
            }

            let mesh = MeshResource.generateSphere(radius: placement.displayRadius)
            let material = material(for: placement.body)
            return ModelEntity(mesh: mesh, materials: [material])
        }

        private static func rotationOrientation(for placement: ARBodyPlacement) -> simd_quatf {
            let tilt = simd_quatf(angle: placement.axialTiltRadians, axis: SolarSystemSceneRotation.axialTiltAxis)
            let spin = simd_quatf(angle: placement.rotationAngleRadians, axis: SIMD3<Float>(0, 1, 0))
            return tilt * spin
        }

        private static func orbitEntity(for path: ExperienceOrbitPath, detail: SceneRenderDetail, center: SIMD3<Float>) -> Entity {
            let root = Entity()
            root.name = "orbit:\(path.bodyId)"
            replaceOrbitContents(in: root, for: path, detail: detail, center: center)
            return root
        }

        private static func replaceOrbitContents(
            in root: Entity,
            for path: ExperienceOrbitPath,
            detail: SceneRenderDetail,
            center: SIMD3<Float>
        ) {
            root.children.removeAll()
            let budget = ARSceneOrbitRenderBudget(path: path, detail: detail, scale: 0.095, center: center)
            let material = SimpleMaterial(
                color: UIColor.white.withAlphaComponent(path.bodyId == "moon" ? 0.34 : 0.18),
                roughness: 0.6,
                isMetallic: false
            )

            if let mesh = orbitRibbonMesh(points: budget.meshPoints, thickness: budget.lineThickness) {
                let entity = ModelEntity(mesh: mesh, materials: [material])
                entity.name = "orbit:\(path.bodyId)"
                root.addChild(entity)
                return
            }

            let dotMesh = MeshResource.generateSphere(radius: budget.lineThickness * 2.5)
            for point in budget.fallbackDotPoints {
                let dot = ModelEntity(
                    mesh: dotMesh,
                    materials: [material]
                )
                dot.name = "orbit:\(path.bodyId)"
                dot.position = point
                root.addChild(dot)
            }
        }

        private static func orbitRibbonMesh(points: [SIMD3<Float>], thickness: Float) -> MeshResource? {
            guard points.count > 2 else { return nil }

            let halfThickness = thickness / 2
            var vertices: [SIMD3<Float>] = []
            var indices: [UInt32] = []

            for index in points.indices {
                let side = SolarSystemSceneOrbitRibbon.sideVector(
                    for: points,
                    at: index,
                    halfThickness: halfThickness
                )
                vertices.append(points[index] - side)
                vertices.append(points[index] + side)
            }

            for index in points.indices {
                let current = UInt32(index * 2)
                let next = UInt32(((index + 1) % points.count) * 2)
                indices.append(contentsOf: [
                    current, current + 1, next,
                    current + 1, next + 1, next
                ])
            }

            var descriptor = MeshDescriptor(name: "orbitRibbon")
            descriptor.positions = MeshBuffers.Positions(vertices)
            descriptor.primitives = .triangles(indices)
            return try? MeshResource.generate(from: [descriptor])
        }

        private static func structureKey(
            for snapshot: ExperienceSceneSnapshot,
            settings: ExperienceSceneSettings
        ) -> String {
            let bodyKey = snapshot.bodies
                .map { body in
                    let radius = Int((body.displayRadius * 1_000).rounded())
                    return "\(body.id):\(body.body.type.rawValue):\(radius):\(body.body.textureName ?? ""):\(body.body.modelName ?? "")"
                }
                .joined(separator: "|")
            let orbitKey = settings.showOrbits
                ? snapshot.orbitPaths.map { "\($0.id):\(ARSceneOrbitRenderBudget.maxMeshPointCount(for: settings.renderDetail))" }.joined(separator: "|")
                : "no-orbits"

            return "\(settings.distanceScaleMode.rawValue):\(settings.renderDetail.rawValue):\(Int(settings.distanceCompression.rounded())):\(settings.showOrbits)-\(bodyKey)-\(orbitKey)"
        }

        private static func material(for body: CelestialBody) -> UnlitMaterial {
            var material = UnlitMaterial(color: fallbackColor(for: body))

            if let texture = textureResource(for: body) {
                material.color = .init(tint: .white, texture: .init(texture))
            }

            return material
        }

        private static func textureResource(for body: CelestialBody) -> TextureResource? {
            guard let textureName = body.textureName else {
                return nil
            }

            if let cachedTexture = textureCache[textureName] {
                return cachedTexture
            }

            guard let url = Bundle.main.url(
                forResource: textureName,
                withExtension: "jpg",
                subdirectory: "Planets"
            ) else {
                return nil
            }

            guard let texture = try? TextureResource.load(contentsOf: url) else {
                return nil
            }

            textureCache[textureName] = texture
            return texture
        }

        private static func satelliteEntity(scale: Float) -> Entity {
            let root = Entity()
            let body = ModelEntity(
                mesh: .generateBox(size: SIMD3<Float>(0.035, 0.024, 0.024)),
                materials: [SimpleMaterial(color: .lightGray, roughness: 0.5, isMetallic: false)]
            )
            root.addChild(body)

            let panelMaterial = SimpleMaterial(color: UIColor(red: 0.10, green: 0.22, blue: 0.50, alpha: 1), roughness: 0.4, isMetallic: false)
            let leftPanel = ModelEntity(mesh: .generateBox(size: SIMD3<Float>(0.055, 0.006, 0.024)), materials: [panelMaterial])
            leftPanel.position.x = -0.046
            root.addChild(leftPanel)

            let rightPanel = ModelEntity(mesh: .generateBox(size: SIMD3<Float>(0.055, 0.006, 0.024)), materials: [panelMaterial])
            rightPanel.position.x = 0.046
            root.addChild(rightPanel)

            root.scale = SIMD3<Float>(repeating: max(0.32, scale * 5.5))
            return root
        }

        private static func fallbackColor(for body: CelestialBody) -> UIColor {
            switch body.id {
            case "sun":
                return UIColor(red: 1, green: 0.74, blue: 0.20, alpha: 1)
            case "mercury", "moon":
                return UIColor(red: 0.55, green: 0.54, blue: 0.52, alpha: 1)
            case "venus":
                return UIColor(red: 0.86, green: 0.67, blue: 0.38, alpha: 1)
            case "earth":
                return UIColor(red: 0.16, green: 0.38, blue: 0.84, alpha: 1)
            case "mars":
                return UIColor(red: 0.78, green: 0.32, blue: 0.18, alpha: 1)
            case "jupiter", "saturn":
                return UIColor(red: 0.73, green: 0.58, blue: 0.42, alpha: 1)
            case "uranus", "neptune":
                return UIColor(red: 0.28, green: 0.62, blue: 0.84, alpha: 1)
            default:
                return UIColor(red: 0.78, green: 0.80, blue: 0.84, alpha: 1)
            }
        }
    }
}

private struct ARBodyPlacement {
    let body: CelestialBody
    let displayRadius: Float
    let position: SIMD3<Float>
    let rotationAngleRadians: Float
    let axialTiltRadians: Float
}

private struct ARRenderTree {
    let root: ModelEntity
    let center: SIMD3<Float>
    let bodyEntities: [String: Entity]
    let orbitEntities: [String: Entity]
}

struct ARSceneOrbitRenderBudget {
    let meshPoints: [SIMD3<Float>]
    let fallbackDotPoints: [SIMD3<Float>]
    let lineThickness: Float

    init(path: ExperienceOrbitPath, detail: SceneRenderDetail, scale: Float, center: SIMD3<Float>) {
        meshPoints = Self.sampledPoints(
            path.points,
            limit: Self.maxMeshPointCount(for: detail)
        ).map { ($0 * scale) - center }
        fallbackDotPoints = path.points.enumerated().compactMap { index, point in
            index.isMultiple(of: detail.arOrbitStride) ? (point * scale) - center : nil
        }
        lineThickness = path.bodyId == "moon" ? 0.0022 : 0.0016
    }

    var renderItemCount: Int {
        meshPoints.count > 2 ? 1 : fallbackDotPoints.count
    }

    static func maxMeshPointCount(for detail: SceneRenderDetail) -> Int {
        switch detail {
        case .low:
            return 48
        case .balanced:
            return 72
        case .high:
            return 96
        }
    }

    private static func sampledPoints(_ points: [SIMD3<Float>], limit: Int) -> [SIMD3<Float>] {
        guard points.count > limit, limit > 0 else {
            return points
        }

        return (0..<limit).map { index in
            let sourceIndex = min(points.count - 1, Int(Double(index) * Double(points.count) / Double(limit)))
            return points[sourceIndex]
        }
    }
}

private struct ARPlacementBounds {
    let center: SIMD3<Float>
    let size: SIMD3<Float>

    init(placements: [ARBodyPlacement]) {
        guard !placements.isEmpty else {
            center = .zero
            size = SIMD3<Float>(repeating: 0.45)
            return
        }

        let minX = placements.map { $0.position.x - $0.displayRadius }.min() ?? -0.2
        let maxX = placements.map { $0.position.x + $0.displayRadius }.max() ?? 0.2
        let minY = placements.map { $0.position.y - $0.displayRadius }.min() ?? -0.2
        let maxY = placements.map { $0.position.y + $0.displayRadius }.max() ?? 0.2
        let minZ = placements.map { $0.position.z - $0.displayRadius }.min() ?? -0.2
        let maxZ = placements.map { $0.position.z + $0.displayRadius }.max() ?? 0.2

        center = SIMD3<Float>(
            (minX + maxX) / 2,
            (minY + maxY) / 2,
            (minZ + maxZ) / 2
        )
        size = SIMD3<Float>(
            max(0.35, maxX - minX + 0.2),
            max(0.35, maxY - minY + 0.2),
            max(0.35, maxZ - minZ + 0.2)
        )
    }
}

#endif
