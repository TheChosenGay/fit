import SwiftUI

// MARK: - Design System Preview Gallery

@available(iOS 15.0, *)
struct DesignSystemPreview: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.xxl) {
                colorSection
                typographySection
                iconSection
                spacingSection
                cornerRadiusSection
                shadowSection
            }
            .padding(DSSpacing.lg)
        }
        .background(Color.dsBackground)
    }

    // MARK: - Colors

    private var colorSection: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            Text("Colors")
                .dsTextStyle(.title1)
                .foregroundColor(.dsLabel)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: DSSpacing.sm) {
                colorSwatch("primary", Color.dsPrimary)
                colorSwatch("primaryVariant", Color.dsPrimaryVariant)
                colorSwatch("secondary", Color.dsSecondary)
                colorSwatch("secondaryVariant", Color.dsSecondaryVariant)
                colorSwatch("background", Color.dsBackground)
                colorSwatch("bgSecondary", Color.dsBackgroundSecondary)
                colorSwatch("surface", Color.dsSurface)
                colorSwatch("surfaceSecondary", Color.dsSurfaceSecondary)
                colorSwatch("label", Color.dsLabel)
                colorSwatch("labelSecondary", Color.dsLabelSecondary)
                colorSwatch("labelTertiary", Color.dsLabelTertiary)
                colorSwatch("separator", Color.dsSeparator)
                colorSwatch("fill", Color.dsFill)
                colorSwatch("error", Color.dsError)
                colorSwatch("success", Color.dsSuccess)
                colorSwatch("warning", Color.dsWarning)
            }
        }
    }

    private func colorSwatch(_ name: String, _ color: Color) -> some View {
        VStack(spacing: DSSpacing.xxs) {
            RoundedRectangle(cornerRadius: DSCornerRadius.small)
                .fill(color)
                .frame(height: 48)
                .overlay(
                    RoundedRectangle(cornerRadius: DSCornerRadius.small)
                        .stroke(Color.dsSeparator, lineWidth: 0.5)
                )
            Text(name)
                .dsTextStyle(.caption2)
                .foregroundColor(.dsLabelSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    // MARK: - Typography

    private var typographySection: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            Text("Typography")
                .dsTextStyle(.title1)
                .foregroundColor(.dsLabel)

            ForEach(DSTextStyle.allCases, id: \.name) { style in
                HStack {
                    Text(style.name)
                        .dsTextStyle(.caption1)
                        .foregroundColor(.dsLabelTertiary)
                        .frame(width: 90, alignment: .leading)
                    Text("The quick brown fox")
                        .dsTextStyle(style)
                        .foregroundColor(.dsLabel)
                }
            }
        }
    }

    // MARK: - Icons

    private var iconSection: some View {
        VStack(alignment: .leading, spacing: DSSpacing.lg) {
            Text("Icons")
                .dsTextStyle(.title1)
                .foregroundColor(.dsLabel)

            // All icons at regular weight
            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                Text("All Icons")
                    .dsTextStyle(.headline)
                    .foregroundColor(.dsLabelSecondary)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: DSSpacing.md) {
                    ForEach(DSIconName.allCases, id: \.rawValue) { name in
                        VStack(spacing: DSSpacing.xxs) {
                            DSIcon(name: name)
                                .foregroundColor(.dsLabel)
                            Text(name.rawValue)
                                .dsTextStyle(.caption2)
                                .foregroundColor(.dsLabelTertiary)
                        }
                    }
                }
            }

            // Weight comparison — pick 4 representative icons to fit screen
            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                Text("Weights")
                    .dsTextStyle(.headline)
                    .foregroundColor(.dsLabelSecondary)

                let sampleIcons: [DSIconName] = [.camera, .settings, .activity, .user]

                ForEach(DSIconWeight.allCases, id: \.rawValue) { weight in
                    HStack {
                        Text(weight.name)
                            .dsTextStyle(.caption1)
                            .foregroundColor(.dsLabelTertiary)
                            .frame(width: 56, alignment: .leading)
                        HStack(spacing: DSSpacing.lg) {
                            ForEach(sampleIcons, id: \.rawValue) { name in
                                DSIcon(name: name, weight: weight)
                                    .foregroundColor(.dsLabel)
                            }
                        }
                        Spacer()
                    }
                }
            }

            // Color variants — 2-column grid
            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                Text("Color Variants")
                    .dsTextStyle(.headline)
                    .foregroundColor(.dsLabelSecondary)

                let colorPairs: [(String, Color)] = [
                    ("primary", .dsPrimary),
                    ("secondary", .dsSecondary),
                    ("label", .dsLabel),
                    ("error", .dsError),
                    ("success", .dsSuccess),
                    ("warning", .dsWarning)
                ]

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DSSpacing.sm) {
                    ForEach(colorPairs, id: \.0) { name, color in
                        HStack(spacing: DSSpacing.xs) {
                            DSIcon(name: .camera, weight: .medium)
                                .foregroundColor(color)
                            DSIcon(name: .settings, weight: .medium)
                                .foregroundColor(color)
                            Text(name)
                                .dsTextStyle(.caption1)
                                .foregroundColor(.dsLabelTertiary)
                        }
                    }
                }
            }

            // Size comparison
            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                Text("Sizes")
                    .dsTextStyle(.headline)
                    .foregroundColor(.dsLabelSecondary)

                HStack(spacing: DSSpacing.md) {
                    ForEach([16, 20, 24, 32, 40] as [CGFloat], id: \.self) { sz in
                        VStack(spacing: DSSpacing.xxs) {
                            DSIcon(name: .camera, weight: .regular, size: sz)
                                .foregroundColor(.dsPrimary)
                            Text("\(Int(sz))pt")
                                .dsTextStyle(.caption2)
                                .foregroundColor(.dsLabelTertiary)
                        }
                    }
                }
            }

            // Modifier usage demo
            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                Text("Icon Modifier")
                    .dsTextStyle(.headline)
                    .foregroundColor(.dsLabelSecondary)

                VStack(alignment: .leading, spacing: DSSpacing.sm) {
                    Text("Settings")
                        .dsTextStyle(.body)
                        .foregroundColor(.dsLabel)
                        .dsIcon(.settings, color: .dsPrimary)

                    Text("Camera")
                        .dsTextStyle(.body)
                        .foregroundColor(.dsLabel)
                        .dsIcon(.camera, weight: .bold, color: .dsSecondary)

                    Text("Activity")
                        .dsTextStyle(.body)
                        .foregroundColor(.dsLabel)
                        .dsIcon(.activity, weight: .light, size: 16, color: .dsSuccess, position: .trailing, spacing: DSSpacing.xxs)

                    Text("Alert")
                        .dsTextStyle(.headline)
                        .foregroundColor(.dsError)
                        .dsIcon(.alertTriangle, weight: .medium, color: .dsError)
                }
                .padding(DSSpacing.md)
                .background(Color.dsSurface)
                .cornerRadius(DSCornerRadius.medium)
            }
        }
    }

    // MARK: - Spacing

    private var spacingSection: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            Text("Spacing")
                .dsTextStyle(.title1)
                .foregroundColor(.dsLabel)

            spacingBar("xxs", DSSpacing.xxs)
            spacingBar("xs", DSSpacing.xs)
            spacingBar("sm", DSSpacing.sm)
            spacingBar("md", DSSpacing.md)
            spacingBar("lg", DSSpacing.lg)
            spacingBar("xl", DSSpacing.xl)
            spacingBar("xxl", DSSpacing.xxl)
            spacingBar("xxxl", DSSpacing.xxxl)
            spacingBar("huge", DSSpacing.huge)
        }
    }

    private func spacingBar(_ name: String, _ value: CGFloat) -> some View {
        HStack(spacing: DSSpacing.xs) {
            Text("\(name) (\(Int(value)))")
                .dsTextStyle(.caption1)
                .foregroundColor(.dsLabelSecondary)
                .frame(width: 80, alignment: .leading)
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.dsPrimary)
                .frame(width: value * 3, height: 12)
        }
    }

    // MARK: - Corner Radius

    private var cornerRadiusSection: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            Text("Corner Radius")
                .dsTextStyle(.title1)
                .foregroundColor(.dsLabel)

            HStack(spacing: DSSpacing.md) {
                radiusBox("small", DSCornerRadius.small)
                radiusBox("medium", DSCornerRadius.medium)
                radiusBox("large", DSCornerRadius.large)
                radiusBox("xl", DSCornerRadius.xl)
            }
        }
    }

    private func radiusBox(_ name: String, _ radius: CGFloat) -> some View {
        VStack(spacing: DSSpacing.xxs) {
            RoundedRectangle(cornerRadius: radius)
                .fill(Color.dsPrimary.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: radius)
                        .stroke(Color.dsPrimary, lineWidth: 1.5)
                )
                .frame(width: 56, height: 56)
            Text(name)
                .dsTextStyle(.caption2)
                .foregroundColor(.dsLabelSecondary)
        }
    }

    // MARK: - Shadows

    private var shadowSection: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            Text("Shadows")
                .dsTextStyle(.title1)
                .foregroundColor(.dsLabel)

            HStack(spacing: DSSpacing.xl) {
                shadowCard("subtle", .subtle)
                shadowCard("medium", .medium)
                shadowCard("prominent", .prominent)
            }
        }
    }

    private func shadowCard(_ name: String, _ level: DSShadow.Level) -> some View {
        VStack(spacing: DSSpacing.xs) {
            RoundedRectangle(cornerRadius: DSCornerRadius.medium)
                .fill(Color.dsSurface)
                .frame(width: 80, height: 60)
                .dsShadow(level)
            Text(name)
                .dsTextStyle(.caption2)
                .foregroundColor(.dsLabelSecondary)
        }
    }
}

// MARK: - Previews

#Preview("Design System - Light") {
    DesignSystemPreview()
}

#Preview("Design System - Dark") {
    DesignSystemPreview()
        .preferredColorScheme(.dark)
}
