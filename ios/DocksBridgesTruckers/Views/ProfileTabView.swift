import SwiftUI

struct ProfileTabView: View {
    @Environment(AppViewModel.self) private var viewModel
    @Environment(NotificationService.self) private var notificationService
    @Environment(NetworkMonitor.self) private var networkMonitor
    @State private var editName: String = ""
    @State private var editHeight: String = ""
    @State private var editWeight: String = ""
    @State private var editWidth: String = ""
    @State private var editPlate: String = ""
    @State private var showSaved: Bool = false
    @State private var saveTask: Task<Void, Never>?
    @State private var showReportHazardAlert: Bool = false
    @State private var showReportDockAlert: Bool = false
    @State private var validationError: String?
    @State private var showResetConfirmation: Bool = false
    @State private var hasUnsavedChanges: Bool = false
    @State private var showEmailUnavailable: Bool = false
    @State private var selectedTruckType: TruckType?
    @State private var isLoadingProfile: Bool = false
    @State private var showShareSheet: Bool = false
    @State private var pdfData: Data?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    heroSection
                    truckFormSection
                    notificationSection
                    exportPDFSection
                    quickActionsSection
                    cacheInfoSection
                    settingsSection
                    infoSection
                    versionText
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .navigationTitle("Profile")
            .scrollDismissesKeyboard(.interactively)
            .background(Color(.systemGroupedBackground))
            .onAppear {
                if !hasUnsavedChanges {
                    loadProfile()
                }
            }
            .onDisappear {
                saveTask?.cancel()
                if hasUnsavedChanges {
                    silentSaveProfile()
                }
            }
            .onChange(of: viewModel.truckProfile.type) { _, _ in
                loadProfile()
            }
            .sensoryFeedback(.selection, trigger: selectedTruckType)
            .alert("Email Not Available", isPresented: $showEmailUnavailable) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("No email app is configured on this device. Please email support@docksbridgestruckers.com manually.")
            }
        }
    }

    private var heroSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(AppTheme.accent.opacity(0.1))
                    .frame(width: 88, height: 88)
                Image(systemName: "truck.box.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(AppTheme.accent)
            }

            Text(viewModel.truckProfile.name.isEmpty ? "Set Up Your Truck" : viewModel.truckProfile.name)
                .font(.title2.bold())

            Text("Your truck details help find the safest route")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    private var truckFormSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Truck Settings")
                .font(.headline)

            VStack(spacing: 10) {
                formField(title: "Driver / Truck Name", text: $editName, icon: "person.fill")

                VStack(alignment: .leading, spacing: 6) {
                    Label("Vehicle Type", systemImage: "truck.box.fill")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)

                    ScrollView(.horizontal) {
                        HStack(spacing: 8) {
                            ForEach(TruckType.allCases, id: \.self) { type in
                                Button {
                                    selectedTruckType = type
                                    viewModel.updateTruckType(type)
                                    loadProfile()
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

                HStack(spacing: 10) {
                    formField(title: "Height (m)", text: $editHeight, icon: "arrow.up.and.down", keyboard: .decimalPad)
                    formField(title: "Weight (t)", text: $editWeight, icon: "scalemass", keyboard: .decimalPad)
                    formField(title: "Width (m)", text: $editWidth, icon: "arrow.left.and.right", keyboard: .decimalPad)
                }

                formField(title: "Plate Number", text: $editPlate, icon: "rectangle.fill", keyboard: .default)
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
                .background(Color.red.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
            }

            Button {
                saveProfile()
            } label: {
                Label(showSaved ? "Saved!" : "Save Profile", systemImage: showSaved ? "checkmark.circle.fill" : "square.and.arrow.down")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(showSaved ? .green : AppTheme.accent)
            .controlSize(.large)
            .sensoryFeedback(.success, trigger: showSaved)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private var notificationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "bell.fill")
                    .foregroundStyle(AppTheme.accent)
                Text("Notifications")
                    .font(.headline)
            }

            if notificationService.isAuthorized {
                HStack(spacing: 12) {
                    Image(systemName: "bell.badge.fill")
                        .font(.title3)
                        .foregroundStyle(AppTheme.accent)
                        .frame(width: 40, height: 40)
                        .background(AppTheme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Hazard & Dock Alerts")
                            .font(.subheadline.bold())
                        Text("Get notified about changes to hazards and docks near your route")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Toggle("", isOn: Binding(
                        get: { notificationService.notificationsEnabled },
                        set: { notificationService.notificationsEnabled = $0 }
                    ))
                    .tint(AppTheme.accent)
                    .labelsHidden()
                }
                .padding(12)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
            } else {
                Button {
                    Task { await notificationService.requestAuthorization() }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "bell.slash.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .frame(width: 40, height: 40)
                            .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Enable Notifications")
                                .font(.subheadline.bold())
                                .foregroundStyle(.primary)
                            Text("Get real-time alerts about hazards and dock status changes")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(12)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
                }
            }
        }
    }

    private var exportPDFSection: some View {
        Button {
            generatePDF()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "doc.richtext")
                    .font(.title3)
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 40, height: 40)
                    .background(AppTheme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Export PDF Report")
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                    Text("Truck profile, hazards & docks summary")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "square.and.arrow.up")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        }
        .sheet(isPresented: $showShareSheet) {
            if let pdfData {
                ShareSheet(items: [pdfData])
            }
        }
    }

    private func generatePDF() {
        let vm = viewModel
        let data = PDFExportService.generateReport(
            truckProfile: vm.truckProfile,
            hazards: vm.hazards,
            docks: vm.docks,
            hazardStatusProvider: { vm.hazardStatus($0) }
        )
        pdfData = data
        showShareSheet = true
    }

    private var quickActionsSection: some View {
        HStack(spacing: 10) {
            Button {
                showReportHazardAlert = true
            } label: {
                quickAction(title: "Report\nHazard", icon: "exclamationmark.triangle.fill", color: AppTheme.accent)
            }
            Button {
                showReportDockAlert = true
            } label: {
                quickAction(title: "Report\nDock", icon: "mappin.circle.fill", color: AppTheme.accent)
            }
        }
        .alert("Report a Hazard", isPresented: $showReportHazardAlert) {
            Button("Send Email") {
                openReportEmail(subject: "New Hazard Report", body: "Hazard type:%0ALocation:%0AClearance height:%0AAdditional details:")
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Help fellow truckers! Send details about a low bridge, wire, or weight limit you've encountered.")
        }
        .alert("Report a Dock", isPresented: $showReportDockAlert) {
            Button("Send Email") {
                openReportEmail(subject: "New Dock Report", body: "Dock name:%0ABusiness:%0AAddress:%0AAdditional details:")
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Know a loading dock? Send us the details and we'll add it to the database.")
        }
    }

    private func quickAction(title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 40, height: 40)
                .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
            Text(title)
                .font(.caption.bold())
                .multilineTextAlignment(.leading)
                .foregroundStyle(.primary)
            Spacer()
            Image(systemName: "plus")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private var cacheInfoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: networkMonitor.isConnected ? "wifi" : "wifi.slash")
                    .foregroundStyle(networkMonitor.isConnected ? .green : .red)
                Text("Connection & Cache")
                    .font(.headline)
            }

            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    Image(systemName: networkMonitor.isConnected ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(networkMonitor.isConnected ? .green : .red)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(networkMonitor.isConnected ? "Connected" : "Offline")
                            .font(.subheadline.bold())
                        if networkMonitor.connectionType != nil {
                            Text(networkMonitor.connectionDescription)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }

                Divider()

                HStack(spacing: 12) {
                    Image(systemName: "internaldrive.fill")
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Cached Data")
                            .font(.subheadline.bold())
                        Text("\(viewModel.hazards.count) hazards · \(viewModel.docks.count) docks")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let refresh = viewModel.lastRefreshFormatted {
                            Text("Last updated \(refresh)")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    Spacer()
                }
            }
            .padding(12)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        }
    }

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "info.circle")
                    .foregroundStyle(.secondary)
                Text("Data sourced from OpenStreetMap and community reports. Clearances may change due to road works or resurfacing. Always verify signs on approach.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "hand.raised.fill")
                    .foregroundStyle(.secondary)
                Text("Your truck profile is stored on this device only. We do not collect or share your personal data.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "gearshape.fill")
                    .foregroundStyle(.secondary)
                Text("Settings")
                    .font(.headline)
            }

            Button {
                showResetConfirmation = true
            } label: {
                settingsRow(icon: "arrow.counterclockwise", iconColor: AppTheme.accent, title: "Reset to Defaults", subtitle: "Resets truck profile to Semi-Trailer defaults")
            }

            NavigationLink {
                PrivacyPolicyView()
            } label: {
                settingsRow(icon: "hand.raised.fill", iconColor: .blue, title: "Privacy Policy", subtitle: "How your data is handled")
            }

            .confirmationDialog("Reset Profile?", isPresented: $showResetConfirmation, titleVisibility: .visible) {
                Button("Reset to Defaults", role: .destructive) {
                    viewModel.updateTruckType(.semi_trailer)
                    loadProfile()
                    hasUnsavedChanges = false
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will reset your truck profile to Semi-Trailer defaults. This cannot be undone.")
            }
        }
    }

    private func settingsRow(icon: String, iconColor: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(iconColor)
                .frame(width: 32, height: 32)
                .background(iconColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(10)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private var versionText: some View {
        VStack(spacing: 4) {
            Text("Docks & Bridges Trucker")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"))")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Text("Made for Australian truckers 🇦🇺")
                .font(.caption2)
                .foregroundStyle(.quaternary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
        .padding(.bottom, 8)
    }

    private func formField(title: String, text: Binding<String>, icon: String, keyboard: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: icon)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            TextField(title, text: text)
                .keyboardType(keyboard)
                .padding(10)
                .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
                .onChange(of: text.wrappedValue) { _, _ in
                    guard !isLoadingProfile else { return }
                    hasUnsavedChanges = true
                }
        }
    }

    private func openReportEmail(subject: String, body: String) {
        let urlString = "mailto:support@docksbridgestruckers.com?subject=\(subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? subject)&body=\(body)"
        if let url = URL(string: urlString) {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            } else {
                showEmailUnavailable = true
            }
        }
    }

    private func loadProfile() {
        isLoadingProfile = true
        editName = viewModel.truckProfile.name
        editHeight = String(format: "%.1f", viewModel.truckProfile.height)
        editWeight = String(format: "%.1f", viewModel.truckProfile.weight)
        editWidth = String(format: "%.1f", viewModel.truckProfile.width)
        editPlate = viewModel.truckProfile.plateNumber
        hasUnsavedChanges = false
        isLoadingProfile = false
    }

    private func silentSaveProfile() {
        let height = Double(editHeight)
        let weight = Double(editWeight)
        let width = Double(editWidth)
        guard let h = height, h > 0, h <= 10,
              let w = weight, w > 0, w <= 200,
              let wd = width, wd > 0, wd <= 6 else { return }
        viewModel.truckProfile.name = editName
        viewModel.truckProfile.height = h
        viewModel.truckProfile.weight = w
        viewModel.truckProfile.width = wd
        viewModel.truckProfile.plateNumber = editPlate
        viewModel.saveProfile()
        hasUnsavedChanges = false
    }

    private func saveProfile() {
        var errors: [String] = []
        let height = Double(editHeight)
        let weight = Double(editWeight)
        let width = Double(editWidth)

        if editHeight.isEmpty { errors.append("Height is required") }
        else if height == nil { errors.append("Height is not a valid number") }
        else if let h = height, h <= 0 { errors.append("Height must be positive") }
        else if let h = height, h > 10 { errors.append("Height cannot exceed 10m") }

        if editWeight.isEmpty { errors.append("Weight is required") }
        else if weight == nil { errors.append("Weight is not a valid number") }
        else if let w = weight, w <= 0 { errors.append("Weight must be positive") }
        else if let w = weight, w > 200 { errors.append("Weight cannot exceed 200t") }

        if editWidth.isEmpty { errors.append("Width is required") }
        else if width == nil { errors.append("Width is not a valid number") }
        else if let wd = width, wd <= 0 { errors.append("Width must be positive") }
        else if let wd = width, wd > 6 { errors.append("Width cannot exceed 6m") }

        if !errors.isEmpty {
            validationError = errors.joined(separator: ". ")
            return
        }

        validationError = nil
        viewModel.truckProfile.name = editName
        if let h = height, h > 0 { viewModel.truckProfile.height = h }
        if let w = weight, w > 0 { viewModel.truckProfile.weight = w }
        if let wd = width, wd > 0 { viewModel.truckProfile.width = wd }
        viewModel.truckProfile.plateNumber = editPlate
        viewModel.saveProfile()
        hasUnsavedChanges = false
        showSaved = true
        saveTask?.cancel()
        let task = Task {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            showSaved = false
        }
        saveTask = task
    }
}
