#if os(iOS)
import ARKit
import RealityKit
import SwiftUI
import UIKit

struct LunaARSceneView: UIViewRepresentable {
    let bodies: [CelestialBody]
    let settings: SolarSystemSceneSettings
    let recenterTrigger: Int

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero)
        view.automaticallyConfigureSession = false
        context.coordinator.configureSession(for: view)
        context.coordinator.installCoachingOverlay(in: view)
        context.coordinator.update(
            view,
            bodies: bodies,
            settings: settings,
            recenterTrigger: recenterTrigger
        )
        return view
    }

    func updateUIView(_ view: ARView, context: Context) {
        context.coordinator.update(
            view,
            bodies: bodies,
            settings: settings,
            recenterTrigger: recenterTrigger
        )
    }

    final class Coordinator: NSObject, ARCoachingOverlayViewDelegate {
        private var anchor: AnchorEntity?
        private var installedGestures: [UIGestureRecognizer] = []
        private var lastRecenterTrigger: Int?

        func configureSession(for view: ARView) {
            guard ARWorldTrackingConfiguration.isSupported else { return }

            let configuration = ARWorldTrackingConfiguration()
            configuration.planeDetection = [.horizontal]
            configuration.environmentTexturing = .automatic
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

        func update(
            _ view: ARView,
            bodies: [CelestialBody],
            settings: SolarSystemSceneSettings,
            recenterTrigger: Int
        ) {
            guard recenterTrigger > 0 else {
                if let anchor {
                    view.scene.removeAnchor(anchor)
                    self.anchor = nil
                }
                lastRecenterTrigger = recenterTrigger
                return
            }

            let shouldRecenter = anchor == nil || lastRecenterTrigger != recenterTrigger
            if shouldRecenter {
                recenter(in: view)
                lastRecenterTrigger = recenterTrigger
            }

            guard let anchor else { return }

            installedGestures.forEach { view.removeGestureRecognizer($0) }
            installedGestures.removeAll()
            anchor.children.removeAll()

            let root = Self.gestureRoot(for: bodies, settings: settings)
            anchor.addChild(root)
            installedGestures = view.installGestures([.translation, .rotation, .scale], for: root)
        }

        private func recenter(in view: ARView) {
            if let anchor {
                view.scene.removeAnchor(anchor)
            }

            let anchor = AnchorEntity(world: Self.anchorTransform(for: view))
            self.anchor = anchor
            view.scene.addAnchor(anchor)
        }

        private static func gestureRoot(for bodies: [CelestialBody], settings: SolarSystemSceneSettings) -> ModelEntity {
            let placements = ExperienceSceneLayout.placements(for: bodies, settings: settings)
            let arPlacements = placements.map { placement -> ARBodyPlacement in
                ARBodyPlacement(
                    body: placement.body,
                    displayRadius: max(0.0025, placement.displayRadius * 0.11),
                    position: SIMD3<Float>(
                        placement.position.x * 0.11,
                        placement.position.y * 0.11,
                        placement.position.z * 0.11
                    )
                )
            }
            let bounds = ARPlacementBounds(placements: arPlacements)
            let root = ModelEntity()
            root.position = bounds.center
            root.collision = CollisionComponent(shapes: [.generateBox(size: bounds.size)])

            for placement in arPlacements {
                let entity = entity(for: placement)
                entity.position = placement.position - bounds.center
                root.addChild(entity)
            }

            return root
        }

        private static func anchorTransform(for view: ARView) -> simd_float4x4 {
            var translation = matrix_identity_float4x4
            translation.columns.3.y = -0.08
            translation.columns.3.z = -1.25
            return simd_mul(view.cameraTransform.matrix, translation)
        }

        private static func entity(for placement: ARBodyPlacement) -> Entity {
            if placement.body.type == .satellite {
                return satelliteEntity(scale: placement.displayRadius)
            }

            let mesh = MeshResource.generateSphere(radius: placement.displayRadius)
            let material = material(for: placement.body)
            return ModelEntity(mesh: mesh, materials: [material])
        }

        private static func material(for body: CelestialBody) -> UnlitMaterial {
            var material = UnlitMaterial(color: fallbackColor(for: body))

            if let texture = textureResource(for: body) {
                material.color = .init(tint: .white, texture: .init(texture))
            }

            return material
        }

        private static func textureResource(for body: CelestialBody) -> TextureResource? {
            guard let textureName = body.textureName,
                  let url = Bundle.main.url(
                    forResource: textureName,
                    withExtension: "jpg",
                    subdirectory: "Planets"
                  ) else {
                return nil
            }

            return try? TextureResource.load(contentsOf: url)
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

            root.scale = SIMD3<Float>(repeating: max(1, scale * 8))
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
