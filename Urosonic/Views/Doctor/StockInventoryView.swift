// StockInventoryView.swift — Live medical supply and inventory tracker
// Aura MedTech Design System

import SwiftUI

struct StockInventoryView: View {
    @EnvironmentObject var router:    AppRouter
    @EnvironmentObject var authState: AuthState
    @State private var items:     [APIStockItem] = []
    @State private var showAdd  = false
    @State private var appeared = false
    @State private var isLoading = true
    @State private var search   = ""

    @Environment(\.dismiss) var dismiss

    var filtered: [APIStockItem] {
        search.isEmpty ? items : items.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.slateBg.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header Bar
                BackButtonRow(
                    title: "Equipment & Supplies",
                    subtitle: "\(items.count) total tracked items"
                ) {
                    if !router.doctorHomePath.isEmpty {
                        router.doctorHomePath.removeLast()
                    } else {
                        dismiss()
                    }
                }

                if isLoading && items.isEmpty {
                    VStack {
                        Spacer()
                        ProgressView().tint(Color.appTeal)
                        Spacer()
                    }
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 14) {
                            // Summary Cards (OK / Low / Critical)
                            HStack(spacing: 10) {
                                summaryChip(
                                    count: items.filter { $0.stockStatus == .ok }.count,
                                    label: "Optimal",
                                    color: Color.uroSuccess,
                                    bg: Color.uroSuccessBg
                                )
                                summaryChip(
                                    count: items.filter { $0.stockStatus == .low }.count,
                                    label: "Low Stock",
                                    color: Color.uroWarning,
                                    bg: Color.uroWarningBg
                                )
                                summaryChip(
                                    count: items.filter { $0.stockStatus == .critical }.count,
                                    label: "Critical",
                                    color: Color.uroDanger,
                                    bg: Color.uroDangerBg
                                )
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                            .offset(y: appeared ? 0 : 16).opacity(appeared ? 1 : 0)

                            // Search Input
                            HStack(spacing: 10) {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(Color.appTeal)
                                TextField("Search inventory items...", text: $search)
                                    .font(.system(size: 14))

                                if !search.isEmpty {
                                    Button { search = "" } label: {
                                        Image(systemName: "xmark.circle.fill").foregroundColor(Color.slateMuted)
                                    }
                                }
                            }
                            .padding(.horizontal, 14)
                            .frame(height: 46)
                            .background(Color.slateCard)
                            .cornerRadius(14)
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.slateBorder, lineWidth: 1))
                            .padding(.horizontal, 16)

                            // Items List
                            ForEach(Array(filtered.enumerated()), id: \.element.id) { idx, item in
                                inventoryItemCard(item, idx: idx)
                            }

                            Spacer(minLength: 100)
                        }
                    }
                }
            }

            // Floating Action Button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button {
                        showAdd = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .bold))
                            Text("Add Item")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [Color.appTeal, Color(hex: "0F766E")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(Capsule())
                        .shadow(color: Color.appTeal.opacity(0.4), radius: 12, y: 6)
                    }
                    .tactileButton()
                    .padding(.trailing, 20)
                    .padding(.bottom, 36)
                }
            }
        }
        .sheet(isPresented: $showAdd) { addStockSheet }
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) { appeared = true }
            Task { await loadData() }
        }
        .refreshable { await loadData() }
    }

    private func loadData() async {
        isLoading = true
        let response = try? await APIClient.shared.getStock(doctorId: authState.userId)
        items = response?.items ?? []
        isLoading = false
    }

    @ViewBuilder
    func summaryChip(count: Int, label: String, color: Color, bg: Color) -> some View {
        VStack(spacing: 3) {
            Text("\(count)")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color.slateSub)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(bg.opacity(0.8))
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(color.opacity(0.25), lineWidth: 0.8))
    }

    @ViewBuilder
    func inventoryItemCard(_ item: APIStockItem, idx: Int) -> some View {
        let statusColor: Color = item.stockStatus == .ok ? Color.uroSuccess : item.stockStatus == .low ? Color.uroWarning : Color.uroDanger

        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(Color.slateText)
                    Text(item.category)
                        .font(.system(size: 12))
                        .foregroundColor(Color.slateSub)
                }
                Spacer()
                StatusBadgeView(status: item.status)
            }

            VStack(spacing: 5) {
                HStack {
                    Text("In Stock: \(item.currentQty) \(item.unit)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color.slateText)
                    Spacer()
                    Text("Threshold: \(item.threshold) \(item.unit)")
                        .font(.system(size: 11))
                        .foregroundColor(Color.slateSub)
                }
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.slateBorder).frame(height: 8)
                        Capsule().fill(statusColor).frame(width: max(g.size.width * CGFloat(item.percentage) / 100, 4), height: 8)
                    }
                }.frame(height: 8)
            }

            if item.stockStatus != .ok {
                Button {
                    Task {
                        _ = try? await APIClient.shared.restockItem(id: item.id, quantity: item.threshold)
                        await loadData()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12, weight: .bold))
                        Text("Quick Restock (+\(item.threshold) \(item.unit))")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(statusColor)
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
                    .background(statusColor.opacity(0.1))
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(statusColor.opacity(0.3), lineWidth: 1))
                }
                .tactileButton()
            }
        }
        .padding(14)
        .uroCard(cornerRadius: 18)
        .padding(.horizontal, 16)
        .offset(x: appeared ? 0 : 20)
        .opacity(appeared ? 1 : 0)
        .animation(.spring(response: 0.4).delay(Double(idx) * 0.04), value: appeared)
    }

    // Add Sheet State
    @State private var newName     = ""
    @State private var newCategory = "Medical Supplies"
    @State private var newQty      = ""
    @State private var newThresh   = ""
    @State private var newUnit     = "units"

    @ViewBuilder
    var addStockSheet: some View {
        NavigationStack {
            Form {
                Section("Item Details") {
                    TextField("Item Name", text: $newName)
                    Picker("Category", selection: $newCategory) {
                        ForEach(["Medical Supplies", "PPE", "Consumables", "Equipment"], id: \.self) { Text($0) }
                    }
                    HStack {
                        TextField("Current Count", text: $newQty).keyboardType(.numberPad)
                        TextField("Min Threshold", text: $newThresh).keyboardType(.numberPad)
                    }
                    TextField("Unit (units/boxes/kits…)", text: $newUnit)
                }
            }
            .navigationTitle("Add Equipment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showAdd = false }
                        .foregroundColor(Color.slateSub)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        Task {
                            guard !newName.isEmpty, let c = Int(newQty), let t = Int(newThresh) else { return }
                            if let item = try? await APIClient.shared.addStockItem(
                                doctorId: authState.userId,
                                name: newName,
                                category: newCategory,
                                currentQty: c,
                                threshold: t,
                                unit: newUnit
                            ) {
                                withAnimation(.spring()) {
                                    items.insert(item, at: 0)
                                }
                            }
                            showAdd = false
                        }
                    }
                    .disabled(newName.isEmpty || newQty.isEmpty || newThresh.isEmpty)
                    .foregroundColor(Color.appTeal)
                }
            }
        }
    }
}
