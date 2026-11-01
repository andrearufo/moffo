import SwiftUI
import MoffoCore

/// Moffo itself: a little jelly drop. Everything is drawn in a unit square scaled to `size`.
struct Jelly: View {
    var mood: Mood
    var stage = Stage.adult
    var form: AdultForm?
    var activity = Activity.idle
    var squish = false
    var size: CGFloat = 120
    var detailed = true  // false for the tiny menu bar icon

    var body: some View {
        ZStack {
            switch mood {
            case .egg: egg
            case .dead: tombstone
            default:
                jelly
                    .scaleEffect(detailed ? growth : 1, anchor: .bottom)
                    .overlay(detailed ? props : nil)
            }
        }
        .frame(width: size, height: size)
    }

    private var growth: CGFloat {
        switch stage {
        case .baby: 0.6
        case .child: 0.8
        default: 1
        }
    }

    private var color: Color {
        switch mood {
        case .sick: Color(red: 0.62, green: 0.72, blue: 0.55)
        case .sad: Color(red: 0.62, green: 0.70, blue: 0.95)
        case .ok: Color(red: 1.0, green: 0.70, blue: 0.80)
        default: form == .grumpy ? Color(red: 0.85, green: 0.45, blue: 0.62) : Color(red: 1.0, green: 0.55, blue: 0.72)
        }
    }

    /// Little emoji props that bob along with the squish while an activity runs.
    @ViewBuilder private var props: some View {
        let s = size, up: CGFloat = squish ? -s * 0.04 : 0
        switch activity {
        case .eating: emoji("🍓", 0.16).offset(x: s * 0.2, y: s * 0.32 + up)
        case .healing: emoji("💊", 0.14).offset(x: s * 0.2, y: s * 0.32 + up)
        case .studying: emoji("📖", 0.2).offset(y: s * 0.36)
        case .playing: emoji("⚽️", 0.16).offset(x: s * 0.36, y: squish ? -s * 0.3 : s * 0.05)
        case .bathing:
            emoji("🫧", 0.14).offset(x: -s * 0.36, y: squish ? -s * 0.2 : -s * 0.05)
            emoji("🫧", 0.1).offset(x: s * 0.38, y: squish ? s * 0.05 : -s * 0.15)
            emoji("🫧", 0.12).offset(x: s * 0.1, y: squish ? -s * 0.42 : -s * 0.32)
        case .idle, .sleeping: EmptyView()
        }
    }

    private func emoji(_ e: String, _ scale: CGFloat) -> some View {
        Text(e).font(.system(size: size * scale))
            .animation(.easeInOut(duration: 0.5), value: squish)
    }

    private var jelly: some View {
        let s = size
        return ZStack {
            if detailed && form == .shiny {
                Text("✦").font(.system(size: s * 0.16)).foregroundStyle(.yellow)
                    .shadow(color: .orange, radius: 2)
                    .offset(y: -s * 0.46)
                    .scaleEffect(squish ? 1.15 : 0.9)
            }
            DropShape()
                .fill(LinearGradient(colors: [color.opacity(0.85), color], startPoint: .top, endPoint: .bottom))
                .overlay(DropShape().stroke(Color.black.opacity(0.75), lineWidth: max(1, s * 0.025)))
            if detailed {
                Ellipse().fill(.white.opacity(0.6))
                    .frame(width: s * 0.14, height: s * 0.2).rotationEffect(.degrees(25))
                    .offset(x: -s * 0.22, y: -s * 0.05)
            }
            face
        }
        .scaleEffect(x: squish ? 1.07 : 1, y: squish ? 0.93 : 1, anchor: .bottom)
    }

