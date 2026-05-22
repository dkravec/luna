import SwiftUI
import simd

struct ScreenshotARPreviewView: View {
    let bodies: [CelestialBody]
    let settings: ExperienceSceneSettings
    let simulationDate: Date

    private var solarSystemBodies: [CelestialBody] {
        bodies
            .filter { body in
                body.type == .star
                    || body.type == .planet
                    || body.type == .moon
                    || body.type == .dwarfPlanet
            }
            .sorted { $0.displayOrder < $1.displayOrder }
    }

    var body: some View {
        GeometryReader { proxy in
            let snapshot = ExperienceSceneEngine.snapshot(
                for: solarSystemBodies,
                settings: settings,
                simulationDate: simulationDate
            )
            let layout = ScreenshotARPreviewLayout(snapshot: snapshot, size: proxy.size)

            ZStack {
                Image("ScreenshotRoom")
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()

                LinearGradient(
                    colors: [.black.opacity(0.05), .black.opacity(0.26)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                ForEach(layout.orbits) { orbit in
                    Path { path in
                        guard let first = orbit.points.first else { return }
                        path.move(to: first)
                        for point in orbit.points.dropFirst() {
                            path.addLine(to: point)
                        }
                        path.closeSubpath()
                    }
                    .stroke(.white.opacity(0.24), lineWidth: 1)
                }

                ForEach(layout.placements) { placement in
                    VStack(spacing: 5) {
                        BodyVisual(celestialBody: placement.body, size: placement.bodySize)
                            .shadow(color: .black.opacity(0.24), radius: 10, x: 0, y: 5)

                        if settings.showLabels {
                            Text(placement.body.name)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 4)
                                .background(.black.opacity(0.48), in: Capsule(style: .continuous))
                        }
                    }
                    .position(placement.position)
                }

                VStack(spacing: 8) {
                    Circle()
                        .stroke(Color.accentColor.opacity(0.9), lineWidth: 2)
                        .frame(width: 64, height: 64)
                        .overlay {
                            Circle()
                                .fill(Color.accentColor.opacity(0.9))
                                .frame(width: 8, height: 8)
                        }

                    Text("Readable scale")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.black.opacity(0.46), in: Capsule(style: .continuous))
                }
                .position(x: proxy.size.width * 0.5, y: proxy.size.height * 0.56)
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("screenshot.arPreview")
        }
    }
}

private struct ScreenshotARPlacement: Identifiable {
    let id: String
    let body: CelestialBody
    let bodySize: CGFloat
    let position: CGPoint
}

private struct ScreenshotAROrbit: Identifiable {
    let id: String
    let points: [CGPoint]
}

private struct ScreenshotARPreviewLayout {
    let placements: [ScreenshotARPlacement]
    let orbits: [ScreenshotAROrbit]

    init(snapshot: ExperienceSceneSnapshot, size: CGSize) {
        let floorCenter = CGPoint(x: size.width * 0.5, y: size.height * 0.66)
        let maxWidth = max(size.width * 0.78, 1)
        let maxDepth = max(size.height * 0.28, 1)
        let bounds = snapshot.bounds
        let xScale = maxWidth / CGFloat(max(bounds.size.x, 0.001))
        let zScale = maxDepth / CGFloat(max(bounds.size.z, 0.001))
        let scale = min(xScale, zScale)

        func project(_ point: SIMD3<Float>) -> CGPoint {
            CGPoint(
                x: floorCenter.x + CGFloat(point.x - bounds.center.x) * scale,
                y: floorCenter.y + CGFloat(point.z - bounds.center.z) * scale * 0.42 - CGFloat(point.y) * scale
            )
        }

        placements = snapshot.bodies
            .filter { $0.body.type != .star }
            .prefix(10)
            .map { body in
                ScreenshotARPlacement(
                    id: body.id,
                    body: body.body,
                    bodySize: max(18, min(44, CGFloat(body.displayRadius) * scale * 2.8)),
                    position: project(body.position)
                )
            }

        orbits = snapshot.orbitPaths.prefix(9).map { path in
            ScreenshotAROrbit(
                id: path.id,
                points: path.points.enumerated().compactMap { index, point in
                    index.isMultiple(of: 4) ? project(point) : nil
                }
            )
        }
    }
}
