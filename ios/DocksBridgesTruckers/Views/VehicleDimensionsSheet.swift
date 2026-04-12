import SwiftUI

struct VehicleDimensionsSheet: View {
    @Environment(AppViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
    @State private var editHeight: String = ""
    @State private var editWeight: String = ""
    @State private var editLength: String = ""
    @State private var validationError: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    HStack(spacing: 10) {
                        Image(systemName: viewModel.truckProfile.type.icon)
                            .font(.title3.bold())
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(AppTheme.cardGradient, in: RoundedRectangle(cornerRadius: 12))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(viewModel.truckProfile.type.label)
                                .font(.headline)
                            Text("Adjust dimensions for hazard checks")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }

                    VStack(spacing: 12) {
                        dimensionRow(icon: "arrow.up.and.down", label: "Height", unit: "m", text: $editHeight, hint: "Vehicle height in metres")
                        dimensionRow(icon: "scalemass", label: "Weight", unit: "t", text: $editWeight, hint: "Gross vehicle mass in tonnes")
                        dimensionRow(icon: "arrow.left.and.right", label: "Length", unit: "m", text: $editLength, hint: "Total vehicle length in metres")
                    }

                    if let error = validationError {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                    }

                    truckTypeSelector

                    Button {
                        saveDimensions()
                    } label: {
                        Text("Save & Close")
                            .font(.subheadline.bold())
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(AppTheme.accent, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Vehicle Dimensions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onAppear {
            editHeight = String(format: "%.1f", viewModel.truckProfile.height)
            editWeight = String(format: "%.1f", viewModel.truckProfile.weight)
            editLength = String(format: "%.1f", viewModel.truckProfile.length)
        }
    }

    private func dimensionRow(icon: String, label: String, unit: String, text: Binding<String>, hint: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body.bold())
                .foregroundStyle(AppTheme.accent)
                .frame(width: 36, height: 36)
                .background(AppTheme.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.subheadline.bold())
                Text(hint)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 4) {
                TextField("0.0", text: text)
                    .keyboardType(.decimalPad)
                    .font(.headline.monospacedDigit())
                    .multilineTextAlignment(.trailing)
                    .frame(width: 60)

                Text(unit)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private var truckTypeSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quick Set by Vehicle Type")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(TruckType.allCases, id: \.self) { type in
                        Button {
                            viewModel.updateTruckType(type)
                            editHeight = String(format: "%.1f", type.defaultHeight)
                            editWeight = String(format: "%.1f", type.defaultWeight)
                            editLength = String(format: "%.1f", type.defaultLength)
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: type.icon)
                                    .font(.caption)
                                Text(type.label)
                                    .font(.caption2.bold())
                            }
                            .foregroundStyle(viewModel.truckProfile.type == type ? .white : .primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                viewModel.truckProfile.type == type ? AppTheme.accent : Color(.tertiarySystemGroupedBackground),
                                in: RoundedRectangle(cornerRadius: 10)
                            )
                        }
                    }
                }
            }
            .scrollIndicators(.hidden)
            .contentMargins(.horizontal, 0)
        }
    }

    private func saveDimensions() {
        guard let h = Double(editHeight), h > 0, h <= 10 else {
            validationError = "Height must be between 0 and 10m"
            return
        }
        guard let w = Double(editWeight), w > 0, w <= 200 else {
            validationError = "Weight must be between 0 and 200t"
            return
        }
        guard let l = Double(editLength), l > 0, l <= 60 else {
            validationError = "Length must be between 0 and 60m"
            return
        }
        validationError = nil
        viewModel.truckProfile.height = h
        viewModel.truckProfile.weight = w
        viewModel.truckProfile.length = l
        viewModel.saveProfile()
        dismiss()
    }
}