    @ViewBuilder private var face: some View {
        let s = size
        let eyeY = s * 0.1
        let line = max(1, s * 0.03)
        HStack(spacing: s * 0.2) {
            ForEach(0..<2, id: \.self) { _ in
                switch mood {
                case .sleeping:
                    Capsule().fill(.black).frame(width: s * 0.1, height: line)
                case .sick:
                    Text("@").font(.system(size: s * 0.12, weight: .bold))
                default:
                    Ellipse().fill(.black).frame(width: s * 0.08, height: s * 0.11)
                        .overlay(detailed ? Circle().fill(.white).frame(width: s * 0.03).offset(x: s * 0.015, y: -s * 0.02) : nil)
                }
            }
        }
        .overlay(mood == .studying ? glasses : nil)
        .offset(y: eyeY)

        if detailed && form == .grumpy && mood != .sleeping {
            HStack(spacing: s * 0.18) {
                Capsule().fill(.black).frame(width: s * 0.11, height: line).rotationEffect(.degrees(20))
                Capsule().fill(.black).frame(width: s * 0.11, height: line).rotationEffect(.degrees(-20))
            }
            .offset(y: eyeY - s * 0.1)
        }

        if detailed {
            if mood == .happy || mood == .ok {
                HStack(spacing: s * 0.42) {
                    ForEach(0..<2, id: \.self) { _ in
                        Ellipse().fill(Color.red.opacity(0.35)).frame(width: s * 0.11, height: s * 0.06)
                    }
                }
                .offset(y: s * 0.2)
            }
            MouthShape(smile: mood == .happy ? 1 : mood == .ok || mood == .studying ? 0.4 : mood == .sleeping ? 0 : -0.6)
                .stroke(.black, style: StrokeStyle(lineWidth: line, lineCap: .round))
                .frame(width: s * 0.14, height: s * 0.06)
                .offset(y: s * 0.24)
            if mood == .sleeping {
                Text("z z").font(.system(size: s * 0.12, weight: .bold, design: .rounded))
                    .offset(x: s * 0.32, y: -s * 0.3)
            }
            if mood == .sick {
                Ellipse().fill(Color.cyan.opacity(0.8)).frame(width: s * 0.06, height: s * 0.1)
                    .offset(x: s * 0.28, y: -s * 0.05)
            }
        }
    }

    private var glasses: some View {
        HStack(spacing: size * 0.08) {
            ForEach(0..<2, id: \.self) { _ in
                Circle().stroke(.black, lineWidth: max(1, size * 0.02)).frame(width: size * 0.2, height: size * 0.2)
            }
        }
    }

    private var egg: some View {
        Ellipse()
            .fill(Color(red: 1, green: 0.96, blue: 0.86))
            .overlay(Ellipse().stroke(.black.opacity(0.75), lineWidth: max(1, size * 0.025)))
            .overlay(detailed ? Circle().fill(color.opacity(0.6)).frame(width: size * 0.12).offset(x: -size * 0.1, y: size * 0.05) : nil)
            .overlay(detailed ? Circle().fill(color.opacity(0.6)).frame(width: size * 0.08).offset(x: size * 0.12, y: -size * 0.12) : nil)
            .frame(width: size * 0.62, height: size * 0.8)
            .rotationEffect(.degrees(squish ? 4 : -4))
            .offset(y: size * 0.08)
    }

    private var tombstone: some View {
        UnevenRoundedRectangle(topLeadingRadius: size * 0.3, topTrailingRadius: size * 0.3)
            .fill(Color.gray.opacity(0.6))
            .overlay(detailed ? Text("RIP").font(.system(size: size * 0.16, weight: .heavy, design: .rounded)) : nil)
            .frame(width: size * 0.6, height: size * 0.75)
            .offset(y: size * 0.1)
    }
}

/// Gumdrop body: wide soft bottom, dome top with a tiny tip.
struct DropShape: Shape {
    func path(in r: CGRect) -> Path {
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: r.minX + x * r.width, y: r.minY + y * r.height) }
        var path = Path()
        path.move(to: p(0.12, 0.92))
        path.addQuadCurve(to: p(0.88, 0.92), control: p(0.5, 1.0))
        path.addCurve(to: p(0.5, 0.12), control1: p(1.04, 0.62), control2: p(0.82, 0.16))
        path.addCurve(to: p(0.12, 0.92), control1: p(0.18, 0.16), control2: p(-0.04, 0.62))
        path.closeSubpath()
        return path
    }
}

/// smile: 1 = big smile, 0 = flat, negative = frown.
struct MouthShape: Shape {
    var smile: CGFloat
    func path(in r: CGRect) -> Path {
        var path = Path()
        let y = smile >= 0 ? r.minY : r.maxY
        path.move(to: CGPoint(x: r.minX, y: y))
        path.addQuadCurve(to: CGPoint(x: r.maxX, y: y), control: CGPoint(x: r.midX, y: y + smile * r.height * 2))
        return path
    }
}
